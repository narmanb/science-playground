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
- NAV-aware scan acquisition: the selected target gets priority only while it remains inside the legitimate sensor cone
- Three useful science depths on major worlds: **Remote / Spectral / Proximity**
- Persistent science catalog that remembers the best completed survey depth for every body
- Science-priority navigation that can skip fully surveyed targets
- Contextual science objective derived from the selected NAV target, approach zone, and saved catalog progress
- Science-envelope guidance showing the next required observation radius, current clearance in body radii, relative closing/opening motion, and ETA when closing
- Thrust-derived stopping-distance guidance using live ship mass, flight-mode thrust, relative closing speed, and current fore/aft-axis alignment
- Trajectory-based navigation: destination bearing and actual velocity are separate instruments
- Celestial collision shells plus altitude, relative closing speed, closest-approach time, predicted miss clearance, and impact-corridor versus projected-flyby warnings
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

Close approaches add another piloting problem. The proximity instrument subtracts estimated body motion from the ship's velocity, reports current clearance and radial closing speed, and projects constant-relative-velocity motion forward to the **closest point of approach (CPA)**. It therefore distinguishes a true future collision-shell intercept from a fast tangential flyby. A direct intercept is labeled **IMPACT CORRIDOR** with time to CPA and predicted shell penetration; a non-impacting close pass is labeled **PROJECTED FLYBY** with time to CPA and predicted positive clearance.

The CPA projection is intentionally a short-horizon inertial predictor rather than an orbital propagator. It answers “where does the current relative velocity take me if nobody changes anything?” and updates continuously as the pilot changes the trajectory.

## Science loop

SCAN is an active maneuver rather than an instant information button. Center a celestial body in the sensor cone, begin the scan, and maintain alignment while analysis accumulates. Excess rotation reduces signal quality; losing the target causes the analysis to decay.

When a NAV target is inside the valid acquisition cone, SCAN treats that selection as explicit pilot intent and prefers it even if another scannable body is slightly better centered. If the NAV target leaves the cone, the preference disappears and scanning immediately returns to normal best-centered free acquisition. NAV therefore reduces accidental scans without becoming an invisible hard lock.

Major worlds expose progressively deeper observations as the ship approaches:

1. **Remote Survey** — bulk physical and orbital information.
2. **Spectral Pass** — adds rotation and atmosphere-model detail.
3. **Proximity Pass** — resolves local pressure/ring/model-status details.

The best completed depth is written to `user://science_discoveries.json`, so catalog progress survives app restarts. A contextual cockpit objective uses that saved progress and the current approach zone to indicate whether a scan is ready or whether a closer pass is required.

When a closer tier is required, the same profile thresholds used to assign science depth are exposed directly to the cockpit. The objective shows the target envelope in body radii (currently **≤12R** for Spectral and **≤5R** for Proximity on three-tier worlds), current clearance, and relative radial motion after subtracting estimated target orbital movement. When the ship is closing, it also estimates time to the science envelope.

The approach instrument also estimates the distance required to remove the current radial closing speed using commanded fore/aft thrust. It uses the ship's live mass, the current flight-mode thrust multiplier, and the actual alignment of the ship's main fore/aft axis with the required radial braking direction. The display therefore distinguishes a positive **BRAKE MARGIN** from **BRAKE / ALIGN NOW** without pretending passive damping or an autopilot will save the approach.

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
- verifies science-priority NAV skips completed Nysa and selects Veyr;
- verifies the completed Nysa sensor report clears when NAV moves on;
- renders and verifies a Veyr Spectral-approach state using the exact ≤12R science envelope, current clearance, relative closing rate, and ETA;
- verifies thrust-only stopping distance, 100% main-axis alignment in the deterministic safe case, positive brake margin, and the transition to **BRAKE / ALIGN NOW** when stopping distance exceeds the remaining envelope gap;
- adversarially tests NAV-aware scan acquisition with a temporary centered competitor, including both selected-target priority inside the cone and free-scan fallback outside it;
- tests trajectory hazards with a remote CI-only body: a direct intercept must render **IMPACT CORRIDOR** with CPA and shell penetration, while a high-speed offset pass must render **PROJECTED FLYBY** with positive predicted clearance;
- requires eleven visual artifacts: active flight, catalog, objective, science NAV, approach, braking, intercept, flyby, and close inspection frames for Veyr, Orun, and Kharis.

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
