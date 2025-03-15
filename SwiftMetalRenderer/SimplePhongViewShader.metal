#include <metal_stdlib>
using namespace metal;

struct Vertex {
    float2 position [[attribute(0)]];
    float3 color [[attribute(1)]];
};

struct FragmentInput {
    float4 position [[position]];
    float4 color;
};

vertex FragmentInput vertex_main(Vertex v [[stage_in]],
                                 constant float4x4 &matrix [[buffer(1)]]){
    return {
        .position { matrix * float4(v.position, 1.0, 1.0) },
        .color { float4(v.color, 1.0) }
    };
}

fragment float4 fragment_main(FragmentInput input [[stage_in]]){
    return input.color;
}
