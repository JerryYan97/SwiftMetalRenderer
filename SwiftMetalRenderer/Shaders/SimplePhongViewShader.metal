#include <metal_stdlib>
#include "PBR.metal"
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
    float4 tangent;
    float4 worldPos;
    float2 uv;
};

constant uint RENDER_INFO_MASK0_CNST_BASE_COLOR = 0x00000001;
constant uint RENDER_INFO_MASK0_CNST_METALLIC_ROUGHNESS = 0x00000002;
constant uint RENDER_INFO_MASK0_CNST_NORMAL = 0x00000004;
constant uint RENDER_INFO_MASK0_CNST_AO = 0x00000008;

struct RenderInfoBuffer
{
    float4x4 modelMatrix;
    float4x4 perspectiveMatrix;
    float4x4 viewMatrix;
    float4 camWorldPos;
};

struct MaterialInfoBuffer
{
    /// materialInfoMask[0]:
    /// 0x1: Whether the base color is constant;
    /// 0x2: Whether the metallic-roughness are constants;
    uint4 materialInfoMask;
    ///
    
    float4 baseColor;
    float4 pbrInfo; // [0]: metallic; [1]: Roughness;
};

struct VertShaderUnifiedInfo
{
    float3 vertPosition;
    float3 vertNormal;
    float3 vertTangent;
    float2 vertUV;
    RenderInfoBuffer renderInfo;
};

FragmentInput UnifiedVertexShader_main(VertShaderUnifiedInfo info)
{
    float4x4 MVP = info.renderInfo.perspectiveMatrix * info.renderInfo.viewMatrix * info.renderInfo.modelMatrix;
    // float4x4 MVP = info.renderInfo.vpMatrix * info.renderInfo.modelMatrix;
    
    return {
        .position { MVP * float4(info.vertPosition, 1.0) },
        .color { float4(1.0, 1.0, 1.0, 1.0) },
        .uv { info.vertUV },
        .normal { info.renderInfo.modelMatrix * float4(info.vertNormal, 0.0) },
        .tangent { info.renderInfo.modelMatrix * float4(info.vertTangent, 0.0)},
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
        .vertTangent{v.tangent},
        .renderInfo = renderInfo
    };
    
    return UnifiedVertexShader_main(info);
}

vertex FragmentInput vertex_main_POS_NRM_UV(Vertex_POS_NRM_UV v [[stage_in]],
                                            constant RenderInfoBuffer &renderInfo [[buffer(1)]]){
    VertShaderUnifiedInfo info {
        .vertPosition{v.position},
        .vertNormal{v.normal},
        .vertUV{v.uv},
        .renderInfo = renderInfo
    };
    
    return UnifiedVertexShader_main(info);
}

fragment float4 fragment_main(FragmentInput input [[stage_in]],
                              constant MaterialInfoBuffer &materialInfo [[buffer(1)]],
                              constant RenderInfoBuffer &renderInfo [[buffer(2)]],
                              texture2d<float> albedoTex [[texture(1)]],
                              sampler albedoSampler[[sampler(1)]],
                              texture2d<float> normalTex[[texture(2)]],
                              sampler normalTexSampler[[sampler(2)]],
                              texture2d<float> roughnessMetallicTex[[texture(3)]],
                              sampler roughnessMetallicSampler[[sampler(3)]],
                              texture2d<float> aoTex[[texture(4)]],
                              sampler aoSampler[[sampler(4)]]){
    
    // constexpr sampler defaultSampler(mag_filter::linear, min_filter::linear);
    
    // float3 lightRadiance(1.0, 1.0, 1.0);
    float3 lightDir = float3(1, 3, 0) - input.worldPos.xyz;
    lightDir = normalize(lightDir);
    
    float3 normal(input.normal.xyz);
    normal = normalize(normal);
    
    float3 ambientLight = float3(0.529, 0.81, 0.92) * 0.05;
    
    float3 refAlbedo = float3(1.0, 1.0, 1.0);
    float3 diffAlbedo = float3(1.0, 1.0, 1.0);
    if((materialInfo.materialInfoMask.x & RENDER_INFO_MASK0_CNST_BASE_COLOR) > 0)
    {
        refAlbedo = materialInfo.baseColor.xyz;
        diffAlbedo = materialInfo.baseColor.xyz;
    }
    else
    {
        refAlbedo = albedoTex.sample(albedoSampler, input.uv).xyz;
        diffAlbedo = refAlbedo;
    }
    
    float roughness = 0.0;
    float metallic = 0.0;
    if((materialInfo.materialInfoMask.x & RENDER_INFO_MASK0_CNST_METALLIC_ROUGHNESS) > 0)
    {
        float3 roughnessMetalSample = roughnessMetallicTex.sample(roughnessMetallicSampler, input.uv).xyz;
        roughness = roughnessMetalSample.g;
        metallic = roughnessMetalSample.b;
    }
    else
    {
        roughness = 0.2;
        metallic = 0.0;
    }
    
    roughness = 0.2;
    
    if((materialInfo.materialInfoMask.x & RENDER_INFO_MASK0_CNST_NORMAL) > 0)
    {
        float3 worldNormal = normal;
        float3 normalSampled = normalTex.sample(normalTexSampler, input.uv).xyz;
        float3 tangent = normalize(input.tangent.xyz);
        float3 biTangent = normalize(cross(worldNormal, tangent));
        normalSampled = normalSampled * 2.0 - 1.0;
        normal = tangent * normalSampled.x + biTangent * normalSampled.y + worldNormal * normalSampled.z;
    }
    
    float aoFactor = 1.0;
    if((materialInfo.materialInfoMask.x & RENDER_INFO_MASK0_CNST_AO) > 0)
    {
        aoFactor = aoTex.sample(aoSampler, input.uv).r;
    }
    
    float3 wo = normalize(renderInfo.camWorldPos.xyz - input.worldPos.xyz);
    
    float viewNormalCosTheta = max(dot(normal, wo), 0.0);

    float3 Lo = float3(0.0, 0.0, 0.0); // Output light values to the view direction.
    uint lightCnt = 4;
    float3 lightOneRad = float3(20.0, 20.0, 20.0);
    float3 lightRadiance[4] = { lightOneRad, lightOneRad, lightOneRad, lightOneRad };
    float offset = 1.0;
    float3 lightPositions[4] = {
        renderInfo.camWorldPos.xyz + float3(offset, offset, 0.0),
        renderInfo.camWorldPos.xyz + float3(-offset, offset, 0.0),
        renderInfo.camWorldPos.xyz + float3(offset, -offset, 0.0),
        renderInfo.camWorldPos.xyz + float3(-offset, -offset, 0.0)
    };
    
    for (uint i = 0; i < lightCnt; i++)
    {
        float3 lightColor = lightRadiance[i];
        float3 lightPos = lightPositions[i];
        float3 wi = normalize(lightPos - input.worldPos.xyz);
        float3 H = normalize(wi + wo);
        float distance = length(lightPos - input.worldPos.xyz);

        float attenuation = 1.0 / (distance * distance);
        float3 radiance = lightColor * attenuation;

        float lightNormalCosTheta = max(dot(normal, wi), 0.0);

        float NDF = DistributionGGX(normal, H, roughness);
        float G = GeometrySmithDirectLight(normal, wo, wi, roughness);

        float3 F0 = float3(0.04, 0.04, 0.04);
        F0 = F0 * (1.0 - float3(metallic, metallic, metallic)) + refAlbedo * float3(metallic, metallic, metallic);
        // F0 = lerp(F0, refAlbedo, float3(metallic, metallic, metallic));
        
        float3 F = FresnelSchlick(max(dot(H, wo), 0.0), F0);

        float3 NFG = NDF * F * G;

        float denominator = 4.0 * viewNormalCosTheta * lightNormalCosTheta + 0.0001;

        float3 specular = NFG / denominator;

        float3 kD = float3(1.0, 1.0, 1.0) - F; // The amount of light goes into the material.
        kD *= (1.0 - metallic);

        Lo += (kD * (diffAlbedo / 3.14159265359) + specular) * radiance * lightNormalCosTheta;
    }
    
    float3 ambient = ambientLight.xyz * refAlbedo * aoFactor;
    float3 finalColor = ambient + Lo;
    
    // Gamma Correction
    finalColor = finalColor / (finalColor + float3(1.0, 1.0, 1.0));
    finalColor = pow(finalColor, float3(1.0 / 2.2, 1.0 / 2.2, 1.0 / 2.2));
    
    return float4(finalColor, 1.0);
}
