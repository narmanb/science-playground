"""Generate a deterministic physical manifest for the prototype alien system.

This intentionally uses only the Python standard library so it can run anywhere.
Later passes can replace approximations with Astropy/SciPy/specialist models while
keeping the JSON contract consumed by Godot stable.
"""

from __future__ import annotations

import json
import math
from pathlib import Path

G_EARTH = 9.80665
T_SUN_K = 5772.0
DAYS_PER_YEAR = 365.25
EARTH_EQUILIBRIUM_REFERENCE_K = 278.5


def stellar_luminosity_from_mass(mass_solar: float) -> float:
    """Simple main-sequence approximation suitable for the first prototype."""
    if mass_solar < 0.43:
        return 0.23 * mass_solar**2.3
    if mass_solar < 2.0:
        return mass_solar**4.0
    return 1.5 * mass_solar**3.5


def stellar_radius_from_mass(mass_solar: float) -> float:
    return mass_solar**0.8


def stellar_temperature_k(luminosity_solar: float, radius_solar: float) -> float:
    return T_SUN_K * (luminosity_solar / radius_solar**2) ** 0.25


def orbital_period_days(semimajor_axis_au: float, primary_mass_solar: float) -> float:
    return DAYS_PER_YEAR * math.sqrt(semimajor_axis_au**3 / primary_mass_solar)


def surface_gravity_m_s2(mass_earth: float, radius_earth: float) -> float:
    return G_EARTH * mass_earth / radius_earth**2


def equilibrium_temperature_k(
    luminosity_solar: float,
    semimajor_axis_au: float,
    bond_albedo: float,
) -> float:
    # 278.5 K is the zero-greenhouse Earth-at-1-AU normalization. The 0.7
    # denominator keeps Earthlike albedo near the familiar ~255 K result.
    return (
        EARTH_EQUILIBRIUM_REFERENCE_K
        * luminosity_solar**0.25
        / math.sqrt(semimajor_axis_au)
        * ((1.0 - bond_albedo) / 0.7) ** 0.25
    )


def build_manifest() -> dict:
    star_mass = 0.73
    star_luminosity = stellar_luminosity_from_mass(star_mass)
    star_radius = stellar_radius_from_mass(star_mass)

    nysa_mass = 2.60
    nysa_radius = 1.34
    nysa_axis = 0.68
    nysa_albedo = 0.28

    return {
        "schema_version": 1,
        "system_name": "Asterion Prototype",
        "seed": 731942,
        "scale_note": "Physical values are real-unit metadata; Godot uses a compressed playable spatial scale.",
        "star": {
            "name": "Asterion",
            "mass_solar": round(star_mass, 6),
            "radius_solar": round(star_radius, 6),
            "luminosity_solar": round(star_luminosity, 6),
            "effective_temperature_k": round(stellar_temperature_k(star_luminosity, star_radius), 1),
            "spectral_hint": "K-type orange dwarf",
            "calculation_notes": [
                "Luminosity currently uses a piecewise main-sequence mass-luminosity approximation.",
                "Radius currently uses R ~ M^0.8.",
            ],
        },
        "bodies": [
            {
                "name": "Nysa",
                "kind": "oceanic_super_earth_candidate",
                "mass_earth": nysa_mass,
                "radius_earth": nysa_radius,
                "surface_gravity_m_s2": round(surface_gravity_m_s2(nysa_mass, nysa_radius), 3),
                "surface_gravity_g": round(surface_gravity_m_s2(nysa_mass, nysa_radius) / G_EARTH, 3),
                "semimajor_axis_au": nysa_axis,
                "orbital_period_days": round(orbital_period_days(nysa_axis, star_mass), 3),
                "bond_albedo": nysa_albedo,
                "equilibrium_temperature_k": round(
                    equilibrium_temperature_k(star_luminosity, nysa_axis, nysa_albedo), 1
                ),
                "rotation_period_hours": 31.0,
                "atmosphere": {
                    "surface_pressure_bar": 2.7,
                    "composition": {
                        "N2": 0.78,
                        "CO2": 0.12,
                        "H2O_and_trace": 0.10,
                    },
                    "status": "artistic placeholder; greenhouse model not yet connected",
                },
                "rings": {
                    "present": True,
                    "art_direction": "thin icy-mineral ring plane with visibly uneven density",
                },
                "science_status": "mixed_calculated_and_placeholder",
            },
            {
                "name": "Thale",
                "kind": "rocky_moon",
                "parent": "Nysa",
                "mass_earth": 0.10,
                "radius_earth": 0.48,
                "surface_gravity_m_s2": round(surface_gravity_m_s2(0.10, 0.48), 3),
                "science_status": "prototype_placeholder_orbit",
            },
        ],
    }


def main() -> None:
    output = Path(__file__).resolve().parents[2] / "data" / "asterion_system.json"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(build_manifest(), indent=2) + "\n", encoding="utf-8")
    print(output)


if __name__ == "__main__":
    main()
