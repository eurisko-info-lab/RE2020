import RE2020.BuildingCategory.MaisonIndividuelle

namespace RE2020

/--
Detailed full-model building definition for a certified BBC 2005 individual house
(Maison Pierre), built in 2011.

This module intentionally keeps only the static building description:
plan areas, envelope layers, and baseline geometry/material assumptions.
-/

def maisonPierre2011PlanAreas : List (String × Float) :=
  [ ("SEJOUR", 37.97),
    ("CUISINE", 8.89),
    ("CELLIER", 4.60),
    ("CH1", 8.62),
    ("CH2", 9.46),
    ("CH3", 8.30),
    ("CH4", 11.90),
    ("SDB", 5.26),
    ("WC", 4.81),
    ("DEGT", 2.64),
    ("GARAGE", 21.02) ]

def maisonPierre2011WallLayers : List WallLayer :=
  [ { name := "Enduit exterieur", thickness := 0.015, conductivity := 0.87, volumetricHeatCapacity := 1.7e6 },
    { name := "Parpaing creux", thickness := 0.20, conductivity := 1.13, volumetricHeatCapacity := 1.0e6 },
    { name := "ITE PSE", thickness := 0.12, conductivity := 0.038, volumetricHeatCapacity := 4.0e4 },
    { name := "Doublage BA13", thickness := 0.013, conductivity := 0.25, volumetricHeatCapacity := 6.5e5 } ]

def maisonPierre2011RoofLayers : List WallLayer :=
  [ { name := "Plaque de platre", thickness := 0.013, conductivity := 0.25, volumetricHeatCapacity := 6.5e5 },
    { name := "Laine minerale", thickness := 0.30, conductivity := 0.040, volumetricHeatCapacity := 3.0e4 },
    { name := "Support toiture", thickness := 0.020, conductivity := 0.13, volumetricHeatCapacity := 5.0e5 } ]

def maisonPierre2011FloorLayers : List WallLayer :=
  [ { name := "Chape", thickness := 0.06, conductivity := 1.40, volumetricHeatCapacity := 1.8e6 },
    { name := "Isolation sous dalle", thickness := 0.08, conductivity := 0.035, volumetricHeatCapacity := 3.0e4 },
    { name := "Dalle beton", thickness := 0.16, conductivity := 1.75, volumetricHeatCapacity := 2.1e6 } ]

def maisonPierre2011DetailedBuilding : Building :=
  let floorArea := 95.0
  let heatedVolume := floorArea * 2.5
  let wallLayers := maisonPierre2011WallLayers
  let roofLayers := maisonPierre2011RoofLayers
  let floorLayers := maisonPierre2011FloorLayers
  let wallU := computeUValueFromLayers wallLayers
  let roofU := computeUValueFromLayers roofLayers
  let floorU := computeUValueFromLayers floorLayers
  let wallCapacity := computeCapacityFromLayers wallLayers
  let roofCapacity := computeCapacityFromLayers roofLayers
  let floorCapacity := computeCapacityFromLayers floorLayers
  { name := "Maison Pierre BBC2005 2011 (modele detaille)",
    category := BuildingCategory.MaisonIndividuelle,
    climateZone := ClimateZone.H1c,
    groups :=
      [ { name := "Zone chauffee principale",
          volume := heatedVolume,
          referenceArea := floorArea,
          opaqueWalls :=
            [ { name := "Murs exterieurs hors facade nord", area := 62.0, layers := wallLayers, uValue := wallU, thermalCapacity := wallCapacity, solarAbsorptivity := 0.60 },
              { name := "Mur nord mitoyen garage", area := 24.0, layers := [], uValue := 0.45, thermalCapacity := wallCapacity, solarAbsorptivity := 0.20 },
              { name := "Toiture combles amenages", area := 103.0, layers := roofLayers, uValue := roofU, thermalCapacity := roofCapacity, solarAbsorptivity := 0.70 },
              { name := "Plancher bas", area := 95.0, layers := floorLayers, uValue := floorU, thermalCapacity := floorCapacity, solarAbsorptivity := 0.45 } ],
          windows :=
            [ { name := "Fenetre cuisine est", area := 1.62, uValue := 0.9, gValue := 0.50, frameRatio := 0.28, orientation := 90.0, tilt := 90.0, shadingFactor := 0.85 },
              { name := "Fenetre chambre ouest", area := 1.62, uValue := 0.9, gValue := 0.50, frameRatio := 0.28, orientation := 270.0, tilt := 90.0, shadingFactor := 0.85 },
              { name := "Fenetres est x2", area := 2.50, uValue := 0.9, gValue := 0.50, frameRatio := 0.28, orientation := 90.0, tilt := 90.0, shadingFactor := 0.88 },
              { name := "Velux 78x98 x2", area := 1.53, uValue := 1.2, gValue := 0.42, frameRatio := 0.33, orientation := 270.0, tilt := 30.0, shadingFactor := 0.85 } ],
          linearBridges :=
            [ { length := 118.0, psi := 0.20 },
              { length := 35.0, psi := 0.12 } ],
          pointBridges :=
            [ { count := 40, chi := 0.02 } ],
          airPermeabilityQ4 := 0.80,
          internalHeatGains := 4.5 } ],
    totalReferenceArea := floorArea,
    airPermeabilityQ4 := 0.80 }

end RE2020
