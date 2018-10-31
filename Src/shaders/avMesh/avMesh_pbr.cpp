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
    float3 F0;
    F0 = albedo.xyz * metallic;
    albedo.xyz *= (1.0 - metallic);    
    //metallic = 1.0 - pow(abs(1.0-metallic), 32);
    
    float4 pCrd = In.pCoord;
    pCrd.xyz /= pCrd.w;    
    
    Out.Color = Clustered_GGX(pCrd.xyz, In.vCoord, In.wCoord, norm, normalize(In.vCoord), albedo, F0, metallic, roughness);
    
    //Out.Color = float4(tonemapReinhard(Out.Color.xyz), Out.Color.a);
    //Out.Color.xyz = norm.xyz;
    Out.Normal = PackNormal(norm);
    //Out.Color = diff;
    
    return Out;
}