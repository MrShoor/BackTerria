#include "hlsl.h"
#include "matrices.h"
#include "lighting_types.h"

float3 headSize;
RWTexture3D<uint> headBuffer : register(u0);
globallycoherent RWStructuredBuffer<ListNode> lightLinkedList : register(u1);

struct Frustum {
    float4 plane[6];
    float3 pts[8];
};

float3 Unproject(float3 ppt) {
    float4 Out;
    Out = mul(float4(ppt, 1.0), VP_InverseMatrix);
    return Out.xyz/Out.w;
}

float3 ProjectFromView(float3 pt) {
    float4 Out;
    Out = mul(float4(pt, 1.0), P_Matrix);
    return Out.xyz/Out.w;
}

Frustum BuildFrustum(float3 boundmin, float3 boundmax) {
    Frustum Out;
    float3 pt0 = Unproject(boundmin);
    float3 pt1 = Unproject(float3(boundmin.x, boundmax.y, boundmin.z));
    float3 pt2 = Unproject(float3(boundmax.x, boundmin.y, boundmin.z));
    float3 pt3 = Unproject(float3(boundmin.x, boundmax.y, boundmax.z));
    float3 pt4 = Unproject(float3(boundmax.x, boundmin.y, boundmax.z));
    float3 pt5 = Unproject(boundmax);
    Out.plane[0].xyz = -normalize(cross(pt2-pt0, pt1-pt0)); //near
    Out.plane[1].xyz = -normalize(cross(pt4-pt5, pt3-pt5)); //far
    Out.plane[2].xyz = -normalize(cross(pt5-pt4, pt2-pt4)); //right
    Out.plane[3].xyz = -normalize(cross(pt3-pt1, pt0-pt1)); //left
    Out.plane[4].xyz = -normalize(cross(pt1-pt3, pt5-pt3)); //top
    Out.plane[5].xyz = -normalize(cross(pt0-pt2, pt4-pt2)); //bottom

    Out.plane[0].w = -dot(Out.plane[0].xyz, pt0); //near
    Out.plane[1].w = -dot(Out.plane[1].xyz, pt5); //far
    Out.plane[2].w = -dot(Out.plane[2].xyz, pt4); //right
    Out.plane[3].w = -dot(Out.plane[3].xyz, pt1); //left
    Out.plane[4].w = -dot(Out.plane[4].xyz, pt3); //top
    Out.plane[5].w = -dot(Out.plane[5].xyz, pt2); //bottom
    
    Out.pts[0] = pt0;
    Out.pts[1] = pt1;
    Out.pts[2] = pt2;
    Out.pts[3] = pt3;
    Out.pts[4] = pt4;
    Out.pts[5] = pt5;
    Out.pts[6] = Unproject(float3(boundmax.x, boundmax.y, boundmin.z));
    Out.pts[7] = Unproject(float3(boundmin.x, boundmin.y, boundmax.z));
    
    return Out;
}

float3 PointLineProjection(float3 pt, float3 ro, float3 rd_n) {
    float cs = dot(pt-ro, rd_n);
    return ro + rd_n * cs;
}

float4 GetSplitPlane(Light l, float3 pt) {
    float4 pl;
    float3 ptDir = pt - l.PosRange.xyz;
    float ptDirLen = length(ptDir);
    float dot_ptDir_lDir = dot(ptDir, l.Dir);
    if ( dot_ptDir_lDir >= l.Angles.y*ptDirLen ) { //point case
        pl.xyz = normalize(pt - l.PosRange.xyz);
        pl.w = -dot(pl.xyz, l.PosRange.xyz + pl.xyz*l.PosRange.w);        
    } else { //cone side case
        float3 pp = PointLineProjection(pt, l.PosRange.xyz, l.Dir);
        float a = length(pp - l.PosRange.xyz);
        float tn = sqrt( saturate(1.0 - l.Angles.y*l.Angles.y) ) / l.Angles.y;
        float b = a * tn;
        float3 p1 = pp + normalize(pt - pp)*b;
        float b2 = b * tn;
        float3 p2 = pp + l.Dir * b2;
        pl.xyz = normalize(p1 - p2);
        pl.w = -dot(pl.xyz, l.PosRange.xyz);
    }
    return pl;
}

bool LightInFrustum(Light light, Frustum f) {
    uint i;
    uint j;
    for (i = 0; i < 6; i++) {
        if (dot(f.plane[i].xyz, light.PosRange.xyz) + f.plane[i].w > light.PosRange.w) return false;
    }
    for (i = 0; i < 8; i++) {
        float4 pl = GetSplitPlane(light, f.pts[i]);
        for (j = 0; j < 8; j++) {
            if (dot(f.pts[j], pl.xyz)+pl.w < 0) break;
        }
        if (j == 8) return false;
    }
    return true;
}

[numthreads(8, 8, 8)]
void CS(uint3 id: SV_DispatchThreadID)
{
    float3 boundMin = (float3)id / headSize;
    float3 boundMax = ((float3)id + float3(1.0,1.0,1.0)) / headSize;
    
    boundMin.xy = lerp(float2(-1.0, -1.0), float2(1.0, 1.0), boundMin.xy);
    boundMax.xy = lerp(float2(-1.0, -1.0), float2(1.0, 1.0), boundMax.xy);
    boundMin.z = ProjectFromView(float3(0,0,lerp(planesNearFar.x, planesNearFar.y, boundMin.z))).z;
    boundMax.z = ProjectFromView(float3(0,0,lerp(planesNearFar.x, planesNearFar.y, boundMax.z))).z;
    
    Frustum f = BuildFrustum(boundMin, boundMax);
    headBuffer[id] = 0xffffffff;
    for (uint i = 0; i < (uint)lightCount; i++) {
        if (LightInFrustum(light_list[i], f)) {
            uint n = lightLinkedList.IncrementCounter();
            if (n == 0xffffffff) return;
            uint prev_n = headBuffer[id];
            ListNode newNode;
            newNode.LightIdx = i;
            newNode.NextNode = prev_n;
            lightLinkedList[n] = newNode;
            headBuffer[id] = n;
//            headBuffer[id] = 0;
        }
    }
}