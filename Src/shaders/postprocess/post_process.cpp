#include "hlsl.h"
#include "matrices.h"
#include "utils.h"

struct VS_Input {
    uint VertexID: SV_VertexID;
};

struct VS_Output {
    float4 Pos : SV_Position;
};

float2 Quad[4] = {{-1,-1},{-1,1},{1,-1},{1,1}};

VS_Output VS(VS_Input In) {
    VS_Output Out;
    Out.Pos = float4(Quad[In.VertexID], 0.0, 1.0);
    return Out;
}

///////////////////////////////////////////////////////////////////////////////

#define SAMPLES_COUNT 16
#define SSAO_RADIUS 1.0
#define SSAO_BIAS SSAO_RADIUS * 0.1


struct PS_Output {
    float4 Color : SV_Target0;
};

static const float2 uHammerslayPts[SAMPLES_COUNT] = {
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

Texture2D Color; SamplerState ColorSampler;
Texture2D Depth; SamplerState DepthSampler;
Texture2D Normals; SamplerState NormalsSampler;
Texture2D RandomTex; SamplerState RandomTexSampler;

float3 Get_vPos(int2 pixel) {
    float4 Out;
    Depth.GetDimensions(Out.x, Out.y);
    Out.xy = (pixel / Out.xy);
    Out.xy -= 0.5;
    Out.xy *= float2(2.0, -2.0); 
    Out.z = Depth.Load(int3(pixel,0)).r;
    Out.w = 1.0;
    Out = mul(Out, P_InverseMatrix);
    return Out.xyz /= Out.w;
}

float3 Get_vNormal(int2 pixel) {
    return UnpackNormal(Normals.Load(int3(pixel,0)));
}

float4 Get_Color(int2 pixel) {
    return Color.Load(int3(pixel,0));
}

float3 Get_SphereSample(int sample_idx, float2 offset) {
    float2 h = uHammerslayPts[sample_idx].xy + offset;
    h.x = acos(frac(1.0-h.x));
    h.y *= 2*M_PI;
    return float3(sin(h.x) * cos(h.y), sin(h.x) * sin(h.y), cos(h.x));
}

float3 Get_Random(int2 pixel) {
    return RandomTex.Sample(RandomTexSampler, pixel / 4.0).xyz;
}

float SampleOcclusion(float3 vCoord, float originalZ){
    float4 pCoord = mul(float4(vCoord,1.0), P_Matrix);
    pCoord.xy /= pCoord.w;
    float2 uv = pCoord.xy*float2(0.5,-0.5) + float2(0.5,0.5);
    float d = Depth.Sample(DepthSampler, uv).r;
    float2 dw = mul(float4(0,0,d,1.0), P_InverseMatrix).zw;
    d = dw.x/dw.y - vCoord.z;
    return d < 0 ? min(1, SSAO_RADIUS/abs(d)) : 0;
}

PS_Output PS(VS_Output In) {
    PS_Output Out;
    
    float3 vPos = Get_vPos(In.Pos.xy);
    float3 vNormal = Get_vNormal(In.Pos.xy);
    float3 SampleStart = vPos + vNormal * SSAO_BIAS;
    float3 rnd = Get_Random(In.Pos.xy);
    
    float ssao = 0;
    for (int i = 0; i < SAMPLES_COUNT; i++) {
        float3 sample = Get_SphereSample(i, rnd.xy);
        sample *= sign(dot(sample, vNormal));
        ssao += SampleOcclusion(SampleStart+sample*SSAO_RADIUS, vPos.z);
    }
    ssao = 1.0 - ssao/SAMPLES_COUNT;
    //ssao = pow(ssao, 2.2);
    
    Out.Color = Get_Color(In.Pos.xy);
    Out.Color.rgb *= ssao;
    //Out.Color = float4(ssao,ssao,ssao,1.0);
    
    return Out;
}