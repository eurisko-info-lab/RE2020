/-
  RE2020.Scenarios
  Scénarios conventionnels détaillés selon la méthode Th-BCE 2020

  Ce module définit les profils horaires d'occupation, gains internes,
  ventilation et consignes utilisés dans les calculs réglementaires.
-/

import RE2020.Types
import RE2020.Building

namespace RE2020

/-- Type de scénario (résidentiel vs tertiaire) -/
inductive ScenarioType where
  | Residentiel
  | TertiaireBureau
  | TertiaireEnseignement
  deriving Repr, DecidableEq

/-- Données horaires pour un scénario (24 valeurs) -/
structure HourlyProfile where
  occupation      : Array Float   -- 0.0 à 1.0 (taux d'occupation)
  internalGains   : Array Float   -- W/m² (gains internes totaux)
  ventilationRate : Array Float   -- m³/h.m²
  heatingSetpoint : Array Float   -- °C
  coolingSetpoint : Array Float   -- °C
  deriving Repr

/-- Scénario conventionnel simplifié pour le résidentiel -/
def residentialScenario : HourlyProfile :=
  let hours := Array.range 24
  {
    occupation := hours.map fun h =>
      if h >= 7 && h <= 22 then 0.7 else 1.0,   -- plus présent le soir/nuit
    internalGains := hours.map fun h =>
      if h >= 7 && h <= 22 then 5.0 else 2.0,   -- W/m²
    ventilationRate := Array.replicate 24 0.5,    -- m³/h.m² constant (simplifié)
    heatingSetpoint := Array.replicate 24 20.0,
    coolingSetpoint := Array.replicate 24 26.0
  }

/-- Scénario conventionnel simplifié pour bureaux -/
def officeScenario : HourlyProfile :=
  {
    occupation := Array.replicate 24 0.0
      |>.set! 8 0.8 |>.set! 9 1.0 |>.set! 10 1.0 |>.set! 11 1.0
      |>.set! 12 0.6 |>.set! 13 0.8 |>.set! 14 1.0 |>.set! 15 1.0
      |>.set! 16 1.0 |>.set! 17 0.9 |>.set! 18 0.5,
    internalGains := Array.replicate 24 8.0,     -- plus élevé en tertiaire
    ventilationRate := Array.replicate 24 1.0,
    heatingSetpoint := Array.replicate 24 21.0,
    coolingSetpoint := Array.replicate 24 25.0
  }

/-- Récupère le scénario adapté au type de bâtiment -/
def getScenario (category : BuildingCategory) : HourlyProfile :=
  match category with
  | BuildingCategory.MaisonIndividuelle
  | BuildingCategory.LogementCollectif => residentialScenario
  | BuildingCategory.Bureau => officeScenario
  | _ => residentialScenario

/-- Applique le scénario à un groupe thermique pour une heure donnée -/
def applyScenarioToGroup
    (group : ThermalGroup)
    (scenario : HourlyProfile)
    (hour : Nat) : (Float × Float × Float × Float × Float) :=
  let h := hour % 24
  let occ := scenario.occupation[h]!
  let gains := scenario.internalGains[h]! * group.referenceArea
  let vent := scenario.ventilationRate[h]!
  let heatSet := scenario.heatingSetpoint[h]!
  let coolSet := scenario.coolingSetpoint[h]!
  (occ, gains, vent, heatSet, coolSet)

end RE2020
