/-
  RE2020.Building
  Modèle de données du bâtiment conforme aux règles Th-BAT 2020
  et à la méthode Th-BCE 2020.

  Ce fichier définit la représentation exacte du bâtiment telle que
  la réglementation l'exige pour les calculs.
-/

import RE2020.Types

namespace RE2020

/-- Couche d'une paroi multi-couches -/
structure WallLayer where
  name : String
  thickness : Float      -- m
  conductivity : Float   -- W/(m.K)
  volumetricHeatCapacity : Float  -- J/(m³.K)
  deriving Repr

/-- Propriétés thermiques d'une paroi opaque (support multi-couches) -/
structure OpaqueWall where
  name           : String
  area           : Float
  layers         : List WallLayer   -- support multi-couches
  uValue         : Float            -- peut être calculé depuis les layers ou donné
  thermalCapacity : Float           -- capacité surfacique totale (J/m²/K)
  solarAbsorptivity : Float
  deriving Repr

/-- Calcule le U-value effectif depuis les couches (si non fourni) -/
def computeUValueFromLayers (layers : List WallLayer) : Float :=
  if layers.isEmpty then 1.0 else
    let resistances := layers.map (fun l => l.thickness / l.conductivity)
    1.0 / resistances.foldl (· + ·) 0.0

/-- Calcule la capacité thermique surfacique totale depuis les couches -/
def computeCapacityFromLayers (layers : List WallLayer) : Float :=
  layers.foldl (fun acc l => acc + l.thickness * l.volumetricHeatCapacity) 0.0

/-- Baie vitrée / fenêtre -/
structure Window where
  name           : String
  area           : Float          -- m²
  uValue         : Float          -- W/(m².K)
  gValue         : Float          -- facteur solaire (0..1)
  frameRatio     : Float          -- proportion de dormant (0..1)
  orientation    : Float          -- azimut en degrés (0 = Sud)
  tilt           : Float          -- inclinaison (90° = vertical)
  shadingFactor  : Float          -- facteur de masque solaire (0..1)
  deriving Repr

/-- Pont thermique linéique -/
structure LinearThermalBridge where
  length : Float    -- m
  psi    : Float    -- W/(m.K)
  deriving Repr

/-- Pont thermique ponctuel -/
structure PointThermalBridge where
  count : Nat
  chi   : Float     -- W/K
  deriving Repr

/-- Groupe thermique (zone homogène) -/
structure ThermalGroup where
  name                : String
  volume              : Float                    -- m³
  referenceArea       : Float                    -- SHAB ou SU du groupe
  opaqueWalls         : List OpaqueWall
  windows             : List Window
  linearBridges       : List LinearThermalBridge
  pointBridges        : List PointThermalBridge
  airPermeabilityQ4   : Float                    -- m³/(h.m²) à 4 Pa
  internalHeatGains   : Float                    -- W/m² (moyenne conventionnelle)
  deriving Repr

/-- Bâtiment complet selon la réglementation -/
structure Building where
  name             : String
  category         : BuildingCategory
  climateZone      : ClimateZone
  groups           : List ThermalGroup          -- découpage en groupes thermiques
  totalReferenceArea : Float                    -- SHAB ou SU totale
  airPermeabilityQ4 : Float                     -- valeur globale si non précisée par groupe
  deriving Repr

/-- Calcul de la surface de référence totale -/
def Building.totalRefArea (b : Building) : Float :=
  b.groups.foldl (fun acc g => acc + g.referenceArea) 0

/-- Vérification basique de cohérence du modèle (à enrichir) -/
def Building.isValid (b : Building) : Bool :=
  b.totalReferenceArea > 0 && !b.groups.isEmpty

end RE2020
