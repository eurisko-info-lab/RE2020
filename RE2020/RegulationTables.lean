/-
  RE2020.RegulationTables
  Tables de coefficients reglementaires et metadonnees de provenance.

  Objectif:
  - centraliser les coefficients dans un module dedie
  - versionner les valeurs
  - associer chaque valeur a une citation explicite
-/

import RE2020.Types

namespace RE2020

/-- Metadonnees de provenance machine-checkable pour une valeur reglementaire. -/
structure RegulationCitation where
  sourceDoc : String
  sectionId : String
  tableId : String
  articleRef : String
  version : String
  effectiveDate : String
  deriving Repr

/-- Coefficient indexe par zone climatique. -/
structure ZoneCoefficient where
  zone : ClimateZone
  value : Float
  citation : RegulationCitation
  deriving Repr

/-- Coefficient indexe par categorie de batiment. -/
structure CategoryCoefficient where
  category : BuildingCategory
  value : Float
  citation : RegulationCitation
  deriving Repr

/-- Coefficient indexe par bande de surface de reference. -/
structure AreaBandCoefficient where
  minArea : Float
  maxArea : Float
  value : Float
  citation : RegulationCitation
  deriving Repr

/-- Coefficient indexe par usage energetique du pipeline. -/
structure UsageFactorCoefficient where
  usage : String
  value : Float
  citation : RegulationCitation
  deriving Repr

/-- Bande de seuil de confort DH selon moyenne glissante exterieure. -/
structure ComfortThresholdBand where
  minRunningMean : Float
  maxRunningMean : Float
  comfortTemp : Float
  citation : RegulationCitation
  deriving Repr

/-- Bundle valeur + citation pour un coefficient de modulation. -/
structure ModulationValue where
  value : Float
  citation : RegulationCitation
  deriving Repr

/-- Bundle complet des coefficients de modulation avec citations. -/
structure ModulationTrace where
  geo : ModulationValue
  combles : ModulationValue
  surfMoy : ModulationValue
  surfTot : ModulationValue
  bruit : ModulationValue
  cat : ModulationValue
  deriving Repr

/-- Version de reference des tables embarquees. -/
def modulationTableVersion : String := "re2020-convention-table-v2"

/-- Constructeur de citation avec identifiants legaux explicites. -/
def mkCitation (sectionId tableId articleRef : String) : RegulationCitation :=
  { sourceDoc := "Arrete du 4 aout 2021 relatif aux exigences RE2020 + Guide RE2020",
    sectionId := sectionId,
    tableId := tableId,
    articleRef := articleRef,
    version := "2026-06-27",
    effectiveDate := "2026-06-27" }

/-- Table geographique (Mbgeo / Mcgeo) par zone climatique. -/
def geoCoefficientTable : List ZoneCoefficient :=
  [ { zone := .H1a,
      value := 0.15,
      citation := mkCitation "Annexe II.B" "MBGEO-H1a" "Arrete 4 aout 2021 - Annexe II, modulation geographique" },
    { zone := .H1b,
      value := 0.13,
      citation := mkCitation "Annexe II.B" "MBGEO-H1b" "Arrete 4 aout 2021 - Annexe II, modulation geographique" },
    { zone := .H1c,
      value := 0.11,
      citation := mkCitation "Annexe II.B" "MBGEO-H1c" "Arrete 4 aout 2021 - Annexe II, modulation geographique" },
    { zone := .H2a,
      value := 0.08,
      citation := mkCitation "Annexe II.B" "MBGEO-H2a" "Arrete 4 aout 2021 - Annexe II, modulation geographique" },
    { zone := .H2b,
      value := 0.06,
      citation := mkCitation "Annexe II.B" "MBGEO-H2b" "Arrete 4 aout 2021 - Annexe II, modulation geographique" },
    { zone := .H2c,
      value := 0.04,
      citation := mkCitation "Annexe II.B" "MBGEO-H2c" "Arrete 4 aout 2021 - Annexe II, modulation geographique" },
    { zone := .H2d,
      value := 0.05,
      citation := mkCitation "Annexe II.B" "MBGEO-H2d" "Arrete 4 aout 2021 - Annexe II, modulation geographique" },
    { zone := .H3,
      value := 0.02,
      citation := mkCitation "Annexe II.B" "MBGEO-H3" "Arrete 4 aout 2021 - Annexe II, modulation geographique" } ]

/-- Table combles selon categorie de batiment. -/
def comblesCoefficientTable : List CategoryCoefficient :=
  [ { category := .MaisonIndividuelle,
      value := 0.04,
      citation := mkCitation "Annexe II.B" "MBCOMBLES-MI" "Arrete 4 aout 2021 - Annexe II, modulation combles" },
    { category := .LogementCollectif,
      value := 0.02,
      citation := mkCitation "Annexe II.B" "MBCOMBLES-LC" "Arrete 4 aout 2021 - Annexe II, modulation combles" },
    { category := .Bureau,
      value := 0.01,
      citation := mkCitation "Annexe II.B" "MBCOMBLES-BUR" "Arrete 4 aout 2021 - Annexe II, modulation combles" },
    { category := .EnseignementPrimaireSecondaire,
      value := 0.015,
      citation := mkCitation "Annexe II.B" "MBCOMBLES-ENS" "Arrete 4 aout 2021 - Annexe II, modulation combles" },
    { category := .Autre,
      value := 0.01,
      citation := mkCitation "Annexe II.B" "MBCOMBLES-AUT" "Arrete 4 aout 2021 - Annexe II, modulation combles" } ]

/-- Table bruit selon categorie de batiment. -/
def bruitCoefficientTable : List CategoryCoefficient :=
  [ { category := .MaisonIndividuelle,
      value := 0.00,
      citation := mkCitation "Annexe II.B" "MBBRUIT-MI" "Arrete 4 aout 2021 - Annexe II, modulation bruit" },
    { category := .LogementCollectif,
      value := 0.01,
      citation := mkCitation "Annexe II.B" "MBBRUIT-LC" "Arrete 4 aout 2021 - Annexe II, modulation bruit" },
    { category := .Bureau,
      value := 0.02,
      citation := mkCitation "Annexe II.B" "MBBRUIT-BUR" "Arrete 4 aout 2021 - Annexe II, modulation bruit" },
    { category := .EnseignementPrimaireSecondaire,
      value := 0.015,
      citation := mkCitation "Annexe II.B" "MBBRUIT-ENS" "Arrete 4 aout 2021 - Annexe II, modulation bruit" },
    { category := .Autre,
      value := 0.01,
      citation := mkCitation "Annexe II.B" "MBBRUIT-AUT" "Arrete 4 aout 2021 - Annexe II, modulation bruit" } ]

/-- Table categorie (modulation Cep) selon categorie de batiment. -/
def catCoefficientTable : List CategoryCoefficient :=
  [ { category := .MaisonIndividuelle,
      value := 0.00,
      citation := mkCitation "Annexe II.C" "MCCAT-MI" "Arrete 4 aout 2021 - Annexe II, modulation categorie Cep" },
    { category := .LogementCollectif,
      value := 0.01,
      citation := mkCitation "Annexe II.C" "MCCAT-LC" "Arrete 4 aout 2021 - Annexe II, modulation categorie Cep" },
    { category := .Bureau,
      value := 0.03,
      citation := mkCitation "Annexe II.C" "MCCAT-BUR" "Arrete 4 aout 2021 - Annexe II, modulation categorie Cep" },
    { category := .EnseignementPrimaireSecondaire,
      value := 0.02,
      citation := mkCitation "Annexe II.C" "MCCAT-ENS" "Arrete 4 aout 2021 - Annexe II, modulation categorie Cep" },
    { category := .Autre,
      value := 0.015,
      citation := mkCitation "Annexe II.C" "MCCAT-AUT" "Arrete 4 aout 2021 - Annexe II, modulation categorie Cep" } ]

/-- Table surfMoy par bandes de surface. -/
def surfMoyCoefficientTable : List AreaBandCoefficient :=
  [ { minArea := 0.0,
      maxArea := 60.0,
      value := 0.05,
      citation := mkCitation "Annexe II.B" "MBSURFMOY-000-060" "Arrete 4 aout 2021 - Annexe II, modulation surface moyenne" },
    { minArea := 60.0,
      maxArea := 120.0,
      value := 0.03,
      citation := mkCitation "Annexe II.B" "MBSURFMOY-060-120" "Arrete 4 aout 2021 - Annexe II, modulation surface moyenne" },
    { minArea := 120.0,
      maxArea := 300.0,
      value := 0.015,
      citation := mkCitation "Annexe II.B" "MBSURFMOY-120-300" "Arrete 4 aout 2021 - Annexe II, modulation surface moyenne" },
    { minArea := 300.0,
      maxArea := 1000000000.0,
      value := 0.0,
      citation := mkCitation "Annexe II.B" "MBSURFMOY-300-INF" "Arrete 4 aout 2021 - Annexe II, modulation surface moyenne" } ]

/-- Table surfTot par bandes de surface. -/
def surfTotCoefficientTable : List AreaBandCoefficient :=
  [ { minArea := 0.0,
      maxArea := 100.0,
      value := 0.03,
      citation := mkCitation "Annexe II.B" "MBSURFTOT-000-100" "Arrete 4 aout 2021 - Annexe II, modulation surface totale" },
    { minArea := 100.0,
      maxArea := 500.0,
      value := 0.015,
      citation := mkCitation "Annexe II.B" "MBSURFTOT-100-500" "Arrete 4 aout 2021 - Annexe II, modulation surface totale" },
    { minArea := 500.0,
      maxArea := 2000.0,
      value := 0.005,
      citation := mkCitation "Annexe II.B" "MBSURFTOT-500-2000" "Arrete 4 aout 2021 - Annexe II, modulation surface totale" },
    { minArea := 2000.0,
      maxArea := 1000000000.0,
      value := 0.0,
      citation := mkCitation "Annexe II.B" "MBSURFTOT-2000-INF" "Arrete 4 aout 2021 - Annexe II, modulation surface totale" } ]

/-- Table des facteurs d'energie primaire par usage du pipeline actuel. -/
def primaryEnergyFactorTable : List UsageFactorCoefficient :=
  [ { usage := "heating",
      value := 1.0,
      citation := mkCitation "Annexe III" "PEF-HEATING" "Facteur energie primaire chauffage selon vecteur retenu" },
    { usage := "dhw",
      value := 2.3,
      citation := mkCitation "Annexe III" "PEF-DHW" "Facteur energie primaire ECS (convention electrique par defaut)" },
    { usage := "cooling",
      value := 2.3,
      citation := mkCitation "Annexe III" "PEF-COOLING" "Facteur energie primaire refroidissement (electricite)" },
    { usage := "lighting",
      value := 2.3,
      citation := mkCitation "Annexe III" "PEF-LIGHTING" "Facteur energie primaire eclairage (electricite)" },
    { usage := "auxiliaries",
      value := 2.3,
      citation := mkCitation "Annexe III" "PEF-AUX" "Facteur energie primaire auxiliaires (electricite)" } ]

/-- Table des facteurs d'energie non renouvelable par usage du pipeline actuel. -/
def nonRenewableEnergyFactorTable : List UsageFactorCoefficient :=
  [ { usage := "heating",
      value := 1.0,
      citation := mkCitation "Annexe III" "PENR-HEATING" "Facteur non renouvelable chauffage selon vecteur retenu" },
    { usage := "dhw",
      value := 2.3,
      citation := mkCitation "Annexe III" "PENR-DHW" "Facteur non renouvelable ECS (convention electrique par defaut)" },
    { usage := "cooling",
      value := 2.3,
      citation := mkCitation "Annexe III" "PENR-COOLING" "Facteur non renouvelable refroidissement (electricite)" },
    { usage := "lighting",
      value := 2.3,
      citation := mkCitation "Annexe III" "PENR-LIGHTING" "Facteur non renouvelable eclairage (electricite)" },
    { usage := "auxiliaries",
      value := 2.3,
      citation := mkCitation "Annexe III" "PENR-AUX" "Facteur non renouvelable auxiliaires (electricite)" } ]

/-- Table des poids de la formule Bbio par terme de besoin. -/
def bbioWeightTable : List UsageFactorCoefficient :=
  [ { usage := "heating_need",
      value := 2.0,
      citation := mkCitation "Annexe II" "BBIO-W-HEAT" "Ponderation Bbio du besoin de chauffage" },
    { usage := "cooling_need",
      value := 2.0,
      citation := mkCitation "Annexe II" "BBIO-W-COOL" "Ponderation Bbio du besoin de refroidissement" },
    { usage := "lighting_need",
      value := 5.0,
      citation := mkCitation "Annexe II" "BBIO-W-LIGHT" "Ponderation Bbio du besoin d'eclairage" } ]

/-- Table des seuils de confort adaptatifs pour le calcul DH. -/
def dhComfortThresholdTable : List ComfortThresholdBand :=
  [ { minRunningMean := 0.0,
      maxRunningMean := 26.0,
      comfortTemp := 26.0,
      citation := mkCitation "Annexe III" "DH-COMFORT-LOW"
        "Seuil confort DH pour moyenne exterieure <= 26C" },
    { minRunningMean := 26.0,
      maxRunningMean := 28.0,
      comfortTemp := 27.0,
      citation := mkCitation "Annexe III" "DH-COMFORT-MID"
        "Seuil confort DH pour moyenne exterieure entre 26C et 28C" },
    { minRunningMean := 28.0,
      maxRunningMean := 1000.0,
      comfortTemp := 28.0,
      citation := mkCitation "Annexe III" "DH-COMFORT-HIGH"
        "Seuil confort DH pour moyenne exterieure >= 28C" } ]

private def lookupZoneValue (table : List ZoneCoefficient) (zone : ClimateZone) (fallback : Float) : Float :=
  match table.find? (fun e => e.zone == zone) with
  | some entry => entry.value
  | none => fallback

private def lookupCategoryValue (table : List CategoryCoefficient) (category : BuildingCategory) (fallback : Float) : Float :=
  match table.find? (fun e => e.category == category) with
  | some entry => entry.value
  | none => fallback

private def lookupAreaBandValue (table : List AreaBandCoefficient) (area : Float) (fallback : Float) : Float :=
  let a := max 0.0 area
  match table.find? (fun e => e.minArea <= a && a < e.maxArea) with
  | some entry => entry.value
  | none => fallback

private def lookupUsageFactorValue (table : List UsageFactorCoefficient) (usage : String) (fallback : Float) : Float :=
  match table.find? (fun e => e.usage == usage) with
  | some entry => entry.value
  | none => fallback

private def lookupUsageFactorCitation? (table : List UsageFactorCoefficient) (usage : String) : Option RegulationCitation :=
  match table.find? (fun e => e.usage == usage) with
  | some entry => some entry.citation
  | none => none

private def lookupComfortThresholdValue (table : List ComfortThresholdBand) (runningMean : Float) (fallback : Float) : Float :=
  match table.find? (fun e => e.minRunningMean <= runningMean && runningMean < e.maxRunningMean) with
  | some entry => entry.comfortTemp
  | none => fallback

private def lookupComfortThresholdCitation? (table : List ComfortThresholdBand) (runningMean : Float) : Option RegulationCitation :=
  match table.find? (fun e => e.minRunningMean <= runningMean && runningMean < e.maxRunningMean) with
  | some entry => some entry.citation
  | none => none

private def lookupZoneCitation? (table : List ZoneCoefficient) (zone : ClimateZone) : Option RegulationCitation :=
  match table.find? (fun e => e.zone == zone) with
  | some entry => some entry.citation
  | none => none

private def lookupCategoryCitation? (table : List CategoryCoefficient) (category : BuildingCategory) : Option RegulationCitation :=
  match table.find? (fun e => e.category == category) with
  | some entry => some entry.citation
  | none => none

private def lookupAreaBandCitation? (table : List AreaBandCoefficient) (area : Float) : Option RegulationCitation :=
  let a := max 0.0 area
  match table.find? (fun e => e.minArea <= a && a < e.maxArea) with
  | some entry => some entry.citation
  | none => none

/-- Valeur de modulation geographique. -/
def geoModulationValue (zone : ClimateZone) : Float :=
  lookupZoneValue geoCoefficientTable zone 0.0

/-- Valeur de modulation combles. -/
def comblesModulationValue (category : BuildingCategory) : Float :=
  lookupCategoryValue comblesCoefficientTable category 0.0

/-- Valeur de modulation bruit. -/
def bruitModulationValue (category : BuildingCategory) : Float :=
  lookupCategoryValue bruitCoefficientTable category 0.0

/-- Valeur de modulation categorie (Cep). -/
def catModulationValue (category : BuildingCategory) : Float :=
  lookupCategoryValue catCoefficientTable category 0.0

/-- Valeur de modulation surfMoy. -/
def surfMoyModulationValue (area : Float) : Float :=
  lookupAreaBandValue surfMoyCoefficientTable area 0.0

/-- Valeur de modulation surfTot. -/
def surfTotModulationValue (area : Float) : Float :=
  lookupAreaBandValue surfTotCoefficientTable area 0.0

/-- Citation reglementaire de la modulation geographique. -/
def geoModulationCitation? (zone : ClimateZone) : Option RegulationCitation :=
  lookupZoneCitation? geoCoefficientTable zone

/-- Citation reglementaire de la modulation combles. -/
def comblesModulationCitation? (category : BuildingCategory) : Option RegulationCitation :=
  lookupCategoryCitation? comblesCoefficientTable category

/-- Citation reglementaire de la modulation bruit. -/
def bruitModulationCitation? (category : BuildingCategory) : Option RegulationCitation :=
  lookupCategoryCitation? bruitCoefficientTable category

/-- Citation reglementaire de la modulation categorie (Cep). -/
def catModulationCitation? (category : BuildingCategory) : Option RegulationCitation :=
  lookupCategoryCitation? catCoefficientTable category

/-- Citation reglementaire de la modulation surfMoy. -/
def surfMoyModulationCitation? (area : Float) : Option RegulationCitation :=
  lookupAreaBandCitation? surfMoyCoefficientTable area

/-- Citation reglementaire de la modulation surfTot. -/
def surfTotModulationCitation? (area : Float) : Option RegulationCitation :=
  lookupAreaBandCitation? surfTotCoefficientTable area

/-- Construction traceable des modulations (valeurs + citations). -/
def modulationTrace? (zone : ClimateZone) (category : BuildingCategory) (area : Float) : Option ModulationTrace := do
  let geoCit <- geoModulationCitation? zone
  let comblesCit <- comblesModulationCitation? category
  let surfMoyCit <- surfMoyModulationCitation? area
  let surfTotCit <- surfTotModulationCitation? area
  let bruitCit <- bruitModulationCitation? category
  let catCit <- catModulationCitation? category
  pure {
    geo := { value := geoModulationValue zone, citation := geoCit },
    combles := { value := comblesModulationValue category, citation := comblesCit },
    surfMoy := { value := surfMoyModulationValue area, citation := surfMoyCit },
    surfTot := { value := surfTotModulationValue area, citation := surfTotCit },
    bruit := { value := bruitModulationValue category, citation := bruitCit },
    cat := { value := catModulationValue category, citation := catCit }
  }

/-- Facteur d'energie primaire pour un usage. -/
def primaryEnergyFactorValue (usage : String) : Float :=
  lookupUsageFactorValue primaryEnergyFactorTable usage 1.0

/-- Facteur d'energie non renouvelable pour un usage. -/
def nonRenewableEnergyFactorValue (usage : String) : Float :=
  lookupUsageFactorValue nonRenewableEnergyFactorTable usage 1.0

/-- Citation reglementaire du facteur d'energie primaire pour un usage. -/
def primaryEnergyFactorCitation? (usage : String) : Option RegulationCitation :=
  lookupUsageFactorCitation? primaryEnergyFactorTable usage

/-- Citation reglementaire du facteur d'energie non renouvelable pour un usage. -/
def nonRenewableEnergyFactorCitation? (usage : String) : Option RegulationCitation :=
  lookupUsageFactorCitation? nonRenewableEnergyFactorTable usage

/-- Poids Bbio associe a un terme de besoin (chauffage/refroidissement/eclairage). -/
def bbioWeightValue (term : String) : Float :=
  lookupUsageFactorValue bbioWeightTable term 1.0

/-- Citation reglementaire du poids Bbio pour un terme de besoin. -/
def bbioWeightCitation? (term : String) : Option RegulationCitation :=
  lookupUsageFactorCitation? bbioWeightTable term

/-- Seuil de confort adaptatif DH pour une moyenne glissante exterieure. -/
def dhComfortThresholdForRunningMean (runningMean : Float) : Float :=
  lookupComfortThresholdValue dhComfortThresholdTable runningMean 26.0

/-- Citation du seuil de confort adaptatif DH pour une moyenne glissante exterieure. -/
def dhComfortThresholdCitationForRunningMean? (runningMean : Float) : Option RegulationCitation :=
  lookupComfortThresholdCitation? dhComfortThresholdTable runningMean

end RE2020
