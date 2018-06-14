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

#define SAMPLES_COUNT 32
#define SSAO_RADIUS 1.0
#define SSAO_BIAS SSAO_RADIUS * 0.05


struct PS_Output {
    float4 Color : SV_Target0;
};

float4 uHammerslayPts[SAMPLES_COUNT];

Texture2D Color; SamplerState ColorSampler;
Texture2D Depth; SamplerState DepthSampler;
Texture2D Normals; SamplerState NormalsSampler;

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
    h *= float2(M_PI,2*M_PI);
    return float3(sin(h.x) * cos(h.y), sin(h.x) * sin(h.y), cos(h.x));
}

float SampleOcclusion(float3 vCoord){
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
    
    float ssao = 0;
    for (int i = 0; i < SAMPLES_COUNT; i++) {
        float3 sample = Get_SphereSample(i, 0);
        sample *= sign(dot(sample, vNormal));
        ssao += SampleOcclusion(SampleStart+sample*SSAO_RADIUS);
    }
    ssao = 1.0 - ssao/SAMPLES_COUNT;
    
    Out.Color = Get_Color(In.Pos.xy);
    Out.Color.rgb *= ssao;
    //Out.Color = float4(ssao,ssao,ssao,1.0);
    
    return Out;
}