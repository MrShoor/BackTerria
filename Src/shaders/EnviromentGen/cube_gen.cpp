#include "hlsl.h"
#pragma pack_matrix( row_major )

struct VS_In {
    uint FaceID : SV_VertexID;
};

struct VS_Out {
    uint FaceID : FaceID;
};

VS_Out VS(VS_In In) {
    VS_Out Out;
    Out.FaceID = In.FaceID;
    return Out;
}

////////////////////////////////////////////////////////////
struct GS_Output {
    float4 Pos      : SV_Position;
    uint   ArrayIdx : SV_RenderTargetArrayIndex;
    float3 Dir      : Dir;
};

float4x4 viewProjInv[6];
static const float2 Quad[4] = { {-1, -1}, {-1, 1}, {1, -1}, {1, 1} };

[maxvertexcount(3*6)]
void GS( point VS_Out input[1], inout TriangleStream<GS_Output> OutputStream )
{   
    //[unroll]
    for (uint j=0; j<4; j++)
    {
        GS_Output Out;

        Out.Pos = float4(Quad[j], 0.5, 1.0);
        Out.ArrayIdx = input[0].FaceID;
        float4 tmp = mul(Out.Pos, viewProjInv[input[0].FaceID]);
        tmp.xyz /= tmp.w;
        Out.Dir = tmp.xyz;

        OutputStream.Append( Out );
    }
    OutputStream.RestartStrip();
}

//////////////////////////////////////////////////////////// input uniforms

TextureCube Cube; SamplerState CubeSampler;
float uRoughness;

struct PS_Out {
    float4 Color : SV_Target0;
};

static const float PI = 3.14159265359;

////////////////////////////////////////////////////////////

float4 IntegrateIrradiance(float3 normal) {
    float4 Out = 0;
    
    float3 up    = float3(0.0, 1.0, 0.0);
    float3 right = cross(up, normal);
    up = cross(normal, right);

    float sampleDelta = 0.025;
    float nrSamples = 0.0; 
    for(float phi = 0.0; phi < 2.0 * PI; phi += sampleDelta)
    {
        for(float theta = 0.0; theta < 0.5 * PI; theta += sampleDelta)
        {
            float3 tangentSample = float3(sin(theta) * cos(phi),  sin(theta) * sin(phi), cos(theta));
            float3 sampleVec = tangentSample.x * right + tangentSample.y * up + tangentSample.z * normal;
            Out += Cube.Sample(CubeSampler, sampleVec) * cos(theta) * sin(theta);
            nrSamples++;
        }
    }
    Out = PI * Out * (1.0 / float(nrSamples));    
    return Out;
}

PS_Out PS_Irradiance(GS_Output In) {
    PS_Out Out;
    Out.Color = IntegrateIrradiance(normalize(In.Dir));
    return Out;
}

////////////////////////////////////////////////////////////

float RadicalInverse_VdC(uint bits) 
{
    bits = (bits << 16u) | (bits >> 16u);
    bits = ((bits & 0x55555555u) << 1u) | ((bits & 0xAAAAAAAAu) >> 1u);
    bits = ((bits & 0x33333333u) << 2u) | ((bits & 0xCCCCCCCCu) >> 2u);
    bits = ((bits & 0x0F0F0F0Fu) << 4u) | ((bits & 0xF0F0F0F0u) >> 4u);
    bits = ((bits & 0x00FF00FFu) << 8u) | ((bits & 0xFF00FF00u) >> 8u);
    return float(bits) * 2.3283064365386963e-10; // / 0x100000000
}

float2 Hammersley(uint i, uint N)
{
    return float2(float(i)/float(N), RadicalInverse_VdC(i));
}  

float3 ImportanceSampleGGX(float2 Xi, float3 N, float roughness)
{
    float a = roughness*roughness;
	
    float phi = 2.0 * PI * Xi.x;
    float cosTheta = sqrt((1.0 - Xi.y) / (1.0 + (a*a - 1.0) * Xi.y));
    float sinTheta = sqrt(1.0 - cosTheta*cosTheta);
	
    // from spherical coordinates to cartesian coordinates
    float3 H;
    H.x = cos(phi) * sinTheta;
    H.y = sin(phi) * sinTheta;
    H.z = cosTheta;
	
    // from tangent-space vector to world-space sample vector
    float3 up        = abs(N.z) < 0.999 ? float3(0.0, 0.0, 1.0) : float3(1.0, 0.0, 0.0);
    float3 tangent   = normalize(cross(up, N));
    float3 bitangent = cross(N, tangent);
	
    float3 sampleVec = tangent * H.x + bitangent * H.y + N * H.z;
    return normalize(sampleVec);
}

#define RADIANCE_SAMPLE_COUNT 1024

PS_Out PS_Radiance(GS_Output In) {
    PS_Out Out;
    
    float3 N = normalize(In.Dir);    
    float3 R = N;
    float3 V = R;

    float totalWeight = 0.0;   
    float4 prefilteredColor = 0.0;
    [loop]
    for(uint i = 0u; i < RADIANCE_SAMPLE_COUNT; ++i)
    {
        float2 Xi = Hammersley(i, RADIANCE_SAMPLE_COUNT);
        float3 H  = ImportanceSampleGGX(Xi, N, uRoughness);
        float3 L  = normalize(2.0 * dot(V, H) * H - V);

        float NdotL = max(dot(N, L), 0.0);
        if(NdotL > 0.0)
        {
            prefilteredColor += Cube.SampleLevel(CubeSampler, L, 0.0) * NdotL;
            totalWeight      += NdotL;
        }
    }
    
    Out.Color = prefilteredColor / totalWeight;
    return Out;
}