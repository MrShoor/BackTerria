#include "hlsl.h"
#include "matrices.h"
#include "utils.h"

struct VS_Input {
    uint VertexID: SV_VertexID;
};

struct VS_Output {
    float4 Pos : SV_Position;
    float2 UV  : UV;
};

float2 Quad[4] = {{-1,-1},{-1,1},{1,-1},{1,1}};

VS_Output VS(VS_Input In) {
    VS_Output Out;
    Out.Pos = float4(Quad[In.VertexID], 0.0, 1.0);
    Out.UV = Quad[In.VertexID]*float2(0.5,-0.5) + float2(0.5,0.5);
    return Out;
}

/////////////////////////////////////////////////////
struct PS_Output {
    float4 Color : SV_Target0;
};

Texture2D Color; SamplerState ColorSampler;
Texture2D Emission; SamplerState EmissionSampler;
int StartEmissionLOD;

float3 ACESFilm(float3 x)
{
    float a = 2.51f;
    float b = 0.03f;
    float c = 2.43f;
    float d = 0.59f;
    float e = 0.14f;
    return saturate((x*(a*x+b))/(x*(c*x+d)+e));
}

float3 tonemapReinhard(float3 x){
    return x / (1.0 + x);
}

float3 Uncharted2Tonemap(float3 x)
{
    float A = 0.15;
    float B = 0.50;
    float C = 0.10;
    float D = 0.20;
    float E = 0.02;
    float F = 0.30;
    
   return ((x*(A*x+C*B)+D*E)/(x*(A*x+B)+D*F))-E/F;
}

float3 Uncharted2TonemapFull(float3 x) {
   float3 curr = Uncharted2Tonemap(x*2);

   float W = 11.2;
   
   float3 whiteScale = 1.0f/Uncharted2Tonemap(W);
   return curr*whiteScale;
}

static const float EmiLODWeight[4] = {0.1, 0.15, 0.34, 0.6};

PS_Output PS(VS_Output In) {
    PS_Output Out;
    Out.Color = Color.Load(int3(In.Pos.xy,0)) + Emission.Sample(EmissionSampler, In.UV);
    Out.Color.xyz = Uncharted2TonemapFull(Out.Color.xyz);
    //Out.Color.xyz = pow(abs(Out.Color.xyz), 1/2.2);
//    float4 emi = 0.0;
//    float lod = StartEmissionLOD;
//    for (int i = 0; i < 4; i++) {
//        emi += Emission.SampleLevel(EmissionSampler, In.UV, lod) * EmiLODWeight[i];
//        lod += 1.0;
//    }
//    Out.Color += emi;
    return Out;
}