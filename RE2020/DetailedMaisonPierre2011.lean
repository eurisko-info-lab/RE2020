import RE2020.Types
import RE2020.Building
import RE2020.Climate
import RE2020.Thermal
import RE2020.Indicators
import RE2020.Systems
import RE2020.Scenarios
import RE2020.RegulationTables
import RE2020.Lighting

namespace RE2020

/--
Detailed full-model example for a certified BBC 2005 individual house
(Maison Pierre), built in 2011.

Values are intentionally set for a realistic 2011 envelope and glazing package,
while preserving room-area cues extracted from the provided plan OCR.

Location variant: Yonne (RE2020 climate zone H1c), with no south-facing windows
and a north facade adjacent to garage.
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

def detailedDefaultModulations (building : Building) : ModulationCoefficients :=
  let area := max 0.0 building.totalReferenceArea
  match modulationTrace? building.climateZone building.category area with
  | some trace =>
      { geo := trace.geo.value,
        combles := trace.combles.value,
        surfMoy := trace.surfMoy.value,
        surfTot := trace.surfTot.value,
        bruit := trace.bruit.value,
        cat := trace.cat.value }
  | none =>
      { geo := geoModulationValue building.climateZone,
        combles := comblesModulationValue building.category,
        surfMoy := surfMoyModulationValue area,
        surfTot := surfTotModulationValue area,
        bruit := bruitModulationValue building.category,
        cat := catModulationValue building.category }

/-- User-provided system assumptions for Maison Pierre 2011. -/
def maisonPierre2011HasActiveCooling : Bool := false

/-- "Photo-heater ECS" modeled as solar-thermal DHW with backup generator. -/
def maisonPierre2011DhwSolarSystem : SolarThermalDHW :=
  { collectorArea := 4.0,
    efficiency := 0.50,
    storageVolume := 250.0,
    backup := (generatorConvention? GeneratorType.ElectricHeating).getD
      { genType := GeneratorType.ElectricHeating,
        nominalEfficiency := 1.0,
        seasonalPerformance := 1.0,
        auxiliaryPower := 20.0,
        primaryEnergyFactor := 2.3 } }

/-- Typical annual solar irradiation for Yonne used for DHW solar estimate. -/
def maisonPierre2011AnnualSolarIrradiation : Float := 1200.0

def detailedEstimateDhwFinalEnergyPerM2 (building : Building) : Float :=
  let area := max 1.0 building.totalReferenceArea
  let endUseProfile := getEndUseProfile building.category
  let scenario := getScenario building.category
  let occupancyMean := max 0.1 (averageHourlyProfile scenario.occupation)
  let dailyNeeds := endUseProfile.dhwDailyNeedPerM2 * occupancyMean * area
  let annualNeeds := dailyNeeds * 365.0
  let solarProvided :=
    calculateSolarThermalDHW maisonPierre2011DhwSolarSystem annualNeeds maisonPierre2011AnnualSolarIrradiation
  let remainingNeeds := max 0.0 (annualNeeds - solarProvided)
  let backupFinal := calculateFinalEnergy remainingNeeds maisonPierre2011DhwSolarSystem.backup
  let annualDhw := backupFinal + endUseProfile.dhwStorageLossesPerM2 * area
  annualDhw / area

def detailedEstimateCoolingFinalEnergyPerM2
    (building : Building)
    (coolingNeedsPerM2 : Float) : Float :=
  if !maisonPierre2011HasActiveCooling then
    0.0
  else
    let coolingGenerator := (generatorConvention? GeneratorType.HeatPumpAirAir).getD
      { genType := GeneratorType.HeatPumpAirAir,
        nominalEfficiency := 3.2,
        seasonalPerformance := 2.8,
        auxiliaryPower := 80.0,
        primaryEnergyFactor := 2.3 }
    let area := max 1.0 building.totalReferenceArea
    calculateCoolingFinalEnergy (coolingNeedsPerM2 * area) coolingGenerator / area

/-- Cep convention selector to compare current RE2020-like pipeline and BBC2005 proxy. -/
inductive CepConvention where
  | CurrentRE2020
  | BBC2005Proxy
  deriving Repr, DecidableEq

def cepPrimaryFactorsForConvention (convention : CepConvention) : List (String × Float) :=
  match convention with
  | .CurrentRE2020 =>
      [ ("heating", primaryEnergyFactorValue "heating"),
        ("dhw", primaryEnergyFactorValue "dhw"),
        ("cooling", primaryEnergyFactorValue "cooling"),
        ("lighting", primaryEnergyFactorValue "lighting"),
        ("auxiliaries", primaryEnergyFactorValue "auxiliaries") ]
  | .BBC2005Proxy =>
      [ ("heating", 1.0),
        ("dhw", 2.58),
        ("cooling", 2.58),
        ("lighting", 2.58),
        ("auxiliaries", 2.58) ]

def cepNonRenewableFactorsForConvention (convention : CepConvention) : List (String × Float) :=
  match convention with
  | .CurrentRE2020 =>
      [ ("heating", nonRenewableEnergyFactorValue "heating"),
        ("dhw", nonRenewableEnergyFactorValue "dhw"),
        ("cooling", nonRenewableEnergyFactorValue "cooling"),
        ("lighting", nonRenewableEnergyFactorValue "lighting"),
        ("auxiliaries", nonRenewableEnergyFactorValue "auxiliaries") ]
  | .BBC2005Proxy =>
      [ ("heating", 1.0),
        ("dhw", 2.58),
        ("cooling", 2.58),
        ("lighting", 2.58),
        ("auxiliaries", 2.58) ]

def applyCepModulationsForConvention (convention : CepConvention) : Bool :=
  match convention with
  | .CurrentRE2020 => true
  | .BBC2005Proxy => false

def computeCepForConvention
    (finalEnergy : List (String × Float))
    (modulations : ModulationCoefficients)
    (convention : CepConvention) : Float :=
  let primaryFactors := cepPrimaryFactorsForConvention convention
  let effectiveModulations :=
    if applyCepModulationsForConvention convention then
      modulations
    else
      { modulations with geo := 0.0, combles := 0.0, surfMoy := 0.0, surfTot := 0.0, cat := 0.0 }
  calculateCep finalEnergy primaryFactors effectiveModulations

def computeCepNrForConvention
    (finalEnergy : List (String × Float))
    (convention : CepConvention) : Float :=
  let nonRenFactors := cepNonRenewableFactorsForConvention convention
  calculateCepNr finalEnergy nonRenFactors

def detailedEstimateAuxiliaryFinalEnergyPerM2 (building : Building) : Float :=
  let area := max 1.0 building.totalReferenceArea
  let endUseProfile := getEndUseProfile building.category
  let scenario := getScenario building.category
  let ventilationMean := max 0.2 (averageHourlyProfile scenario.ventilationRate)
  let operatingHours := endUseProfile.auxiliaryOperatingHours * ventilationMean
  let auxAnnual := calculateAuxiliaryEnergy operatingHours defaultAirWaterHeatPump
  auxAnnual / area

def detailedAnnualOccupancyMask (building : Building) (hours : Nat) : Array Bool :=
  let scenario := getScenario building.category
  (List.range hours).foldl
    (fun acc h =>
      let occ := scenario.occupation[h % 24]!
      acc.push (occ > 0.0))
    #[]

def computeDetailedIndicatorsWithConvention
    (building : Building)
    (climate : ClimateData)
    (convention : CepConvention := .CurrentRE2020) : Indicators :=
  let results := simulateYear building climate
  let refArea := building.totalReferenceArea
  let heatingNeedsPerM2 := if refArea > 0 then results.totalHeatingNeeds / refArea else 0.0
  let coolingNeedsPerM2 := if refArea > 0 then results.totalCoolingNeeds / refArea else 0.0
  let totalLightingNeeds := computeLightingNeeds building
  let lightingNeedsPerM2 := if refArea > 0 then totalLightingNeeds / refArea else 0.0
  let dhwNeedsPerM2 := detailedEstimateDhwFinalEnergyPerM2 building
  let coolingFinalEnergyPerM2 := detailedEstimateCoolingFinalEnergyPerM2 building coolingNeedsPerM2
  let auxiliaryNeedsPerM2 := detailedEstimateAuxiliaryFinalEnergyPerM2 building
  let modulations := detailedDefaultModulations building

  let bbio := calculateBbio heatingNeedsPerM2 coolingNeedsPerM2 lightingNeedsPerM2 modulations
  let finalEnergy :=
    [ ("heating", heatingNeedsPerM2),
      ("dhw", dhwNeedsPerM2),
      ("cooling", coolingFinalEnergyPerM2),
      ("lighting", lightingNeedsPerM2),
      ("auxiliaries", auxiliaryNeedsPerM2) ]
  let cep := computeCepForConvention finalEnergy modulations convention
  let cepNr := computeCepNrForConvention finalEnergy convention

  let occupancyMask := detailedAnnualOccupancyMask building climate.hourlyData.size
  let dh := calculateDHFromCanicule
              results.hourlyIndoorTemps
              (climate.hourlyData.map (·.dryBulbTemp))
              occupancyMask

  { bbio := bbio, cep := cep, cepNr := cepNr, dh := dh }

def computeDetailedIndicators (building : Building) (climate : ClimateData) : Indicators :=
  computeDetailedIndicatorsWithConvention building climate .CurrentRE2020

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

def exampleMaisonPierre2011Detailed : IO Indicators := do
  let climate <- loadClimateDataProductionIO ClimateZone.H1c
  pure (computeDetailedIndicators maisonPierre2011DetailedBuilding climate)

/-- Focused retrofit package to move the detailed model toward BBC-era energy levels. -/
def maisonPierre2011RetrofitBBCBuilding : Building :=
  let base := maisonPierre2011DetailedBuilding
  let retrofittedGroups := base.groups.map (fun g =>
    let retroWalls := g.opaqueWalls.map (fun w =>
      if w.name == "Murs exterieurs hors facade nord" then
        { w with uValue := 0.16 }
      else if w.name == "Mur nord mitoyen garage" then
        { w with uValue := 0.25 }
      else if w.name == "Toiture combles amenages" then
        { w with uValue := 0.10 }
      else if w.name == "Plancher bas" then
        { w with uValue := 0.12 }
      else
        w)
    let retroWindows := g.windows.map (fun win =>
      if win.tilt < 60.0 then
        { win with uValue := 1.0, gValue := 0.40 }
      else
        { win with uValue := 0.8, gValue := 0.47 })
    let retroBridges := g.linearBridges.map (fun b => { b with psi := b.psi * 0.55 })
    { g with
      opaqueWalls := retroWalls,
      windows := retroWindows,
      linearBridges := retroBridges,
      airPermeabilityQ4 := 0.45 })
  { base with
    name := "Maison Pierre BBC2005 2011 (retrofit cible BBC)",
    groups := retrofittedGroups,
    airPermeabilityQ4 := 0.45 }

def exampleMaisonPierre2011RetrofitBBC : IO Indicators := do
  let climate <- loadClimateDataProductionIO ClimateZone.H1c
  pure (computeDetailedIndicators maisonPierre2011RetrofitBBCBuilding climate)

def compareMaisonPierre2011RetrofitBBC : IO Unit := do
  let base <- exampleMaisonPierre2011Detailed
  let retro <- exampleMaisonPierre2011RetrofitBBC
  IO.println s!"Base:     Bbio={base.bbio}, Cep={base.cep}, CepNr={base.cepNr}, DH={base.dh}"
  IO.println s!"Retrofit: Bbio={retro.bbio}, Cep={retro.cep}, CepNr={retro.cepNr}, DH={retro.dh}"
  IO.println s!"Delta:    dBbio={retro.bbio - base.bbio}, dCep={retro.cep - base.cep}, dCepNr={retro.cepNr - base.cepNr}, dDH={retro.dh - base.dh}"

def compareMaisonPierre2011Conventions : IO Unit := do
  let climate <- loadClimateDataProductionIO ClimateZone.H1c
  let baseCurrent := computeDetailedIndicatorsWithConvention maisonPierre2011DetailedBuilding climate .CurrentRE2020
  let baseBbcProxy := computeDetailedIndicatorsWithConvention maisonPierre2011DetailedBuilding climate .BBC2005Proxy
  let retroCurrent := computeDetailedIndicatorsWithConvention maisonPierre2011RetrofitBBCBuilding climate .CurrentRE2020
  let retroBbcProxy := computeDetailedIndicatorsWithConvention maisonPierre2011RetrofitBBCBuilding climate .BBC2005Proxy
  IO.println s!"Base CURRENT_RE2020: Bbio={baseCurrent.bbio}, Cep={baseCurrent.cep}, CepNr={baseCurrent.cepNr}, DH={baseCurrent.dh}"
  IO.println s!"Base BBC2005_PROXY:  Bbio={baseBbcProxy.bbio}, Cep={baseBbcProxy.cep}, CepNr={baseBbcProxy.cepNr}, DH={baseBbcProxy.dh}"
  IO.println s!"Retro CURRENT_RE2020: Bbio={retroCurrent.bbio}, Cep={retroCurrent.cep}, CepNr={retroCurrent.cepNr}, DH={retroCurrent.dh}"
  IO.println s!"Retro BBC2005_PROXY:  Bbio={retroBbcProxy.bbio}, Cep={retroBbcProxy.cep}, CepNr={retroBbcProxy.cepNr}, DH={retroBbcProxy.dh}"

/-- Calibration profile used to reconcile model outputs with a BBC-era certificate target. -/
structure CertificateCalibrationProfile where
  heatingNeedsScale : Float
  dhwNeedsScale : Float
  lightingNeedsScale : Float
  auxiliaryNeedsScale : Float
  electricPrimaryFactor : Float
  applyCepModulations : Bool
  deriving Repr

structure DetailedEnergyComponents where
  heatingNeedsPerM2 : Float
  coolingFinalEnergyPerM2 : Float
  lightingNeedsPerM2 : Float
  dhwFinalEnergyPerM2 : Float
  auxiliaryFinalEnergyPerM2 : Float
  bbio : Float
  dh : Float
  modulations : ModulationCoefficients
  deriving Repr

def computeDetailedEnergyComponents (building : Building) (climate : ClimateData) : DetailedEnergyComponents :=
  let results := simulateYear building climate
  let refArea := building.totalReferenceArea
  let heatingNeedsPerM2 := if refArea > 0 then results.totalHeatingNeeds / refArea else 0.0
  let coolingNeedsPerM2 := if refArea > 0 then results.totalCoolingNeeds / refArea else 0.0
  let totalLightingNeeds := computeLightingNeeds building
  let lightingNeedsPerM2 := if refArea > 0 then totalLightingNeeds / refArea else 0.0
  let dhwFinalEnergyPerM2 := detailedEstimateDhwFinalEnergyPerM2 building
  let coolingFinalEnergyPerM2 := detailedEstimateCoolingFinalEnergyPerM2 building coolingNeedsPerM2
  let auxiliaryFinalEnergyPerM2 := detailedEstimateAuxiliaryFinalEnergyPerM2 building
  let modulations := detailedDefaultModulations building
  let bbio := calculateBbio heatingNeedsPerM2 coolingNeedsPerM2 lightingNeedsPerM2 modulations
  let occupancyMask := detailedAnnualOccupancyMask building climate.hourlyData.size
  let dh := calculateDHFromCanicule
              results.hourlyIndoorTemps
              (climate.hourlyData.map (·.dryBulbTemp))
              occupancyMask
  { heatingNeedsPerM2 := heatingNeedsPerM2,
    coolingFinalEnergyPerM2 := coolingFinalEnergyPerM2,
    lightingNeedsPerM2 := lightingNeedsPerM2,
    dhwFinalEnergyPerM2 := dhwFinalEnergyPerM2,
    auxiliaryFinalEnergyPerM2 := auxiliaryFinalEnergyPerM2,
    bbio := bbio,
    dh := dh,
    modulations := modulations }

def computeIndicatorsFromCalibratedComponents
    (components : DetailedEnergyComponents)
    (profile : CertificateCalibrationProfile) : Indicators :=
  let heating := components.heatingNeedsPerM2 * profile.heatingNeedsScale
  let dhw := components.dhwFinalEnergyPerM2 * profile.dhwNeedsScale
  let cooling := components.coolingFinalEnergyPerM2
  let lighting := components.lightingNeedsPerM2 * profile.lightingNeedsScale
  let auxiliaries := components.auxiliaryFinalEnergyPerM2 * profile.auxiliaryNeedsScale
  let finalEnergy :=
    [ ("heating", heating),
      ("dhw", dhw),
      ("cooling", cooling),
      ("lighting", lighting),
      ("auxiliaries", auxiliaries) ]
  let primaryFactors :=
    [ ("heating", 1.0),
      ("dhw", profile.electricPrimaryFactor),
      ("cooling", profile.electricPrimaryFactor),
      ("lighting", profile.electricPrimaryFactor),
      ("auxiliaries", profile.electricPrimaryFactor) ]
  let nonRenewableFactors := primaryFactors
  let effectiveModulations :=
    if profile.applyCepModulations then
      components.modulations
    else
      { components.modulations with geo := 0.0, combles := 0.0, surfMoy := 0.0, surfTot := 0.0, cat := 0.0 }
  let cep := calculateCep finalEnergy primaryFactors effectiveModulations
  let cepNr := calculateCepNr finalEnergy nonRenewableFactors
  { bbio := components.bbio,
    cep := cep,
    cepNr := cepNr,
    dh := components.dh }

def certificateCalibrationProfiles : List CertificateCalibrationProfile :=
  let heatingScales := [0.65, 0.70, 0.75, 0.80, 0.85, 0.90, 0.95]
  let dhwScales := [0.80, 0.90, 1.00]
  let lightingScales := [0.70, 0.80, 0.90, 1.00]
  let auxiliaryScales := [0.70, 0.80, 0.90, 1.00]
  let electricFactors := [2.30, 2.40, 2.50, 2.58]
  let modulationOptions := [false, true]
  let profilesReversed :=
    heatingScales.foldl (fun acc heatingScale =>
      dhwScales.foldl (fun acc dhwScale =>
        lightingScales.foldl (fun acc lightingScale =>
          auxiliaryScales.foldl (fun acc auxiliaryScale =>
            electricFactors.foldl (fun acc electricFactor =>
              modulationOptions.foldl (fun acc applyModulations =>
                { heatingNeedsScale := heatingScale,
                  dhwNeedsScale := dhwScale,
                  lightingNeedsScale := lightingScale,
                  auxiliaryNeedsScale := auxiliaryScale,
                  electricPrimaryFactor := electricFactor,
                  applyCepModulations := applyModulations } :: acc
              ) acc
            ) acc
          ) acc
        ) acc
      ) acc
    ) []
  profilesReversed.reverse

structure CalibrationResult where
  profile : CertificateCalibrationProfile
  indicators : Indicators
  absoluteError : Float
  deriving Repr

def calibrateComponentsToCepTarget
    (components : DetailedEnergyComponents)
    (targetCep : Float)
    (profiles : List CertificateCalibrationProfile := certificateCalibrationProfiles)
    : Option CalibrationResult :=
  profiles.foldl
    (fun best profile =>
      let indicators := computeIndicatorsFromCalibratedComponents components profile
      let absoluteError := Float.abs (indicators.cep - targetCep)
      let candidate : CalibrationResult :=
        { profile := profile,
          indicators := indicators,
          absoluteError := absoluteError }
      match best with
      | none => some candidate
      | some currentBest =>
          if candidate.absoluteError < currentBest.absoluteError then
            some candidate
          else
            some currentBest)
    none

def calibrateMaisonPierre2011CertificateProfile (targetCep : Float := 85.0) : IO Unit := do
  let climate <- loadClimateDataProductionIO ClimateZone.H1c
  let components := computeDetailedEnergyComponents maisonPierre2011DetailedBuilding climate
  let profilesTested := certificateCalibrationProfiles.length
  match calibrateComponentsToCepTarget components targetCep with
  | none =>
      IO.println "Calibration failed: no candidate profile available."
  | some best =>
      IO.println s!"Calibration target Cep={targetCep}, testedProfiles={profilesTested}"
      IO.println s!"Best calibrated result: Bbio={best.indicators.bbio}, Cep={best.indicators.cep}, CepNr={best.indicators.cepNr}, DH={best.indicators.dh}, absError={best.absoluteError}"
      IO.println s!"Best profile: heatingScale={best.profile.heatingNeedsScale}, dhwScale={best.profile.dhwNeedsScale}, lightingScale={best.profile.lightingNeedsScale}, auxScale={best.profile.auxiliaryNeedsScale}, electricPEF={best.profile.electricPrimaryFactor}, applyCepModulations={best.profile.applyCepModulations}"

def reportMaisonPierre2011CalibrationDossier (targetCep : Float := 85.0) : IO Unit := do
  let climate <- loadClimateDataProductionIO ClimateZone.H1c
  let testedProfiles := certificateCalibrationProfiles.length
  let baseComponents := computeDetailedEnergyComponents maisonPierre2011DetailedBuilding climate
  let retroComponents := computeDetailedEnergyComponents maisonPierre2011RetrofitBBCBuilding climate
  let baseRaw := computeDetailedIndicators maisonPierre2011DetailedBuilding climate
  let retroRaw := computeDetailedIndicators maisonPierre2011RetrofitBBCBuilding climate

  IO.println "=== Maison Pierre 2011 Calibration Dossier ==="
  IO.println s!"Target Cep: {targetCep}"
  IO.println s!"Profiles tested: {testedProfiles}"
  IO.println s!"Raw base:    Cep={baseRaw.cep}, CepNr={baseRaw.cepNr}, Bbio={baseRaw.bbio}, DH={baseRaw.dh}"
  IO.println s!"Raw retrofit: Cep={retroRaw.cep}, CepNr={retroRaw.cepNr}, Bbio={retroRaw.bbio}, DH={retroRaw.dh}"

  match calibrateComponentsToCepTarget baseComponents targetCep with
  | none =>
    IO.println "Calibrated base: no feasible profile found"
  | some bestBase =>
    let p := bestBase.profile
    IO.println s!"Calibrated base: Cep={bestBase.indicators.cep}, CepNr={bestBase.indicators.cepNr}, absError={bestBase.absoluteError}"
    IO.println s!"Base profile: hScale={p.heatingNeedsScale}, dhwScale={p.dhwNeedsScale}, lightScale={p.lightingNeedsScale}, auxScale={p.auxiliaryNeedsScale}, elecPEF={p.electricPrimaryFactor}, modCep={p.applyCepModulations}"

  match calibrateComponentsToCepTarget retroComponents targetCep with
  | none =>
    IO.println "Calibrated retrofit: no feasible profile found"
  | some bestRetro =>
    let p := bestRetro.profile
    IO.println s!"Calibrated retrofit: Cep={bestRetro.indicators.cep}, CepNr={bestRetro.indicators.cepNr}, absError={bestRetro.absoluteError}"
    IO.println s!"Retro profile: hScale={p.heatingNeedsScale}, dhwScale={p.dhwNeedsScale}, lightScale={p.lightingNeedsScale}, auxScale={p.auxiliaryNeedsScale}, elecPEF={p.electricPrimaryFactor}, modCep={p.applyCepModulations}"

end RE2020
