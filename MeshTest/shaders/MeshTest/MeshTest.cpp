#include "hlsl.h"
#include "matrices.h"

struct VS_Input {
    float3 vsCoord   : vsCoord;
    float3 vsNormal  : vsNormal;
    float4 vsTex     : vsTex;
    float4 vsWeight  : vsWeight;
    int4   vsWIndex  : vsWIndex;
    int    vsMatIdx  : vsMatIdx;
    uint   IID       : SV_InstanceID;
};

struct InstanceData {
    int BoneOffset;
};

StructuredBuffer<float4x4> Bones;
StructuredBuffer<InstanceData> Instances;

struct VS_Output {
    float4 Pos      : SV_Position;
    float3 vCoord   : vCoord;
    float3 vNorm    : vNorm;
    float4 Tex      : Tex;
//    float  MatIndex  : MatIndex;
};

float4x4 GetBoneTransform(in float4 Indices, in float4 Weights) {
    float4x4 m = {
        1, 0, 0, 0,
        0, 1, 0, 0,
        0, 0, 1, 0,
        0, 0, 0, 1
    };
    if (Indices.x>=0.0) m  = Bones[Indices.x]*Weights.x;
    if (Indices.y>=0.0) m += Bones[Indices.y]*Weights.y;
    if (Indices.z>=0.0) m += Bones[Indices.z]*Weights.z;
    if (Indices.w>=0.0) m += Bones[Indices.w]*Weights.w;
    return m;
}

VS_Output VS(VS_Input In) {
    VS_Output Out;
    
    InstanceData idata = Instances[In.IID];
    
    float4x4 objTransform = GetBoneTransform(In.vsWIndex + float(idata.BoneOffset), In.vsWeight);
    float4 crd = mul(float4(In.vsCoord, 1.0), objTransform);
    float3 norm = mul(In.vsNormal, (float3x3)objTransform);
    
    Out.Pos = mul(crd, VP_Matrix);
    Out.vCoord = mul(crd, V_Matrix).xyz;
    Out.vNorm = mul(norm, (float3x3)V_Matrix);
    Out.Tex = In.vsTex;
    return Out;
}

///////////////////////////////////////////////////////////////////////////////

struct PS_Output {
    float4 Color : SV_Target0;
};

PS_Output PS(VS_Output In) {
    PS_Output Out;
    //float b = -dot(normalize(In.vNorm), normalize(In.vCoord));
    float b = -dot(normalize(In.vNorm), float3(0,0,1));
    Out.Color.xyz = b < 0 ? float3(-b,0,0) : b;
    Out.Color.w = 1.0;
    return Out;
}