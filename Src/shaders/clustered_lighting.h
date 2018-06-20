#ifndef CLUSTERED_LIGHTING_H
#define	CLUSTERED_LIGHTING_H

#include "lighting_types.h"
#pragma pack_matrix( row_major )

#define DEPTH_BIAS 0.000
#define PI 3.1415926535897932384626433832795

//input
float3 light_headBufferSize;
Texture3D<uint> light_headBuffer;
StructuredBuffer<ListNode> light_linkedList;

TextureCubeArray ShadowCube512; SamplerComparisonState ShadowCube512Sampler;
//TextureCubeArray ShadowCube512; SamplerState ShadowCube512Sampler;
//input

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

float4x4 getCubeMatrix(float3 LightDir, int matIdx) {
    float dmax = max(abs(LightDir.x), max(abs(LightDir.y), abs(LightDir.z)));
    int n = matIdx;
    if (dmax == -LightDir.x) {
        n = n + 1;
    } else if (dmax == LightDir.y) {
        n = n + 2;
    } else if (dmax == -LightDir.y) {
        n = n + 3;
    } else if (dmax == LightDir.z) {
        n = n + 4;
    } else if (dmax == -LightDir.z) {
        n = n + 5;
    }
    return light_matrices[n];
}

float _sampleCubeShadowRude(float3 Pt, Light light)
{
    if (light.ShadowSizeSliceRange.y < 0) return 1.0;
    float3 cubeDir = Pt - light.PosRange.xyz;
    float4x4 m = getCubeMatrix(cubeDir, light.MatrixOffset);
    float4 projPt = mul(m, float4(Pt,1.0));
    projPt.z /= projPt.w;
    
    return ShadowCube512.SampleCmpLevelZero(ShadowCube512Sampler, float4(cubeDir,light.ShadowSizeSliceRange.y/6.0), projPt.z-DEPTH_BIAS).r;
}

#define SHADOW_SAMPLES_COUNT 16

static const float2 ShadowHammerslayPts[SHADOW_SAMPLES_COUNT] = {
    {0.0343008, 0.0370528},
    {0.0968008, 0.5370528},
    {0.1593008, 0.2870528},
    {0.2218008, 0.7870528},
    {0.2843008, 0.1620528},
    {0.3468008, 0.6620528},
    {0.4093008, 0.4120528},
    {0.4718008, 0.9120528},
    {0.5343009, 0.0995528},
    {0.5968009, 0.5995528},
    {0.6593009, 0.3495528},
    {0.7218009, 0.8495528},
    {0.7843009, 0.2245528},
    {0.8468009, 0.7245528},
    {0.9093009, 0.4745528},
    {0.9718009, 0.9745528}
};

float _sampleCubeShadowPCF16(float3 Pt, Light light) {
        if (light.ShadowSizeSliceRange.y < 0) return 1.0;
        float3 L = Pt - light.PosRange.xyz;
        float3 Llen = length(L);
        
	float3 SideVector = normalize(cross(L, float3(0, 0, 1))) * Llen;
	float3 UpVector = normalize(cross(SideVector, L)) * Llen;

	SideVector *= 1.0 / 128.0;
	UpVector *= 1.0 / 128.0;

        float4x4 m = getCubeMatrix(L, light.MatrixOffset);
        float4 projPt = mul(m, float4(Pt,1.0));
        projPt.z /= projPt.w;
        float sD = projPt.z;        
        
	float totalShadow = 0;
        
	[unroll] 
        for(int i = 0; i < SHADOW_SAMPLES_COUNT; ++i)
	{
		float3 SamplePos = L + SideVector * (ShadowHammerslayPts[i].x-0.5) + UpVector * (ShadowHammerslayPts[i].y - 0.5);                
		totalShadow += ShadowCube512.SampleCmpLevelZero(
			ShadowCube512Sampler, 
			float4(SamplePos, light.ShadowSizeSliceRange.y/6.0), 
			sD).r;
	}
	totalShadow /= SHADOW_SAMPLES_COUNT;

	return totalShadow;

}

float3 PhongColor(float3 Normal, float3 ViewDir, float3 LightDir, float3 LightColor, float4 Diffuse, float4 Specular, float SpecPower)
{
   float3 RefLightDir = -reflect(LightDir, Normal);
   float diffK = (saturate(dot(Normal, LightDir)));
   if (diffK <= 0.0) return 0.0;
   float3 DiffuseK = LightColor * diffK;
   float3 DiffuseColor = Diffuse.rgb * DiffuseK;
   float3 SpecularColor = (1.0-diffK) * Specular.rgb * (pow(saturate(dot(ViewDir, RefLightDir)), SpecPower));
   return (DiffuseColor + SpecularColor);
}

float4 Clustered_Phong(float3 ProjPos, float3 ViewPos, float3 WorldPos, float3 Normal, float3 ViewDir, float4 Diffuse, float4 Specular, float4 Ambient, float SpecPower) {
    float4 Out = float4(Ambient.xyz*Diffuse.xyz, 1.0);
    
    float z = (ViewPos.z - planesNearFar.x) / (planesNearFar.y - planesNearFar.x);
    ProjPos.xy *= 0.5;
    ProjPos.xy += 0.5;
    ProjPos.z = z;
    uint3 crd = trunc(ProjPos.xyz*(light_headBufferSize+0.0));
    uint nodeIdx = light_headBuffer[crd];
    int i = 0;
    while ((nodeIdx != 0xffffffff)&&(i<10)) {
        ListNode node = light_linkedList[nodeIdx];
        nodeIdx = node.NextNode;
        i++;
        
        Light l = light_list[node.LightIdx];
                
        //l.PosRange.xyz = mul(float4(l.PosRange.xyz, 1.0), V_Matrix).xyz;
        float3 LightDir = l.PosRange.xyz - WorldPos;// ViewPos;
        LightDir = mul(float4(LightDir,0), V_Matrix).xyz;
        float dist = length(LightDir);
        LightDir /= dist;
        float atten = saturate(1.0 - ((dist * dist) / (l.PosRange.w * l.PosRange.w)));
        
        //if (l.ShadowSizeSliceRange.y == 6) {
            atten *= _sampleCubeShadowPCF16(WorldPos, l);
        
        Out.xyz += PhongColor(Normal, ViewDir, LightDir, l.Color, Diffuse, Specular, SpecPower)*atten;        
        //}
        
        //Out.xyz = 1.0;
    }
        
    return Out;
}

float GGX_PartialGeometry(float cosThetaN, float alpha)
{
    float cosTheta_sqr = saturate(cosThetaN*cosThetaN);
    float tan2 = ( 1 - cosTheta_sqr ) / cosTheta_sqr;
    float GP = 2 / ( 1 + sqrt( 1 + alpha * alpha * tan2 ) );
    return GP;
}

float GGX_Distribution(float cosThetaNH, float alpha)
{
    float alpha2 = alpha * alpha;
    float NH_sqr = saturate(cosThetaNH * cosThetaNH);
    float den = NH_sqr * alpha2 + (1.0 - NH_sqr);
    return alpha2 / ( PI * den * den );
}

float3 FresnelSchlick(float3 F0, float cosTheta) {
    return F0 + (1.0 - F0) * pow(1.0 - saturate(cosTheta), 5.0);
}

float3 CookTorrance_GGX(float3 n, float3 l, float3 v, float3 h, float3 F0, float3 albedo, float roughness) {
    //precompute dots
    float NL = dot(n, l);
    if (NL <= 0.0) return 0.0;
    float NV = dot(n, v);
    if (NV <= 0.0) return 0.0;
    float NH = dot(n, h);
    float HV = dot(h, v);
    
    //precompute roughness square
    float roug_sqr = roughness*roughness;
    
    //calc coefficients
    float G = GGX_PartialGeometry(NV, roug_sqr) * GGX_PartialGeometry(NL, roug_sqr);
    float D = GGX_Distribution(NH, roug_sqr);
    float3 F = FresnelSchlick(F0, HV);
    
    //mix
    float3 specK = G*D*F*0.25/(NV);    
    float3 diffK = saturate(1.0-F)/PI;
    return max(0.0, albedo*diffK*NL + specK);
}

float4 Clustered_GGX(float3 ProjPos, float3 ViewPos, float3 WorldPos, float3 Normal, float3 ViewDir, float4 Albedo, float3 Ambient, float3 F0, float roughness) {
    float4 Out = float4(Ambient.xyz*Albedo.xyz, Albedo.a);    
    
    float z = (ViewPos.z - planesNearFar.x) / (planesNearFar.y - planesNearFar.x);
    ProjPos.xy *= 0.5;
    ProjPos.xy += 0.5;
    ProjPos.z = z;
    uint3 crd = trunc(ProjPos.xyz*(light_headBufferSize+0.0));
    uint nodeIdx = light_headBuffer[crd];
    int i = 0;
    
    float3 v = -ViewDir;
    
    while ((nodeIdx != 0xffffffff)&&(i<10)) {
        ListNode node = light_linkedList[nodeIdx];
        nodeIdx = node.NextNode;
        i++;
        
        Light light = light_list[node.LightIdx];
        light.Color = light.Color * 5;

        float3 l = light.PosRange.xyz - WorldPos;
        float dist = length(l);
        l = mul(float4(l/dist,0), V_Matrix).xyz;
        float3 h = normalize(l + v);
        float atten = saturate(1.0 - ((dist * dist) / (light.PosRange.w * light.PosRange.w)));
        
        atten *= _sampleCubeShadowPCF16(WorldPos, light);
        
        Out.xyz += CookTorrance_GGX(Normal, l, v, h, F0, Albedo.xyz, roughness)*light.Color*atten;
    }
        
    return Out;
}

float3 tonemapReinhard_simple(float3 x){
    return x / (1.0 + x);
}

float3 tonemapReinhard(float3 x){
    float exposure = 0.125;
    float lum = dot(x, float3(0.2126f, 0.7152f, 0.0722f));
    float L = exposure*lum;//(scale / averageLum) * lum;
    //float Ld = (L * (1.0 + L / lumwhite2)) / (1.0 + L);
    float Ld = (L * (1.0 + L)) / (1.0 + L);
    return (x / lum) * Ld;
}

#endif	/* CLUSTERED_LIGHTING_H */