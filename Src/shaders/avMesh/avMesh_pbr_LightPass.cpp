#include "hlsl.h"
#include "matrices.h"
#include "utils.h"
#include "clustered_lighting.h"

struct VS_Input {
    uint VertexID: SV_VertexID;
};

struct VS_Output {
    float4 Pos : SV_Position;
    float2 PP  : PP;
    //float2 UV  : UV;
};

float2 Quad[4] = {{-1,-1},{-1,1},{1,-1},{1,1}};

VS_Output VS(VS_Input In) {
    VS_Output Out;
    Out.Pos = float4(Quad[In.VertexID], 0.0, 1.0);
    Out.PP = Quad[In.VertexID];
    //Out.UV = Quad[In.VertexID]*FBOFlip * 0.5 + 0.5;
    return Out;
}

///////////////////////////////////////////////////////////////

Texture2D Albedo; SamplerState AlbedoSampler;
Texture2D Norm; SamplerState NormSampler;
Texture2D Rg_AO_Mtl; SamplerState Rg_AO_MtlSampler;
Texture2D Depth; SamplerState DepthSampler;

struct PS_Output {
    float4 Color : SV_Target0;
};

PS_Output PS(VS_Output In) {
    PS_Output Out;
    int3 pixel_crd = int3(In.Pos.xy, 0);
    
    float4 albedo = Albedo.Load(pixel_crd);
    albedo = pow(abs(albedo), 2.2);
    
    float3 norm = (Norm.Load(pixel_crd).xyz - 0.5) * 2.0;
    float3 rg_ao_mtl = Rg_AO_Mtl.Load(pixel_crd).xyz;
    float depth = Depth.Load(pixel_crd).r;
    
    if (depth<0.00001) discard;
    
    float4 pCoord = float4(In.PP, depth, 1.0);
    float4 vCoord = mul(pCoord, P_InverseMatrix);
    float4 wCoord = mul(pCoord, VP_InverseMatrix);
    vCoord.xyz /= vCoord.w;
    wCoord.xyz /= wCoord.w;
    
    float3 F0 = 0.01;
    F0 = lerp(F0, albedo.xyz, rg_ao_mtl.z);

    Out.Color = Clustered_GGX(pCoord.xyz, vCoord.xyz, wCoord.xyz, norm, normalize(vCoord.xyz), albedo, F0, rg_ao_mtl.z, rg_ao_mtl.x);
    Out.Color.xyz *= rg_ao_mtl.y;
    return Out;
}