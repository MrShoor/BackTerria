#!BPY

bl_info = {
    "name": "Backterria export",
    "description": "Export 3d model for loading at BackTerria game engine",
    "author": "Alexander Busarov",
    "version": (1, 0),
    "blender": (2, 65, 0),
    "location": "File > Import-Export",
    "warning": "", # used for warning icon and text in addons panel
    "wiki_url": "http://wiki.blender.org/index.php/Extensions:2.5/Py/"
                "Scripts/My_Script",
    "category": "Import-Export"}

import bpy
from bpy.props import (
        StringProperty,
        BoolProperty,
        )

from . import bmesh_export_impl

class Export_bMesh(bpy.types.Operator):
    """Export selection to bMesh"""
    bl_idname = "export_scene.bmesh"
    bl_label = "Export bMesh"
    
    filepath = StringProperty(subtype='FILE_PATH')

    do_pbr_pack = BoolProperty(
            name="Pack Metallic, AO, Roghness",
            description="Pack Specular.Intensity, Shading.Ambient, Specular.Hardness in single texture to RGB channels accordingly",
            default=True,
            )
    
    def Export(self):
        File = open(self.filepath, 'w')
        
        for scene in bpy.data.scenes:
            for obj in scene.objects:
                File.write(obj.name)
        File.close()
    
    def execute(self, context):
        self.filepath = bpy.path.ensure_ext(self.filepath, ".bmesh")
        bmesh_export_impl.ExportToFile(self.filepath, self.do_pbr_pack)
        #from . import export_avm_impl
        #Exporter = export_avm_impl.avModelExporter(self, context)
        #self.Export()
        return {'FINISHED'}

    def invoke(self, context, event):
        if not self.filepath:
            self.filepath = bpy.path.ensure_ext(bpy.data.filepath, ".bmesh")
        context.window_manager.fileselect_add(self)
        return {'RUNNING_MODAL'}

def menu_func(self, context):
    self.layout.operator(Export_bMesh.bl_idname, text="bMesh (.bmesh)")

def register():
    bpy.utils.register_module(__name__)

    bpy.types.INFO_MT_file_export.append(menu_func)

def unregister():
    bpy.utils.unregister_module(__name__)

    bpy.types.INFO_MT_file_export.remove(menu_func)

if __name__ == "__main__":
    register()