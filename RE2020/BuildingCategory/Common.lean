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

/-- Default modulations for the detailed shared building pipeline. -/
def defaultDetailedBuildingModulations (building : Building) : ModulationCoefficients :=
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

/-- Default modulation alias for the detailed shared pipeline. -/
abbrev detailedDefaultModulations := defaultDetailedBuildingModulations

/-- Default assumption without active cooling on the detailed shared pipeline. -/
def defaultDetailedBuildingHasActiveCooling : Bool := false

/-- Shared conventional solar DHW system for the detailed pipeline. -/
def defaultDetailedDhwSolarSystem : SolarThermalDHW :=
  { collectorArea := 4.0,
    efficiency := 0.50,
    storageVolume := 250.0,
    backup := (generatorConvention? GeneratorType.ElectricHeating).getD
      { genType := GeneratorType.ElectricHeating,
        nominalEfficiency := 1.0,
        seasonalPerformance := 1.0,
        auxiliaryPower := 20.0,
        primaryEnergyFactor := 2.3 } }

/-- Shared conventional annual solar irradiation for the detailed pipeline. -/
def defaultDetailedAnnualSolarIrradiation : Float := 1200.0

def detailedEstimateDhwFinalEnergyPerM2 (building : Building) : Float :=
  let area := max 1.0 building.totalReferenceArea
  let endUseProfile := getEndUseProfile building.category
  let scenario := getScenario building.category
  let occupancyMean := max 0.1 (averageHourlyProfile scenario.occupation)
  let dailyNeeds := endUseProfile.dhwDailyNeedPerM2 * occupancyMean * area
  let annualNeeds := dailyNeeds * 365.0
  let solarProvided :=
    calculateSolarThermalDHW defaultDetailedDhwSolarSystem annualNeeds defaultDetailedAnnualSolarIrradiation
  let remainingNeeds := max 0.0 (annualNeeds - solarProvided)
  let backupFinal := calculateFinalEnergy remainingNeeds defaultDetailedDhwSolarSystem.backup
  let annualDhw := backupFinal + endUseProfile.dhwStorageLossesPerM2 * area
  annualDhw / area

def detailedEstimateDhwFinalEnergyPerM2WithHeatPumpBackup
    (building : Building)
    (seasonalPerformance : Float) : Float :=
  let area := max 1.0 building.totalReferenceArea
  let endUseProfile := getEndUseProfile building.category
  let scenario := getScenario building.category
  let occupancyMean := max 0.1 (averageHourlyProfile scenario.occupation)
  let dailyNeeds := endUseProfile.dhwDailyNeedPerM2 * occupancyMean * area
  let annualNeeds := dailyNeeds * 365.0
  let solarProvided :=
    calculateSolarThermalDHW defaultDetailedDhwSolarSystem annualNeeds defaultDetailedAnnualSolarIrradiation
  let remainingNeeds := max 0.0 (annualNeeds - solarProvided)
  let backupFinal := remainingNeeds / max 1.0 seasonalPerformance
  let annualDhw := backupFinal + endUseProfile.dhwStorageLossesPerM2 * area
  annualDhw / area

def detailedEstimateCoolingFinalEnergyPerM2
    (building : Building)
    (coolingNeedsPerM2 : Float) : Float :=
  if !defaultDetailedBuildingHasActiveCooling then
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
  let modulations := defaultDetailedBuildingModulations building

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

structure DetailedEnergyComponents where
  referenceArea : Float
  heatingNeedsPerM2 : Float
  coolingNeedsPerM2 : Float
  coolingFinalEnergyPerM2 : Float
  lightingNeedsPerM2 : Float
  dhwFinalEnergyPerM2 : Float
  auxiliaryFinalEnergyPerM2 : Float
  bbio : Float
  dh : Float
  modulations : ModulationCoefficients
  deriving Repr

def computeDetailedEnergyComponentsWithSetpoints
    (building : Building)
    (climate : ClimateData)
    (setpoints : Setpoints := {}) : DetailedEnergyComponents :=
  let results := simulateYear building climate none setpoints
  let refArea := building.totalReferenceArea
  let heatingNeedsPerM2 := if refArea > 0 then results.totalHeatingNeeds / refArea else 0.0
  let coolingNeedsPerM2 := if refArea > 0 then results.totalCoolingNeeds / refArea else 0.0
  let totalLightingNeeds := computeLightingNeeds building
  let lightingNeedsPerM2 := if refArea > 0 then totalLightingNeeds / refArea else 0.0
  let dhwFinalEnergyPerM2 := detailedEstimateDhwFinalEnergyPerM2 building
  let coolingFinalEnergyPerM2 := detailedEstimateCoolingFinalEnergyPerM2 building coolingNeedsPerM2
  let auxiliaryFinalEnergyPerM2 := detailedEstimateAuxiliaryFinalEnergyPerM2 building
  let modulations := defaultDetailedBuildingModulations building
  let bbio := calculateBbio heatingNeedsPerM2 coolingNeedsPerM2 lightingNeedsPerM2 modulations
  let occupancyMask := detailedAnnualOccupancyMask building climate.hourlyData.size
  let dh := calculateDHFromCanicule
              results.hourlyIndoorTemps
              (climate.hourlyData.map (·.dryBulbTemp))
              occupancyMask
  { referenceArea := refArea,
    heatingNeedsPerM2 := heatingNeedsPerM2,
    coolingNeedsPerM2 := coolingNeedsPerM2,
    coolingFinalEnergyPerM2 := coolingFinalEnergyPerM2,
    lightingNeedsPerM2 := lightingNeedsPerM2,
    dhwFinalEnergyPerM2 := dhwFinalEnergyPerM2,
    auxiliaryFinalEnergyPerM2 := auxiliaryFinalEnergyPerM2,
    bbio := bbio,
    dh := dh,
    modulations := modulations }

def computeDetailedEnergyComponentsWithHourlySetpoints
    (building : Building)
    (climate : ClimateData)
    (setpointsAtHour : Nat → Setpoints)
    (ventRateAtHour : Nat → Float := fun _ => 0.6) : DetailedEnergyComponents :=
  let hours := climate.hourlyData.size
  let firstSetpoints := setpointsAtHour 0
  let initialTemps := building.groups.map (fun _ => firstSetpoints.heatingSetpoint)
  let initialState :=
    (initialTemps, initialTemps, #[], #[], #[], 0.0, 0.0)

  let (_, _, indoorArr, heatingArr, coolingArr, totalHeating, totalCooling) :=
    (List.range hours).foldl
      (fun (st : List Float × List Float × Array Float × Array Float × Array Float × Float × Float) i =>
        let (airTemps, massTemps, indoorAcc, heatingAcc, coolingAcc, heatSum, coolSum) := st
        let climateHour := climate.hourlyData[i]!
        let dayOfYear := (i / 24) + 1
        let hourOfDay := i % 24
        let setpoints := setpointsAtHour i
        let ventRate := ventRateAtHour i
        let (newAir, newMass, heatingPowerW, coolingPowerW, weightedIndoor, areaSum) :=
          simulateBuildingHour building.groups airTemps massTemps climateHour dayOfYear hourOfDay setpoints ventRate
        let avgIndoor := if areaSum > 0 then weightedIndoor / areaSum else setpoints.heatingSetpoint
        let heatingKWh := heatingPowerW / 1000.0
        let coolingKWh := coolingPowerW / 1000.0
        ( newAir,
          newMass,
          indoorAcc.push avgIndoor,
          heatingAcc.push heatingKWh,
          coolingAcc.push coolingKWh,
          heatSum + heatingKWh,
          coolSum + coolingKWh ))
      initialState

  let results : SimulationResults :=
    { hourlyIndoorTemps := indoorArr,
      hourlyHeatingNeeds := heatingArr,
      hourlyCoolingNeeds := coolingArr,
      totalHeatingNeeds := totalHeating,
      totalCoolingNeeds := totalCooling }
  let refArea := building.totalReferenceArea
  let heatingNeedsPerM2 := if refArea > 0 then results.totalHeatingNeeds / refArea else 0.0
  let coolingNeedsPerM2 := if refArea > 0 then results.totalCoolingNeeds / refArea else 0.0
  let totalLightingNeeds := computeLightingNeeds building
  let lightingNeedsPerM2 := if refArea > 0 then totalLightingNeeds / refArea else 0.0
  let dhwFinalEnergyPerM2 := detailedEstimateDhwFinalEnergyPerM2 building
  let coolingFinalEnergyPerM2 := detailedEstimateCoolingFinalEnergyPerM2 building coolingNeedsPerM2
  let auxiliaryFinalEnergyPerM2 := detailedEstimateAuxiliaryFinalEnergyPerM2 building
  let modulations := defaultDetailedBuildingModulations building
  let bbio := calculateBbio heatingNeedsPerM2 coolingNeedsPerM2 lightingNeedsPerM2 modulations
  let occupancyMask := detailedAnnualOccupancyMask building climate.hourlyData.size
  let dh := calculateDHFromCanicule
              results.hourlyIndoorTemps
              (climate.hourlyData.map (·.dryBulbTemp))
              occupancyMask
  { referenceArea := refArea,
    heatingNeedsPerM2 := heatingNeedsPerM2,
    coolingNeedsPerM2 := coolingNeedsPerM2,
    coolingFinalEnergyPerM2 := coolingFinalEnergyPerM2,
    lightingNeedsPerM2 := lightingNeedsPerM2,
    dhwFinalEnergyPerM2 := dhwFinalEnergyPerM2,
    auxiliaryFinalEnergyPerM2 := auxiliaryFinalEnergyPerM2,
    bbio := bbio,
    dh := dh,
    modulations := modulations }

def computeDetailedEnergyComponents (building : Building) (climate : ClimateData) : DetailedEnergyComponents :=
  computeDetailedEnergyComponentsWithSetpoints building climate {}

/-- Calibration profile used to reconcile model outputs with an external target. -/
structure CertificateCalibrationProfile where
  heatingNeedsScale : Float
  dhwNeedsScale : Float
  lightingNeedsScale : Float
  auxiliaryNeedsScale : Float
  electricPrimaryFactor : Float
  applyCepModulations : Bool
  deriving Repr

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

def climateKgCO2FromDetailedComponents
    (components : DetailedEnergyComponents)
    (heatingCO2Factor : Float := 0.227)
    (electricCO2Factor : Float := 0.079) : Float :=
  let heating := components.heatingNeedsPerM2
  let electricUses :=
    components.dhwFinalEnergyPerM2 +
    components.coolingFinalEnergyPerM2 +
    components.lightingNeedsPerM2 +
    components.auxiliaryFinalEnergyPerM2
  heating * heatingCO2Factor + electricUses * electricCO2Factor

def climateKgCO2FromCalibratedComponents
    (components : DetailedEnergyComponents)
    (profile : CertificateCalibrationProfile)
    (heatingCO2Factor : Float := 0.227)
    (electricCO2Factor : Float := 0.079) : Float :=
  let heating := components.heatingNeedsPerM2 * profile.heatingNeedsScale
  let dhw := components.dhwFinalEnergyPerM2 * profile.dhwNeedsScale
  let cooling := components.coolingFinalEnergyPerM2
  let lighting := components.lightingNeedsPerM2 * profile.lightingNeedsScale
  let auxiliaries := components.auxiliaryFinalEnergyPerM2 * profile.auxiliaryNeedsScale
  let electricUses := dhw + cooling + lighting + auxiliaries
  heating * heatingCO2Factor + electricUses * electricCO2Factor

inductive EnergyClimateClass where
  | A | B | C | D | E | F | G
  deriving Repr, DecidableEq

def energyClimateClassRank (c : EnergyClimateClass) : Nat :=
  match c with
  | .A => 1
  | .B => 2
  | .C => 3
  | .D => 4
  | .E => 5
  | .F => 6
  | .G => 7

def energyClimateClassLabel (c : EnergyClimateClass) : String :=
  match c with
  | .A => "A"
  | .B => "B"
  | .C => "C"
  | .D => "D"
  | .E => "E"
  | .F => "F"
  | .G => "G"

def energyClassFromCep (cep : Float) : EnergyClimateClass :=
  if cep <= 70.0 then .A
  else if cep <= 110.0 then .B
  else if cep <= 180.0 then .C
  else if cep <= 250.0 then .D
  else if cep <= 330.0 then .E
  else if cep <= 420.0 then .F
  else .G

def climateClassFromKgCO2 (kgCO2 : Float) : EnergyClimateClass :=
  if kgCO2 <= 6.0 then .A
  else if kgCO2 <= 11.0 then .B
  else if kgCO2 <= 30.0 then .C
  else if kgCO2 <= 50.0 then .D
  else if kgCO2 <= 70.0 then .E
  else if kgCO2 <= 100.0 then .F
  else .G

def typicalStatusFromClass (c : EnergyClimateClass) : String :=
  match c with
  | .A => "Tres performant (BBC, RT 2012, RE 2020)"
  | .B => "Performant (renovation poussee, neuf RT 2005)"
  | .C => "Moyen (logements renoves, chauffage gaz recent)"
  | .D => "Mediocre - moyenne du parc francais"
  | .E => "Insuffisant - audit obligatoire a la vente"
  | .F => "Passoire thermique - interdiction location en 2028"
  | .G => "Passoire thermique - interdiction location en 2025"

def worstEnergyClimateClass (energyClass climateClass : EnergyClimateClass) : EnergyClimateClass :=
  if energyClimateClassRank energyClass >= energyClimateClassRank climateClass then
    energyClass
  else
    climateClass

structure DpeLikeIndicators where
  energyKWhEPm2 : Float
  climateKgCO2m2 : Float
  energyClass : EnergyClimateClass
  climateClass : EnergyClimateClass
  overallClass : EnergyClimateClass
  typicalStatus : String
  deriving Repr

def mkDpeLikeIndicators (energyKWhEPm2 climateKgCO2m2 : Float) : DpeLikeIndicators :=
  let eClass := energyClassFromCep energyKWhEPm2
  let cClass := climateClassFromKgCO2 climateKgCO2m2
  let overall := worstEnergyClimateClass eClass cClass
  { energyKWhEPm2 := energyKWhEPm2,
    climateKgCO2m2 := climateKgCO2m2,
    energyClass := eClass,
    climateClass := cClass,
    overallClass := overall,
    typicalStatus := typicalStatusFromClass overall }

/-- Package systeme partage pour les comparaisons d'equipements. -/
structure ResilienceSystemsPackage where
  hasActiveCooling : Bool
  hasDoubleFluxVentilation : Bool
  acHeatingSeasonalPerformance : Float
  coolingSeasonalPerformance : Float
  summerNightNaturalCoolingMaxGain : Float
  summerNightStartHour : Nat
  summerNightEndHour : Nat
  summerNightStartDay : Nat
  summerNightEndDay : Nat
  nightVentOutdoorMaxTemp : Float
  coolingCapacityCoverage : Float
  coolingAvailabilityRatio : Float
  coolingBatteryDependency : Float
  dhPerUnmetCoolingKWh : Float
  doubleFluxHeatingNeedsGain : Float
  doubleFluxAuxMultiplier : Float
  woodCoolestDays : Nat
  pvBatteryUsableElectricityPerM2 : Float
  pvHeatingAllocationShare : Float
  comfortHeatingSetpoint : Float
  comfortCoolingSetpoint : Float
  daytimeComfortHeatingSetpoint : Float
  daytimeComfortCoolingSetpoint : Float
  daytimeStartHour : Nat
  daytimeEndHour : Nat
  dhwHeatPumpSeasonalPerformance : Float
  woodPrimaryFactor : Float
  woodNonRenewableFactor : Float
  electricCO2Factor : Float
  woodCO2Factor : Float
  deriving Repr

def defaultResilienceSystemsPackage : ResilienceSystemsPackage :=
  { hasActiveCooling := true,
    hasDoubleFluxVentilation := true,
    acHeatingSeasonalPerformance := 4.4,
    coolingSeasonalPerformance := 4.2,
    summerNightNaturalCoolingMaxGain := 0.45,
    summerNightStartHour := 21,
    summerNightEndHour := 7,
    summerNightStartDay := 152,
    summerNightEndDay := 273,
    nightVentOutdoorMaxTemp := 22.0,
    coolingCapacityCoverage := 0.95,
    coolingAvailabilityRatio := 0.97,
    coolingBatteryDependency := 0.20,
    dhPerUnmetCoolingKWh := 9.0,
    doubleFluxHeatingNeedsGain := 0.22,
    doubleFluxAuxMultiplier := 1.20,
    woodCoolestDays := 20,
    pvBatteryUsableElectricityPerM2 := 42.0,
    pvHeatingAllocationShare := 0.35,
    comfortHeatingSetpoint := 22.0,
    comfortCoolingSetpoint := 23.0,
    daytimeComfortHeatingSetpoint := 22.0,
    daytimeComfortCoolingSetpoint := 23.0,
    daytimeStartHour := 8,
    daytimeEndHour := 22,
    dhwHeatPumpSeasonalPerformance := 3.6,
    woodPrimaryFactor := 0.60,
    woodNonRenewableFactor := 0.10,
    electricCO2Factor := 0.079,
    woodCO2Factor := 0.030 }

def electricFactorForConvention (convention : CepConvention) : Float :=
  match convention with
  | .CurrentRE2020 => primaryEnergyFactorValue "dhw"
  | .BBC2005Proxy => 2.58

def insertDesc (x : Float) (xs : List Float) : List Float :=
  match xs with
  | [] => [x]
  | y :: ys =>
      if x >= y then
        x :: xs
      else
        y :: insertDesc x ys

def sortDesc (xs : List Float) : List Float :=
  xs.foldl (fun acc x => insertDesc x acc) []

def topNSum (n : Nat) (xs : List Float) : Float :=
  (sortDesc xs).take n |>.foldl (· + ·) 0.0

def dailyHeatingDemandProxyFromTemps (temps : List Float) : List Float :=
  let rec go (remaining : List Float) (hourInDay : Nat) (dayDemand : Float) (daysRev : List Float) : List Float :=
    match remaining with
    | [] =>
        if hourInDay = 0 then
          daysRev.reverse
        else
          (dayDemand :: daysRev).reverse
    | t :: ts =>
        let hourlyDemand := max 0.0 (18.0 - t)
        let nextDemand := dayDemand + hourlyDemand
        if hourInDay = 23 then
          go ts 0 0.0 (nextDemand :: daysRev)
        else
          go ts (hourInDay + 1) nextDemand daysRev
  go temps 0 0.0 []

def heatingShareFromCoolestDays (climate : ClimateData) (coolestDays : Nat := 20) : Float :=
  let temps := climate.hourlyData.toList.map (·.dryBulbTemp)
  let dailyDemand := dailyHeatingDemandProxyFromTemps temps
  let totalDemand := dailyDemand.foldl (· + ·) 0.0
  if totalDemand > 0 then
    topNSum coolestDays dailyDemand / totalDemand
  else
    0.0

def isSummerNightHour (h : HourlyClimate) (systems : ResilienceSystemsPackage) : Bool :=
  let dayOfYear := (h.hour / 24) + 1
  let hourOfDay := h.hour % 24
  let inSummer := systems.summerNightStartDay <= dayOfYear && dayOfYear <= systems.summerNightEndDay
  let inNight := hourOfDay >= systems.summerNightStartHour || hourOfDay <= systems.summerNightEndHour
  inSummer && inNight

def summerNightNaturalCoolingAvailability (climate : ClimateData) (systems : ResilienceSystemsPackage) : Float :=
  let hours := climate.hourlyData.toList
  let summerNightHours := hours.filter (fun h => isSummerNightHour h systems)
  let totalSummerNightHours := summerNightHours.length
  if totalSummerNightHours = 0 then
    0.0
  else
    let favorableHours :=
      summerNightHours.filter (fun h => h.dryBulbTemp <= systems.nightVentOutdoorMaxTemp)
    Float.ofNat favorableHours.length / Float.ofNat totalSummerNightHours

/-- Delta between two indicator evaluations. -/
structure IndicatorDelta where
  bbio : Float
  cep : Float
  cepNr : Float
  dh : Float
  deriving Repr

/-- Before/after comparison for adding reversible A/C to any building. -/
structure ReversibleAcIndicatorComparison where
  withoutAc : Indicators
  withAc : Indicators
  delta : IndicatorDelta
  deriving Repr

def computeIndicatorDelta (before after : Indicators) : IndicatorDelta :=
  { bbio := after.bbio - before.bbio,
    cep := after.cep - before.cep,
    cepNr := after.cepNr - before.cepNr,
    dh := after.dh - before.dh }

/-- Turns off active cooling while preserving the rest of the reversible-system assumptions. -/
def disableActiveCooling (systems : ResilienceSystemsPackage) : ResilienceSystemsPackage :=
  { systems with hasActiveCooling := false }

def computeIndicatorsWithResilienceSystems
    (building : Building)
    (climate : ClimateData)
    (systems : ResilienceSystemsPackage := defaultResilienceSystemsPackage)
    (convention : CepConvention := .CurrentRE2020) : Indicators :=
  let setpointsAtHour := fun (i : Nat) =>
    let hourOfDay := i % 24
    if systems.daytimeStartHour <= hourOfDay && hourOfDay <= systems.daytimeEndHour then
      { heatingSetpoint := systems.daytimeComfortHeatingSetpoint,
        coolingSetpoint := systems.daytimeComfortCoolingSetpoint }
    else
      { heatingSetpoint := systems.comfortHeatingSetpoint,
        coolingSetpoint := systems.comfortCoolingSetpoint }
  let components := computeDetailedEnergyComponentsWithHourlySetpoints building climate setpointsAtHour
  let electricFactor := electricFactorForConvention convention

  let heatingNeedsPerM2 :=
    if systems.hasDoubleFluxVentilation then
      components.heatingNeedsPerM2 * (1.0 - systems.doubleFluxHeatingNeedsGain)
    else
      components.heatingNeedsPerM2
  let coolingNeedsPerM2 := components.coolingNeedsPerM2
  let naturalCoolingAvailability := summerNightNaturalCoolingAvailability climate systems
  let naturalCoolingServed :=
    coolingNeedsPerM2 * systems.summerNightNaturalCoolingMaxGain * naturalCoolingAvailability
  let coolingNeedsAfterNatural := max 0.0 (coolingNeedsPerM2 - naturalCoolingServed)
  let coolingServedBeforeBattery :=
    if systems.hasActiveCooling then
      coolingNeedsAfterNatural * systems.coolingCapacityCoverage * systems.coolingAvailabilityRatio
    else
      0.0
  let dhwFinalEnergyPerM2 :=
    detailedEstimateDhwFinalEnergyPerM2WithHeatPumpBackup building systems.dhwHeatPumpSeasonalPerformance
  let lightingNeedsPerM2 := components.lightingNeedsPerM2
  let auxiliaryNeedsPerM2 :=
    if systems.hasDoubleFluxVentilation then
      components.auxiliaryFinalEnergyPerM2 * systems.doubleFluxAuxMultiplier
    else
      components.auxiliaryFinalEnergyPerM2

  let woodHeatingShare := heatingShareFromCoolestDays climate systems.woodCoolestDays
  let woodHeatingPerM2 := heatingNeedsPerM2 * woodHeatingShare
  let electricHeatingNeedsPerM2 := heatingNeedsPerM2 - woodHeatingPerM2
  let electricHeatingFinalBeforePv :=
    if systems.hasActiveCooling then
      electricHeatingNeedsPerM2 / max 1.0 systems.acHeatingSeasonalPerformance
    else
      electricHeatingNeedsPerM2

  let coolingFinalBeforeBattery :=
    if systems.hasActiveCooling then
      coolingServedBeforeBattery / max 1.0 systems.coolingSeasonalPerformance
    else
      0.0

  let nonHeatingElectricUses :=
    dhwFinalEnergyPerM2 + coolingFinalBeforeBattery + lightingNeedsPerM2 + auxiliaryNeedsPerM2
  let pvToNonHeating := min nonHeatingElectricUses systems.pvBatteryUsableElectricityPerM2
  let nonHeatingRemaining := max 0.0 (nonHeatingElectricUses - pvToNonHeating)
  let remainingPvAfterNonHeating := max 0.0 (systems.pvBatteryUsableElectricityPerM2 - pvToNonHeating)
  let pvToHeating := min electricHeatingFinalBeforePv (remainingPvAfterNonHeating * systems.pvHeatingAllocationShare)
  let electricHeatingNet := max 0.0 (electricHeatingFinalBeforePv - pvToHeating)
  let nonHeatingRemainingRatio :=
    if nonHeatingElectricUses > 0 then
      nonHeatingRemaining / nonHeatingElectricUses
    else
      1.0

  let pvCoverageRatio :=
    if nonHeatingElectricUses > 0 then
      pvToNonHeating / nonHeatingElectricUses
    else
      1.0
  let coolingBatteryFactor :=
    1.0 - systems.coolingBatteryDependency * (1.0 - pvCoverageRatio)
  let coolingServedAfterBattery := coolingServedBeforeBattery * max 0.0 coolingBatteryFactor
  let coolingUnmet := max 0.0 (coolingNeedsAfterNatural - coolingServedAfterBattery)
  let coolingFinalEnergyPerM2 :=
    if systems.hasActiveCooling then
      coolingServedAfterBattery / max 1.0 systems.coolingSeasonalPerformance
    else
      0.0

  let dhwNet := dhwFinalEnergyPerM2 * nonHeatingRemainingRatio
  let coolingNet := coolingFinalEnergyPerM2 * nonHeatingRemainingRatio
  let lightingNet := lightingNeedsPerM2 * nonHeatingRemainingRatio
  let auxiliariesNet := auxiliaryNeedsPerM2 * nonHeatingRemainingRatio

  let finalEnergy :=
    [ ("wood_heating", woodHeatingPerM2),
      ("electric_heating", electricHeatingNet),
      ("dhw", dhwNet),
      ("cooling", coolingNet),
      ("lighting", lightingNet),
      ("auxiliaries", auxiliariesNet) ]

  let primaryFactors :=
    [ ("wood_heating", systems.woodPrimaryFactor),
      ("electric_heating", electricFactor),
      ("dhw", electricFactor),
      ("cooling", electricFactor),
      ("lighting", electricFactor),
      ("auxiliaries", electricFactor) ]
  let nonRenewableFactors :=
    [ ("wood_heating", systems.woodNonRenewableFactor),
      ("electric_heating", electricFactor),
      ("dhw", electricFactor),
      ("cooling", electricFactor),
      ("lighting", electricFactor),
      ("auxiliaries", electricFactor) ]
  let effectiveModulations :=
    if applyCepModulationsForConvention convention then
      components.modulations
    else
      { components.modulations with geo := 0.0, combles := 0.0, surfMoy := 0.0, surfTot := 0.0, cat := 0.0 }

  let bbio := calculateBbio heatingNeedsPerM2 coolingNeedsPerM2 components.lightingNeedsPerM2 components.modulations
  let cep := calculateCep finalEnergy primaryFactors effectiveModulations
  let cepNr := calculateCepNr finalEnergy nonRenewableFactors
  let dhLimitedAc := components.dh + coolingUnmet * systems.dhPerUnmetCoolingKWh

  { bbio := bbio,
    cep := cep,
    cepNr := cepNr,
    dh := dhLimitedAc }

def resilienceClimateKgCO2
    (building : Building)
    (climate : ClimateData)
    (systems : ResilienceSystemsPackage := defaultResilienceSystemsPackage) : Float :=
  let setpointsAtHour := fun (i : Nat) =>
    let hourOfDay := i % 24
    if systems.daytimeStartHour <= hourOfDay && hourOfDay <= systems.daytimeEndHour then
      { heatingSetpoint := systems.daytimeComfortHeatingSetpoint,
        coolingSetpoint := systems.daytimeComfortCoolingSetpoint }
    else
      { heatingSetpoint := systems.comfortHeatingSetpoint,
        coolingSetpoint := systems.comfortCoolingSetpoint }
  let components := computeDetailedEnergyComponentsWithHourlySetpoints building climate setpointsAtHour
  let heatingNeedsPerM2 :=
    if systems.hasDoubleFluxVentilation then
      components.heatingNeedsPerM2 * (1.0 - systems.doubleFluxHeatingNeedsGain)
    else
      components.heatingNeedsPerM2
  let coolingNeedsPerM2 := components.coolingNeedsPerM2
  let naturalCoolingAvailability := summerNightNaturalCoolingAvailability climate systems
  let naturalCoolingServed :=
    coolingNeedsPerM2 * systems.summerNightNaturalCoolingMaxGain * naturalCoolingAvailability
  let coolingNeedsAfterNatural := max 0.0 (coolingNeedsPerM2 - naturalCoolingServed)
  let coolingServedBeforeBattery :=
    if systems.hasActiveCooling then
      coolingNeedsAfterNatural * systems.coolingCapacityCoverage * systems.coolingAvailabilityRatio
    else
      0.0
  let dhwFinalEnergyPerM2 :=
    detailedEstimateDhwFinalEnergyPerM2WithHeatPumpBackup building systems.dhwHeatPumpSeasonalPerformance
  let coolingFinalBeforeBattery :=
    if systems.hasActiveCooling then
      coolingServedBeforeBattery / max 1.0 systems.coolingSeasonalPerformance
    else
      0.0
  let auxiliaryNeedsPerM2 :=
    if systems.hasDoubleFluxVentilation then
      components.auxiliaryFinalEnergyPerM2 * systems.doubleFluxAuxMultiplier
    else
      components.auxiliaryFinalEnergyPerM2
  let woodHeatingShare := heatingShareFromCoolestDays climate systems.woodCoolestDays
  let woodHeatingPerM2 := heatingNeedsPerM2 * woodHeatingShare
  let electricHeatingNeedsPerM2 := heatingNeedsPerM2 - woodHeatingPerM2
  let electricHeatingFinalBeforePv :=
    if systems.hasActiveCooling then
      electricHeatingNeedsPerM2 / max 1.0 systems.acHeatingSeasonalPerformance
    else
      electricHeatingNeedsPerM2
  let nonHeatingElectricUses :=
    dhwFinalEnergyPerM2 + coolingFinalBeforeBattery + components.lightingNeedsPerM2 + auxiliaryNeedsPerM2
  let pvToNonHeating := min nonHeatingElectricUses systems.pvBatteryUsableElectricityPerM2
  let nonHeatingRemaining := max 0.0 (nonHeatingElectricUses - pvToNonHeating)
  let remainingPvAfterNonHeating := max 0.0 (systems.pvBatteryUsableElectricityPerM2 - pvToNonHeating)
  let pvToHeating := min electricHeatingFinalBeforePv (remainingPvAfterNonHeating * systems.pvHeatingAllocationShare)
  let electricHeatingNet := max 0.0 (electricHeatingFinalBeforePv - pvToHeating)
  let nonHeatingRemainingRatio := if nonHeatingElectricUses > 0 then nonHeatingRemaining / nonHeatingElectricUses else 1.0
  let electricNonHeatingNet := nonHeatingElectricUses * nonHeatingRemainingRatio
  woodHeatingPerM2 * systems.woodCO2Factor + (electricHeatingNet + electricNonHeatingNet) * systems.electricCO2Factor

/-- Compare indicators for the same house without and with reversible A/C. -/
def compareIndicatorsWithoutVsWithReversibleAc
    (building : Building)
    (climate : ClimateData)
    (systemsWithAc : ResilienceSystemsPackage := defaultResilienceSystemsPackage)
    (convention : CepConvention := .CurrentRE2020) : ReversibleAcIndicatorComparison :=
  let withoutAc :=
    computeIndicatorsWithResilienceSystems building climate (disableActiveCooling systemsWithAc) convention
  let withAc :=
    computeIndicatorsWithResilienceSystems building climate systemsWithAc convention
  { withoutAc := withoutAc,
    withAc := withAc,
    delta := computeIndicatorDelta withoutAc withAc }

end RE2020
