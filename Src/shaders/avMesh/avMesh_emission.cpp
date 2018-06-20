#include "hlsl.h"
#include "matrices.h"
#include "avModelMaterials.h"
#include "utils.h"
#include "avMesh_common.h"

struct VS_Output {
    float4 Pos       : SV_Position;
    float2 vTex      : vTex;
    float  MatIndex  : MatIndex;
};

VS_Output VS(VS_Input In) {
    VS_Output Out;
    float4x4 mBone = GetBoneTransform(In.vsWIndex+In.aiBoneMatOffset.x, In.vsWeight);
    float3 crd = mul(float4(In.vsCoord, 1.0), mBone).xyz;
    Out.vTex = In.vsTex;
    Out.Pos = mul(float4(crd, 1.0), VP_Matrix);
    Out.MatIndex = In.aiBoneMatOffset.y + In.vsMatIndex + 0.5;
    return Out;
}

///////////////////////////////////////////////////////////////////////////////

struct PS_Output {
    float4 Color : SV_Target0;
};

PS_Output PS(VS_Output In) {
    PS_Output Out;
    ModelMaterialDesc m = LoadMaterialDesc((int)In.MatIndex);    
    Out.Color = m.Shading_Emit(In.vTex, m.Diff) * m.Hardness_IOR_EmitFactor.z * 10.0;
    return Out;
}