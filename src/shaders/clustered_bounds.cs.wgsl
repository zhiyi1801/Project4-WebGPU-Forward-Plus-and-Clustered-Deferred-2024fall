@group(0) @binding(0) var<uniform> cameraUniforms : CameraUniforms;
@group(0) @binding(3) var<storage, read_write> clusters : Clusters;

fn lineIntersectionToZPlane(a : vec3<f32>, b : vec3<f32>, zDistance : f32) -> vec3<f32> {
    let normal = vec3<f32>(0.0, 0.0, 1.0);
    let ab = b - a;
    let t = (zDistance - dot(normal, a)) / dot(normal, ab);
    return a + t * ab;
}
fn clipToView(clip : vec4<f32>) -> vec4<f32> {
    let view = cameraUniforms.inverseProjMatrix * clip;
    return view / vec4<f32>(view.w, view.w, view.w, view.w); 
}
fn screen2View(screen : vec4<f32>) -> vec4<f32> {
    let texCoord = screen.xy / cameraUniforms.outputSize.xy;
    let clip = vec4<f32>(vec2<f32>(texCoord.x, 1.0 - texCoord.y) * 2.0 - vec2<f32>(1.0, 1.0), screen.z, screen.w);
    return clipToView(clip);
}

const tileCount = vec3<u32>(32u, 18u, 48u);
const eyePos = vec3<f32>(0.0);

@compute @workgroup_size(4, 2, 4)
fn main(@builtin(global_invocation_id) global_id : vec3<u32>) {
    let tileIndex = global_id.x +
                    global_id.y * tileCount.x +
                    global_id.z * tileCount.x * tileCount.y;
    let tileSize = vec2<f32>(cameraUniforms.outputSize.x / f32(tileCount.x),
                            cameraUniforms.outputSize.y / f32(tileCount.y));
    let maxPoint_sS = vec4<f32>(vec2<f32>(f32(global_id.x+1u), f32(global_id.y+1u)) * tileSize, 0.0, 1.0);
    let minPoint_sS = vec4<f32>(vec2<f32>(f32(global_id.x), f32(global_id.y)) * tileSize, 0.0, 1.0);
    let maxPoint_vS = screen2View(maxPoint_sS).xyz;
    let minPoint_vS = screen2View(minPoint_sS).xyz;
    let tileNear = -cameraUniforms.zNear * pow(cameraUniforms.zFar/ cameraUniforms.zNear, f32(global_id.z)/f32(tileCount.z));
    let tileFar = -cameraUniforms.zNear * pow(cameraUniforms.zFar/ cameraUniforms.zNear, f32(global_id.z+1u)/f32(tileCount.z));
    let minPointNear = lineIntersectionToZPlane(eyePos, minPoint_vS, tileNear);
    let minPointFar = lineIntersectionToZPlane(eyePos, minPoint_vS, tileFar);
    let maxPointNear = lineIntersectionToZPlane(eyePos, maxPoint_vS, tileNear);
    let maxPointFar = lineIntersectionToZPlane(eyePos, maxPoint_vS, tileFar);
    clusters.bounds[tileIndex].minAABB = min(min(minPointNear, minPointFar),min(maxPointNear, maxPointFar));
    clusters.bounds[tileIndex].maxAABB = max(max(minPointNear, minPointFar),max(maxPointNear, maxPointFar));
}
