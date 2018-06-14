/* 
 * File:   utils.h
 * Author: alexander.busarov
 *
 * Created on June 14, 2018, 12:34 PM
 */

#ifndef UTILS_H
#define	UTILS_H

static const float M_PI = 3.1415926535897932384626433832795;

float4 PackNormal(float3 UnpackedNormal) {
    float4 Out;
    Out.xyz = UnpackedNormal*0.5 + 0.5;
    Out.w = 0;
    return Out;
}

float3 UnpackNormal(float4 PackedNormal) {
    float3 Out = (PackedNormal.xyz-0.5)*2.0;
    return Out;
}

#endif	/* UTILS_H */

