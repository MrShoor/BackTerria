import bpy
import os
import numpy as np
import bmesh
import shutil as sh
import sys
from mathutils import Vector
from enum import Enum

OX = 0
OY = 2
OZ = 1
OW = 3
MaxWeightsCount = 4;

class MapType(Enum):
    Unknown = 0
    Hardness = 1
    AO = 2
    Metallic = 3
    
class ImageAdapter:
    def __init__(self, Image):
        self.Image = Image
        if (not Image is None):
            self.TargetName = Image.name
            self.TargetSize = Image.size
        else:
            self.TargetName = ''
            self.TargetSize = [0, 0]
        self.Pixels = []
    
pack_pbr_types = ([MapType.Hardness, MapType.Metallic, MapType.AO])
        
imgToRemove = {}

class StreamOut:
    outfile = None
    outfilename = ''
    
    def __init__(self, fname):
        if os.path.isfile(fname):
            os.remove(fname)
        self.outfile = open(fname, 'wb')
        self.outfilename = fname
    def WFloat(self, value):
        self.outfile.write(np.float32(value))
    def WInt(self, value):
        self.outfile.write(np.int32(value))
    def WStr(self, value):
        b = value.encode('utf-8');
        self.WInt(len(b))
        self.outfile.write(b)
    def WBool(self, value):
        if value:
            self.outfile.write(np.ubyte(1))
        else:
            self.outfile.write(np.ubyte(0))
    def WMatrix(self, m):
        self.WFloat(m[OX][OX])
        self.WFloat(m[OY][OX])
        self.WFloat(m[OZ][OX])
        self.WFloat(m[OW][OX])
        
        self.WFloat(m[OX][OY])
        self.WFloat(m[OY][OY])
        self.WFloat(m[OZ][OY])
        self.WFloat(m[OW][OY])
        
        self.WFloat(m[OX][OZ])
        self.WFloat(m[OY][OZ])
        self.WFloat(m[OZ][OZ])
        self.WFloat(m[OW][OZ])
        
        self.WFloat(m[OX][OW])
        self.WFloat(m[OY][OW])
        self.WFloat(m[OZ][OW])
        self.WFloat(m[OW][OW])
        
    def WVec(self, v):
        self.WFloat(v[OX])
        self.WFloat(v[OY])
        self.WFloat(v[OZ])
        
    def WTexVec(self, v):
        self.WFloat(v[0])
        self.WFloat(1.0-v[1])
        
    def WColor(self, c):
        self.WFloat(c[0])
        self.WFloat(c[1])
        self.WFloat(c[2])
        self.WFloat(c[3])
        
def Export(so, pack_pbr = False):
    
    #meshToVertexGroup = {}
    meshes_to_id = {}
    meshes_lst = []
    meshes_to_vgroups = {}
    materials_to_id = {}
    materials_lst = []
    
    def CollectMeshes(objects, meshes_to_id, meshes_lst, meshes_to_vgroup):
        for obj in objects:
            mesh = obj.data
            if not mesh in meshes_to_id:
                meshes_to_vgroups[mesh] = obj.vertex_groups
                meshes_to_id[mesh] = len(meshes_lst)
                meshes_lst += [mesh]
    
    def CollectMaterials(meshes, materials_to_id, materials_lst):
        for mesh in meshes:
            for mat in mesh.materials:
                if not mat in materials_to_id:
                    materials_to_id[mat] = len(materials_lst)
                    materials_lst += [mat]
    
    #faces - list of bm.faces, verts - list of vertex positions
    def EvalSmoothNormals(faces, verts):
        normals = [Vector((0,0,0))]*len(verts)
        for f in faces:
            p1 = verts[f.verts[0].index]
            p2 = verts[f.verts[1].index]
            p3 = verts[f.verts[2].index]
            n = (p2-p1).cross(p3-p1)
            if (n.dot(f.normal) < 0):
                n = -n
            normals[f.verts[0].index] = normals[f.verts[0].index] + n
            normals[f.verts[1].index] = normals[f.verts[1].index] + n
            normals[f.verts[2].index] = normals[f.verts[2].index] + n    
        for n in normals:
            n.normalize()
        return normals    
    
    def WriteMesh(mesh, materials_to_id, vgroups):
        sys.stdout.write('Write mesh: ' + mesh.name + ' ... ')
        
        bm = bmesh.new()
        try:
            so.WStr(mesh.name)
            
            so.WInt(len(mesh.materials))
            for mat in mesh.materials:
                so.WInt(materials_to_id[mat])
            
            shapekeys = []
            
            bm.from_mesh(mesh)
            bmesh.ops.triangulate(bm, faces=bm.faces)
            
            morph_frames = [];
            blend_shapes = [];
            
            if len(bm.verts.layers.shape) > 0:
                if mesh.shape_keys.use_relative:
                    skname = mesh.shape_keys.reference_key.name
                    sk = bm.verts.layers.shape.get(skname)
                    verts = [v[sk] for v in bm.verts]
                    norms = EvalSmoothNormals(bm.faces, verts)
                    morph_frames += [(verts, norms, skname, 0)]
                    for bsname in bm.verts.layers.shape.keys():
                        if bsname == skname:
                            continue
                        bs = bm.verts.layers.shape.get(bsname)
                        bsverts = [v[bs] for v in bm.verts]
                        bsnorms = EvalSmoothNormals(bm.faces, bsverts)
                        
                        delta_verts = []
                        delta_norms = []
                        delta_idx = []                        
                        for i in range(len(verts)):
                            bsverts[i] -= verts[i]
                            bsnorms[i] -= norms[i]
                            l1 = bsverts[i].length_squared
                            l2 = bsnorms[i].length_squared
                            if ((l1>0.001) or (l2>0.0001)):
                                delta_verts += [bsverts[i]]
                                delta_norms += [bsnorms[i]]
                                delta_idx += [i]
                        blend_shapes += [(delta_idx, delta_verts, delta_norms, bsname)]
                else:
                    for skname in bm.verts.layers.shape.keys():
                        sk = bm.verts.layers.shape.get(skname)
                        verts = [v[sk] for v in bm.verts]
                        norms = EvalSmoothNormals(bm.faces, verts)
                        time = mesh.shape_keys.key_blocks[skname].frame
                        morph_frames += [(verts, norms, skname, time)]
            else:
                verts = [v.co for v in bm.verts]
                norms = EvalSmoothNormals(bm.faces, verts)
                morph_frames += [(verts, norms, '', 0)]
            
            uvmaps = [] if bm.loops.layers.uv.active is None else [bm.loops.layers.uv.active]
            for uv in bm.loops.layers.uv.values():
                if (uv != uvmaps[0]):
                    uvmaps += [uv]
            uvmaps = uvmaps[:2]
                        
            #vert idx
            vert_hash = {}
            vert_lst = []
            tris_indices = []
            ind_remap = {}
            bm.verts.ensure_lookup_table()
            for f in bm.faces:
                for i in range(3):
                    uvs = (\
                        (0,0) if len(uvmaps) == 0 else tuple(f.loops[i][uvmaps[0]].uv), \
                        (0,0) if len(uvmaps) <= 1 else tuple(f.loops[i][uvmaps[1]].uv)  \
                        )
                    custom_norm = (0,0,0) if f.smooth else tuple(f.normal)
                    
                    mat_idx = f.material_index if len(mesh.materials) > 0 else -1
                                            
                    gr = [(g.group, g.weight) for g in mesh.vertices[f.verts[i].index].groups if g.group >= 0]
                    gr.sort(key=lambda w: w[1], reverse=True)
                    gr = gr[0:MaxWeightsCount]

                    new_vertex = (f.verts[i].index, f.smooth, custom_norm, mat_idx, uvs, tuple(gr))
                    if new_vertex in vert_hash:
                        tris_indices += [ vert_hash[new_vertex] ]
                    else:
                        vert_hash[new_vertex] = len(vert_lst)
                        tris_indices += [ len(vert_lst) ]
                        vert_lst += [new_vertex]
                    if f.verts[i].index in ind_remap:
                        ind_remap[f.verts[i].index] += [tris_indices[-1]]
                    else:
                        ind_remap[f.verts[i].index] = [tris_indices[-1]]
            
            #write vertices len
            so.WInt(len(vert_lst))
                        
            #common vertex data
            for vert in vert_lst:
                so.WTexVec(vert[4][0]) #write UV1
                so.WTexVec(vert[4][1]) #write UV2
                gr = vert[5]
                summW = 0;
                for g in gr:
                    summW += g[1]
                so.WInt(len(gr))
                for g in gr:
                    so.WInt( g[0] )
                    so.WFloat(g[1]/summW)
                so.WInt(vert[3]) #write material index                

            #write morphs len
            so.WInt(len(morph_frames))
            #morph vertex data
            for morph in morph_frames:
                so.WStr(morph[2]) #write morph name
                so.WInt(morph[3]) #write morph time
                for vert in vert_lst:
                    so.WVec(morph[0][vert[0]]) #write coord
                    so.WVec(morph[1][vert[0]] if vert[1] else vert[2]) #write normal
                    
            #write indices
            so.WInt(len(tris_indices))
            for i in tris_indices:
                so.WInt(i)
                
            #write blend shapes
            so.WInt(len(blend_shapes))
            for shape in blend_shapes:
                so.WStr(shape[3]) #write blend shape name
                vert_cnt = 0
                for oldind in shape[0]:
                    for ind in ind_remap[oldind]:
                        vert_cnt += 1
                so.WInt(vert_cnt)
                for oldind, vert, norm in zip(shape[0], shape[1], shape[2]):
                    for ind in ind_remap[oldind]:
                        so.WVec(vert) #delta coord
                        so.WVec(norm) #delta normal
                        so.WInt(ind) #affected index
                        
            #write vertex groups
            so.WInt(len(vgroups))
            for vg in vgroups:
                so.WStr(vg.name)
                
            print('done')
        finally:
            bm.free()
            del bm
            
    def WriteObjectInstance(obj, meshes_to_id, arm_to_idx):
        sys.stdout.write('Write instance: ' + obj.name + ' ... ')
        obj.update_from_editmode()
        so.WStr(obj.name)
        so.WMatrix(obj.matrix_parent_inverse.inverted()*obj.matrix_local)
        so.WInt(meshes_to_id[obj.data])
        so.WInt(arm_to_idx.get(obj.parent, -1))
        so.WMatrix(obj.matrix_parent_inverse) #bind transform
        print('done')
        
    def GetPoseBoneAbsTransform(bone):
        #return bone.id_data.matrix_world*bone.matrix_channel*bone.id_data.matrix_world.inverted()
        #return arm_transform * bone.matrix_channel * arm_transform.inverted()
        return bone.matrix_channel
    
    def GetPoseBoneTransform(bone):
        m = GetPoseBoneAbsTransform(bone)
        if not (bone.parent is None):
            m2 = GetPoseBoneAbsTransform(bone.parent)
            m = m2.inverted()*m
        else:
            m = bone.id_data.matrix_local * m
        return m
        
    def WriteArmature(obj):
        obj.update_from_editmode()
        so.WStr(obj.name)
        so.WMatrix(obj.matrix_local.inverted())
        
        #indexing bones
        bones_lst = []
        bonename_to_idx = {}
        bone_to_idx = {}
        for b in obj.pose.bones:
            bonename_to_idx[b.name] = len(bones_lst)
            bone_to_idx[b] = len(bones_lst)
            bones_lst += [b]
            
        #saving bones
        so.WInt(len(bones_lst))
        for b in bones_lst:
            so.WStr(b.name)
        for b in bones_lst:
            so.WInt(bone_to_idx.get(b.parent, -1)) #save parent index
        for b in bones_lst:
            so.WMatrix(GetPoseBoneTransform(b))
            
        #saving animations
        def GetAffectedBones(action):
            def GetChannelName(channel):
                return channel.data_path.split('["')[1].split('"]')[0]
            affectedNames = {}
            for g in action.groups:
                for c in g.channels:
                    CName = GetChannelName(c)
                    boneIdx = bonename_to_idx.get(CName, -1)
                    if (boneIdx>=0):
                        affectedNames[CName] = boneIdx
            return affectedNames.values()
        
        actions_to_save = {}
        for act in bpy.data.actions:
            afbones = GetAffectedBones(act)
            if len(afbones) > 0:
                actions_to_save[act] = afbones
        
        so.WInt(len(actions_to_save))
        for act, abones in actions_to_save.items():
            so.WStr(act.name)
            so.WInt(len(act.pose_markers))
            for mark in act.pose_markers:
                so.WStr(mark.name)
                so.WInt(mark.frame)
            
            so.WInt(len(abones))
            for boneidx in abones:
                so.WInt(boneidx)
            
            oldAction = obj.animation_data.action
            oldFrame = bpy.context.scene.frame_current
            try:
                obj.animation_data.action = act
                frameStart = int(act.frame_range[0])
                frameEnd = int(act.frame_range[1]) + 1
                so.WInt(frameStart)
                so.WInt(frameEnd)
                for frame in range(frameStart, frameEnd):
                    bpy.context.scene.frame_set(frame)
                    for boneIdx in abones:
                        so.WMatrix(GetPoseBoneTransform(bones_lst[boneIdx]))
            finally:
                bpy.context.scene.frame_set(oldFrame)
                obj.animation_data.action = oldAction

    imgToSave = {}
    imgProcessed = {}
    def AddImageToSave(material, image, map_type = MapType.Unknown):
        if image is None:
            return ''
        
        procKey = (material, image, map_type)
        procResult = imgProcessed.get(procKey, '')
        if (procResult != ''):
            return procResult
        if ("NewSize" in material):
            def_size = (material["NewSize"], material["NewSize"])
        else:
            def_size = (material.get("NewSizeX", image.size[0]), material.get("NewSizeY", image.size[1]))
        
        adapter = ImageAdapter(image)
        
        if (pack_pbr and (map_type in pack_pbr_types)):
            packed_image_name = material.name + '_pbrpack_mtl_ao_rg.png'
            adapter = imgToSave.get(packed_image_name)
            if (adapter is None):
                adapter = ImageAdapter(None)
                adapter.TargetName = packed_image_name
                adapter.TargetSize = def_size;
                adapter.Pixels = [material.specular_color[0], 1.0, material.specular_hardness/512.0, 0.0]*adapter.TargetSize[0]*adapter.TargetSize[1]
                imgToSave[adapter.TargetName] = adapter
            
            doremove = False
            srcimg = image
            try:
                if (adapter.TargetSize != image.size):
                    srcimg = image.copy()
                    doremove = True
                    srcimg.scale(adapter.TargetSize[0], adapter.TargetSize[1])
                    
                channel = 2
                if (map_type == MapType.AO):
                  channel = 1
                elif(map_type == MapType.Metallic):
                  channel = 0
                
                src_pixels = srcimg.pixels[:]
                for i in range(channel, len(adapter.Pixels), 4):
                    adapter.Pixels[i] = src_pixels[i]
            finally:
                if (doremove):
                    bpy.data.images.remove(srcimg)
        else:
            if (def_size != image.size):
                img = image.copy()
                imgToRemove[img.name] = True
                img.scale(def_size[0], def_size[1])
                adapter.Image = img
                adapter.TargetSize = def_size
                adapter.TargetName = image.name
        
        imgToSave[adapter.TargetName] = adapter
        imgProcessed[procKey] = adapter.TargetName        
        return adapter.TargetName
    
    def SaveAllImages():
        outdir = os.path.dirname(so.outfilename)
        
        for name, adapter in imgToSave.items():
            new_path = os.path.join(outdir, adapter.TargetName)
            #print('new_path: '+new_path);
            if (not adapter.Image is None):
                img = adapter.Image
                old_path = img.filepath_raw
                old_format = img.file_format
                img.filepath_raw = new_path
                img.file_format = 'PNG'
                img.save()
                img.filepath_raw = old_path
                img.file_format = old_format
            else:
                img = bpy.data.images.new('', adapter.TargetSize[0], adapter.TargetSize[1])
                try:
                    img.filepath_raw = new_path
                    img.file_format = 'PNG'
                    img.pixels = adapter.Pixels
                    img.save()
                finally:
                    bpy.data.images.remove(img)

    def WriteMaterial(mat):
        #default initializaiton
        m_diffuseColor = [1,1,1,1]
        m_specularColor = [1,1,1,1]
        m_specularHardness = 50
        m_specularIOR = 0
        m_emitFactor = 0;
        
        diffuseMap_Intensity = ''
        diffuseMap_IntensityFactor = 0            
        diffuseMap_Color = ''
        diffuseMap_ColorFactor = 0
        diffuseMap_Alpha = ''
        diffuseMap_AlphaFactor = 0
        diffuseMap_Translucency = ''
        diffuseMap_TranslucencyFactor = 0
        shadingMap_Ambient = ''
        shadingMap_AmbientFactor = 0
        shadingMap_Emit = ''
        shadingMap_EmitFactor = 0
        shadingMap_Mirror = ''
        shadingMap_MirrorFactor = 0
        shadingMap_RayMirror = ''
        shadingMap_RayMirrorFactor = 0        
        specularMap_Intensity = ''
        specularMap_IntensityFactor = 0
        specularMap_Color = ''
        specularMap_ColorFactor = 0
        specularMap_Hardness = ''
        specularMap_HardnessFactor = 0     
        geometryMap_Normal = ''
        geometryMap_NormalFactor = 0
        geometryMap_Warp = ''
        geometryMap_WarpFactor = 0
        geometryMap_Displace = ''
        geometryMap_DisplaceFactor = 0
        
        #reading parameters from material
        m_diffuseColor = [c*mat.diffuse_intensity for c in mat.diffuse_color]
        m_diffuseColor.append(mat.alpha)
        m_specularColor = [c*mat.specular_intensity for c in mat.specular_color]
        m_specularColor.append(mat.specular_alpha)
        m_specularHardness = mat.specular_hardness
        m_specularIOR = mat.specular_ior
        m_emitFactor = mat.emit
        
        for ts in mat.texture_slots:
            if (not ts is None) and (ts.use) and (not ts.texture is None) and (ts.texture.type == 'IMAGE') and (not ts.texture.image is None):
                if ts.use_map_diffuse:
                    diffuseMap_Intensity = AddImageToSave(mat, ts.texture.image)
                    diffuseMap_IntensityFactor = ts.diffuse_factor
                if ts.use_map_color_diffuse:
                    diffuseMap_Color = AddImageToSave(mat, ts.texture.image)
                    diffuseMap_ColorFactor = ts.diffuse_color_factor
                if ts.use_map_alpha:
                    diffuseMap_Alpha = AddImageToSave(mat, ts.texture.image)
                    diffuseMap_AlphaFactor = ts.alpha_factor
                if ts.use_map_translucency:
                    diffuseMap_Translucency = AddImageToSave(mat, ts.texture.image)
                    diffuseMap_TranslucencyFactor = ts.alpha_factor
                if ts.use_map_ambient:
                    shadingMap_Ambient = AddImageToSave(mat, ts.texture.image, MapType.AO)
                    shadingMap_AmbientFactor = ts.ambient_factor
                if ts.use_map_emit:
                    shadingMap_Emit = AddImageToSave(mat, ts.texture.image)
                    shadingMap_EmitFactor = ts.emit_factor
                if ts.use_map_mirror:
                    shadingMap_MirrorFactor = AddImageToSave(mat, ts.texture.image)
                    shadingMap_MirrorFactor = ts.mirror_factor
                if ts.use_map_raymir:
                    shadingMap_RayMirrorFactor = AddImageToSave(mat, ts.texture.image)
                    shadingMap_RayMirrorFactor = ts.raymir_factor
                if ts.use_map_reflect:
                    specularMap_Intensity = AddImageToSave(mat, ts.texture.image, MapType.Metallic)
                    specularMap_IntensityFactor = ts.specular_factor
                if ts.use_map_color_spec:
                    specularMap_Color = AddImageToSave(mat, ts.texture.image)
                    specularMap_ColorFactor = ts.specular_color_factor
                if ts.use_map_hardness:
                    specularMap_Hardness = AddImageToSave(mat, ts.texture.image, MapType.Hardness)
                    specularMap_HardnessFactor = ts.hardness_factor
                if ts.use_map_normal:
                    geometryMap_Normal = AddImageToSave(mat, ts.texture.image)
                    geometryMap_NormalFactor = ts.normal_factor                                
                if ts.use_map_warp:
                    geometryMap_Warp = AddImageToSave(mat, ts.texture.image)
                    geometryMap_WarpFactor = ts.warp_factor
                if ts.use_map_displacement:
                    geometryMap_Displace = AddImageToSave(mat, ts.texture.image)
                    geometryMap_DisplaceFactor = ts.displacement_factor                  
        
        #saving material params                
        so.WColor(m_diffuseColor)
        so.WColor(m_specularColor)
        so.WFloat(m_specularHardness)
        so.WFloat(m_specularIOR)
        so.WFloat(m_emitFactor)
        
        so.WStr(diffuseMap_Intensity)
        so.WFloat(diffuseMap_IntensityFactor)
        so.WStr(diffuseMap_Color)
        so.WFloat(diffuseMap_ColorFactor)
        so.WStr(diffuseMap_Alpha)
        so.WFloat(diffuseMap_AlphaFactor)
        so.WStr(diffuseMap_Translucency)
        so.WFloat(diffuseMap_TranslucencyFactor)
        so.WStr(shadingMap_Ambient)
        so.WFloat(shadingMap_AmbientFactor)
        so.WStr(shadingMap_Emit)
        so.WFloat(shadingMap_EmitFactor)
        so.WStr(shadingMap_Mirror)
        so.WFloat(shadingMap_MirrorFactor)
        so.WStr(shadingMap_RayMirror)
        so.WFloat(shadingMap_RayMirrorFactor)
        so.WStr(specularMap_Intensity)
        so.WFloat(specularMap_IntensityFactor)
        so.WStr(specularMap_Color)
        so.WFloat(specularMap_ColorFactor)
        so.WStr(specularMap_Hardness)
        so.WFloat(specularMap_HardnessFactor)
        so.WStr(geometryMap_Normal)
        so.WFloat(geometryMap_NormalFactor)
        so.WStr(geometryMap_Warp)
        so.WFloat(geometryMap_WarpFactor)
        so.WStr(geometryMap_Displace)
        so.WFloat(geometryMap_DisplaceFactor)
    
    objs_lst = [obj for obj in bpy.data.objects if obj.type == 'MESH' and len(obj.users_scene) > 0]
    
    CollectMeshes(objs_lst, meshes_to_id, meshes_lst, meshes_to_vgroups)        
    CollectMaterials(meshes_lst, materials_to_id, materials_lst)

    so.WInt(len(materials_lst))
    for mat in materials_lst:
        WriteMaterial(mat)
    SaveAllImages()

    arm_lst = [a for a in bpy.data.objects if (a.type=='ARMATURE') and (len(a.users_scene)>0)]
    arm_to_idx = {arm:i for arm, i in zip(arm_lst, range(len(arm_lst)))}
    so.WInt(len(arm_lst))
    for arm in arm_lst:
        WriteArmature(arm)

    so.WInt(len(meshes_lst))
    for mesh in meshes_lst:
        WriteMesh(mesh, materials_to_id, meshes_to_vgroups[mesh])
        
    so.WInt(len(objs_lst))
    for obj in objs_lst:
        WriteObjectInstance(obj, meshes_to_id, arm_to_idx)

def ExportToFile(fname, packpbr):
    so = StreamOut(fname)
    try:
        Export(so, packpbr)
    finally:
        so.outfile.close()
        del so
        
        for name, toremove in imgToRemove.items():
            if name in bpy.data.images:
                bpy.data.images.remove(bpy.data.images[name])

def TestExport():
    ExportToFile('D:\\test\\out.dat', false)
