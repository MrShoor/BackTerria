/* 
 * File:   lighting_types.h
 * Author: alexander.busarov
 *
 * Created on February 5, 2018, 2:47 PM
 */

#ifndef LIGHTING_TYPES_H
#define	LIGHTING_TYPES_H

struct Light {
    float4 PosRange;
    float  LightSize;
    float3 Color;
    float3 Dir;
    float2 Angles;
    uint   MatrixOffset;  
    int4   ShadowSizeSliceRangeMode;
};

struct ListNode {
    uint LightIdx;
    uint NextNode;
};

struct LightMatrix {
    float4x4 viewProj;
    float4x4 view;
    float4x4 proj;
    float4x4 ProjInv;
};

float2 depthRange;
float2 planesNearFar;
float lightCount;
StructuredBuffer<Light> light_list;
StructuredBuffer<LightMatrix> light_matrices;

#endif	/* LIGHTING_TYPES_H */

