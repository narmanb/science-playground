"""Generate a deterministic physical manifest for the prototype alien system.

This intentionally uses only the Python standard library so it can run anywhere.
Later passes can replace approximations with Astropy/SciPy/specialist models while
keeping the JSON contract consumed by Godot stable.
"""

from __future__ import annotations

import json
import math
from pathlib import Path
from typing import Any

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
    # The /0.7 term normalizes an Earthlike Bond albedo (0.30) to the familiar
    # ~255 K zero-greenhouse Earth result while retaining the 278.5 K reference.
    return (
        EARTH_EQUILIBRIUM_REFERENCE_K
        * luminosity_solar**0.25
        / math.sqrt(semimajor_axis_au)
        * ((1.0 - bond_albedo) / 0.7) ** 0.25
    )


def calculated_planet(
    *,
    name: str,
    kind: str,
    mass_earth: float,
    radius_earth: float,
    semimajor_axis_au: float,
    bond_albedo: float,
    rotation_period_hours: float,
    initial_phase_degrees: float,
    star_mass_solar: float,
    star_luminosity_solar: float,
    atmosphere: dict[str, Any],
    science_status: str,
    rings: dict[str, Any] | None = None,
) -> dict[str, Any]:
    gravity = surface_gravity_m_s2(mass_earth, radius_earth)
    body: dict[str, Any] = {
        "name": name,
        "kind": kind,
        "mass_earth": mass_earth,
        "radius_earth": radius_earth,
        "surface_gravity_m_s2": round(gravity, 3),
        "surface_gravity_g": round(gravity / G_EARTH, 3),
        "semimajor_axis_au": semimajor_axis_au,
        "orbital_period_days": round(
            orbital_period_days(semimajor_axis_au, star_mass_solar), 3
        ),
        "bond_albedo": bond_albedo,
        "equilibrium_temperature_k": round(
            equilibrium_temperature_k(
                star_luminosity_solar,
                semimajor_axis_au,
                bond_albedo,
            ),
            1,
        ),
        "rotation_period_hours": rotation_period_hours,
        "initial_phase_degrees": initial_phase_degrees,
        "atmosphere": atmosphere,
        "science_status": science_status,
    }
    if rings is not None:
        body["rings"] = rings
    return body


def build_manifest() -> dict[str, Any]:
    star_mass = 0.73
    star_luminosity = stellar_luminosity_from_mass(star_mass)
    star_radius = stellar_radius_from_mass(star_mass)

    veyr = calculated_planet(
        name="Veyr",
        kind="iron_rich_rocky_world",
        mass_earth=0.72,
        radius_earth=0.91,
        semimajor_axis_au=0.24,
        bond_albedo=0.12,
        rotation_period_hours=19.4,
        initial_phase_degrees=142.0,
        star_mass_solar=star_mass,
        star_luminosity_solar=star_luminosity,
        atmosphere={
            "surface_pressure_bar": 0.18,
            "composition_hint": "thin CO2 / N2 volcanic atmosphere",
            "status": "artistic composition placeholder",
        },
        science_status="calculated_bulk_properties_with_artistic_atmosphere",
    )

    nysa = calculated_planet(
        name="Nysa",
        kind="oceanic_super_earth_candidate",
        mass_earth=2.60,
        radius_earth=1.34,
        semimajor_axis_au=0.68,
        bond_albedo=0.28,
        rotation_period_hours=31.0,
        initial_phase_degrees=0.0,
        star_mass_solar=star_mass,
        star_luminosity_solar=star_luminosity,
        atmosphere={
            "surface_pressure_bar": 2.7,
            "composition": {
                "N2": 0.78,
                "CO2": 0.12,
                "H2O_and_trace": 0.10,
            },
            "status": "artistic placeholder; greenhouse model not yet connected",
        },
        rings={
            "present": True,
            "art_direction": "thin icy-mineral ring plane with visibly uneven density",
        },
        science_status="mixed_calculated_and_placeholder",
    )

    thale = {
        "name": "Thale",
        "kind": "rocky_moon",
        "parent": "Nysa",
        "mass_earth": 0.10,
        "radius_earth": 0.48,
        "surface_gravity_m_s2": round(surface_gravity_m_s2(0.10, 0.48), 3),
        "science_status": "prototype_placeholder_orbit",
    }

    orun = calculated_planet(
        name="Orun",
        kind="cold_sub_neptune",
        mass_earth=6.8,
        radius_earth=2.35,
        semimajor_axis_au=1.15,
        bond_albedo=0.38,
        rotation_period_hours=18.1,
        initial_phase_degrees=232.0,
        star_mass_solar=star_mass,
        star_luminosity_solar=star_luminosity,
        atmosphere={
            "composition_hint": "H2 / He envelope with methane-bearing upper clouds",
            "status": "artistic composition placeholder",
        },
        science_status="calculated_bulk_properties_with_artistic_envelope",
    )

    kharis = calculated_planet(
        name="Kharis",
        kind="ringed_ice_giant",
        mass_earth=68.0,
        radius_earth=8.2,
        semimajor_axis_au=1.9,
        bond_albedo=0.44,
        rotation_period_hours=13.6,
        initial_phase_degrees=64.0,
        star_mass_solar=star_mass,
        star_luminosity_solar=star_luminosity,
        atmosphere={
            "composition_hint": "H2 / He / methane ice-giant envelope",
            "status": "artistic composition placeholder",
        },
        rings={
            "present": True,
            "art_direction": "broad dark rings with narrow bright shepherd bands",
        },
        science_status="calculated_bulk_properties_with_artistic_envelope_and_rings",
    )

    return {
        "schema_version": 2,
        "system_name": "Asterion Prototype",
        "seed": 731942,
        "scale_note": "Physical values are real-unit metadata; Godot uses a compressed playable spatial scale.",
        "star": {
            "name": "Asterion",
            "mass_solar": round(star_mass, 6),
            "radius_solar": round(star_radius, 6),
            "luminosity_solar": round(star_luminosity, 6),
            "effective_temperature_k": round(
                stellar_temperature_k(star_luminosity, star_radius), 1
            ),
            "spectral_hint": "K-type orange dwarf",
            "calculation_notes": [
                "Luminosity currently uses a piecewise main-sequence mass-luminosity approximation.",
                "Radius currently uses R ~ M^0.8.",
            ],
        },
        "bodies": [veyr, nysa, thale, orun, kharis],
    }


def main() -> None:
    output = Path(__file__).resolve().parents[2] / "data" / "asterion_system.json"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(build_manifest(), indent=2) + "\n", encoding="utf-8")
    print(output)


if __name__ == "__main__":
    main()
