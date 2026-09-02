# Science Playground — Alien System Flight Lab

A Godot 4 Android-first experimental space exploration project. The goal is not a conventional combat game: it is a first-person spacecraft experience built around unusual flight controls, scientifically coherent alien systems, scanning, orbital motion, and procedural 3D content.

## Current prototype target

- Godot **4.7.2 stable**
- Android first; phone testing initially, Retroid Pocket 5 as a hardware target
- Six-degree-of-freedom inertial spacecraft movement
- Three flight modes: **Cruise / Vector / Drift**
- **Inertial Lock** velocity-hold system
- D-pad / RCS burst translation on physical controllers
- Touchscreen vector and attitude pads
- Procedural test system: star, rocky planet, moon, asteroid belt
- Blender Python tooling for procedural/modular assets
- Scientific-generation layer kept separate from rendering so real calculations can feed the world generator later

## Controls — first prototype

### Touch
- Left half drag: vector thrust (strafe + forward/reverse)
- Right half drag: pitch/yaw attitude control
- On-screen buttons: flight mode, inertial lock, roll, vertical RCS, scan

### Gamepad / Retroid
- Left stick: strafe + forward/reverse thrust
- Right stick: pitch/yaw
- L2 / R2: roll
- D-pad: discrete RCS translation bursts
- R1: inertial lock
- Y: cycle flight mode
- X: scan

The control layout is intentionally spacecraft-specific rather than a standard twin-stick shooter layout.

## Project layout

- `scenes/` Godot scenes
- `scripts/` flight, UI, and procedural-system code
- `tools/blender/` Blender Python generators
- `docs/` design and scientific-layer notes

## Development rule

Flying the spacecraft should itself be an activity, not merely transportation between interesting places.
