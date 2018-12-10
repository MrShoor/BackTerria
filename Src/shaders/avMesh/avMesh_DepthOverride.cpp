#include "hlsl.h"
#include "matrices.h"
#include "avMesh_common.h"

struct VS_Output {
    float4 Pos   : SV_Position;
    float3 vView : vView;
    float3 vNorm : vNorm;
};

VS_Output VS(VS_Input In) {
    VS_Output Out;
    float4x4 mBone = GetBoneTransform(In.vsWIndex+In.aiBoneMatOffset.x, In.vsWeight);
    float3 crd = mul(float4(In.vsCoord, 1.0), mBone).xyz;
    float3 norm = mul( In.vsNormal, (float3x3) mBone );
    Out.vNorm = mul(normalize(norm), (float3x3)V_Matrix);
    Out.vView = mul(float4(crd, 1.0), V_Matrix).xyz;
    Out.Pos = mul(float4(crd, 1.0), VP_Matrix);
    return Out;
}

///////////////////////////////////////////////////////////////////////////////

struct PS_Output {
    float4 Color : SV_Target0;
};

float3 OverrideColor;

PS_Output PS(VS_Output In) {
    PS_Output Out;
    In.vNorm = normalize(In.vNorm);
    In.vView = normalize(In.vView);
    float d = -dot(In.vNorm, In.vView);
    if (d <= 0) discard;
    Out.Color.rgb = OverrideColor;
    Out.Color.a = 1.0-d;
    Out.Color.rgb *= Out.Color.a;
    return Out;
}