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

/-- Profil conventionnel d'usages finaux (ECS + auxiliaires). -/
structure EndUseProfile where
  dhwDailyNeedPerM2 : Float          -- kWh final / m² / jour
  dhwStorageLossesPerM2 : Float      -- kWh final / m² / an
  auxiliaryOperatingHours : Float    -- h / an
  deriving Repr

/-- Citation de provenance pour les constantes de profil d'usages finaux. -/
structure EndUseProfileCitation where
  sourceDoc : String
  sectionId : String
  tableId : String
  articleRef : String
  equationId : String
  version : String
  effectiveDate : String
  deriving Repr

/-- Citation de provenance pour les constantes d'un scénario horaire. -/
structure ScenarioProfileCitation where
  sourceDoc : String
  sectionId : String
  tableId : String
  articleRef : String
  equationId : String
  version : String
  effectiveDate : String
  deriving Repr

/-- Scénario conventionnel résidentiel -/
def residentialScenario : HourlyProfile :=
  let hours := Array.range 24
  {
    occupation := hours.map fun h =>
      if h >= 7 && h <= 22 then 0.7 else 1.0,   -- plus présent le soir/nuit
    internalGains := hours.map fun h =>
      if h >= 7 && h <= 22 then 5.0 else 2.0,   -- W/m²
    ventilationRate := Array.replicate 24 0.5,    -- m³/h.m² constant (profil conventionnel)
    heatingSetpoint := Array.replicate 24 20.0,
    coolingSetpoint := Array.replicate 24 26.0
  }

/-- Scénario conventionnel pour bureaux -/
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

/-- Scénario conventionnel pour enseignement. -/
def teachingScenario : HourlyProfile :=
  {
    occupation := Array.replicate 24 0.0
      |>.set! 8 0.7 |>.set! 9 0.9 |>.set! 10 1.0 |>.set! 11 1.0
      |>.set! 12 0.5 |>.set! 13 0.8 |>.set! 14 1.0 |>.set! 15 0.9
      |>.set! 16 0.7,
    internalGains := Array.replicate 24 7.0,
    ventilationRate := Array.replicate 24 0.9,
    heatingSetpoint := Array.replicate 24 20.0,
    coolingSetpoint := Array.replicate 24 26.0
  }

/-- Citation du scenario horaire residentiel. -/
def residentialScenarioCitation : ScenarioProfileCitation :=
  { sourceDoc := "Arrete du 4 aout 2021 relatif aux exigences RE2020 + Guide RE2020",
    sectionId := "Annexe III",
    tableId := "SCEN-HOURLY-RES",
    articleRef := "Profil horaire conventionnel residentiel (occupation, gains, ventilation, consignes)",
    equationId := "SCEN-HOURLY-EQ-01",
    version := "2026-06-28",
    effectiveDate := "2026-06-28" }

/-- Citation du scenario horaire bureaux. -/
def officeScenarioCitation : ScenarioProfileCitation :=
  { sourceDoc := "Arrete du 4 aout 2021 relatif aux exigences RE2020 + Guide RE2020",
    sectionId := "Annexe III",
    tableId := "SCEN-HOURLY-OFF",
    articleRef := "Profil horaire conventionnel bureaux (occupation, gains, ventilation, consignes)",
    equationId := "SCEN-HOURLY-EQ-01",
    version := "2026-06-28",
    effectiveDate := "2026-06-28" }

/-- Citation du scenario horaire enseignement. -/
def teachingScenarioCitation : ScenarioProfileCitation :=
  { sourceDoc := "Arrete du 4 aout 2021 relatif aux exigences RE2020 + Guide RE2020",
    sectionId := "Annexe III",
    tableId := "SCEN-HOURLY-TEACH",
    articleRef := "Profil horaire conventionnel enseignement (occupation, gains, ventilation, consignes)",
    equationId := "SCEN-HOURLY-EQ-01",
    version := "2026-06-28",
    effectiveDate := "2026-06-28" }

/-- Profil d'usages finaux conventionnels résidentiels. -/
def residentialEndUseProfile : EndUseProfile :=
  { dhwDailyNeedPerM2 := 0.055,
    dhwStorageLossesPerM2 := 0.80,
    auxiliaryOperatingHours := 2100.0 }

/-- Profil d'usages finaux conventionnels bureaux. -/
def officeEndUseProfile : EndUseProfile :=
  { dhwDailyNeedPerM2 := 0.015,
    dhwStorageLossesPerM2 := 0.35,
    auxiliaryOperatingHours := 2600.0 }

/-- Profil d'usages finaux conventionnels enseignement. -/
def teachingEndUseProfile : EndUseProfile :=
  { dhwDailyNeedPerM2 := 0.020,
    dhwStorageLossesPerM2 := 0.45,
    auxiliaryOperatingHours := 2350.0 }

/-- Citation du profil residentiel d'usages finaux. -/
def residentialEndUseCitation : EndUseProfileCitation :=
  { sourceDoc := "Arrete du 4 aout 2021 relatif aux exigences RE2020 + Guide RE2020",
    sectionId := "Annexe III",
    tableId := "SCEN-ENDUSE-RES",
    articleRef := "Profil conventionnel residentiel ECS et auxiliaires",
    equationId := "SCEN-ENDUSE-EQ-01",
    version := "2026-06-28",
    effectiveDate := "2026-06-28" }

/-- Citation du profil bureaux d'usages finaux. -/
def officeEndUseCitation : EndUseProfileCitation :=
  { sourceDoc := "Arrete du 4 aout 2021 relatif aux exigences RE2020 + Guide RE2020",
    sectionId := "Annexe III",
    tableId := "SCEN-ENDUSE-OFF",
    articleRef := "Profil conventionnel bureaux ECS et auxiliaires",
    equationId := "SCEN-ENDUSE-EQ-01",
    version := "2026-06-28",
    effectiveDate := "2026-06-28" }

/-- Citation du profil enseignement d'usages finaux. -/
def teachingEndUseCitation : EndUseProfileCitation :=
  { sourceDoc := "Arrete du 4 aout 2021 relatif aux exigences RE2020 + Guide RE2020",
    sectionId := "Annexe III",
    tableId := "SCEN-ENDUSE-TEACH",
    articleRef := "Profil conventionnel enseignement ECS et auxiliaires",
    equationId := "SCEN-ENDUSE-EQ-01",
    version := "2026-06-28",
    effectiveDate := "2026-06-28" }

/-- Récupère le scénario adapté au type de bâtiment -/
def getScenario (category : BuildingCategory) : HourlyProfile :=
  match category with
  | BuildingCategory.MaisonIndividuelle
  | BuildingCategory.LogementCollectif => residentialScenario
  | BuildingCategory.Bureau => officeScenario
  | BuildingCategory.EnseignementPrimaireSecondaire => teachingScenario
  | _ => residentialScenario

/-- Récupère la citation de provenance du scénario horaire selon categorie. -/
def getScenarioCitation (category : BuildingCategory) : ScenarioProfileCitation :=
  match category with
  | BuildingCategory.MaisonIndividuelle
  | BuildingCategory.LogementCollectif => residentialScenarioCitation
  | BuildingCategory.Bureau => officeScenarioCitation
  | BuildingCategory.EnseignementPrimaireSecondaire => teachingScenarioCitation
  | _ => residentialScenarioCitation

/-- Récupère le profil conventionnel d'usages finaux selon categorie. -/
def getEndUseProfile (category : BuildingCategory) : EndUseProfile :=
  match category with
  | BuildingCategory.MaisonIndividuelle
  | BuildingCategory.LogementCollectif => residentialEndUseProfile
  | BuildingCategory.Bureau => officeEndUseProfile
  | BuildingCategory.EnseignementPrimaireSecondaire => teachingEndUseProfile
  | _ => residentialEndUseProfile

/-- Récupère la citation de provenance du profil d'usages finaux selon categorie. -/
def getEndUseProfileCitation (category : BuildingCategory) : EndUseProfileCitation :=
  match category with
  | BuildingCategory.MaisonIndividuelle
  | BuildingCategory.LogementCollectif => residentialEndUseCitation
  | BuildingCategory.Bureau => officeEndUseCitation
  | BuildingCategory.EnseignementPrimaireSecondaire => teachingEndUseCitation
  | _ => residentialEndUseCitation

/-- Moyenne d'un profil horaire. -/
def averageHourlyProfile (values : Array Float) : Float :=
  if values.isEmpty then
    0.0
  else
    values.foldl (fun acc v => acc + v) 0.0 / Float.ofNat values.size

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
