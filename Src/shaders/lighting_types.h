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
    float3 Color;
    float3 Dir;
    float2 Angles;
    uint   MatrixOffset;  
    int3   ShadowSizeSliceRange;
};

struct ListNode {
    uint LightIdx;
    uint NextNode;
};

float2 depthRange;
float2 planesNearFar;
float lightCount;
StructuredBuffer<Light> light_list;
StructuredBuffer<float4x4> light_matrices;

#endif	/* LIGHTING_TYPES_H */

