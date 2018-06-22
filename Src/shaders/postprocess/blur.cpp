#include "hlsl.h"

struct VS_Input {
    uint VertexID: SV_VertexID;
};

struct VS_Output {
    float4 Pos : SV_Position;
    float2 UV  : UV;
};

static const float2 Quad[4] = {{-1,-1},{-1,1},{1,-1},{1,1}};

VS_Output VS(VS_Input In) {
    VS_Output Out;
    Out.Pos = float4(Quad[In.VertexID], 0.0, 1.0);
    Out.UV = Quad[In.VertexID]*float2(0.5,-0.5) + float2(0.5,0.5);
    return Out;
}

///////////////////////////////////////////////////////////////////////////////

#define BLUR_WIDTH 9
Texture2D Color; SamplerState ColorSampler;
float2 Direction;
float YLimit;
float ResultMult;

const static float Kernel[BLUR_WIDTH] = {0.0162162162, 0.0540540541, 0.1216216216, 0.1945945946, 0.2270270270, 0.1945945946, 0.1216216216, 0.0540540541, 0.0162162162};

struct PS_Output {
    float4 Color: SV_Target0;
};

PS_Output PS(VS_Output In) {
    PS_Output Out;
    Out.Color = float4(0,0,0,1);
            
    for (int i = 0; i < BLUR_WIDTH; i++) {
        float3 sample = Color.SampleLevel(ColorSampler, In.UV + Direction*(i - (BLUR_WIDTH-1)*0.5), 0).xyz;
        float Y = dot(sample, float3(0.212656, 0.715158, 0.072186));
        Out.Color.xyz += Y > YLimit ? sample * Kernel[i] : 0;
    }
    Out.Color.xyz *= ResultMult;
    return Out;
}