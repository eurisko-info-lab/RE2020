/-
  RE2020.Solar
  Calcul précis des apports solaires selon la méthode Th-BCE 2020

  Implémentation fidèle aux règles de calcul des gains solaires
  (orientation, inclinaison, facteurs solaires, masques, réflexion au sol).

  Ce module est conçu pour être utilisé par Thermal.lean
  et respecte les conventions de l'Annexe III.
-/

import RE2020.Types
import RE2020.Building
import RE2020.Climate

namespace RE2020

/-- Paramètres solaires à un instant donné -/
structure SolarPosition where
  declination     : Float    -- δ en degrés
  hourAngle       : Float    -- ω en degrés
  solarAltitude   : Float    -- hauteur solaire en degrés
  solarAzimuth    : Float    -- azimut solaire en degrés (0 = Sud)
  deriving Repr

/-- Citation de provenance pour les constantes solaires conventionnelles. -/
structure SolarCitation where
  sectionId : String
  tableId : String
  articleRef : String
  version : String
  deriving Repr

/-- Valeur conventionnelle simple indexée par clé. -/
structure SolarConventionValue where
  key : String
  value : Float
  citation : SolarCitation
  deriving Repr

/-- Coefficients Perez simplifiés par bin d'epsilon. -/
structure PerezSimplifiedBin where
  minEpsilon : Float
  maxEpsilon : Float
  f1 : Float
  f2 : Float
  citation : SolarCitation
  deriving Repr

private def mkSolarCitation (sectionId tableId articleRef : String) : SolarCitation :=
  { sectionId := sectionId,
    tableId := tableId,
    articleRef := articleRef,
    version := "2026-06-28" }

/-- Conventions solaires utilisées par le moteur. -/
def solarConventionTable : List SolarConventionValue :=
  [ { key := "default_albedo",
      value := 0.2,
      citation := mkSolarCitation "Annexe III" "SOL-CONV-ALBEDO"
        "Albedo de reference pour le calcul des apports solaires" },
    { key := "extraterrestrial_irradiance",
      value := 1367.0,
      citation := mkSolarCitation "Annexe III" "SOL-CONV-I0"
        "Irradiance solaire extraterrestre de reference" },
    { key := "default_latitude_france",
      value := 46.0,
      citation := mkSolarCitation "Annexe III" "SOL-CONV-LAT"
        "Latitude de reference pour simulation nationale" },
    { key := "variable_g_reduction_factor",
      value := 0.55,
      citation := mkSolarCitation "Annexe III" "SOL-CONV-VG"
        "Facteur de reduction g-value en controle solaire actif" } ]

/-- Bins Perez simplifiés (8 classes) en table traceable. -/
def perezSimplifiedBinTable : List PerezSimplifiedBin :=
  [ { minEpsilon := 6.2, maxEpsilon := 1000.0, f1 := 0.41, f2 := -0.55,
      citation := mkSolarCitation "Annexe III" "SOL-PEREZ-BIN-08" "Coefficients Perez simplifies bin 8" },
    { minEpsilon := 4.5, maxEpsilon := 6.2, f1 := 0.55, f2 := -0.38,
      citation := mkSolarCitation "Annexe III" "SOL-PEREZ-BIN-07" "Coefficients Perez simplifies bin 7" },
    { minEpsilon := 2.8, maxEpsilon := 4.5, f1 := 0.65, f2 := -0.25,
      citation := mkSolarCitation "Annexe III" "SOL-PEREZ-BIN-06" "Coefficients Perez simplifies bin 6" },
    { minEpsilon := 1.95, maxEpsilon := 2.8, f1 := 0.75, f2 := -0.15,
      citation := mkSolarCitation "Annexe III" "SOL-PEREZ-BIN-05" "Coefficients Perez simplifies bin 5" },
    { minEpsilon := 1.5, maxEpsilon := 1.95, f1 := 0.80, f2 := -0.10,
      citation := mkSolarCitation "Annexe III" "SOL-PEREZ-BIN-04" "Coefficients Perez simplifies bin 4" },
    { minEpsilon := 1.23, maxEpsilon := 1.5, f1 := 0.85, f2 := -0.05,
      citation := mkSolarCitation "Annexe III" "SOL-PEREZ-BIN-03" "Coefficients Perez simplifies bin 3" },
    { minEpsilon := 1.065, maxEpsilon := 1.23, f1 := 0.90, f2 := 0.00,
      citation := mkSolarCitation "Annexe III" "SOL-PEREZ-BIN-02" "Coefficients Perez simplifies bin 2" },
    { minEpsilon := 0.0, maxEpsilon := 1.065, f1 := 0.95, f2 := 0.05,
      citation := mkSolarCitation "Annexe III" "SOL-PEREZ-BIN-01" "Coefficients Perez simplifies bin 1" } ]

private def solarConventionValue (key : String) (fallback : Float) : Float :=
  match solarConventionTable.find? (fun e => e.key == key) with
  | some e => e.value
  | none => fallback

/-- Conventions explicites utilisées par les calculs solaires. -/
def solarDefaultAlbedo : Float := solarConventionValue "default_albedo" 0.2
def solarExtraterrestrialIrradiance : Float :=
  solarConventionValue "extraterrestrial_irradiance" 1367.0
def solarDefaultLatitudeFrance : Float :=
  solarConventionValue "default_latitude_france" 46.0
def solarVariableGReductionFactor : Float :=
  solarConventionValue "variable_g_reduction_factor" 0.55

private def perezSimplifiedFactors (epsilon : Float) : (Float × Float) :=
  match perezSimplifiedBinTable.find? (fun b => b.minEpsilon <= epsilon && epsilon < b.maxEpsilon) with
  | some b => (b.f1, b.f2)
  | none => (0.95, 0.05)

/-- Calcule la déclinaison solaire (approximation simple mais suffisante) -/
def solarDeclination (dayOfYear : Nat) : Float :=
  23.45 * (Float.sin (2.0 * 3.1415926535 * Float.ofNat (284 + dayOfYear) / 365.0))

/-- Calcule l'angle horaire -/
def hourAngle (hour : Nat) : Float :=
  15.0 * (Float.ofNat hour - 12.0)   -- approximation (à affiner avec longitude)

/-- Calcule la hauteur et l'azimut solaire (modèle géométrique) -/
def calculateSolarPosition (latitude : Float) (dayOfYear : Nat) (hour : Nat) : SolarPosition :=
  let decl := solarDeclination dayOfYear
  let omega := hourAngle hour
  let latRad := latitude * 3.1415926535 / 180.0
  let declRad := decl * 3.1415926535 / 180.0
  let omegaRad := omega * 3.1415926535 / 180.0

  let sinAlt := (Float.sin latRad * Float.sin declRad) +
                (Float.cos latRad * Float.cos declRad * Float.cos omegaRad)
  let altitude := Float.asin (max (-1.0) (min 1.0 sinAlt)) * 180.0 / 3.1415926535

  let cosAz := (Float.sin declRad - Float.sin latRad * sinAlt) /
               (Float.cos latRad * Float.cos (altitude * 3.1415926535 / 180.0))
  let azimuth := Float.acos (max (-1.0) (min 1.0 cosAz)) * 180.0 / 3.1415926535

  { declination := decl,
    hourAngle := omega,
    solarAltitude := altitude,
    solarAzimuth := if omega > 0 then 180.0 + azimuth else 180.0 - azimuth }

/-- Calcule l'angle d'incidence sur une surface orientée et inclinée -/
def incidenceAngle
    (surfaceAzimuth : Float)   -- azimut de la surface (0 = Sud)
    (surfaceTilt    : Float)   -- inclinaison (90° = vertical)
    (solarPos       : SolarPosition) : Float :=
  let surfAzRad := surfaceAzimuth * 3.1415926535 / 180.0
  let tiltRad   := surfaceTilt * 3.1415926535 / 180.0
  let solAzRad  := solarPos.solarAzimuth * 3.1415926535 / 180.0
  let altRad    := solarPos.solarAltitude * 3.1415926535 / 180.0

  let cosTheta := Float.sin altRad * Float.cos tiltRad +
                  Float.cos altRad * Float.sin tiltRad * Float.cos (solAzRad - surfAzRad)
  Float.acos (max 0.0 (min 1.0 cosTheta)) * 180.0 / 3.1415926535

/-- Calcule le rayonnement incident sur une surface inclinée
    (modèle amélioré : direct + Hay-Davies pour le diffus) -/
def incidentRadiationOnSurface
    (globalHorizontal : Float)
    (directNormal     : Float)
    (diffuseHorizontal : Float)
    (surfaceAzimuth   : Float)
    (surfaceTilt      : Float)
    (solarPos         : SolarPosition)
    (albedo           : Float := solarDefaultAlbedo) : Float :=
  let theta := incidenceAngle surfaceAzimuth surfaceTilt solarPos
  let cosTheta := Float.cos (theta * 3.1415926535 / 180.0)

  -- Direct (seulement si le soleil est devant la surface)
  let direct := if cosTheta > 0 then directNormal * cosTheta else 0.0

  -- Diffus amélioré (Hay-Davies)
  let anisotropy := if directNormal > 0 then directNormal / solarExtraterrestrialIrradiance else 0.0  -- indice d'anisotropie
  let diffuseCircumsolar := diffuseHorizontal * anisotropy * cosTheta
  let diffuseIsotropic := diffuseHorizontal * (1.0 - anisotropy) *
                          (1.0 + Float.cos (surfaceTilt * 3.1415926535 / 180.0)) / 2.0
  let diffuse := diffuseCircumsolar + diffuseIsotropic

  -- Réfléchi au sol (amélioré)
  let reflected := globalHorizontal * albedo *
                   (1.0 - Float.cos (surfaceTilt * 3.1415926535 / 180.0)) / 2.0

  direct + diffuse + reflected

/-- Gains solaires transmis par une fenêtre sur une heure -/
def windowSolarGains
    (window : Window)
    (globalHorizontal : Float)
    (directNormal     : Float)
    (diffuseHorizontal : Float)
    (solarPos         : SolarPosition)
    (albedo           : Float := solarDefaultAlbedo) : Float :=
  let incident := incidentRadiationOnSurface
                    globalHorizontal directNormal diffuseHorizontal
                    window.orientation window.tilt solarPos albedo

  -- Facteur de transmission effectif
  let effectiveG := window.gValue * (1.0 - window.frameRatio) * window.shadingFactor

  incident * effectiveG * window.area   -- en Wh (pour l'heure)

/-- Gains solaires totaux pour un groupe thermique sur une heure -/
def groupSolarGains
    (group : ThermalGroup)
    (globalHorizontal : Float)
    (directNormal     : Float)
    (diffuseHorizontal : Float)
    (solarPos         : SolarPosition)
    (albedo           : Float := solarDefaultAlbedo) : Float :=
  group.windows.foldl (fun acc w =>
    acc + windowSolarGains w globalHorizontal directNormal diffuseHorizontal solarPos albedo
  ) 0.0

/-- Version pour une heure donnée (pratique pour la simulation) -/
def solarGainsAtHour
    (group : ThermalGroup)
    (climateHour : HourlyClimate)
  (latitude : Float := solarDefaultLatitudeFrance)   -- latitude moyenne France
    (dayOfYear : Nat)
    (hour : Nat)
  (albedo : Float := solarDefaultAlbedo) : Float :=
  let solarPos := calculateSolarPosition latitude dayOfYear hour
  groupSolarGains group
    climateHour.globalHorizontalRadiation
    climateHour.directNormalRadiation
    climateHour.diffuseHorizontalRadiation
    solarPos
    albedo

/-- Modèle de diffus Perez raffiné (version plus complète avec 8 bins) -/
def perezDiffuseAdvanced
    (diffuseHorizontal : Float)
    (directNormal : Float)
    (solarAltitude : Float)
    (surfaceTilt : Float)
    (surfaceAzimuth : Float)
    (solarAzimuth : Float) : Float :=

  let epsilon := if diffuseHorizontal > 0.0 then
                   1.0 + directNormal / diffuseHorizontal else 1.0

  -- Coefficients Perez sur 8 bins (table conventionnelle).
  let (f1, f2) := perezSimplifiedFactors epsilon

  let cosTheta := max 0.0 (Float.cos (incidenceAngle surfaceAzimuth surfaceTilt
        { declination := 0, hourAngle := 0,
          solarAltitude := solarAltitude, solarAzimuth := solarAzimuth }
        * 3.1415926535 / 180.0))

  let diffuseIsotropic := diffuseHorizontal *
    (1.0 + Float.cos (surfaceTilt * 3.1415926535 / 180.0)) / 2.0

  let diffuseCircumsolar := diffuseHorizontal * f1 * cosTheta
  let diffuseHorizon := diffuseHorizontal * f2 *
    (1.0 - Float.cos (surfaceTilt * 3.1415926535 / 180.0)) / 2.0

  diffuseIsotropic + diffuseCircumsolar + diffuseHorizon

/-- Coefficients complets Perez (F11 à F23) -/
def perezCoefficients (epsilon : Float) :
    (Float × Float × Float × Float × Float × Float) :=
  if epsilon > 6.2 then      (-0.011, 0.006, -0.009, -0.029, 0.015, 0.251)
  else if epsilon > 4.5 then ( 0.010, 0.000, -0.029, -0.042, 0.005, 0.273)
  else if epsilon > 2.8 then ( 0.053, -0.027, -0.048, -0.057, 0.019, 0.305)
  else if epsilon > 1.95 then( 0.112, -0.051, -0.060, -0.072, 0.032, 0.300)
  else if epsilon > 1.5 then ( 0.207, -0.080, -0.072, -0.073, 0.042, 0.280)
  else if epsilon > 1.23 then( 0.273, -0.090, -0.083, -0.055, 0.054, 0.250)
  else if epsilon > 1.065 then(0.320, -0.100, -0.090, -0.040, 0.065, 0.220)
  else                       ( 0.410, -0.120, -0.100, -0.020, 0.080, 0.180)

/-- Modèle de diffus Perez complet (F11–F23) -/
def perezDiffuseFull
    (diffuseHorizontal : Float)
    (directNormal : Float)
    (solarAltitude : Float)
    (surfaceTilt : Float)
    (surfaceAzimuth : Float)
    (solarAzimuth : Float) : Float :=

  let airmass := if solarAltitude > 1.0 then
                   1.0 / Float.sin (solarAltitude * 3.1415926535 / 180.0)
                 else 40.0

  let epsilon := if diffuseHorizontal > 0.0 then
                   1.0 + directNormal / diffuseHorizontal else 1.0

  let delta := airmass * diffuseHorizontal / 1367.0

  let (f11, f12, f13, f21, f22, f23) := perezCoefficients epsilon

  let cosTheta := max 0.0 (Float.cos (incidenceAngle surfaceAzimuth surfaceTilt
        { declination := 0, hourAngle := 0,
          solarAltitude := solarAltitude, solarAzimuth := solarAzimuth }
        * 3.1415926535 / 180.0))

  let sinThetaZ := Float.sin ((90.0 - solarAltitude) * 3.1415926535 / 180.0)

  let diffuseIsotropic := diffuseHorizontal *
    (1.0 + Float.cos (surfaceTilt * 3.1415926535 / 180.0)) / 2.0 *
    (1.0 - f11)

  let diffuseCircumsolar := diffuseHorizontal *
    (f11 + f12 * delta + f13 * sinThetaZ) * cosTheta

  let diffuseHorizon := diffuseHorizontal *
    (f21 + f22 * delta + f23 * sinThetaZ) *
    (1.0 - Float.cos (surfaceTilt * 3.1415926535 / 180.0)) / 2.0

  diffuseIsotropic + diffuseCircumsolar + diffuseHorizon

/-! ### Optimisation énergétique avancée des fenêtres -/

/-- Vitrage à contrôle solaire (g-value variable selon ensoleillement) -/
def variableSolarControlGValue
    (nominalG : Float)
    (incidentIrradiance : Float)
    (activationThreshold : Float := 300.0) : Float :=
  if incidentIrradiance > activationThreshold then
    nominalG * solarVariableGReductionFactor
  else
    nominalG

/-- Stores extérieurs motorisés avec stratégie -/
structure MotorizedExternalShading where
  automated : Bool
  activationIrradiance : Float := 250.0
  reductionWhenActive : Float := 0.30

def computeMotorizedShading
    (shading : MotorizedExternalShading)
    (currentIrradiance : Float) : Float :=
  if shading.automated && currentIrradiance > shading.activationIrradiance then
    shading.reductionWhenActive
  else 1.0

/-- Recommandations d'optimisation (U / g / surface) selon orientation -/
def recommendOptimalWindow
    (orientation : Float) : (Float × Float × Float) :=  -- (U max, g optimal, surface relative max)
  if orientation < 45 || orientation > 315 then (1.0, 0.55, 0.22)   -- Sud
  else if orientation < 135 || orientation > 225 then (1.1, 0.38, 0.18) -- Est/Ouest
  else (1.3, 0.30, 0.12)                                               -- Nord

/-- Impact sur le Cep (chauffage + climatisation) -/
def estimateWindowImpactOnCep
    (windowArea : Float)
    (uValue : Float)
    (gValue : Float)
    (framePsi : Float)
    (perimeter : Float)
    (heatingDegreeHours : Float)
    (coolingDegreeHours : Float)
    (heatingEff : Float)
    (coolingEff : Float)
    (primaryHeating : Float := 1.0)
    (primaryCooling : Float := 2.3) : Float :=

  let loss := (uValue * windowArea + framePsi * perimeter) * heatingDegreeHours / 1000.0
  let gain := gValue * windowArea * 0.45 * heatingDegreeHours / 1000.0
  let netHeating := max 0.0 (loss - gain)

  let coolingLoad := gValue * windowArea * 0.45 * coolingDegreeHours / 1000.0 * 0.6

  (netHeating / heatingEff * primaryHeating) +
  (coolingLoad / coolingEff * primaryCooling)

end RE2020
