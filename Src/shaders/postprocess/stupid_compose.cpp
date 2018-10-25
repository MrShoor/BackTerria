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

static const float EmiLODWeight[4] = {0.1, 0.15, 0.34, 0.6};

PS_Output PS(VS_Output In) {
    PS_Output Out;
    Out.Color = Color.Load(int3(In.Pos.xy,0)) + Emission.Sample(EmissionSampler, In.UV);
    
//    float4 emi = 0.0;
//    float lod = StartEmissionLOD;
//    for (int i = 0; i < 4; i++) {
//        emi += Emission.SampleLevel(EmissionSampler, In.UV, lod) * EmiLODWeight[i];
//        lod += 1.0;
//    }
//    Out.Color += emi;
    return Out;
}