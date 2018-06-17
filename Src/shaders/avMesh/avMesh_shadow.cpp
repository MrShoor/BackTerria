#include "hlsl.h"
#pragma pack_matrix( row_major )
#include "avMesh_common.h"

struct VS_Output {
    float3 Coord     : Coord;
    float2 vsTex     : vsTex;
    float  MatIndex  : MatIndex;
};

VS_Output VS(VS_Input In) {
    VS_Output Out;
    float4x4 mBone = GetBoneTransform(In.vsWIndex+In.aiBoneMatOffset.x, In.vsWeight);
    Out.Coord = mul(float4(In.vsCoord, 1.0), mBone).xyz;
    Out.vsTex = In.vsTex;
    Out.MatIndex = In.aiBoneMatOffset.y + In.vsMatIndex + 0.5;
    return Out;
}

////////////////////////////////////////////////////////

struct GS_Output {
    float4 Pos      : SV_Position;
    uint   ArrayIdx : SV_RenderTargetArrayIndex;
    float2 vsTex    : vsTex;
    float  MatIndex : MatIndex;
};

float4x4 viewProj[6];
uint matCount;
uint sliceOffset;

[maxvertexcount(3*6)]
void GS( triangle VS_Output input[3], inout TriangleStream<GS_Output> OutputStream )
{   
    [unroll]
    for( uint i=0; i<min(6, matCount); i++ )
    {
        [unroll]
        for (uint j=0; j<3; j++)
        {
            GS_Output Out;
            Out.Pos = mul(float4(input[j].Coord,1.0), viewProj[i]);
            Out.ArrayIdx = i;// + sliceOffset;
            Out.vsTex = input[j].vsTex;
            Out.MatIndex = input[j].MatIndex;		
            OutputStream.Append( Out );
        }
        OutputStream.RestartStrip();
    }
}

////////////////////////////////////////////////////////

#include "avModelMaterials.h"

struct PS_Output {
    float4 Color : SV_Target0;
};

void PS(GS_Output In) {
//    ModelMaterialDesc m = LoadMaterialDesc((int)In.MatIndex);
//    float4 diff = m.Diffuse_Color(In.vsTex, m.Diff);
//    if (diff.a < 0.1) discard;
    
//    PS_Output Out;
//    Out.Color = In.Pos.z;
//    return Out;
}