"""Procedural cockpit generator for Science Playground.

Run inside Blender:
    blender --background --python tools/blender/generate_cockpit_blockout.py -- --output cockpit_blockout.glb

Coordinates in create_cockpit() are authored as Godot-space coordinates (Y up, -Z
forward). Before export, the scene is rotated into Blender's Z-up convention so
Blender's glTF Y-up conversion lands back in the intended Godot coordinates.
"""

import argparse
import math
import sys
from pathlib import Path

import bpy
from mathutils import Matrix


def args_after_double_dash():
    if "--" not in sys.argv:
        return []
    return sys.argv[sys.argv.index("--") + 1 :]


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", default="cockpit_blockout.glb")
    return parser.parse_args(args_after_double_dash())


def reset_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.meshes, bpy.data.curves, bpy.data.materials):
        for block in list(datablocks):
            if block.users == 0:
                datablocks.remove(block)


def material(name, base_color, metallic=0.0, roughness=0.5, emission=None, emission_strength=1.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*base_color, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if emission is not None:
        if "Emission Color" in bsdf.inputs:
            bsdf.inputs["Emission Color"].default_value = (*emission, 1.0)
            bsdf.inputs["Emission Strength"].default_value = emission_strength
        elif "Emission" in bsdf.inputs:
            bsdf.inputs["Emission"].default_value = (*emission, 1.0)
            bsdf.inputs["Emission Strength"].default_value = emission_strength
    return mat


def add_box(name, location, scale, mat, bevel=0.06, rotation=(0.0, 0.0, 0.0)):
    bpy.ops.mesh.primitive_cube_add(location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bevel_mod = obj.modifiers.new("SoftEdges", "BEVEL")
    bevel_mod.width = bevel
    bevel_mod.segments = 2
    obj.data.materials.append(mat)
    return obj


def add_cylinder(name, location, radius, depth, mat, rotation=(0.0, 0.0, 0.0), vertices=24):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    return obj


def add_torus(name, location, major_radius, minor_radius, mat, rotation=(0.0, 0.0, 0.0)):
    bpy.ops.mesh.primitive_torus_add(
        major_radius=major_radius,
        minor_radius=minor_radius,
        major_segments=36,
        minor_segments=10,
        location=location,
        rotation=rotation,
    )
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    return obj


def create_cockpit():
    hull = material("Hull", (0.032, 0.045, 0.055), metallic=0.74, roughness=0.34)
    dark = material("DarkPanels", (0.012, 0.018, 0.022), metallic=0.38, roughness=0.48)
    trim = material("Trim", (0.065, 0.085, 0.095), metallic=0.7, roughness=0.26)
    teal = material(
        "TealInstrument",
        (0.01, 0.055, 0.06),
        metallic=0.15,
        roughness=0.32,
        emission=(0.01, 0.23, 0.25),
        emission_strength=0.75,
    )
    screen = material(
        "ScannerScreen",
        (0.012, 0.07, 0.075),
        metallic=0.05,
        roughness=0.22,
        emission=(0.015, 0.17, 0.19),
        emission_strength=0.52,
    )
    amber = material(
        "AmberControl",
        (0.09, 0.035, 0.006),
        metallic=0.1,
        roughness=0.38,
        emission=(0.38, 0.075, 0.008),
        emission_strength=0.62,
    )

    # Main lower dashboard shell and recessed instrument bay.
    add_box("DashboardLower", (0.0, -1.05, -2.2), (2.45, 0.22, 0.8), hull, bevel=0.12,
            rotation=(math.radians(-9), 0, 0))
    add_box("DashboardInset", (0.0, -0.83, -2.36), (1.48, 0.04, 0.42), dark, bevel=0.035,
            rotation=(math.radians(-9), 0, 0))
    add_box("DashboardLip", (0.0, -0.69, -2.31), (1.62, 0.045, 0.055), trim, bevel=0.025,
            rotation=(math.radians(-9), 0, 0))

    # Small discrete indicators rather than one giant glowing slab.
    for i in range(5):
        x = -0.76 + i * 0.38
        add_box(
            f"StatusIndicator_{i:02d}",
            (x, -0.78, -2.25),
            (0.11, 0.025, 0.07),
            teal if i != 3 else amber,
            bevel=0.018,
            rotation=(math.radians(-9), 0, 0),
        )

    # Heavy canopy architecture; deliberately unusual, more submarine than fighter jet.
    add_box("CanopyCrossbar", (0.0, 1.15, -2.65), (2.8, 0.09, 0.11), hull, bevel=0.05)
    add_box("CanopyInnerBrace", (0.0, 0.92, -2.60), (1.9, 0.04, 0.05), trim, bevel=0.025)
    for side in (-1, 1):
        add_box(
            f"CanopyStrut_{side:+d}",
            (2.25 * side, 0.25, -2.55),
            (0.10, 1.9, 0.12),
            hull,
            bevel=0.05,
            rotation=(0, 0, math.radians(16 * side)),
        )
        add_box(
            f"CanopyInnerStrut_{side:+d}",
            (2.02 * side, 0.18, -2.50),
            (0.035, 1.45, 0.055),
            trim,
            bevel=0.02,
            rotation=(0, 0, math.radians(16 * side)),
        )
        add_box(
            f"SideConsole_{side:+d}",
            (1.72 * side, -0.82, -1.35),
            (0.62, 0.22, 1.0),
            dark,
            bevel=0.09,
            rotation=(math.radians(-7), 0, math.radians(-4 * side)),
        )
        # Three recessed side-console keys on each side.
        for key_i in range(3):
            add_box(
                f"SideKey_{side:+d}_{key_i}",
                (1.70 * side, -0.63 + key_i * 0.18, -1.15 - key_i * 0.08),
                (0.10, 0.025, 0.065),
                teal if key_i != 1 else amber,
                bevel=0.015,
                rotation=(math.radians(-7), 0, math.radians(-4 * side)),
            )

    # Vector cage: a physical ring surrounding a movable thrust puck.
    add_torus("VectorCageRing", (-1.42, -0.58, -1.88), 0.42, 0.035, teal,
              rotation=(math.radians(72), 0, 0))
    add_cylinder("VectorPuck", (-1.42, -0.58, -1.80), 0.15, 0.10, trim,
                 rotation=(math.radians(72), 0, 0))

    # Attitude ring: separate rotation control rather than another identical stick.
    add_torus("AttitudeRing", (1.42, -0.58, -1.88), 0.42, 0.035, teal,
              rotation=(math.radians(72), 0, 0))
    add_torus("AttitudeInnerRing", (1.42, -0.58, -1.84), 0.23, 0.026, amber,
              rotation=(math.radians(72), 0, 0))

    # Inertial damping dial with a deliberately oversized mechanical knob.
    add_cylinder("InertialDampingDial", (0.0, -0.62, -1.72), 0.22, 0.12, amber,
                 rotation=(math.radians(72), 0, 0))
    add_torus("InertialDampingBezel", (0.0, -0.64, -1.77), 0.28, 0.025, trim,
              rotation=(math.radians(72), 0, 0))

    # Guarded inertial-lock switch.
    add_box("LockSwitchBase", (0.62, -0.61, -1.69), (0.22, 0.07, 0.28), dark, bevel=0.04,
            rotation=(math.radians(-18), 0, 0))
    add_box("LockSwitchHandle", (0.62, -0.47, -1.66), (0.045, 0.17, 0.045), amber, bevel=0.025,
            rotation=(math.radians(20), 0, 0))

    # Scanner lives low in the dashboard, leaving the forward window unobstructed.
    add_box("ScannerBezel", (0.0, -0.88, -2.18), (0.74, 0.31, 0.055), trim, bevel=0.055,
            rotation=(math.radians(-12), 0, 0))
    add_box("ScannerDisplay", (0.0, -0.84, -2.13), (0.62, 0.25, 0.025), screen, bevel=0.035,
            rotation=(math.radians(-12), 0, 0))

    # Overhead switch bank; switches glow only subtly now.
    add_box("OverheadPanel", (0.0, 1.48, -1.85), (1.25, 0.10, 0.46), dark, bevel=0.07,
            rotation=(math.radians(16), 0, 0))
    for i in range(7):
        x = -0.72 + i * 0.24
        add_cylinder(f"OverheadSwitch_{i:02d}", (x, 1.37, -1.67), 0.035, 0.16, amber,
                     rotation=(math.radians(70), 0, 0), vertices=12)


def orient_for_godot():
    """Convert authored Godot-space transforms into Blender space before glTF export."""
    conversion = Matrix.Rotation(math.radians(90.0), 4, "X")
    for obj in list(bpy.context.scene.objects):
        obj.matrix_world = conversion @ obj.matrix_world


def export_glb(output):
    path = Path(output).expanduser().resolve()
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(path),
        export_format="GLB",
        use_selection=False,
        export_apply=True,
    )
    print(f"Exported cockpit blockout to {path}")


def main():
    args = parse_args()
    reset_scene()
    create_cockpit()
    orient_for_godot()
    export_glb(args.output)


if __name__ == "__main__":
    main()
