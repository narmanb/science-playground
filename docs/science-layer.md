# Scientific World-Generation Layer

The rendering engine and the scientific model are deliberately separate.

Godot should receive compact, validated world parameters rather than carrying heavyweight research/scientific Python dependencies inside the Android build.

## Intended pipeline

1. **Scientific generation (development/tooling side)**
   - Astropy: astronomical units, stellar/planetary quantities, orbital calculations.
   - SymPy / numerical Python: equations, constraints, parameter solving.
   - Scientific Agent Skills: structured workflows and tool guidance for generating and checking systems.
   - Optional specialist packages later for atmospheric, material, or fluid models.

2. **World manifest**
   - Generated JSON/resource containing the star and body parameters.
   - Stable seed for reproducibility.
   - Human-readable provenance/assumptions so we know which values are calculated and which are artistic approximations.

3. **Godot runtime**
   - Loads the manifest.
   - Converts scientific scale to the project's compressed playable scale.
   - Builds meshes/materials/orbits/scan data.
   - Uses floating-origin techniques as the playable system expands.

4. **Blender tooling**
   - Uses the same manifest or derived art parameters to create special meshes: cockpit modules, irregular moons, stations, ruins, rocks, and hero assets.

## First manifest fields

### Star
- mass_solar
- radius_solar
- luminosity_solar
- effective_temperature_k
- spectral_class
- display_color

### Planet/moon
- mass_earth
- radius_earth
- gravity_m_s2
- semimajor_axis_au
- eccentricity
- orbital_period_days
- rotation_period_hours
- equilibrium_temperature_k
- atmosphere composition/pressure when modeled
- surface type
- ring/moon relationships

## Design constraint

Scientific coherence should create surprising worlds, not make every world visually conservative. When a visual invention exceeds what the current model can justify, it should be marked as an artistic assumption rather than silently presented as calculated science.
