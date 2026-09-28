bl_info = {
    "name": "Sprite Sheet Generator",
    "author": "GameSome - mabaci",
    "version": (2, 1, 0),
    "blender": (3, 6, 0),
    "location": "View3D > Sidebar > Sprite Sheet",
    "description": "Generate sprite sheets from animations with armature rotation and dynamic sizing",
    "category": "Render",
}

import bpy
import os
import re
import tempfile
import shutil
import numpy as np
from mathutils import Vector, Matrix, Euler
import math
import json
from bpy.props import (
    StringProperty,
    IntProperty,
    BoolProperty,
    EnumProperty,
    FloatProperty,
    PointerProperty,
    CollectionProperty,
)
from bpy.types import (
    Panel,
    Operator,
    PropertyGroup,
    UIList,
)

# ==================== UTILITY FUNCTIONS ====================

def sanitize_filename(name):
    """Remove invalid characters from filename."""
    name = re.sub(r'[<>:"/\\|?*]', '_', name)
    name = re.sub(r'_+', '_', name)
    name = name.strip('_ ')
    if name.startswith('.'):
        name = '_' + name[1:]
    if not name:
        name = "unnamed"
    return name

def get_safe_temp_path(temp_dir, animation_name, angle, frame_index):
    """Create safe temporary file path."""
    safe_name = sanitize_filename(animation_name)
    filename = f"{safe_name}_a{angle}_f{frame_index:04d}.png"
    return os.path.join(temp_dir, filename)

def show_popup(message, title="Info", icon='INFO'):
    """Show a popup dialog with a message."""
    def draw(self, context):
        self.layout.label(text=message)
    bpy.context.window_manager.popup_menu(draw, title=title, icon=icon)

def show_error(message):
    """Show an error popup."""
    show_popup(message, title="Error", icon='ERROR')

def show_warning(message):
    """Show a warning popup."""
    show_popup(message, title="Warning", icon='ERROR')

def show_info(message):
    """Show an info popup."""
    show_popup(message, title="Information", icon='INFO')


class SpriteSheetCore:
    """Core functionality for sprite sheet generation."""
    
    @staticmethod
    def get_object_bounding_box_in_frame(obj, frame, camera=None):
        """Calculate object's bounding box in camera view for a specific frame."""
        if not obj:
            return (-1, -1, 1, 1)
        
        bpy.context.scene.frame_set(frame)
        
        if obj.type == 'ARMATURE':
            meshes = [child for child in obj.children if child.type == 'MESH']
            if not meshes:
                return (-1, -1, 1, 1)
            target_objects = meshes
        else:
            target_objects = [obj]
        
        if camera is None:
            camera = bpy.context.scene.camera
        
        if not camera:
            return (-1, -1, 1, 1)
        
        scene = bpy.context.scene
        render_width = scene.render.resolution_x
        render_height = scene.render.resolution_y
        
        modelview_matrix = camera.matrix_world.inverted()
        projection_matrix = camera.calc_matrix_camera(
            bpy.context.evaluated_depsgraph_get(),
            x=render_width,
            y=render_height
        )
        
        min_x, min_y = float('inf'), float('inf')
        max_x, max_y = float('-inf'), float('-inf')
        
        for mesh_obj in target_objects:
            bbox_corners = [mesh_obj.matrix_world @ Vector(corner) 
                          for corner in mesh_obj.bound_box]
            
            for corner in bbox_corners:
                view_corner = modelview_matrix @ corner
                proj_corner = projection_matrix @ view_corner.to_4d()
                
                if proj_corner.w != 0:
                    ndc = proj_corner.to_3d() / proj_corner.w
                    min_x = min(min_x, ndc.x)
                    max_x = max(max_x, ndc.x)
                    min_y = min(min_y, ndc.y)
                    max_y = max(max_y, ndc.y)
        
        if min_x == float('inf'):
            return (-1, -1, 1, 1)
        
        return (
            max(-1, min(min_x, 1)),
            max(-1, min(min_y, 1)),
            max(-1, min(max_x, 1)),
            max(-1, min(max_y, 1))
        )
    
    @staticmethod
    def calculate_animation_bounds(obj, action, frame_start, frame_end, sample_count=20):
        """Calculate maximum bounding box across an animation."""
        if not obj or not action:
            return (1.0, 1.0, 0.0)
        
        original_action = obj.animation_data.action if obj.animation_data else None
        if not obj.animation_data:
            obj.animation_data_create()
        obj.animation_data.action = action
        
        camera = bpy.context.scene.camera
        
        max_width = 0
        max_height = 0
        min_center_y = float('inf')
        max_center_y = float('-inf')
        
        frames_to_check = SpriteSheetCore.interpolate_frames(
            frame_start, frame_end, min(sample_count, frame_end - frame_start + 1)
        )
        
        for frame in frames_to_check:
            bbox = SpriteSheetCore.get_object_bounding_box_in_frame(obj, frame, camera)
            width = bbox[2] - bbox[0]
            height = bbox[3] - bbox[1]
            center_y = (bbox[1] + bbox[3]) / 2
            
            max_width = max(max_width, width)
            max_height = max(max_height, height)
            min_center_y = min(min_center_y, center_y)
            max_center_y = max(max_center_y, center_y)
        
        if obj.animation_data:
            obj.animation_data.action = original_action
        
        center_offset_y = (max_center_y + min_center_y) / 2
        
        return (max_width, max_height, center_offset_y)
    
    @staticmethod
    def get_all_actions_from_object(obj):
        """Get all actions associated with an object."""
        actions = []
        
        if not obj:
            return actions
        
        if obj.animation_data and obj.animation_data.nla_tracks:
            for track in obj.animation_data.nla_tracks:
                for strip in track.strips:
                    if strip.action and strip.action not in actions:
                        actions.append(strip.action)
        
        if obj.animation_data and obj.animation_data.action:
            if obj.animation_data.action not in actions:
                actions.append(obj.animation_data.action)
        
        for action in bpy.data.actions:
            if action.users > 0 and action not in actions:
                actions.append(action)
        
        return actions
    
    @staticmethod
    def get_action_frame_range(action):
        """Get the actual frame range of an action. Compatible with Blender 3.6 to 5.x."""
        if not action:
            return (1, 24)
        
        # Blender 5.x uses attribute access, older versions use dictionary-style
        # Check if action has fcurves attribute (new API) or use fallback
        fcurves = None
        
        # Try new API first (Blender 4.0+)
        if hasattr(action, 'fcurves'):
            fcurves = action.fcurves
        # Fallback for very old versions (pre-3.6)
        elif hasattr(action, 'fcurves'):
            fcurves = action.fcurves
        
        if not fcurves:
            return (1, 24)
        
        frame_start = float('inf')
        frame_end = float('-inf')
        
        for fcurve in fcurves:
            if fcurve.keyframe_points:
                points = fcurve.keyframe_points
                frame_start = min(frame_start, points[0].co[0])
                frame_end = max(frame_end, points[-1].co[0])
        
        if frame_start == float('inf'):
            return (1, 24)
        
        return (int(frame_start), int(frame_end))
    
    @staticmethod
    def interpolate_frames(frame_start, frame_end, target_count):
        """Smart frame interpolation to reduce frame count."""
        if target_count <= 0:
            return []
        
        total_frames = frame_end - frame_start + 1
        
        if target_count >= total_frames:
            return list(range(frame_start, frame_end + 1))
        
        selected = []
        step = (total_frames - 1) / max(target_count - 1, 1)
        
        for i in range(target_count):
            frame = frame_start + round(i * step)
            selected.append(frame)
        
        return selected
    
    @staticmethod
    def apply_action_to_object(obj, action, frame_start, frame_end):
        """Apply an action to an object."""
        if not obj or not action:
            return False
        
        if not obj.animation_data:
            obj.animation_data_create()
        
        obj.animation_data.action = action
        
        scene = bpy.context.scene
        scene.frame_start = frame_start
        scene.frame_end = frame_end
        
        return True
    
    @staticmethod
    def rotate_armature(obj, angle_degrees):
        """Rotate armature around its Z-axis (vertical axis)."""
        if not obj or obj.type != 'ARMATURE':
            return
        
        angle_rad = math.radians(angle_degrees)
        obj.rotation_euler.z += angle_rad
    
    @staticmethod
    def get_camera_base_params(camera, target_obj):
        """Get camera distance and height parameters."""
        if not camera or not target_obj:
            return 5.0, 0.0
        
        cam_pos = camera.matrix_world.translation.copy()
        obj_pos = target_obj.matrix_world.translation.copy()
        
        rel = cam_pos - obj_pos
        horizontal_dist = math.sqrt(rel.x**2 + rel.y**2)
        height = rel.z
        
        return horizontal_dist, height
    
    @staticmethod
    def position_camera_for_frame(camera, target_obj, vertical_offset=0.0):
        """Position camera to center on object with vertical offset."""
        if not camera or not target_obj:
            return False
        
        obj_world_pos = target_obj.matrix_world.translation.copy()
        
        aim_point = obj_world_pos.copy()
        aim_point.z += vertical_offset
        
        direction = aim_point - camera.location
        rot_quat = direction.to_track_quat('-Z', 'Y')
        camera.rotation_euler = rot_quat.to_euler()
        
        return True
    
    @staticmethod
    def render_frame(scene, frame, output_path):
        """Render a single frame."""
        scene.frame_set(frame)
        scene.render.filepath = output_path
        bpy.ops.render.render(write_still=True)

# ==================== PROPERTY GROUPS ====================

class AnimationItem(PropertyGroup):
    """Animation item for sprite sheet."""
    name: StringProperty(name="Name", default="anim")
    action_name: StringProperty(name="Action", default="")
    frame_start: IntProperty(name="Start", default=1, min=1)
    frame_end: IntProperty(name="End", default=24, min=1)
    target_frames: IntProperty(name="Frames", default=10, min=1, max=100)
    enabled: BoolProperty(name="Active", default=True)
    auto_scale: BoolProperty(
        name="Auto Scale",
        description="Automatically calculate sprite size for this animation",
        default=True
    )
    calculated_scale: FloatProperty(name="Calculated Scale", default=1.0, min=0.5, max=2.0)

class SpriteSheetSettings(PropertyGroup):
    """Main sprite sheet settings."""
    
    active_animation_index: IntProperty(default=-1, min=-1)
    
    output_path: StringProperty(
        name="Output Folder",
        description="Folder to save the sprite sheet",
        default=tempfile.gettempdir(),
        subtype='DIR_PATH'
    )
    
    output_filename: StringProperty(
        name="Filename",
        default="sprite_sheet"
    )
    
    base_sprite_width: IntProperty(name="Base Width", default=64, min=16, max=512)
    base_sprite_height: IntProperty(name="Base Height", default=64, min=16, max=512)
    
    use_dynamic_sizing: BoolProperty(
        name="Dynamic Sizing",
        description="Auto-adjust sprite size for animations like jump",
        default=False
    )
    
    max_sprite_width: IntProperty(name="Max Width", default=128, min=64, max=512)
    max_sprite_height: IntProperty(name="Max Height", default=128, min=64, max=512)
    
    padding_percent: FloatProperty(
        name="Padding %",
        description="Padding around sprites",
        default=10.0,
        min=0.0,
        max=50.0
    )
    
    columns: IntProperty(name="Columns", default=10, min=1, max=50)
    
    use_front: BoolProperty(name="Front (0°)", default=True)
    use_right: BoolProperty(name="Right (90°)", default=True)
    use_back: BoolProperty(name="Back (180°)", default=True)
    use_left: BoolProperty(name="Left (270°)", default=True)
    
    flip_y: BoolProperty(
        name="Flip Y Axis",
        description="Flip sprites vertically to correct orientation",
        default=False
    )
    
    track_origin: BoolProperty(
        name="Track Origin",
        description="Camera follows object origin point each frame",
        default=False
    )
    
    include_all_actions: BoolProperty(
        name="Include All Actions",
        default=True
    )
    
    animations: CollectionProperty(type=AnimationItem)

# ==================== OPERATORS ====================

class SPRITESHEET_OT_help(Operator):
    """Show help and documentation"""
    bl_idname = "spritesheet.show_help"
    bl_label = "Help"
    bl_description = "Show usage instructions and documentation"

    def execute(self, context):
        return {'FINISHED'}

    def invoke(self, context, event):
        return context.window_manager.invoke_popup(self, width=500)

    def draw(self, context):
        layout = self.layout

        # Title
        layout.label(text="Sprite Sheet Generator - Help", icon='INFO')
        layout.separator()

        # Quick Start Guide
        box = layout.box()
        box.label(text="Quick Start Guide:", icon='HELP')

        instructions = [
            "1. Select your armature in the 3D Viewport",
            "2. Make sure that all actions are visible in the Dope Sheet/Action Editor.",
            "3. Click 'Detect' to find all animations",
            "4. Choose view angles (Front, Right, Back, Left)",
            "5. Set output folder and filename",
            "6. Click 'Generate Sprite Sheet'",
        ]

        for line in instructions:
            box.label(text=line)

        layout.separator()

        # Tips
        box = layout.box()
        box.label(text="Tips:", icon='LIGHT')

        tips = [
            "• Use transparent background (Render Properties > Film > Transparent)",
            "• Position camera at character's center height",
            "• Enable 'Dynamic Sizing' for jump/fall animations",
            "* Make sure the origin point is at the center of the object and armature.",
            "• Start with low frame counts for testing",
        ]

        for tip in tips:
            box.label(text=tip)

        layout.separator()

        # View Angles Info
        box = layout.box()
        box.label(text="View Angles:", icon='ORIENTATION_VIEW')

        angles_info = [
            "Front (0°)  - Default view",
            "Right (90°) - Side view",
            "Back (180°) - Behind view",
            "Left (270°) - Other side",
        ]

        for info in angles_info:
            box.label(text=info)

        layout.separator()
        layout.label(text="For more help, visit the GitHub repository. //github.com/GameSomeStudio", icon='URL')


class SPRITESHEET_OT_analyze_animation(Operator):
    """Analyze selected animation's bounding box"""
    bl_idname = "spritesheet.analyze_animation"
    bl_label = "Analyze"
    bl_description = "Analyze the selected animation's dimensions"
    
    @classmethod
    def poll(cls, context):
        settings = context.scene.spritesheet_settings
        return settings.active_animation_index >= 0 and context.active_object
    
    def execute(self, context):
        settings = context.scene.spritesheet_settings
        obj = context.active_object
        
        if not obj:
            show_error("Please select an armature first.")
            return {'CANCELLED'}
        
        if obj.type != 'ARMATURE':
            show_error("Selected object must be an armature.")
            return {'CANCELLED'}
        
        anim = settings.animations[settings.active_animation_index]
        action = bpy.data.actions.get(anim.action_name)
        
        if not action:
            show_error("Action not found! Please re-detect actions.")
            return {'CANCELLED'}
        
        width_ndc, height_ndc, center_offset = SpriteSheetCore.calculate_animation_bounds(
            obj, action, anim.frame_start, anim.frame_end
        )
        
        max_scale = max(width_ndc, height_ndc)
        anim.calculated_scale = max_scale
        
        padding_factor = 1 + (settings.padding_percent / 100)
        suggested_width = int(settings.base_sprite_width * max_scale * padding_factor)
        suggested_height = int(settings.base_sprite_height * max_scale * padding_factor)
        
        suggested_width = min(suggested_width, settings.max_sprite_width)
        suggested_height = min(suggested_height, settings.max_sprite_height)
        
        show_info(
            f"Animation: {anim.name}\n"
            f"Scale Factor: {max_scale:.2f}x\n"
            f"Suggested Size: {suggested_width}x{suggested_height}px"
        )
        
        return {'FINISHED'}

class SPRITESHEET_OT_detect_actions(Operator):
    """Scan and add all actions to the list"""
    bl_idname = "spritesheet.detect_actions"
    bl_label = "Detect Actions"
    bl_description = "Scan all actions and add to list (preserves existing list)"
    
    clear_existing: BoolProperty(default=False, options={'HIDDEN'})
    
    def execute(self, context):
        settings = context.scene.spritesheet_settings
        obj = context.active_object
        
        if not obj:
            show_error("Please select an armature in the 3D Viewport first.")
            return {'CANCELLED'}
        
        if obj.type != 'ARMATURE':
            show_error(
                f"The selected object '{obj.name}' is a '{obj.type}', not an armature.\n\n"
                "Please select an armature with animations."
            )
            return {'CANCELLED'}
        
        if settings.include_all_actions:
            all_actions = [a for a in bpy.data.actions if a.users > 0]
        else:
            all_actions = SpriteSheetCore.get_all_actions_from_object(obj)
        
        if not all_actions:
            show_warning(
                "No actions found!\n\n"
                "Make sure your armature has actions assigned.\n"
                "Check the Action Editor or NLA Editor."
            )
            return {'CANCELLED'}
        
        if self.clear_existing:
            settings.animations.clear()
        
        existing_names = {item.action_name for item in settings.animations}
        
        added_count = 0
        for action in all_actions:
            if action.name not in existing_names:
                item = settings.animations.add()
                item.name = sanitize_filename(action.name)
                item.action_name = action.name
                frame_start, frame_end = SpriteSheetCore.get_action_frame_range(action)
                item.frame_start = frame_start
                item.frame_end = frame_end
                item.target_frames = min(10, frame_end - frame_start + 1)
                existing_names.add(action.name)
                added_count += 1
        
        if added_count > 0:
            show_info(f"Added {added_count} new animations to the list.")
        else:
            show_info("All actions are already in the list.")
        
        return {'FINISHED'}

class SPRITESHEET_OT_clear_list(Operator):
    """Clear the animation list"""
    bl_idname = "spritesheet.clear_list"
    bl_label = "Clear List"
    bl_description = "Remove all animations from the list"
    
    def execute(self, context):
        settings = context.scene.spritesheet_settings
        count = len(settings.animations)
        settings.animations.clear()
        settings.active_animation_index = -1
        
        if count > 0:
            show_info(f"Removed {count} animations from the list.")
        
        return {'FINISHED'}

class SPRITESHEET_OT_add_animation(Operator):
    """Add a new animation manually"""
    bl_idname = "spritesheet.add_animation"
    bl_label = "Add Animation"
    
    def execute(self, context):
        settings = context.scene.spritesheet_settings
        item = settings.animations.add()
        item.name = f"anim_{len(settings.animations)}"
        item.frame_start = 1
        item.frame_end = 24
        item.target_frames = 10
        settings.active_animation_index = len(settings.animations) - 1
        return {'FINISHED'}

class SPRITESHEET_OT_remove_animation(Operator):
    """Remove selected animation"""
    bl_idname = "spritesheet.remove_animation"
    bl_label = "Remove"
    
    @classmethod
    def poll(cls, context):
        settings = context.scene.spritesheet_settings
        return settings.active_animation_index >= 0
    
    def execute(self, context):
        settings = context.scene.spritesheet_settings
        idx = settings.active_animation_index
        
        if 0 <= idx < len(settings.animations):
            settings.animations.remove(idx)
            if idx >= len(settings.animations):
                settings.active_animation_index = len(settings.animations) - 1
        
        return {'FINISHED'}

class SPRITESHEET_OT_preview_animation(Operator):
    """Preview selected animation in viewport"""
    bl_idname = "spritesheet.preview_animation"
    bl_label = "Preview"
    
    @classmethod
    def poll(cls, context):
        settings = context.scene.spritesheet_settings
        return settings.active_animation_index >= 0 and context.active_object
    
    def execute(self, context):
        settings = context.scene.spritesheet_settings
        obj = context.active_object
        
        if not obj:
            show_error("Please select an armature first.")
            return {'CANCELLED'}
        
        anim = settings.animations[settings.active_animation_index]
        action = bpy.data.actions.get(anim.action_name)
        
        if action:
            SpriteSheetCore.apply_action_to_object(obj, action, anim.frame_start, anim.frame_end)
            context.scene.frame_set(anim.frame_start)
        else:
            show_warning(f"Action '{anim.action_name}' not found.")
        
        return {'FINISHED'}

class SPRITESHEET_OT_generate(Operator):
    """Generate sprite sheet with armature rotation"""
    bl_idname = "spritesheet.generate"
    bl_label = "Generate Sprite Sheet"
    bl_description = "Generate sprite sheet by rotating the armature for different angles"
    
    @classmethod
    def poll(cls, context):
        settings = context.scene.spritesheet_settings
        return len(settings.animations) > 0 and context.active_object
    
    def execute(self, context):
        settings = context.scene.spritesheet_settings
        obj = context.active_object
        scene = context.scene
        camera = scene.camera
        
        # Validate setup
        if not obj:
            show_error("Please select an armature in the 3D Viewport.")
            return {'CANCELLED'}
        
        if obj.type != 'ARMATURE':
            show_error(
                f"The selected object '{obj.name}' is a '{obj.type}', not an armature.\n\n"
                "Please select an armature with animations."
            )
            return {'CANCELLED'}
        
        if not camera:
            show_error(
                "No camera found in the scene!\n\n"
                "Please add a camera and make it active."
            )
            return {'CANCELLED'}
        
        # Validate output path
        output_dir = bpy.path.abspath(settings.output_path)
        if not os.path.exists(output_dir):
            try:
                os.makedirs(output_dir, exist_ok=True)
            except:
                show_error(
                    f"Cannot access output folder:\n{output_dir}\n\n"
                    "Please choose a different folder."
                )
                return {'CANCELLED'}
        
        if not os.access(output_dir, os.W_OK):
            show_error(
                f"No write permission for folder:\n{output_dir}\n\n"
                "Please choose a folder you have write access to."
            )
            return {'CANCELLED'}
        
        active_animations = [a for a in settings.animations if a.enabled]
        if not active_animations:
            show_error(
                "No animations enabled!\n\n"
                "Check the checkboxes next to the animations you want to render."
            )
            return {'CANCELLED'}
        
        # Get view angles
        view_angles = []
        if settings.use_front: view_angles.append(0)
        if settings.use_right: view_angles.append(90)
        if settings.use_back: view_angles.append(180)
        if settings.use_left: view_angles.append(270)
        
        if not view_angles:
            show_error(
                "No view angles selected!\n\n"
                "Please select at least one view angle (Front, Right, Back, Left)."
            )
            return {'CANCELLED'}
        
        angle_names = {0: "front", 90: "right", 180: "back", 270: "left"}
        
        print("\n" + "="*70)
        print(f"SPRITE SHEET GENERATOR v2.1 - ARMATURE ROTATION MODE")
        print("="*70)
        print(f"Active animations: {len(active_animations)}")
        print(f"View angles: {[f'{angle_names.get(a, a)} ({a}°)' for a in view_angles]}")
        print(f"Total rows: {len(active_animations) * len(view_angles)}")
        print(f"Output: {os.path.join(output_dir, settings.output_filename)}.png")
        
        # Pre-analyze animations
        animation_analyses = {}
        max_sprite_width = settings.base_sprite_width
        max_sprite_height = settings.base_sprite_height
        
        if settings.use_dynamic_sizing:
            print("\nAnalyzing animations...")
            for anim in active_animations:
                if anim.auto_scale:
                    action = bpy.data.actions.get(anim.action_name)
                    if action:
                        width_ndc, height_ndc, center_offset = SpriteSheetCore.calculate_animation_bounds(
                            obj, action, anim.frame_start, anim.frame_end
                        )
                        
                        scale = max(width_ndc, height_ndc)
                        anim.calculated_scale = scale
                        
                        padding_factor = 1 + (settings.padding_percent / 100)
                        sprite_w = int(settings.base_sprite_width * scale * padding_factor)
                        sprite_h = int(settings.base_sprite_height * scale * padding_factor)
                        
                        sprite_w = min(sprite_w, settings.max_sprite_width)
                        sprite_h = min(sprite_h, settings.max_sprite_height)
                        
                        animation_analyses[anim.name] = {
                            'scale': scale,
                            'sprite_width': sprite_w,
                            'sprite_height': sprite_h,
                            'center_offset': center_offset
                        }
                        
                        max_sprite_width = max(max_sprite_width, sprite_w)
                        max_sprite_height = max(max_sprite_height, sprite_h)
                        
                        print(f"  {anim.name}: {scale:.2f}x -> {sprite_w}x{sprite_h}px")
        
        print(f"\nSprite size: {max_sprite_width}x{max_sprite_height}px")
        
        # Save original state
        original_frame = scene.frame_current
        original_action = obj.animation_data.action if obj.animation_data else None
        original_rotation = obj.rotation_euler.copy()
        original_location = obj.location.copy()
        
        orig_res_x = scene.render.resolution_x
        orig_res_y = scene.render.resolution_y
        orig_percentage = scene.render.resolution_percentage
        orig_transparent = scene.render.film_transparent
        
        # Setup render
        scene.render.resolution_x = max_sprite_width
        scene.render.resolution_y = max_sprite_height
        scene.render.resolution_percentage = 100
        scene.render.film_transparent = True
        scene.render.image_settings.file_format = 'PNG'
        scene.render.image_settings.color_mode = 'RGBA'
        
        temp_dir = tempfile.mkdtemp(prefix="spritesheet_")
        all_frames = []
        
        try:
            for anim_idx, anim in enumerate(active_animations):
                print(f"\n{'='*50}")
                print(f"Animation {anim_idx+1}/{len(active_animations)}: {anim.name}")
                
                action = bpy.data.actions.get(anim.action_name)
                if not action:
                    print(f"  WARNING: '{anim.action_name}' not found, skipping!")
                    continue
                
                if settings.use_dynamic_sizing and anim.name in animation_analyses:
                    analysis = animation_analyses[anim.name]
                    sprite_w = analysis['sprite_width']
                    sprite_h = analysis['sprite_height']
                    center_offset = analysis['center_offset']
                else:
                    sprite_w = max_sprite_width
                    sprite_h = max_sprite_height
                    center_offset = 0.0
                
                SpriteSheetCore.apply_action_to_object(
                    obj, action, anim.frame_start, anim.frame_end
                )
                
                frame_list = SpriteSheetCore.interpolate_frames(
                    anim.frame_start, anim.frame_end, anim.target_frames
                )
                
                print(f"  Frames: {len(frame_list)} [{anim.frame_start}-{anim.frame_end}]")
                
                for angle_idx, angle in enumerate(view_angles):
                    angle_name = angle_names.get(angle, str(angle))
                    full_name = f"{anim.name}_{angle_name}"
                    
                    print(f"  [{angle_idx+1}/{len(view_angles)}] {angle_name} ({angle}°)")
                    
                    obj.rotation_euler = original_rotation.copy()
                    SpriteSheetCore.rotate_armature(obj, angle)
                    bpy.context.view_layer.update()
                    
                    frame_paths = []
                    
                    for i, frame in enumerate(frame_list):
                        scene.frame_set(frame)
                        
                        if settings.track_origin:
                            SpriteSheetCore.position_camera_for_frame(
                                camera, obj, center_offset
                            )
                        
                        temp_path = get_safe_temp_path(temp_dir, full_name, angle, i)
                        scene.render.resolution_x = sprite_w
                        scene.render.resolution_y = sprite_h
                        SpriteSheetCore.render_frame(scene, frame, temp_path)
                        frame_paths.append(temp_path)
                    
                    all_frames.append((full_name, frame_paths, sprite_w, sprite_h))
                    print(f"  Done: {len(frame_paths)} frames rendered")
                    
                    obj.rotation_euler = original_rotation.copy()
                    bpy.context.view_layer.update()
            
            if all_frames:
                self.create_final_sprite_sheet(all_frames, settings)
                show_info(
                    f"Sprite sheet saved successfully!\n\n"
                    f"File: {settings.output_filename}.png\n"
                    f"Location: {output_dir}\n"
                    f"Rows: {len(all_frames)}\n"
                    f"Size: {max_sprite_width}x{max_sprite_height}px per sprite"
                )
            else:
                show_error("No frames were rendered. Check the console for details.")
                
        except Exception as e:
            show_error(f"Render error: {str(e)}")
            import traceback
            traceback.print_exc()
            
        finally:
            print(f"\nRestoring original state...")
            
            if obj.animation_data:
                obj.animation_data.action = original_action
            
            obj.rotation_euler = original_rotation
            obj.location = original_location
            bpy.context.view_layer.update()
            
            scene.frame_set(original_frame)
            scene.render.resolution_x = orig_res_x
            scene.render.resolution_y = orig_res_y
            scene.render.resolution_percentage = orig_percentage
            scene.render.film_transparent = orig_transparent
            
            if os.path.exists(temp_dir):
                shutil.rmtree(temp_dir)
                print("Temporary files cleaned up")
            
            print(f"Done!")
        
        return {'FINISHED'}
    
    def create_final_sprite_sheet(self, all_frames, settings):
        """Combine all frames into final sprite sheet."""
        
        max_w = max(frame_data[2] for frame_data in all_frames)
        max_h = max(frame_data[3] for frame_data in all_frames)
        
        max_w = max(max_w, 1)
        max_h = max(max_h, 1)
        
        total_rows = len(all_frames)
        sheet_width = settings.columns * max_w
        sheet_height = total_rows * max_h
        
        print(f"\n{'='*50}")
        print(f"CREATING SPRITE SHEET")
        print(f"  Max sprite: {max_w}x{max_h}px")
        print(f"  Sheet: {sheet_width}x{sheet_height}px")
        
        sheet_pixels = np.zeros((sheet_height, sheet_width, 4), dtype=np.float32)
        
        for row, (anim_name, frame_paths, sprite_w, sprite_h) in enumerate(all_frames):
            placed = 0
            actual_w = max(1, sprite_w)
            actual_h = max(1, sprite_h)
            
            for col, frame_path in enumerate(frame_paths):
                if col >= settings.columns:
                    break
                
                img = bpy.data.images.load(frame_path)
                pixels = np.array(img.pixels)
                
                expected_size = actual_h * actual_w * 4
                if len(pixels) != expected_size:
                    actual_pixels = len(pixels) // 4
                    actual_h = int(math.sqrt(actual_pixels * actual_h / actual_w))
                    actual_w = actual_pixels // actual_h
                    if actual_h <= 0 or actual_w <= 0:
                        actual_h = 1
                        actual_w = actual_pixels
                
                pixels = pixels.reshape((actual_h, actual_w, 4))
                
                if settings.flip_y:
                    pixels = np.flipud(pixels)
                
                y_offset = (max_h - actual_h) // 2
                x_offset = (max_w - actual_w) // 2
                
                y_start = row * max_h + y_offset
                y_end = y_start + actual_h
                x_start = col * max_w + x_offset
                x_end = x_start + actual_w
                
                y_end = min(y_end, sheet_height)
                x_end = min(x_end, sheet_width)
                
                if y_end - y_start < actual_h:
                    pixels = pixels[:y_end - y_start, :, :]
                if x_end - x_start < actual_w:
                    pixels = pixels[:, :x_end - x_start, :]
                
                sheet_pixels[y_start:y_end, x_start:x_end] = pixels
                bpy.data.images.remove(img)
                placed += 1
            
            print(f"  Row {row}: {anim_name} ({placed} frames, {actual_w}x{actual_h}px)")
        
        output_path = os.path.join(
            bpy.path.abspath(settings.output_path),
            f"{settings.output_filename}.png"
        )
        
        os.makedirs(os.path.dirname(output_path), exist_ok=True)
        
        sheet_img = bpy.data.images.new(
            name="SpriteSheet",
            width=sheet_width,
            height=sheet_height,
            alpha=True,
            float_buffer=True
        )
        
        sheet_img.pixels = sheet_pixels.flatten()
        sheet_img.filepath_raw = output_path
        sheet_img.file_format = 'PNG'
        sheet_img.save()
        bpy.data.images.remove(sheet_img)
        
        print(f"\nSprite sheet saved: {output_path}")
        
        # Save metadata
        self.save_metadata(output_path, all_frames, max_w, max_h, settings)
    
    def save_metadata(self, output_path, all_frames, max_w, max_h, settings):
        """Save metadata JSON file."""
        metadata_path = output_path.replace('.png', '_metadata.json')
        
        metadata = {
            'sprite_sheet': os.path.basename(output_path),
            'columns': settings.columns,
            'rows': len(all_frames),
            'max_sprite_width': max_w,
            'max_sprite_height': max_h,
            'animations': []
        }
        
        for row, (anim_name, frame_paths, sprite_w, sprite_h) in enumerate(all_frames):
            metadata['animations'].append({
                'name': anim_name,
                'row': row,
                'frame_count': len(frame_paths),
                'sprite_width': max(1, sprite_w),
                'sprite_height': max(1, sprite_h)
            })
        
        with open(metadata_path, 'w') as f:
            json.dump(metadata, f, indent=2)
        
        print(f"Metadata saved: {metadata_path}")

# ==================== UI LIST ====================

class SPRITESHEET_UL_animations(UIList):
    """Animation list UI."""
    
    def draw_item(self, context, layout, data, item, icon, active_data, active_propname):
        if self.layout_type in {'DEFAULT', 'COMPACT'}:
            row = layout.row(align=True)
            row.prop(item, "enabled", text="")
            row.prop(item, "name", text="", emboss=False)
            
            col = row.column()
            col.scale_x = 0.4
            col.label(text=f"[{item.frame_start}-{item.frame_end}]")
            
            row.prop(item, "target_frames", text="")
            
            if item.auto_scale and item.calculated_scale > 1.0:
                row.label(text=f"×{item.calculated_scale:.1f}", icon='FULLSCREEN_ENTER')
        
        elif self.layout_type == 'GRID':
            layout.alignment = 'CENTER'
            layout.label(text=item.name)

# ==================== PANEL ====================

class VIEW3D_PT_sprite_sheet(Panel):
    """Main sprite sheet panel."""
    bl_label = "Sprite Sheet Generator v2.1"
    bl_idname = "VIEW3D_PT_sprite_sheet"
    bl_space_type = 'VIEW_3D'
    bl_region_type = 'UI'
    bl_category = "Sprite Sheet"
    
    def draw(self, context):
        layout = self.layout
        settings = context.scene.spritesheet_settings
        
        # Help button at top
        row = layout.row(align=True)
        row.operator("spritesheet.show_help", text="Help / Instructions", icon='HELP')
        
        layout.separator()
        
        # Object info
        box = layout.box()
        box.label(text="Selected Object:", icon='OBJECT_DATA')
        obj = context.active_object
        if obj:
            icon = 'ARMATURE_DATA' if obj.type == 'ARMATURE' else 'OBJECT_DATA'
            box.label(text=f"  {obj.name} ({obj.type})", icon=icon)
            if obj.type != 'ARMATURE':
                box.label(text="  Select an ARMATURE!", icon='ERROR')
        else:
            box.label(text="  No object selected!", icon='ERROR')
        
        layout.separator()
        
        # Output settings
        box = layout.box()
        box.label(text="Output:", icon='EXPORT')
        box.prop(settings, "output_path")
        box.prop(settings, "output_filename")
        
        layout.separator()
        
        # Sprite size settings
        box = layout.box()
        box.label(text="Sprite Size:", icon='MESH_GRID')
        
        row = box.row(align=True)
        row.prop(settings, "base_sprite_width", text="Base W")
        row.prop(settings, "base_sprite_height", text="Base H")
        
        box.prop(settings, "use_dynamic_sizing", icon='AUTO')
        
        if settings.use_dynamic_sizing:
            row = box.row(align=True)
            row.prop(settings, "max_sprite_width", text="Max W")
            row.prop(settings, "max_sprite_height", text="Max H")
            box.prop(settings, "padding_percent", text="Padding %")
        
        box.prop(settings, "columns")
        box.prop(settings, "flip_y")
        box.prop(settings, "track_origin")
        
        layout.separator()
        
        # View angles
        box = layout.box()
        box.label(text="View Angles (Armature Rotation):", icon='ORIENTATION_VIEW')
        
        row = box.row(align=True)
        row.prop(settings, "use_front", toggle=True)
        row.prop(settings, "use_right", toggle=True)
        row.prop(settings, "use_back", toggle=True)
        row.prop(settings, "use_left", toggle=True)
        
        layout.separator()
        
        # Animation list
        box = layout.box()
        box.label(text="Animations:", icon='ANIM')
        
        row = box.row(align=True)
        row.operator("spritesheet.detect_actions", text="Detect", icon='VIEWZOOM').clear_existing = False
        row.operator("spritesheet.add_animation", text="", icon='ADD')
        row.operator("spritesheet.clear_list", text="", icon='TRASH')
        
        row = box.row()
        row.template_list(
            "SPRITESHEET_UL_animations",
            "",
            settings,
            "animations",
            settings,
            "active_animation_index",
            rows=5
        )
        
        col = row.column(align=True)
        col.operator("spritesheet.remove_animation", text="", icon='REMOVE')
        col.operator("spritesheet.preview_animation", text="", icon='PLAY')
        col.operator("spritesheet.analyze_animation", text="", icon='VIEWZOOM')
        
        total = len(settings.animations)
        active = len([a for a in settings.animations if a.enabled])
        box.label(text=f"Active: {active}/{total} animations")
        
        layout.separator()
        
        # Generate button
        row = layout.row()
        row.scale_y = 2.0
        row.operator("spritesheet.generate", icon='RENDER_STILL')

# ==================== REGISTRATION ====================

classes = [
    AnimationItem,
    SpriteSheetSettings,
    SPRITESHEET_OT_help,
    SPRITESHEET_OT_analyze_animation,
    SPRITESHEET_OT_detect_actions,
    SPRITESHEET_OT_clear_list,
    SPRITESHEET_OT_add_animation,
    SPRITESHEET_OT_remove_animation,
    SPRITESHEET_OT_preview_animation,
    SPRITESHEET_OT_generate,
    SPRITESHEET_UL_animations,
    VIEW3D_PT_sprite_sheet,
]

def register():
    print("Sprite Sheet Generator v2.1 - Registering...")
    for cls in classes:
        bpy.utils.register_class(cls)
    bpy.types.Scene.spritesheet_settings = PointerProperty(type=SpriteSheetSettings)
    print("✓ Registered!")

def unregister():
    print("Sprite Sheet Generator - Unregistering...")
    for cls in reversed(classes):
        bpy.utils.unregister_class(cls)
    del bpy.types.Scene.spritesheet_settings
    print("✓ Unregistered!")

if __name__ == "__main__":
    register()