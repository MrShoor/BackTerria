#include "hlsl.h"
#include "matrices.h"
#include "avModelMaterials.h"
#include "utils.h"
#include "avMesh_common.h"
#include "clustered_lighting.h"

struct VS_Output {
    float4 Pos       : SV_Position;
    float3 vCoord    : vCoord;
    float3 wCoord    : wCoord;
    float4 pCoord    : pCoord;
    float3 vNorm     : vNorm;
    float2 vTex      : vTex;
    float  MatIndex  : MatIndex;
};

VS_Output VS(VS_Input In) {
    VS_Output Out;
    float4x4 mBone = GetBoneTransform(In.vsWIndex+In.aiBoneMatOffset.x, In.vsWeight);
    float3 crd = mul(float4(In.vsCoord, 1.0), mBone).xyz;
    float3 norm = mul( In.vsNormal, (float3x3) mBone );
    Out.wCoord = crd;
    Out.vCoord = mul(float4(crd, 1.0), V_Matrix).xyz;
    Out.vNorm = mul(normalize(norm), (float3x3)V_Matrix);
    Out.vTex = In.vsTex;
    Out.pCoord = mul(float4(Out.wCoord, 1.0), VP_Matrix);
    Out.Pos = Out.pCoord;
    Out.MatIndex = In.aiBoneMatOffset.y + In.vsMatIndex + 0.5;
    return Out;
}

///////////////////////////////////////////////////////////////////////////////

struct PS_Output {
    float4 Color : SV_Target0;
    float4 Normal: SV_Target1;
};

static const float LightInt = 3;

PS_Output PS(VS_Output In) {
    PS_Output Out;
    In.vNorm = normalize(In.vNorm);
    
    ModelMaterialDesc m = LoadMaterialDesc((int)In.MatIndex);
    
    float3 norm = In.vNorm;
    if (m.mapSpecular_Hardness_mapGeometry_Normal.w > 0.001) {
        float3x3 tbn = CalcTBN(In.vCoord, In.vNorm, In.vTex);
        norm = UnpackNormal(m.Geometry_Normal(In.vTex, float4(0.5,0.5,1,0)));
        norm = mul(norm, tbn);    
    }
    
    float4 albedo = m.Diffuse_Color(In.vTex, m.Diff);
    float roughness = m.Geometry_Hardness(In.vTex, 0.5).x;
    float metallic = m.Specular_Intensity(In.vTex, 0.0).x;    
    metallic = roughness;
    roughness = 0.50;
    float3 F0;
    F0 = albedo.xyz * metallic;
    albedo.xyz *= (1.0 - metallic);    
    //metallic = 1.0 - pow(abs(1.0-metallic), 32);
    
    float4 pCrd = In.pCoord;
    pCrd.xyz /= pCrd.w;    
    Out.Color = Clustered_GGX(pCrd.xyz, In.vCoord, In.wCoord, norm, normalize(In.vCoord), albedo, 0.05, F0, roughness);
    
    //Out.Color = float4(tonemapReinhard(Out.Color.xyz), Out.Color.a);
    //Out.Color.xyz = norm.xyz;
    //Out.Color.xyz = F0;
    Out.Normal = PackNormal(norm);
    //Out.Color = diff;
    
    return Out;
}

PS_Output PS_old(VS_Output In) {
    PS_Output Out;
    In.vNorm = normalize(In.vNorm);
    
    ModelMaterialDesc m = LoadMaterialDesc((int)In.MatIndex);
    float3 norm = In.vNorm;
    
    if (m.mapSpecular_Hardness_mapGeometry_Normal.w > 0.001) {
        float3x3 tbn = CalcTBN(In.vCoord, In.vNorm, In.vTex);
        norm = UnpackNormal(m.Geometry_Normal(In.vTex, float4(0.5,0.5,1,0)));
        norm = mul(norm, tbn);
    }    
    
    float4 diff = m.Diffuse_Color(In.vTex, m.Diff);
    //diff = pow(abs(diff), 2.2);
    float roughness = m.Geometry_Hardness(In.vTex, 0.5).x;
    float metallic = m.Specular_Intensity(In.vTex, 0.0).x;
    
    metallic = 1.0 - pow(abs(1.0-metallic), 32);
    
    float4 spec = {1,1,1,1};
    float4 amb = 0.3;
    float3 lightColor = {1,1,1};
    float3 n = normalize(norm);
    float3 viewDir = normalize(-In.vCoord);
    
    float3 F0;
    F0 = diff.xyz * metallic;
    diff.xyz *= (1.0 - metallic);
    
    //float3 c = PhongColor(n, viewDir, viewDir, lightColor, diff, spec, amb, 20.0).rgb;
    //float3 LightPos = float3(10, 0, 0);
    //float3 LightDir = normalize(LightPos - In.vCoord);
    //float3 H = normalize(LightDir + viewDir);
    
    //float3 c = CookTorrance_GGX(n, LightDir, viewDir, H, F0, diff.xyz, roughness)*5;
    //float3 c = CookTorrance_GGX_sampled(n, viewDir, F0, diff.xyz, roughness)*LightInt;

    //Out.Color = float4(tonemapReinhard(c), diff.a);
    
    //Out.Color = diff;
    //Out.Color = -In.vNorm.z;
    return Out;
}