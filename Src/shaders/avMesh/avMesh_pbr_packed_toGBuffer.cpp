#include "hlsl.h"
#include "matrices.h"
#include "avModelMaterials.h"
#include "utils.h"
#include "avMesh_common.h"

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

float DebugMips(float2 texCoords) {
    return Maps.CalculateLevelOfDetail(MapsSampler, texCoords);
    
    int3 texSize;
    Maps.GetDimensions(texSize.x, texSize.y, texSize.z);
    float mipCount = log2(min(texSize.x, texSize.y));

    float2 dxt = ddx(texCoords*texSize.xy);
    float2 dyt = ddy(texCoords*texSize.xy);
    
//    float len1 = length(dxt);
//    float len2 = length(dyt);
    
    float maxdelta = ( abs( max(dot(dxt, dxt), dot(dyt, dyt)) ) );
    return max(0.5*log2(maxdelta) + 1.0/mipCount, 0.0);
//    return max(log2(max(len1, len2)) + 1.0/mipCount, 0.0);
}

struct PS_Output {
    float4 Color    : SV_Target0;
    float4 Normal   : SV_Target1;
    float4 Rg_AO_Mtl: SV_Target2;
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
        //norm.x = -norm.x;
        norm = mul(norm, tbn);
        norm = normalize(norm);
    }
    
    float4 diff = m.Diffuse_Color(In.vTex, m.Diff);

    float metallic;
    float roughness;
    float AO;
    if (m.mapSpecular_Hardness_mapGeometry_Normal.y > 0.001) {
        float3 packed_rg_ao_mtl = Maps.Sample(MapsSampler, float3(In.vTex, m.mapSpecular_Hardness_mapGeometry_Normal.x)).xyz;
        roughness = packed_rg_ao_mtl.z;
        AO = packed_rg_ao_mtl.y;
        metallic = packed_rg_ao_mtl.x;
    } else {
        roughness = m.Hardness_IOR_EmitFactor.x/512;
        AO = 1.0;
        metallic = m.Spec.x;
    }
    Out.Color = diff;
    Out.Normal = float4( (norm*0.5)+0.5, 1.0);
    Out.Rg_AO_Mtl = float4(roughness, AO, metallic, 1.0);
    return Out;
}