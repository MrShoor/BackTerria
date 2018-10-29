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
TextureCubeArray ShadowCube512_2; SamplerState ShadowCube512_2Sampler;
//TextureCubeArray ShadowCube512; SamplerState ShadowCube512Sampler;
//input

SamplerState SC512SamplerDef {
    Filter = MIN_MAG_LINEAR_MIP_POINT;//MIN_MAG_MIP_LINEAR;
    MaxAnisotropy = 0;
    AddressU = TEXTURE_ADDRESS_CLAMP;
    AddressV = TEXTURE_ADDRESS_CLAMP;
    AddressW = TEXTURE_ADDRESS_CLAMP;
    MaxLOD = 0;
    MinLOD = 0;    
    //ComparisonFunc = GREATER;
        
    
//      MinFilter  : tfLinear;
//      MagFilter  : tfLinear;
//      MipFilter  : tfLinear;
//      Anisotropy : 0;
//      Wrap_X     : twClamp;
//      Wrap_Y     : twClamp;
//      Wrap_Z     : twClamp;
//      Border     : (x: 0; y: 0; z: 0; w: 0);
//      Comparison : cfGreater;     

};

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

#define BLOCKER_SAMPLES_COUNT 16
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

float POM_SelfShadow(float3x3 tbn, float3 vMacroNorm, float3 vLightDir, float2 vTexCoordCurrent, float2 vTexCoordOrig, float vTexH, ModelMaterialDesc m) {
        float3 rayPOM = normalize( mul(tbn, -vLightDir) );
        float fLength         = length( rayPOM );
        float fParallaxLength = sqrt( fLength * fLength - rayPOM.z * rayPOM.z ) / rayPOM.z; 
        float2 fParallaxOffsetTS = normalize(rayPOM.xy) * fParallaxLength * (0.025);
        float numSteps = 4 + 4 * dot(vMacroNorm, normalize(vLightDir));
        float2 texStep = fParallaxOffsetTS / numSteps;
        float hStep = - vTexH / numSteps;
        
        float2 vTex_dx = ddx(vTexCoordOrig) * numSteps ;
        float2 vTex_dy = ddy(vTexCoordOrig) * numSteps ;
        
        float texStepLen = length(texStep);
        
        float atten = 1;
        vTexH += hStep;
        vTexCoordCurrent += texStep;
        for (int i = 1; i < numSteps; i++) {
            float h = 1.0 - m.Geometry_Height(vTexCoordCurrent, vTex_dx, vTex_dy);
            float d = vTexH - 0.05 - h;
            if (d > 0) 
            {
                d /= texStepLen * i;
                atten = saturate( min(atten, 1.0-d) );
            }
            vTexH += hStep;
            vTexCoordCurrent += texStep;
        }
        return atten;
}

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

float _sampleCubeShadowPCSS5x16(float3 Pt, Light light) {
        if (light.ShadowSizeSliceRange.y < 0) return 1.0;
        float3 L = Pt - light.PosRange.xyz;
        float3 Llen = length(L);
        
	float3 SideVector = normalize(cross(L, float3(0, 0, 1)));
	float3 UpVector = normalize(cross(SideVector, L));

	SideVector *= 1.0 / 128.0;
	UpVector *= 1.0 / 128.0;

        float4x4 m = getCubeMatrix(L, light.MatrixOffset);
        float4 projPt = mul(m, float4(Pt,1.0));
        projPt.z /= projPt.w;
        float sD = projPt.z; 
        
        //Llen*=0.5;
        float3 scaledSideVector = SideVector * Llen;
        float3 scaledUpVector = UpVector * Llen;
        
	float totalShadow = 0;
        float blockerSumm = 0;
        float blockerCount = 0;
        
        int i;
        
        //sD -= 0.000001;
        
        //find blockers
	[unroll] 
        for(i = 0; i < BLOCKER_SAMPLES_COUNT; ++i)
	{
		float3 SamplePos = L + scaledSideVector * (ShadowHammerslayPts[i].x-0.5) + scaledUpVector * (ShadowHammerslayPts[i].y - 0.5);                
		float sampleDepth = ShadowCube512.SampleLevel(ShadowCube512_2Sampler, float4(SamplePos, light.ShadowSizeSliceRange.y/6.0), 0.0).r;
                if (sampleDepth > sD) { //todo fix for reverse depth
                    blockerSumm += sampleDepth;
                    blockerCount += 1.0;
                }
	}
        if (blockerCount < 0.5) return 1.0;

        float avgBlockerDepth = blockerSumm / blockerCount;
        
        //return blockerCount/BLOCKER_SAMPLES_COUNT;
        
        float distBlocker = avgBlockerDepth - sD;
        float penumbra = (sD - distBlocker) / distBlocker;
        
        //return penumbra*0.001;
        scaledSideVector = SideVector / penumbra * 256.0 * 2;
        scaledUpVector = UpVector / penumbra * 256.0 * 2;
        
        //soft shadow
	[unroll] 
        for(i = 0; i < SHADOW_SAMPLES_COUNT; ++i)
	{
		float3 SamplePos = L + scaledSideVector * (ShadowHammerslayPts[i].x-0.5) + scaledUpVector * (ShadowHammerslayPts[i].y - 0.5);                
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
   float3 RefLightDir = reflect(LightDir, Normal);
   float diffK = dot(Normal, LightDir);
   if (diffK <= 0.0) return 0.0;
   float3 DiffuseK = LightColor * diffK;
   float3 DiffuseColor = Diffuse.rgb * DiffuseK;
   //float3 SpecularColor = (1.0-diffK) * Specular.rgb * (pow(saturate(dot(ViewDir, RefLightDir)), SpecPower));
   float specK = (pow(saturate(dot(ViewDir, RefLightDir)), SpecPower));
   //float3 SpecularColor = (1.0-diffK) * Specular.rgb * specK;
   float3 SpecularColor = LightColor * Specular.rgb * specK;
   //return SpecularColor;
   return (Diffuse.rgb * LightColor * (1.0-specK) + SpecularColor) * diffK;
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
        //l.Color *= float3(1.5, 1.3, 0.5);
        //l.Color *= float3(249, 253, 96)/128;
        //l.Color *= float3(220, 220, 70)/128;
                
        //l.PosRange.xyz = mul(float4(l.PosRange.xyz, 1.0), V_Matrix).xyz;
        float3 LightDir = l.PosRange.xyz - WorldPos;// ViewPos;
        LightDir = mul(float4(LightDir,0), V_Matrix).xyz;
        
        float dist = length(LightDir);
        LightDir /= dist;
        float atten = saturate(1.0 - ((dist * dist) / (l.PosRange.w * l.PosRange.w)));
        
        //if (l.ShadowSizeSliceRange.y == 6) {
        //    atten *= _sampleCubeShadowPCF16(WorldPos, l);
        atten *= _sampleCubeShadowPCSS5x16(WorldPos, l);
        
        Out.xyz += PhongColor(Normal, ViewDir, LightDir, l.Color, Diffuse, Specular, SpecPower)*atten;        
        //}
        
        //Out.xyz = 1.0;
    }
        
    return Out;
}

float4 Clustered_Phong_POMSS(float3 ProjPos, 
                             float3 ViewPos, 
                             float3 WorldPos, 
                             float3 Normal, 
                             float3 ViewDir, 
                             float4 Diffuse, 
                             float4 Specular, 
                             float4 Ambient, 
                             float SpecPower,
        
                             float3x3 tbn,
                             float3 vMacroNorm,
                             float2 vTexCoordCurrent, float2 vTexCoordOrig,
                             float vTexH, ModelMaterialDesc m) {
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
        
        if (dot(Normal, LightDir) > 0) 
            atten *= POM_SelfShadow(tbn, vMacroNorm, LightDir, vTexCoordCurrent, vTexCoordOrig, vTexH, m);
        
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
        l /= dist;
        float cs_angle_over = saturate(-dot(l, light.Dir) - light.Angles.y);
        
        l = mul(float4(l,0), V_Matrix).xyz;
        float3 h = normalize(l + v);
        float atten = saturate(1.0 - ((dist * dist) / (light.PosRange.w * light.PosRange.w))); //distance attenuation
        if (light.Angles.y) {
            atten *= cs_angle_over==0 ? 0 : saturate(cs_angle_over / (light.Angles.x - light.Angles.y)); //angle attenuation
            //atten *= _sampleShadowPCF16(WorldPos, light);
        } else {
            atten *= _sampleCubeShadowPCF16(WorldPos, light);
        }
        
        Out.xyz += CookTorrance_GGX(Normal, l, v, h, F0, Albedo.xyz, roughness)*light.Color*atten;
        //Out.y += 0.01;
        
        //return Out;
    }
    
    //Out.xyz = 0.0;
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