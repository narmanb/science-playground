# Science Playground — Alien System Flight Lab

A Godot 4 Android-first experimental space exploration project. This is not intended to become a conventional combat game with a spaceship skin: the spacecraft itself is the activity. The prototype is built around inertial first-person flight, unusual piloting instrumentation, scientifically coherent system generation, active scanning, orbital motion, and procedural 3D content.

## Current prototype target

- Godot **4.7.2 stable**
- Android first; phone testing initially, Retroid Pocket 5 as a hardware target
- Six-degree-of-freedom rigid-body spacecraft movement
- Three deliberately different flight modes: **Cruise / Vector / Drift**
- **Inertial Lock** world-space velocity-hold system
- D-pad / RCS burst translation on physical controllers
- Touchscreen vector and attitude pads
- Active sensor scanning that requires keeping a target aligned long enough to complete analysis
- Three useful science depths on major worlds: **Remote / Spectral / Proximity**
- Persistent science catalog that remembers the best completed survey depth for every body
- Science-priority navigation that can skip fully surveyed targets
- Contextual science objective derived from the selected NAV target, approach zone, and saved catalog progress
- Trajectory-based navigation: destination bearing and actual velocity are separate instruments
- Celestial collision shells plus altitude, relative closing-speed, and contact-time warnings
- Manifest-driven planetary rotation periods represented at accelerated visual time
- Procedural Asterion system with four primary worlds, a moon, rings, and an asteroid belt
- Blender Python tooling and GitHub Actions for reproducible modular 3D assets
- Scientific-generation layer kept separate from rendering so calculated physical values can drive artistic worlds without pretending the art layer is a physical simulation

## Asterion system

The current deterministic science manifest contains:

- **Asterion** — K-type orange dwarf
- **Veyr** — inner iron-rich rocky world
- **Nysa** — ringed oceanic super-Earth candidate and the initial cockpit starting target
- **Thale** — Nysa's rocky moon
- **Orun** — cold sub-Neptune
- **Kharis** — outer ringed ice giant
- An asteroid belt between Orun and Kharis

Mass, radius, surface gravity, semimajor axis, orbital period, and equilibrium-temperature values are generated in real physical units and stored in `data/asterion_system.json`. Godot uses a compressed playable spatial scale, so cockpit-space distances and velocities are deliberately labeled **u** and **u/s** rather than falsely presented as kilometers or meters per second. Atmospheric compositions and some geological/cloud details are explicitly art-direction placeholders rather than claims produced by the physical model.

The committed manifest is checked in CI against `tools/science/generate_system_manifest.py`; validation fails if the generated and committed scientific data diverge.

## Flight idea

The HUD intentionally separates three different concepts:

- The **nose reticle** shows where the spacecraft is pointing.
- The **green NAV marker** shows the selected destination bearing.
- The **amber velocity marker** shows the spacecraft's actual world-space direction of travel.

In Vector and Drift modes, the nose and velocity vector can become dramatically separated. Reaching a destination therefore means changing the trajectory, not merely rotating until the target is centered. The system is deliberately avoiding an autopilot-style “point at icon and hold forward” loop.

Close approaches add another piloting problem. The proximity instrument reports clearance above a body's collision shell, relative radial closing speed against the body's own orbital motion, and estimated contact time when appropriate.

## Science loop

SCAN is an active maneuver rather than an instant information button. Center a celestial body in the sensor cone, begin the scan, and maintain alignment while analysis accumulates. Excess rotation reduces signal quality; losing the target causes the analysis to decay.

Major worlds expose progressively deeper observations as the ship approaches:

1. **Remote Survey** — bulk physical and orbital information.
2. **Spectral Pass** — adds rotation and atmosphere-model detail.
3. **Proximity Pass** — resolves local pressure/ring/model-status details.

The best completed depth is written to `user://science_discoveries.json`, so catalog progress survives app restarts. A contextual cockpit objective uses that saved progress and the current approach zone to indicate whether a scan is ready or whether a closer pass is required.

Science-priority NAV searches for the next body whose best completed survey is still below its available maximum. The normal all-body cycle remains available for revisiting completed worlds.

## Controls

### Touch

- Left vector pad: strafe + forward/reverse thrust
- Right attitude pad: pitch/yaw
- RCS ▲ / ▼: vertical translation
- ROLL ◀ / ▶: roll
- MODE: cycle Cruise / Vector / Drift
- LOCK: toggle Inertial Lock
- NAV tap: next unfinished science target
- NAV hold: cycle all celestial targets
- LOG: open/close persistent science catalog
- SCAN: acquire/abort sensor analysis

### Gamepad / Retroid

- Left stick: strafe + forward/reverse thrust
- Right stick: pitch/yaw
- L2 / R2: roll
- D-pad: discrete RCS translation bursts
- R1: Inertial Lock
- Y: cycle flight mode
- A: next unfinished science target
- L1: cycle all navigation targets
- B: open/close science catalog
- X: scan / abort scan

### Keyboard development controls

- W/A/S/D: translation
- Arrow keys: pitch/yaw
- Q/E: roll
- R/F: vertical translation
- M: cycle flight mode
- L: Inertial Lock
- N: next unfinished science target
- Shift+N: cycle all navigation targets
- C: open/close science catalog
- X: scan

## Automated development pipeline

GitHub Actions currently:

- validates Godot script parsing and runtime startup;
- regenerates and verifies the scientific system manifest;
- runs Blender to generate the cockpit GLB;
- builds an Android debug APK;
- renders an active-flight smoke-test frame exercising scanning, navigation, and inertial velocity feedback;
- completes a real Nysa proximity scan and renders the persistent catalog;
- verifies the post-scan objective changes to full-survey-complete;
- verifies science-priority NAV then skips completed Nysa and selects Veyr;
- renders close inspection frames for Veyr, Orun, and Kharis so planetary shader changes can be reviewed without installing every intermediate APK.

## Project layout

- `scenes/` — Godot scenes
- `scripts/` — flight, HUD, scanning, navigation, and procedural-system code
- `shaders/` — lightweight procedural planetary materials
- `data/` — deterministic system manifest consumed by Godot
- `tools/science/` — physical-system generation code
- `tools/blender/` — Blender Python asset generators
- `docs/` — design and scientific-layer notes

## Development rule

**Flying the spacecraft should itself be an activity, not merely transportation between interesting places.**
