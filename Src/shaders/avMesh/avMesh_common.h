/* 
 * File:   avMesh_common.h
 * Author: alexander.busarov
 *
 * Created on June 15, 2018, 8:52 PM
 */

#ifndef AVMESH_COMMON_H
#define	AVMESH_COMMON_H

struct VS_Input {
    float3 vsCoord   : vsCoord;
    float3 vsNormal  : vsNormal;
    float2 vsTex     : vsTex;
    float  vsMatIndex: vsMatIndex;
    float4 vsWIndex  : vsWIndex;
    float4 vsWeight  : vsWeight;
    float2 aiBoneMatOffset: aiBoneMatOffset;
};

Texture2D BoneTransform; SamplerState BoneTransformSampler;

float4x4 GetBoneTransform(in float BoneCoord) {
    float2 TexSize;
    BoneTransform.GetDimensions(TexSize.x, TexSize.y);
    float2 PixSize = 1.0 / TexSize;
    
    float2 TexCoord;
    TexCoord.x = frac(BoneCoord / TexSize.x);
    TexCoord.y = trunc(BoneCoord / TexSize.x) / TexSize.y;
    TexCoord += 0.5 * PixSize;
    
    float4x4 m;
    m[0] = BoneTransform.SampleLevel(BoneTransformSampler, float2(TexCoord.x,                 TexCoord.y), 0);
    m[1] = BoneTransform.SampleLevel(BoneTransformSampler, float2(TexCoord.x +     PixSize.x, TexCoord.y), 0);
    m[2] = BoneTransform.SampleLevel(BoneTransformSampler, float2(TexCoord.x + 2.0*PixSize.x, TexCoord.y), 0);
    m[3] = BoneTransform.SampleLevel(BoneTransformSampler, float2(TexCoord.x + 3.0*PixSize.x, TexCoord.y), 0);
    return m;
}

float4x4 GetBoneTransform(in float4 Indices, in float4 Weights) {
    float4x4 m = {
        1, 0, 0, 0,
        0, 1, 0, 0,
        0, 0, 1, 0,
        0, 0, 0, 1
    };
    float4 ind = Indices*4.0;
    if (Indices.x>=0.0) m  = GetBoneTransform(ind.x)*Weights.x;
    if (Indices.y>=0.0) m += GetBoneTransform(ind.y)*Weights.y;
    if (Indices.z>=0.0) m += GetBoneTransform(ind.z)*Weights.z;
    if (Indices.w>=0.0) m += GetBoneTransform(ind.w)*Weights.w;
    return m;
}

#endif	/* AVMESH_COMMON_H */

