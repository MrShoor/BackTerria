#include "hlsl.h"
#include "matrices.h"
#include "avModelMaterials.h"
#include "utils.h"
#include "avMesh_common.h"
#include "clustered_lighting.h"

struct VS_Output {
    float4 Pos       : SV_Position;
    float3 vCoord    : vCoord;
    float3 wCoord    : wCoord;
    float4 pCoord    : pCoord;
    float3 vNorm     : vNorm;
    float2 vTex      : vTex;
    float  MatIndex  : MatIndex;
};

VS_Output VS(VS_Input In) {
    VS_Output Out;
    float4x4 mBone = GetBoneTransform(In.vsWIndex+In.aiBoneMatOffset.x, In.vsWeight);
    float3 crd = mul(float4(In.vsCoord, 1.0), mBone).xyz;
    float3 norm = mul( In.vsNormal, (float3x3) mBone );
    Out.wCoord = crd;
    Out.vCoord = mul(float4(crd, 1.0), V_Matrix).xyz;
    Out.vNorm = mul(normalize(norm), (float3x3)V_Matrix);
    Out.vTex = In.vsTex;
    Out.pCoord = mul(float4(Out.wCoord, 1.0), VP_Matrix);
    Out.Pos = Out.pCoord;
    Out.MatIndex = In.aiBoneMatOffset.y + In.vsMatIndex + 0.5;
    return Out;
}

///////////////////////////////////////////////////////////////////////////////

struct PS_Output {
    float4 Color : SV_Target0;
    //float4 Normal: SV_Target1;
};

static const float LightInt = 3;

PS_Output PS(VS_Output In) {
    PS_Output Out;
    In.vNorm = normalize(In.vNorm);
    
    float2 vTex_dx = ddx(In.vTex);
    float2 vTex_dy = ddy(In.vTex);
    
    float3 vMacroNorm = In.vNorm;
    float2 vTexCoordOrig = In.vTex;
    float vTexH = 0;
    float3x3 tbn = { {1,0,0}, {0,1,0}, {0,0,1} };
   
    ModelMaterialDesc m = LoadMaterialDesc((int)In.MatIndex);
    
    float3 norm = In.vNorm;
    if (m.mapSpecular_Hardness_mapGeometry_Normal.w > 0.001) {
        tbn = CalcTBN(In.vCoord, In.vNorm, In.vTex);
        
//        float3 rayPOM = normalize( mul(tbn, -In.vCoord) );
//        float fLength         = length( rayPOM );
//        float fParallaxLength = sqrt( fLength * fLength - rayPOM.z * rayPOM.z ) / rayPOM.z; 
//        float2 fParallaxOffsetTS = normalize(rayPOM.xy) * fParallaxLength * (0.05);
//        float numSteps = 8 + 16 * dot(In.vNorm, normalize(-In.vCoord));
//        float2 fTexOffsetPerStep = fParallaxOffsetTS / numSteps;
//    
//        float GeomH = 0;
//        float LastGeomH = 0;
//        for (int i = 0; i < numSteps; i++) {
//            LastGeomH = GeomH;
//            GeomH = 1.0 - m.Geometry_Height(In.vTex, vTex_dx, vTex_dy);
//            if ( GeomH < (i/(numSteps-1)) ) {
//                float hOrigin = ((i-1.0)/(numSteps-1));
//                float hSize = numSteps;
//                float h0 = (LastGeomH - hOrigin)*hSize;
//                float h1 = max(0.0001, 1.0 - (GeomH - hOrigin)*hSize);
//                
//                float h11 = (h1 - h0*h1 - h1*h1)/(h0 + h1);
//                float h01 = h0 * h11 / h1;
//                
//                float d = (h0 + h01) / (h1 + h11 + h0 + h01);
//                In.vTex -= fTexOffsetPerStep * d;
//                vTexH = (i - 1 + d)/(numSteps-1);
//                i = numSteps;
//            } else {
//              In.vTex -= fTexOffsetPerStep;
//            }
//        }
        
        norm = UnpackNormal(m.Geometry_Normal(In.vTex, float4(0.5,0.5,1,0)));
        //norm.xy *= 20;
        norm.y = -norm.y;
        norm.x = -norm.x;
        norm = mul(norm, tbn);
        norm = normalize(norm);
    }
    
    float4 diff = m.Diffuse_Color(In.vTex, m.Diff);
    float spec = m.Specular_Intensity(In.vTex, m.Spec).r;
    diff = pow(abs(diff), 2.2);
    
    float4 pCrd = In.pCoord;
    pCrd.xyz /= pCrd.w;    
    //Out.Color = PhongColor(-norm, normalize(In.vCoord), normalize(In.vCoord), 0.5, diff, 1.0, 0.001, 80.0);
    
//    if (false) { //(m.mapSpecular_Hardness_mapGeometry_Normal.w > 0.001) {
//      Out.Color = Clustered_Phong_POMSS(pCrd.xyz, In.vCoord, In.wCoord, norm, normalize(In.vCoord), diff, 0.5, 0.05, 80.0, 
//              tbn, vMacroNorm, In.vTex, vTexCoordOrig, vTexH, m
//              );
//    } else {
//        
      Out.Color = Clustered_Phong(pCrd.xyz, In.vCoord, In.wCoord, norm, normalize(In.vCoord), diff, m.Spec*spec, 0.05, 180.0);
//    }
    Out.Color *= m.Shading_Ambient(In.vTex);
    
    //Out.Color.yz = 0.0;
    //Out.Normal = PackNormal(norm);
    //Out.Color.xyz = 1.0 - m.Geometry_Height(In.vTex, vTex_dx, vTex_dy);
    //Out.Color.w = 1.0;
    //Out.Color.xyz = norm;
    
    return Out;
}
