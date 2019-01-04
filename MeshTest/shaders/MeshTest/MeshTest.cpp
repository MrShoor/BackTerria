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
    int MaterialOffset;
};

StructuredBuffer<float4x4> Bones;
StructuredBuffer<InstanceData> Instances;

struct VS_Output {
    float4 Pos      : SV_Position;
    float3 vCoord   : vCoord;
    float3 vNorm    : vNorm;
    float4 Tex      : Tex;
    float  MatIndex : MatIndex;
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
    Out.MatIndex = float(idata.MaterialOffset) + In.vsMatIdx;
    return Out;
}

///////////////////////////////////////////////////////////////////////////////

//********** materials stuff ****************
Texture2DArray Maps; SamplerState MapsSampler;

struct MaterialDesc {
    float4 Diff;
    float4 Spec;
    float4 Hardness_IOR_EmitFactor;
    
    float2 mapDiffuse_Intensity;
    float2 mapDiffuse_Color;
    float2 mapDiffuse_Alpha;
    float2 mapDiffuse_Translucency;
    float2 mapShading_Ambient;
    float2 mapShading_Emit;
    float2 mapShading_Mirror;
    float2 mapShading_RayMirror;
    float2 mapSpecular_Intensity;
    float2 mapSpecular_Color;
    float2 mapSpecular_Hardness;
    float2 mapGeometry_Normal;
    float2 mapGeometry_Warp;
    float2 mapGeometry_Displace;
    
    float4 Diffuse_Color(float2 TexCoord) {
        if (mapDiffuse_Color.y > 0.001) {
            return lerp(Diff, Maps.Sample(MapsSampler, float3(TexCoord, mapDiffuse_Color.x)), mapDiffuse_Color.y);
        } else {
            return Diff;
        }
    }
    float4 Geometry_Normal(float2 TexCoord, float4 BaseValue) {
        if (mapGeometry_Normal.y > 0.001) {
            return lerp(BaseValue, Maps.Sample(MapsSampler, float3(TexCoord, mapGeometry_Normal.x)), mapGeometry_Normal.y);
        } else {
            return BaseValue;
        }
    }
    float4 Geometry_Hardness(float2 TexCoord) {
        if (mapSpecular_Hardness.y > 0.001) {
            return lerp(Hardness_IOR_EmitFactor.x, Maps.Sample(MapsSampler, float3(TexCoord, mapSpecular_Hardness.x)), mapSpecular_Hardness.y);
        } else {
            return Hardness_IOR_EmitFactor.x;
        }
    }
    float4 Specular_Intensity(float2 TexCoord, float4 BaseValue) {
        if (mapSpecular_Intensity.y > 0.001) {
            return lerp(BaseValue, Maps.Sample(MapsSampler, float3(TexCoord, mapSpecular_Intensity.x)), mapSpecular_Intensity.y);
        } else {
            return BaseValue;
        }
    }
    float4 Shading_Emit(float2 TexCoord, float4 BaseValue) {
        if (mapShading_Emit.y > 0.001) {
            return lerp(BaseValue, Maps.Sample(MapsSampler, float3(TexCoord, mapShading_Emit.x)), mapShading_Emit.y);
        } else {
            return BaseValue;
        }
    }
    float4 Shading_Ambient(float2 TexCoord) {
        if (mapShading_Ambient.y > 0.001) {
            return Maps.Sample(MapsSampler, float3(TexCoord, mapShading_Ambient.x)) * mapShading_Ambient.y;
        } else {
            return 1.0;
        }
    }
};
StructuredBuffer<MaterialDesc> Materials;
//*******************************************

struct PS_Output {
    float4 Color : SV_Target0;
};

PS_Output PS(VS_Output In) {
    PS_Output Out;
    
    MaterialDesc mat = Materials[In.MatIndex];
    
    //float b = -dot(normalize(In.vNorm), normalize(In.vCoord));
    float b = -dot(normalize(In.vNorm), float3(0,0,1));
    float3 mult = b < 0 ? float3(-b,0,0) : b;
    
    Out.Color = mat.Diffuse_Color(In.Tex.xy);
    Out.Color.xyz *= mult;
    Out.Color.w = 1.0;
    return Out;
}