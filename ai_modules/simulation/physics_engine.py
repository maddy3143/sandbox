"""
Physics Simulation Engine
Wraps PyBullet / Warp for real-time physics simulation of mechanical objects.
"""
import logging
import math
from dataclasses import dataclass, field
from typing import Optional

logger = logging.getLogger(__name__)


@dataclass
class SimulationState:
    time: float = 0.0
    objects: list[dict] = field(default_factory=list)
    forces: list[dict] = field(default_factory=list)
    metrics: dict = field(default_factory=dict)


class GearSimulation:
    """
    Simulates a gear train — computes angular velocities, torques, and mesh forces.
    """

    def __init__(self, gear_ratios: list[float], input_rpm: float = 1000.0):
        self.gear_ratios = gear_ratios
        self.input_rpm = input_rpm

    def compute(self, steps: int = 100, dt: float = 0.01) -> list[SimulationState]:
        states = []
        for i in range(steps):
            t = i * dt
            output_rpm = self.input_rpm / math.prod(self.gear_ratios)
            torque_factor = math.prod(self.gear_ratios)
            tooth_frequency = self.input_rpm / 60 * 20  # 20-tooth gear

            states.append(SimulationState(
                time=t,
                objects=[
                    {"name": f"gear_{j}", "angle_rad": (self.input_rpm / 60 * 2 * math.pi * t) / (r ** j), "rpm": self.input_rpm / (r ** j)}
                    for j, r in enumerate(self.gear_ratios, start=1)
                ],
                metrics={
                    "output_rpm": output_rpm,
                    "torque_multiplier": torque_factor,
                    "efficiency": 0.97 ** len(self.gear_ratios),
                    "mesh_frequency_hz": tooth_frequency,
                },
            ))
        return states


class AirflowSimulation:
    """
    Simplified airflow simulation using the incompressible Navier-Stokes equations.
    Outputs velocity field and temperature distribution.
    """

    def __init__(
        self,
        inlet_velocity_ms: float = 2.5,
        ambient_temp_c: float = 25.0,
        heat_source_watts: float = 45.0,
    ):
        self.inlet_velocity = inlet_velocity_ms
        self.ambient_temp = ambient_temp_c
        self.heat_source_watts = heat_source_watts

    def simulate(self, grid_size: int = 20) -> dict:
        """Produce a simplified velocity + temperature field for visualisation."""
        velocity_field = []
        temp_field = []

        for y in range(grid_size):
            row_v = []
            row_t = []
            for x in range(grid_size):
                nx = x / grid_size
                ny = y / grid_size
                vx = self.inlet_velocity * (1 - ny ** 2)
                vy = 0.2 * math.sin(math.pi * nx)
                distance_to_source = math.sqrt((nx - 0.5) ** 2 + (ny - 0.5) ** 2)
                temp = self.ambient_temp + (self.heat_source_watts / (4 * math.pi * max(distance_to_source, 0.05)))
                row_v.append({"vx": round(vx, 3), "vy": round(vy, 3), "magnitude": round(math.sqrt(vx**2 + vy**2), 3)})
                row_t.append(round(temp, 1))
            velocity_field.append(row_v)
            temp_field.append(row_t)

        max_temp = max(max(row) for row in temp_field)
        return {
            "velocity_field": velocity_field,
            "temperature_field": temp_field,
            "max_velocity_ms": self.inlet_velocity,
            "max_temperature_c": max_temp,
            "avg_temperature_c": self.ambient_temp + self.heat_source_watts / 20,
            "thermal_resistance_ck_w": (max_temp - self.ambient_temp) / self.heat_source_watts,
        }


class StressAnalysis:
    """
    Finite Element Analysis (FEA) wrapper for structural stress simulation.
    In production: interfaces with FEniCS or OpenSees.
    """

    def __init__(self, material_youngs_modulus_gpa: float = 70.0, poisson_ratio: float = 0.33):
        self.E = material_youngs_modulus_gpa * 1e9   # Pa
        self.nu = poisson_ratio

    def analyse(
        self,
        applied_force_n: float = 100.0,
        cross_section_area_m2: float = 0.001,
        length_m: float = 0.1,
    ) -> dict:
        """Compute basic stress, strain, and deformation for a prismatic member."""
        stress_pa = applied_force_n / cross_section_area_m2
        strain = stress_pa / self.E
        deformation_mm = strain * length_m * 1000

        # Von Mises criterion (simplified for uniaxial)
        yield_strength_pa = 270e6  # ~270 MPa for Al 6061-T6
        safety_factor = yield_strength_pa / stress_pa

        return {
            "applied_force_n": applied_force_n,
            "stress_mpa": round(stress_pa / 1e6, 3),
            "strain": round(strain, 8),
            "deformation_mm": round(deformation_mm, 4),
            "safety_factor": round(safety_factor, 2),
            "failure_risk": "High" if safety_factor < 1.5 else "Medium" if safety_factor < 3 else "Low",
            "max_safe_load_n": round(yield_strength_pa * cross_section_area_m2 / 1.5, 1),
        }


class PistonCycleSimulation:
    """Simulates a 4-stroke engine cycle for visualisation."""

    def simulate(self, rpm: float = 3000.0, steps_per_cycle: int = 360) -> list[dict]:
        states = []
        for deg in range(steps_per_cycle):
            crank_angle = math.radians(deg)
            piston_pos = math.cos(crank_angle)   # Simplified slider-crank

            if deg < 90:
                stroke = "Intake"
            elif deg < 180:
                stroke = "Compression"
            elif deg < 270:
                stroke = "Power"
            else:
                stroke = "Exhaust"

            states.append({
                "crank_angle_deg": deg,
                "piston_position": round(piston_pos, 4),
                "stroke": stroke,
                "pressure_kpa": 120 if stroke == "Power" else 10 + deg * 0.3,
            })
        return states
