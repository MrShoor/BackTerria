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

float3x3 CalcTBN(float3 vPos, float3 vNorm, float2 vTex) {
    float3 dPos1 = ddx(vPos);
    float3 dPos2 = ddy(vPos);
    float2 dTex1 = ddx(vTex);
    float2 dTex2 = ddy(vTex);
 
    float3 v2 = cross(dPos2, vNorm);
    float3 v1 = cross(vNorm, dPos1);
    float3 T = v2 * dTex1.x + v1 * dTex2.x;
    float3 B = v2 * dTex1.y + v1 * dTex2.y;
 
    float invdet = 1.0/sqrt(max( dot(T,T), dot(B,B) ));
    
    return float3x3( T * invdet, B * invdet, vNorm );
}

#endif	/* UTILS_H */

