#include <metal_stdlib>
using namespace metal;

struct Vertex_POS_NRM {
    float3 position [[attribute(0)]];
    float3 normal [[attribute(1)]];
};

struct Vertex_POS_NRM_UV {
    float3 position [[attribute(0)]];
    float3 normal [[attribute(1)]];
    float2 uv [[attribute(2)]];
};

struct Vertex_POS_NRM_TAN_UV {
    float3 position [[attribute(0)]];
    float3 normal [[attribute(1)]];
    float3 tangent [[attribute(2)]];
    float2 uv [[attribute(3)]];
};

struct FragmentInput {
    float4 position [[position]];
    float4 color;
    float4 normal;
    float4 worldPos;
};

struct RenderInfoBuffer
{
    float4x4 modelMatrix;
    float4x4 vpMatrix;
};


vertex FragmentInput vertex_main_POS_NRM(Vertex_POS_NRM v [[stage_in]],
                                         constant RenderInfoBuffer &renderInfo [[buffer(1)]])
{
    float4x4 MVP = renderInfo.vpMatrix * renderInfo.modelMatrix;
    
    return {
        .position{ MVP * float4(v.position, 1.0) },
        .color { float4(1.0, 1.0, 1.0, 1.0) },
        .normal { renderInfo.modelMatrix * float4(v.normal, 0.0) },
        .worldPos { renderInfo.modelMatrix * float4(v.position, 1.0) }
    };
}

vertex FragmentInput vertex_main_POS_NRM_TAN_UV(Vertex_POS_NRM_TAN_UV v [[stage_in]],
                                                constant RenderInfoBuffer &renderInfo [[buffer(1)]])
{
    float4x4 MVP = renderInfo.vpMatrix * renderInfo.modelMatrix;
    
    return {
        .position{ MVP * float4(v.position, 1.0) },
        .color { float4(1.0, 1.0, 1.0, 1.0) },
        .normal { renderInfo.modelMatrix * float4(v.normal, 0.0) },
        .worldPos { renderInfo.modelMatrix * float4(v.position, 1.0) }
    };
}

vertex FragmentInput vertex_main_POS_NRM_UV(Vertex_POS_NRM_UV v [[stage_in]],
                                            constant RenderInfoBuffer &renderInfo [[buffer(1)]]){
    float4x4 MVP = renderInfo.vpMatrix * renderInfo.modelMatrix;
    
    return {
        .position { MVP * float4(v.position, 1.0) },
        .color { float4(1.0, 1.0, 1.0, 1.0) },
        .normal { renderInfo.modelMatrix * float4(v.normal, 0.0) },
        .worldPos { renderInfo.modelMatrix * float4(v.position, 1.0) }
    };
}

fragment float4 fragment_main(FragmentInput input [[stage_in]]){
    float3 lightRadiance(1.0, 1.0, 1.0);
    float3 lightDir = float3(1, 3, 0) - input.worldPos.xyz;
    lightDir = normalize(lightDir);
    
    float3 normal(input.normal.xyz);
    normal = normalize(normal);
    
    float3 ambient(0.1, 0.1, 0.1);
    float3 diffuse = max(dot(normal, lightDir), 0.0) * lightRadiance;
    
    return float4(diffuse + ambient, 1.0);
}
