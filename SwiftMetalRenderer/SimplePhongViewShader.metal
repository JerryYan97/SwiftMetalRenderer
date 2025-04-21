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

constant uint RENDER_INFO_MASK0_CNST_BASE_COLOR = 0x00000001;
constant uint RENDER_INFO_MASK0_CNST_METALLIC_ROUGHNESS = 0x00000002;

struct RenderInfoBuffer
{
    float4x4 modelMatrix;
    float4x4 vpMatrix;
    
    /// renderInfoMask[0]:
    /// 0x1: Whether the base color is constant;
    /// 0x2: Whether the metallic-roughness are constants;
    uint4 renderInfoMask;
    ///
    
    float4 baseColor;
    float4 pbrInfo; // [0]: metallic; [1]: Roughness;
};


struct VertShaderUnifiedInfo
{
    float3 vertPosition;
    float3 vertNormal;
    RenderInfoBuffer renderInfo;
};

FragmentInput UnifiedVertexShader_main(VertShaderUnifiedInfo info)
{
    float4x4 MVP = info.renderInfo.vpMatrix * info.renderInfo.modelMatrix;
    
    return {
        .position{ MVP * float4(info.vertPosition, 1.0) },
        .color { float4(1.0, 1.0, 1.0, 1.0) },
        .normal { info.renderInfo.modelMatrix * float4(info.vertNormal, 0.0) },
        .worldPos { info.renderInfo.modelMatrix * float4(info.vertPosition, 1.0) }
    };
}


vertex FragmentInput vertex_main_POS_NRM(Vertex_POS_NRM v [[stage_in]],
                                         constant RenderInfoBuffer &renderInfo [[buffer(1)]])
{
    VertShaderUnifiedInfo info {
        .vertPosition{v.position},
        .vertNormal{v.normal},
        .renderInfo = renderInfo
    };
    
    return UnifiedVertexShader_main(info);
}

vertex FragmentInput vertex_main_POS_NRM_TAN_UV(Vertex_POS_NRM_TAN_UV v [[stage_in]],
                                                constant RenderInfoBuffer &renderInfo [[buffer(1)]])
{
    VertShaderUnifiedInfo info {
        .vertPosition{v.position},
        .vertNormal{v.normal},
        .renderInfo = renderInfo
    };
    
    return UnifiedVertexShader_main(info);
}

vertex FragmentInput vertex_main_POS_NRM_UV(Vertex_POS_NRM_UV v [[stage_in]],
                                            constant RenderInfoBuffer &renderInfo [[buffer(1)]]){
    VertShaderUnifiedInfo info {
        .vertPosition{v.position},
        .vertNormal{v.normal},
        .renderInfo = renderInfo
    };
    
    return UnifiedVertexShader_main(info);
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
