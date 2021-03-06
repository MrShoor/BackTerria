#ifndef CLUSTERED_LIGHTING_H
#define	CLUSTERED_LIGHTING_H

#include "matrices.h"
#include "avModelMaterials.h"
#include "lighting_types.h"
#include "disc.h"
#pragma pack_matrix( row_major )

#define DEPTH_BIAS 0.0000005
#define PI 3.1415926535897932384626433832795

//input
float3 light_headBufferSize;
Texture3D<uint> light_headBuffer;
StructuredBuffer<ListNode> light_linkedList;

TextureCubeArray ShadowCube64; SamplerState ShadowCube64Sampler;
TextureCubeArray ShadowCube128; SamplerState ShadowCube128Sampler;
TextureCubeArray ShadowCube256; SamplerState ShadowCube256Sampler;
TextureCubeArray ShadowCube512; SamplerState ShadowCube512Sampler;
TextureCubeArray ShadowCube1024; SamplerState ShadowCube1024Sampler;
TextureCubeArray ShadowCube2048; SamplerState ShadowCube2048Sampler;

Texture2DArray ShadowSpot64; SamplerState ShadowSpot64Sampler;
Texture2DArray ShadowSpot128; SamplerState ShadowSpot128Sampler;
Texture2DArray ShadowSpot256; SamplerState ShadowSpot256Sampler;
Texture2DArray ShadowSpot512; SamplerState ShadowSpot512Sampler;
Texture2DArray ShadowSpot1024; SamplerState ShadowSpot1024Sampler;
Texture2DArray ShadowSpot2048; SamplerState ShadowSpot2048Sampler;

float4 EnvAmbientColor;
TextureCube EnvRadiance; SamplerState EnvRadianceSampler;
TextureCube EnvIrradiance; SamplerState EnvIrradianceSampler;
Texture2D brdfLUT; SamplerState brdfLUTSampler;

//input

float SampleSadowCubeAuto(float3 Ray, Light l) {
    switch (l.ShadowSizeSliceRangeMode.x) {
        case 64:
            return ShadowCube64.SampleLevel(ShadowCube64Sampler, float4(Ray, l.ShadowSizeSliceRangeMode.y/6.0), 0).r;
        case 128:
            return ShadowCube128.SampleLevel(ShadowCube128Sampler, float4(Ray, l.ShadowSizeSliceRangeMode.y/6.0), 0).r;
        case 256:
            return ShadowCube256.SampleLevel(ShadowCube256Sampler, float4(Ray, l.ShadowSizeSliceRangeMode.y/6.0), 0).r;
        case 512:
            return ShadowCube512.SampleLevel(ShadowCube512Sampler, float4(Ray, l.ShadowSizeSliceRangeMode.y/6.0), 0).r;
        case 1024:
            return ShadowCube1024.SampleLevel(ShadowCube1024Sampler, float4(Ray, l.ShadowSizeSliceRangeMode.y/6.0), 0).r;
        case 2048:
            return ShadowCube2048.SampleLevel(ShadowCube2048Sampler, float4(Ray, l.ShadowSizeSliceRangeMode.y/6.0), 0).r;
        default:
            return 0;
    }
}

float SampleShadowSpotAuto(float2 UV, Light l) {
    switch (l.ShadowSizeSliceRangeMode.x) {
        case 64:
            return ShadowSpot64.SampleLevel(ShadowSpot64Sampler, float3(UV, l.ShadowSizeSliceRangeMode.y), 0).r;
        case 128:
            return ShadowSpot128.SampleLevel(ShadowSpot128Sampler, float3(UV, l.ShadowSizeSliceRangeMode.y), 0).r;
        case 256:
            return ShadowSpot256.SampleLevel(ShadowSpot256Sampler, float3(UV, l.ShadowSizeSliceRangeMode.y), 0).r;        
        case 512:
            return ShadowSpot512.SampleLevel(ShadowSpot512Sampler, float3(UV, l.ShadowSizeSliceRangeMode.y), 0).r;
        case 1024:
            return ShadowSpot1024.SampleLevel(ShadowSpot1024Sampler, float3(UV, l.ShadowSizeSliceRangeMode.y), 0).r;
        case 2048:
            return ShadowSpot2048.SampleLevel(ShadowSpot2048Sampler, float3(UV, l.ShadowSizeSliceRangeMode.y), 0).r;
        default:
            return 0;
    }
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
    return light_matrices[n].viewProj;
}

LightMatrix getCubeLightMatrix(float3 LightDir, int matIdx) {
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

float4x4 getSpotMatrix(int matIdx) {
    return light_matrices[matIdx].viewProj;
}

LightMatrix getLightMatrix(int matIdx) {
    return light_matrices[matIdx];
}

float _testDepth(float PixelDepth, float ShadowMapDepth, float Slope) {
    return (PixelDepth - Slope*DEPTH_BIAS) > ShadowMapDepth;
}

float _sampleCubeShadowRude(float3 Pt, float Slope, Light light)
{
    if (light.ShadowSizeSliceRangeMode.y < 0) return 1.0;
    float3 cubeDir = Pt - light.PosRange.xyz;
    float4x4 m = getCubeMatrix(cubeDir, light.MatrixOffset);
    float4 projPt = mul(float4(Pt,1.0), m);
    projPt.z /= projPt.w;
    float depth = SampleSadowCubeAuto(cubeDir, light);//ShadowCube512.SampleLevel(ShadowCube512Sampler, float4(cubeDir,light.ShadowSizeSliceRangeMode.y/6.0), 0.0).r;
    return _testDepth(projPt.z, depth, Slope);
}

float _sampleSpotShadowRude(float3 Pt, float Slope, Light light)
{
    if (light.ShadowSizeSliceRangeMode.y < 0) return 1.0;
    float4x4 m = getSpotMatrix(light.MatrixOffset);
    float4 projPt = mul(float4(Pt,1.0), m);
    projPt.xyz /= projPt.w;
    projPt.xy *= float2(0.5, -0.5);
    projPt.xy += 0.5;
    float shadowDepth = SampleShadowSpotAuto(projPt.xy, light);
    return _testDepth(projPt.z, shadowDepth, Slope);
}

#define BLOCKER_SAMPLES_COUNT 5
#define SHADOW_SAMPLES_COUNT 16
#define PCSS_SHADOW_MAX_SAMPLES 12

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

float _sampleSpotShadowPCF16(float3 Pt, float Slope, Light light) {
        if (light.ShadowSizeSliceRangeMode.y < 0) return 1.0;
        float3 L = Pt - light.PosRange.xyz;
        float Llen = length(L);
        
        LightMatrix lm = getLightMatrix(light.MatrixOffset);
        float sD = mul(float4(Pt,1.0), lm.view).z;
        
        //evaluate disc center and radius
        float4 tmp = mul(float4(0,0.05,Llen,1), lm.proj);
        tmp.xy /= tmp.w;
        float UVRadius = length(tmp.xy);
        
        tmp = mul(float4(Pt,1), lm.viewProj);
        tmp.xyz /= tmp.w;
        float sD_proj = tmp.z;
        tmp.xy *= float2(0.5,-0.5);
        tmp.xy += 0.5;
        float2 UVCenter = tmp.xy;
        
        //soft shadows
	float totalShadow = 0;
        float DiscScale = DiscSamples[SHADOW_SAMPLES_COUNT].z * UVRadius;
	[loop] 
        for(int i = 0; i < SHADOW_SAMPLES_COUNT; ++i)
	{
            float2 sample = UVCenter + DiscSamples[i].xy * DiscScale;
            float shadowDepth = SampleShadowSpotAuto(sample, light);
            totalShadow += _testDepth(sD_proj, shadowDepth, Slope);
	}
	totalShadow /= SHADOW_SAMPLES_COUNT;

	return totalShadow;
}

float _sampleCubeShadowPCF16(float3 Pt, float Slope, Light light) {
        if (light.ShadowSizeSliceRangeMode.y < 0) return 1.0;
        float3 L = Pt - light.PosRange.xyz;
        float3 Llen = length(L);
        
	float3 SideVector = normalize(cross(L, float3(0, 0, 1))) * Llen;
	float3 UpVector = normalize(cross(SideVector, L)) * Llen;

	SideVector *= 1.0 / 128.0;
	UpVector *= 1.0 / 128.0;

        float4x4 m = getCubeMatrix(L, light.MatrixOffset);
        float4 projPt = mul(float4(Pt,1.0), m);
        projPt.z /= projPt.w;
        float sD = projPt.z;        
        
	float totalShadow = 0;
        
        float DiskScale = DiscSamples[SHADOW_SAMPLES_COUNT].z*0.5;
	[loop]
        for(int i = 0; i < SHADOW_SAMPLES_COUNT; ++i)
	{
		float3 SamplePos = L + SideVector * DiscSamples[i].x*DiskScale + UpVector*DiscSamples[i].y*DiskScale;
                float shadowDepth = SampleSadowCubeAuto(SamplePos, light);
                totalShadow += _testDepth(sD, shadowDepth, Slope);
	}
	totalShadow /= SHADOW_SAMPLES_COUNT;

	return totalShadow;
}

float _sampleSpotShadowPCSS(float3 WorldPt, float Slope, Light light) {
        if (light.ShadowSizeSliceRangeMode.y < 0) return 1.0;
        float3 L = WorldPt - light.PosRange.xyz;
        float Llen = length(L);
        
        LightMatrix lm = getLightMatrix(light.MatrixOffset);
                
        float sD = mul(float4(WorldPt,1.0), lm.view).z;

        //evaluate blockers disc center and radius
        float4 tmp = mul(float4(0,light.LightSize,Llen,1), lm.proj);
        tmp.xy /= tmp.w;
        float UVBlockerRadius = length(tmp.xy)*0.5;
        
        tmp = mul(float4(WorldPt,1), lm.viewProj);
        tmp.xyz /= tmp.w;
        float sD_proj = tmp.z;
        tmp.xy *= float2(0.5,-0.5);
        tmp.xy += 0.5;
        float2 UVCenter = tmp.xy;
  
        //find blockers
        float blockerSumm = 0;
        float blockerCount = 0;        
       
        float DiscScale = DiscSamples[BLOCKER_SAMPLES_COUNT].z * UVBlockerRadius;
        [loop]
        for(int i = 0; i < BLOCKER_SAMPLES_COUNT; ++i)
	{
            float2 sample = UVCenter + DiscSamples[i].xy * DiscScale;
            
            float shadowDepth = SampleShadowSpotAuto(sample, light);
            tmp = mul(float4(0,0,shadowDepth,1), lm.ProjInv);
            float sampleDepth = tmp.z / tmp.w;
            if (sampleDepth < sD+Slope*0.01) { //blocker bias
                blockerSumm += sampleDepth;
                blockerCount += 1.0;
            }
	}
        if (blockerCount < 1.0) return 1.0;
        float avgBlockerDepth = blockerSumm / blockerCount;
        //return avgBlockerDepth-520;
        
        //eval penumbra size and disc params
        float penumbraScale = max(0.0, (sD - avgBlockerDepth)/avgBlockerDepth); // - 0.03
        
        tmp = mul(float4(0,10*penumbraScale,Llen,1), lm.proj);
        tmp.xy /= tmp.w;
        float UVDiscRadius = length(tmp.xy)*0.5;
        
        
        //float UVDiscRadius = max(0.0, penumbraScale * UVBlockerRadius);
        float UVSamplesCount = clamp(PCSS_SHADOW_MAX_SAMPLES * sqrt(penumbraScale), 1.0, PCSS_SHADOW_MAX_SAMPLES);
        
        //soft shadow
        DiscScale = DiscSamples[UVSamplesCount-1].z * UVDiscRadius;// * penumbraScale;
        float totalShadow = 0.0;
	[loop] 
        for(i = 0; i < UVSamplesCount; ++i)
	{
            float2 sample = UVCenter + DiscSamples[i].xy * DiscScale;
            float shadowDepth = SampleShadowSpotAuto(sample, light);
            totalShadow += _testDepth(sD_proj, shadowDepth, Slope);
	}
	totalShadow /= UVSamplesCount;
        return totalShadow;
}

float _sampleCubeShadowPCSS(float3 Pt, float Slope, Light light) {
        if (light.ShadowSizeSliceRangeMode.y < 0) return 1.0;
        float3 L = Pt - light.PosRange.xyz;
        float3 Llen = length(L);
        
	float3 SideVector = normalize(cross(L, float3(0, 0, 1)));
	float3 UpVector = normalize(cross(SideVector, L));

	SideVector *= light.LightSize*0.5;
	UpVector *= light.LightSize*0.5;
        
        LightMatrix lm = getCubeLightMatrix(L, light.MatrixOffset);
        
        float4 projPt = mul(float4(Pt,1.0), lm.viewProj);
        projPt.z /= projPt.w;        
        float sD_proj = projPt.z;
        float sD = mul(float4(Pt,1.0), lm.view).z;
             
        float4 tmp;
	float totalShadow = 0;
        float blockerSumm = 0;
        float blockerCount = 0;
        //find blockers
        
        float DiscScale = DiscSamples[BLOCKER_SAMPLES_COUNT].z*0.5;        
	[loop]
        for(int i = 0; i < BLOCKER_SAMPLES_COUNT; ++i)
	{
		float3 SamplePos = L + SideVector * DiscSamples[i].x * DiscScale + UpVector * DiscSamples[i].y * DiscScale;
		float sampleDepth = SampleSadowCubeAuto(SamplePos, light);
                tmp = mul(float4(0,0,sampleDepth,1.0), lm.ProjInv);
                sampleDepth = tmp.z / tmp.w;
                if (sampleDepth < sD + Slope*0.01) {
                    blockerSumm += sampleDepth;
                    blockerCount += 1.0;
                }
	}
        if (blockerCount < 0.5) return 1.0;
        float avgBlockerDepth = blockerSumm / blockerCount;
        
        //eval penumbra size and disc params
        float penumbraScale = max(0.0, (sD - avgBlockerDepth)/avgBlockerDepth + 0.3);
        float DiscSamplesCount = clamp(PCSS_SHADOW_MAX_SAMPLES * sqrt(penumbraScale), 1.0, PCSS_SHADOW_MAX_SAMPLES);
        DiscScale = DiscSamples[DiscSamplesCount].z * penumbraScale;
        
        //soft shadow
	[loop] 
        for(i = 0; i < DiscSamplesCount; ++i)
	{
            float3 SamplePos = L + (SideVector * DiscSamples[i].x + UpVector * DiscSamples[i].y) * DiscScale;
            float sampleDepth = SampleSadowCubeAuto(SamplePos, light);
            totalShadow += _testDepth(sD_proj, sampleDepth, Slope);
	}
	totalShadow /= DiscSamplesCount;        

	return totalShadow;
}

float3 PhongColor(float3 Normal, float3 ViewDir, float3 LightDir, float3 LightColor, float4 Diffuse, float4 Specular, float SpecPower)
{
   float3 RefLightDir = reflect(LightDir, Normal);
   float diffK = dot(Normal, LightDir);
   if (diffK <= 0.0) return 0.0;
   float3 DiffuseK = LightColor * diffK;
   float3 DiffuseColor = Diffuse.rgb * DiffuseK;
   float specK = (pow(saturate(dot(ViewDir, RefLightDir)), SpecPower));
   float3 SpecularColor = LightColor * Specular.rgb * specK;
   return (Diffuse.rgb * LightColor + SpecularColor) * diffK;
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
        l.Color *= 10.0;
//        l.Color *= float3(1.5, 1.3, 0.5);
//        l.Color *= float3(249, 253, 96)/128;
//        l.Color *= float3(220, 220, 70)/128;

        float3 LightDir = l.PosRange.xyz - WorldPos;
        float dist = length(LightDir);
        LightDir /= dist;
        float cs_angle_over = saturate(-dot(LightDir, l.Dir) - l.Angles.y);
        LightDir = mul(float4(LightDir,0), V_Matrix).xyz;       
        
        float Slope = dot(Normal, LightDir);

        float atten = saturate(1.0 - ((dist * dist) / (l.PosRange.w * l.PosRange.w))); //distance attenuation
        if (l.Angles.y) {
            atten *= cs_angle_over==0 ? 0 : saturate(cs_angle_over / (l.Angles.x - l.Angles.y)); //angle attenuation
            atten *= _sampleSpotShadowPCF16(WorldPos, Slope*0.0, l);
            //return _sampleSpotShadowPCSS(WorldPos, Slope, l);
        } else {
            atten *= _sampleCubeShadowPCSS(WorldPos, Slope*0.0, l);
        }
                
        Out.xyz += PhongColor(Normal, ViewDir, LightDir, l.Color, Diffuse, Specular, SpecPower)*atten;        
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
        
        //if (l.ShadowSizeSliceRangeMode.y == 6) {
            //atten *= _sampleCubeShadowPCF16(WorldPos, S l);
        
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

float3 FresnelSchlickRoughness(float3 F0, float cosTheta, float roughness)
{
    return F0 + (max(1.0 - roughness, F0) - F0) * pow(saturate(1.0 - cosTheta), 5.0);
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

float EnvMult(float3 sampledir) {
    //return pow(abs((sampledir.y + 1.0)*0.5), 2.0)*2.0;
    return 3.0;
}

float3 EnvGamma(float3 sample) {
    return pow(abs(sample), 2.2);
}

float4 Clustered_GGX(float3 ProjPos, float3 ViewPos, float3 WorldPos, float3 Normal, float3 ViewDir, float4 Albedo, float3 F0, float metallic, float roughness) {
    float4 Out = float4(EnvAmbientColor.xyz*Albedo.xyz*EnvAmbientColor.w, Albedo.a);
    roughness = clamp(roughness, 0.01, 0.99);
    
    float z = (ViewPos.z - planesNearFar.x) / (planesNearFar.y - planesNearFar.x);
    ProjPos.xy *= 0.5;
    ProjPos.xy += 0.5;
    ProjPos.z = z;
    uint3 crd = trunc(ProjPos.xyz*(light_headBufferSize+0.0));
    uint nodeIdx = light_headBuffer[crd];
    int i = 0;
    
    float3 v = -ViewDir;
    //[loop]
    while ((nodeIdx != 0xffffffff)&&(i<10)) {
        ListNode node = light_linkedList[nodeIdx];
        nodeIdx = node.NextNode;
        i++;
        
        Light light = light_list[node.LightIdx];
        light.Color = light.Color;

        float3 l = light.PosRange.xyz - WorldPos;
        float dist = length(l);
        l /= dist;
        float cs_angle_over = saturate(-dot(l, light.Dir) - light.Angles.y);
        
        l = mul(float4(l,0), V_Matrix).xyz;
        float3 h = normalize(l + v);
        float atten = saturate(1.0 - ((dist * dist) / (light.PosRange.w * light.PosRange.w))); //distance attenuation
        if (light.Angles.y) {
            atten *= cs_angle_over==0 ? 0 : saturate(cs_angle_over / (light.Angles.x - light.Angles.y)); //angle attenuation
            switch (light.ShadowSizeSliceRangeMode.w) {
                case 1: atten *= _sampleSpotShadowPCSS(WorldPos, 0, light); break;
                case 2: atten *= _sampleSpotShadowPCF16(WorldPos, 0, light); break;
            default:
                atten *= _sampleSpotShadowRude(WorldPos, 0, light); break;
            }
        } else {
            switch (light.ShadowSizeSliceRangeMode.w) {
                case 1: atten *= _sampleCubeShadowPCSS(WorldPos, 0, light); break;
                case 2: atten *= _sampleCubeShadowPCF16(WorldPos, 0, light); break;
            default:
                atten *= _sampleCubeShadowRude(WorldPos, 0, light); break;
            }
            
            //atten *= _sampleCubeShadowPCSS(WorldPos, 0, light);
            //atten *= _sampleCubeShadowRude(WorldPos, 0.0, light);
        }
        
        Out.xyz += CookTorrance_GGX(Normal, l, v, h, F0, Albedo.xyz, roughness)*light.Color*atten;
    }
    
    if (EnvAmbientColor.w < 0.5) {
        float NdotV = saturate(dot(Normal, v));
        
        float3 kS = FresnelSchlickRoughness(F0, NdotV, roughness);
        float3 kD = 1.0 - kS;
        kD *= 1.0 - metallic;
                
        float3 cubeSampleDir = mul(Normal, (float3x3)V_InverseMatrix);
        float3 irradiance = EnvGamma( EnvIrradiance.Sample(EnvIrradianceSampler, cubeSampleDir).rgb ) * EnvMult(cubeSampleDir);
        float3 diffuse    = irradiance * Albedo.xyz;
        
        float3 R = reflect(-v, Normal);
        float MAX_REFLECTION_LOD = 4.0;
        cubeSampleDir = mul(R, (float3x3)V_InverseMatrix);
        float3 prefilteredColor = EnvGamma( EnvRadiance.SampleLevel(EnvRadianceSampler, cubeSampleDir, roughness * MAX_REFLECTION_LOD).rgb ) * EnvMult(cubeSampleDir);
        float2 envBRDF  = brdfLUT.SampleLevel(brdfLUTSampler, float2(NdotV, roughness), 0).rg;
        float3 specular = prefilteredColor * (kS * envBRDF.x + envBRDF.y);
        float3 ambient = (kD * diffuse + specular);
        Out.xyz += ambient;        
//vec3 kS = F;
//vec3 kD = 1.0 - kS;
//kD *= 1.0 - metallic;
//  
//vec3 irradiance = texture(irradianceMap, N).rgb;
//vec3 diffuse    = irradiance * albedo;
//  
//const float MAX_REFLECTION_LOD = 4.0;
//vec3 prefilteredColor = textureLod(prefilterMap, R,  roughness * MAX_REFLECTION_LOD).rgb;   
//vec2 envBRDF  = texture(brdfLUT, vec2(max(dot(N, V), 0.0), roughness)).rg;
//vec3 specular = prefilteredColor * (F * envBRDF.x + envBRDF.y);
//  
//vec3 ambient = (kD * diffuse + specular) * ao;         
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