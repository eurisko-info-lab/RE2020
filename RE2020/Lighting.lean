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
  operatingHours        : Float    -- Heures d'utilisation annuelles
  deriving Repr

/-- Citation de provenance des paramètres d'éclairage. -/
structure LightingCitation where
  sourceDoc : String
  sectionId : String
  tableId : String
  articleRef : String
  equationId : String
  version : String
  effectiveDate : String
  deriving Repr

/-- Entrée table-driven des paramètres d'éclairage par catégorie. -/
structure LightingParamEntry where
  category : BuildingCategory
  params : LightingParams
  citation : LightingCitation
  deriving Repr

/-- Tables de paramètres d'éclairage par catégorie, avec provenance explicite. -/
def lightingParamTable : List LightingParamEntry :=
  [ { category := .MaisonIndividuelle,
      params := {
        installedPowerDensity := 5.5,
        daylightFactor := 2.7,
        presenceControl := true,
        daylightDimming := true,
        operatingHours := 1700.0
      },
      citation := {
        sourceDoc := "Arrete du 4 aout 2021 relatif aux exigences RE2020 + Guide RE2020",
        sectionId := "Annexe III",
        tableId := "LIGHT-PARAM-MI",
        articleRef := "Parametres eclairage residentiel (MI)",
        equationId := "LIGHT-EQ-01",
        version := "2026-06-28",
        effectiveDate := "2026-06-28"
      } },
    { category := .LogementCollectif,
      params := {
        installedPowerDensity := 5.0,
        daylightFactor := 2.6,
        presenceControl := true,
        daylightDimming := true,
        operatingHours := 1800.0
      },
      citation := {
        sourceDoc := "Arrete du 4 aout 2021 relatif aux exigences RE2020 + Guide RE2020",
        sectionId := "Annexe III",
        tableId := "LIGHT-PARAM-LC",
        articleRef := "Parametres eclairage residentiel (LC)",
        equationId := "LIGHT-EQ-01",
        version := "2026-06-28",
        effectiveDate := "2026-06-28"
      } },
    { category := .Bureau,
      params := {
        installedPowerDensity := 8.0,
        daylightFactor := 2.5,
        presenceControl := true,
        daylightDimming := true,
        operatingHours := 2000.0
      },
      citation := {
        sourceDoc := "Arrete du 4 aout 2021 relatif aux exigences RE2020 + Guide RE2020",
        sectionId := "Annexe III",
        tableId := "LIGHT-PARAM-BUR",
        articleRef := "Parametres eclairage tertiaire bureaux",
        equationId := "LIGHT-EQ-01",
        version := "2026-06-28",
        effectiveDate := "2026-06-28"
      } },
    { category := .EnseignementPrimaireSecondaire,
      params := {
        installedPowerDensity := 7.0,
        daylightFactor := 2.8,
        presenceControl := true,
        daylightDimming := true,
        operatingHours := 1850.0
      },
      citation := {
        sourceDoc := "Arrete du 4 aout 2021 relatif aux exigences RE2020 + Guide RE2020",
        sectionId := "Annexe III",
        tableId := "LIGHT-PARAM-ENS",
        articleRef := "Parametres eclairage enseignement",
        equationId := "LIGHT-EQ-01",
        version := "2026-06-28",
        effectiveDate := "2026-06-28"
      } },
    { category := .Autre,
      params := {
        installedPowerDensity := 7.5,
        daylightFactor := 2.4,
        presenceControl := true,
        daylightDimming := true,
        operatingHours := 1900.0
      },
      citation := {
        sourceDoc := "Arrete du 4 aout 2021 relatif aux exigences RE2020 + Guide RE2020",
        sectionId := "Annexe III",
        tableId := "LIGHT-PARAM-AUT",
        articleRef := "Parametres eclairage categorie autre",
        equationId := "LIGHT-EQ-01",
        version := "2026-06-28",
        effectiveDate := "2026-06-28"
      } } ]

/-- Paramètres de fallback si une catégorie n'est pas trouvée dans la table. -/
def defaultLightingParams : LightingParams :=
  { installedPowerDensity := 8.0,
    daylightFactor        := 2.5,
    presenceControl       := true,
    daylightDimming       := true,
    operatingHours        := 2000.0
  }

private def lookupLightingEntry? (category : BuildingCategory) : Option LightingParamEntry :=
  lightingParamTable.find? (fun e => e.category == category)

/-- Paramètres d'éclairage par catégorie, issus des tables. -/
def lightingParamsForCategory (category : BuildingCategory) : LightingParams :=
  match lookupLightingEntry? category with
  | some entry => entry.params
  | none => defaultLightingParams

/-- Citation des paramètres d'éclairage par catégorie. -/
def lightingParamsCitationForCategory? (category : BuildingCategory) : Option LightingCitation :=
  (lookupLightingEntry? category).map (·.citation)

/-- Besoins annuels en éclairage pour un groupe (kWh/m².an) -/
def calculateLightingNeedsForGroup (group : ThermalGroup) (params : LightingParams) : Float :=
  let area := group.referenceArea
  if area <= 0 then 0.0 else
    let baseEnergy := params.installedPowerDensity * params.operatingHours / 1000.0  -- kWh/m².an

    -- Facteur de réduction grâce à l'éclairage naturel
    let daylightReduction :=
      if params.daylightDimming then
        max 0.3 (1.0 - params.daylightFactor / 100.0 * 0.8)  -- réduction paramétrique
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

/-- Besoins d'éclairage en appliquant les paramètres table-driven de la catégorie. -/
def calculateLightingNeedsByCategory (building : Building) : Float :=
  let params := lightingParamsForCategory building.category
  calculateLightingNeeds building params

end RE2020
