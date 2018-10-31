#include "hlsl.h"
#include "matrices.h"

struct VS_In {
    uint VertexID : SV_VertexID;
};

static const float2 Quad[4] = { {-1, -1}, {-1, 1}, {1, -1}, {1, 1} };

struct VS_Out {
    float4 Pos : SV_Position;
    float3 Dir : Dir;
};

VS_Out VS(VS_In In) {
    VS_Out Out;
    Out.Pos = float4(Quad[In.VertexID], 1.0, 1.0);
    float4 tmp = mul(Out.Pos, P_InverseMatrix);
    tmp.xyz /= tmp.w;
    tmp.w = 0.0;
    tmp = mul(tmp, V_InverseMatrix);
    Out.Dir = tmp.xyz;
    return Out;
}

////////////////////////////////////////////////////////////

float3 tonemapReinhard(float3 x){ //input linear, output sRGB
    return x / (1.0 + x);
}

float3 ACESFilm(float3 x) //input linear, output sRGB
{
    float a = 2.51f;
    float b = 0.03f;
    float c = 2.43f;
    float d = 0.59f;
    float e = 0.14f;
    return saturate((x*(a*x+b))/(x*(c*x+d)+e));
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

float3 Uncharted2TonemapFull(float3 x) { //input linear, output sRGB
   float3 curr = Uncharted2Tonemap(x*2);

   float W = 11.2;
   
   float3 whiteScale = 1.0f/Uncharted2Tonemap(W);
   return curr*whiteScale;
}

TextureCube Cube; SamplerState CubeSampler;
float uSampleLevel;

struct PS_Out {
    float4 Color : SV_Target0;
};

PS_Out PS(VS_Out In) {
    PS_Out Out;
    Out.Color = Cube.SampleLevel(CubeSampler, normalize(In.Dir), uSampleLevel);
    Out.Color.xyz = Uncharted2TonemapFull(Out.Color.xyz);
    return Out;
}