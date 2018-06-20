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
    
    float4 diff = m.Diffuse_Color(In.vTex, m.Diff);
    
    float4 pCrd = In.pCoord;
    pCrd.xyz /= pCrd.w;    
    //Out.Color = PhongColor(-norm, normalize(In.vCoord), normalize(In.vCoord), 0.5, diff, 1.0, 0.001, 80.0);
    Out.Color = Clustered_Phong(pCrd.xyz, In.vCoord, In.wCoord, norm, normalize(In.vCoord), diff, 0.5, 0.05, 80.0);
    Out.Normal = PackNormal(norm);
    //Out.Color = diff;
    
    return Out;
}
