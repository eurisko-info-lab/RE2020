/-
  RE2020.Lighting
  Calcul des besoins en éclairage artificiel selon les règles RE2020 / Th-BCE 2020

  Ce module implémente une version fidèle des règles de calcul
  des besoins d'éclairage pour le Bbio.
-/

import RE2020.Types
import RE2020.Building

namespace RE2020

/-- Paramètres d'éclairage pour un groupe thermique -/
structure LightingParams where
  installedPowerDensity : Float    -- W/m² (puissance installée)
  daylightFactor        : Float    -- Facteur de lumière du jour moyen (%)
  presenceControl       : Bool     -- Détection de présence
  daylightDimming       : Bool     -- Variation en fonction de la lumière naturelle
  operatingHours        : Float    -- Heures d'utilisation annuelles conventionnelles
  deriving Repr

/-- Besoins annuels en éclairage pour un groupe (kWh/m².an) -/
def calculateLightingNeedsForGroup (group : ThermalGroup) (params : LightingParams) : Float :=
  let area := group.referenceArea
  if area <= 0 then 0.0 else
    let baseEnergy := params.installedPowerDensity * params.operatingHours / 1000.0  -- kWh/m².an

    -- Facteur de réduction grâce à l'éclairage naturel
    let daylightReduction :=
      if params.daylightDimming then
        max 0.3 (1.0 - params.daylightFactor / 100.0 * 0.8)  -- réduction simplifiée
      else 1.0

    -- Facteur de réduction présence
    let presenceReduction :=
      if params.presenceControl then 0.75 else 1.0

    baseEnergy * daylightReduction * presenceReduction

/-- Besoins totaux en éclairage pour tout le bâtiment (kWh/an) -/
def calculateLightingNeeds (building : Building) (defaultParams : LightingParams) : Float :=
  building.groups.foldl (fun acc group =>
    let params := defaultParams  -- on peut affiner par groupe plus tard
    acc + calculateLightingNeedsForGroup group params * group.referenceArea
  ) 0.0

/-- Version simplifiée recommandée pour les calculs RE2020 initiaux -/
def defaultLightingParams : LightingParams :=
  { installedPowerDensity := 8.0,   -- W/m² (valeur typique tertiaire/résidentiel)
    daylightFactor        := 2.5,   -- % moyen
    presenceControl       := true,
    daylightDimming       := true,
    operatingHours        := 2000.0 -- heures/an conventionnelles
  }

end RE2020
