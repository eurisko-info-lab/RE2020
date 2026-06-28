/-
  RE2020.Optimization
  Simplified building description and target-driven adjustment helpers.

  This module adds a light input model for non-CAD users and a discrete
  search routine that suggests changes to reach target indicator values.
-/

import RE2020.Types
import RE2020.Building
import RE2020.Climate
import RE2020.Indicators
import RE2020.Scenarios
import RE2020.Systems
import RE2020.Thermal
import RE2020.RegulationTables

namespace RE2020

/-- Envelope quality level for the simplified building input. -/
inductive EnvelopeQuality where
  | Basic
  | Standard
  | Good
  | VeryGood
  deriving Repr, DecidableEq

/-- Ventilation level for the simplified building input. -/
inductive VentilationQuality where
  | Natural
  | StandardMechanical
  | HeatRecovery
  deriving Repr, DecidableEq

/-- Heating system choice exposed in the simplified input. -/
inductive HeatingChoice where
  | GasBoiler
  | AirWaterHeatPump
  | AirAirHeatPump
  | DistrictHeating
  | ElectricHeating
  deriving Repr, DecidableEq

/-- Indicator targets supported by the discrete search. -/
inductive TargetMetric where
  | Bbio
  | Cep
  | CepNr
  | Dh
  deriving Repr, DecidableEq

/-- Search-space size preset for the discrete optimization loop. -/
inductive SearchProfile where
  | Conservative
  | Standard
  | Aggressive
  deriving Repr, DecidableEq

/-- Lightweight input model for users without CAD geometry. -/
structure SimplifiedBuildingSpec where
  name : String
  category : BuildingCategory
  climateZone : ClimateZone
  floorArea : Float
  floors : Nat := 1
  windowRatio : Float := 0.18
  envelope : EnvelopeQuality := .Standard
  ventilation : VentilationQuality := .StandardMechanical
  heating : HeatingChoice := .AirWaterHeatPump
  shading : Bool := true
  deriving Repr

/-- A target request expressed on one indicator. -/
structure SimplifiedTargetRequest where
  metric : TargetMetric
  targetValue : Float
  deriving Repr

/-- Relative retrofit costs for each adjustable knob. -/
structure RetrofitCostWeights where
  envelope : Float := 3.0
  ventilation : Float := 2.0
  heating : Float := 4.0
  windowRatio : Float := 1.5
  shading : Float := 0.5
  deriving Repr

/-- Detailed evaluation produced from the simplified input. -/
structure SimplifiedEvaluation where
  building : Building
  indicators : Indicators
  heatingFinalEnergy : Float
  coolingFinalEnergy : Float
  dhwFinalEnergy : Float
  auxiliaryFinalEnergy : Float
  deriving Repr

/-- Result of a target search. -/
structure SimplifiedOptimizationResult where
  spec : SimplifiedBuildingSpec
  evaluation : SimplifiedEvaluation
  achieved : Bool
  gap : Float
  changes : Nat
  deriving Repr

structure EnvelopePackage where
  wallU : Float
  roofU : Float
  floorU : Float
  windowU : Float
  windowG : Float
  airPermeabilityQ4 : Float
  shadingFactor : Float
  deriving Repr

def envelopePackage (quality : EnvelopeQuality) : EnvelopePackage :=
  match quality with
  | .Basic =>
      { wallU := 0.35,
        roofU := 0.25,
        floorU := 0.30,
        windowU := 1.8,
        windowG := 0.55,
        airPermeabilityQ4 := 1.2,
        shadingFactor := 1.0 }
  | .Standard =>
      { wallU := 0.22,
        roofU := 0.18,
        floorU := 0.22,
        windowU := 1.3,
        windowG := 0.50,
        airPermeabilityQ4 := 0.8,
        shadingFactor := 0.9 }
  | .Good =>
      { wallU := 0.16,
        roofU := 0.13,
        floorU := 0.16,
        windowU := 1.1,
        windowG := 0.42,
        airPermeabilityQ4 := 0.6,
        shadingFactor := 0.8 }
  | .VeryGood =>
      { wallU := 0.12,
        roofU := 0.10,
        floorU := 0.12,
        windowU := 0.8,
        windowG := 0.35,
        airPermeabilityQ4 := 0.4,
        shadingFactor := 0.7 }

def ventilationRate (quality : VentilationQuality) : Float :=
  match quality with
  | .Natural => 0.75
  | .StandardMechanical => 0.60
  | .HeatRecovery => 0.35

def defaultInternalGains (category : BuildingCategory) : Float :=
  match category with
  | .MaisonIndividuelle => 4.5
  | .LogementCollectif => 4.2
  | .Bureau => 6.0
  | .EnseignementPrimaireSecondaire => 5.4
  | .Autre => 4.8

def simplifiedHeatingGenerator (choice : HeatingChoice) : Generator :=
  match choice with
  | .GasBoiler => defaultGasBoiler
  | .AirWaterHeatPump => defaultAirWaterHeatPump
  | .AirAirHeatPump =>
      (generatorConvention? GeneratorType.HeatPumpAirAir).getD
        { genType := GeneratorType.HeatPumpAirAir,
          nominalEfficiency := 3.2,
          seasonalPerformance := 2.8,
          auxiliaryPower := 80.0,
          primaryEnergyFactor := 2.3 }
  | .DistrictHeating => defaultDistrictHeating
  | .ElectricHeating =>
      (generatorConvention? GeneratorType.ElectricHeating).getD
        { genType := GeneratorType.ElectricHeating,
          nominalEfficiency := 1.0,
          seasonalPerformance := 1.0,
          auxiliaryPower := 20.0,
          primaryEnergyFactor := 2.3 }

def simplifiedCoolingGenerator (choice : HeatingChoice) : Generator :=
  match choice with
  | .AirAirHeatPump => simplifiedHeatingGenerator choice
  | .AirWaterHeatPump => simplifiedHeatingGenerator choice
  | _ => simplifiedHeatingGenerator .AirAirHeatPump

def simplifiedModulations (building : Building) : ModulationCoefficients :=
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

def simpleFootprintArea (spec : SimplifiedBuildingSpec) : Float :=
  max 1.0 (spec.floorArea / max 1.0 (Float.ofNat spec.floors))

def simpleFootprintSides (spec : SimplifiedBuildingSpec) : Float × Float :=
  let footprintArea := simpleFootprintArea spec
  let aspectRatio := 1.25
  let width := Float.sqrt (footprintArea / aspectRatio)
  let length := footprintArea / max 1.0 width
  (width, length)

def simpleBuildingGeometry (spec : SimplifiedBuildingSpec) : Float × Float × Float × Float :=
  let (width, length) := simpleFootprintSides spec
  let height := 2.7 * Float.ofNat spec.floors
  let perimeter := 2.0 * (width + length)
  (width, length, height, perimeter)

def simplifiedBuilding (spec : SimplifiedBuildingSpec) : Building :=
  let env := envelopePackage spec.envelope
  let (_, _, height, perimeter) := simpleBuildingGeometry spec
  let footprintArea := simpleFootprintArea spec
  let wallGrossArea := perimeter * height
  let totalWindowArea := max 0.0 (spec.floorArea * spec.windowRatio)
  let sideWindowArea := totalWindowArea / 4.0
  let sideOpaqueArea := max 0.0 ((wallGrossArea / 4.0) - sideWindowArea)
  let shadingFactor := if spec.shading then env.shadingFactor else 1.0
  let windows : List Window :=
    [ { name := "Sud", area := sideWindowArea, uValue := env.windowU, gValue := env.windowG, frameRatio := 0.25,
        orientation := 0.0, tilt := 90.0, shadingFactor := shadingFactor },
      { name := "Est", area := sideWindowArea, uValue := env.windowU, gValue := env.windowG, frameRatio := 0.25,
        orientation := 90.0, tilt := 90.0, shadingFactor := shadingFactor },
      { name := "Nord", area := sideWindowArea, uValue := env.windowU, gValue := env.windowG, frameRatio := 0.25,
        orientation := 180.0, tilt := 90.0, shadingFactor := shadingFactor },
      { name := "Ouest", area := sideWindowArea, uValue := env.windowU, gValue := env.windowG, frameRatio := 0.25,
        orientation := 270.0, tilt := 90.0, shadingFactor := shadingFactor } ]
  let opaqueWalls : List OpaqueWall :=
    [ { name := "Facade Sud", area := sideOpaqueArea, layers := [], uValue := env.wallU, thermalCapacity := 120000.0, solarAbsorptivity := 0.6 },
      { name := "Facade Est", area := sideOpaqueArea, layers := [], uValue := env.wallU, thermalCapacity := 120000.0, solarAbsorptivity := 0.6 },
      { name := "Facade Nord", area := sideOpaqueArea, layers := [], uValue := env.wallU, thermalCapacity := 120000.0, solarAbsorptivity := 0.6 },
      { name := "Facade Ouest", area := sideOpaqueArea, layers := [], uValue := env.wallU, thermalCapacity := 120000.0, solarAbsorptivity := 0.6 },
      { name := "Toiture", area := footprintArea, layers := [], uValue := env.roofU, thermalCapacity := 80000.0, solarAbsorptivity := 0.7 },
      { name := "Plancher bas", area := footprintArea, layers := [], uValue := env.floorU, thermalCapacity := 100000.0, solarAbsorptivity := 0.5 } ]
  let thermalGroup : ThermalGroup :=
    { name := spec.name,
      volume := spec.floorArea * 2.7,
      referenceArea := spec.floorArea,
      opaqueWalls := opaqueWalls,
      windows := windows,
      linearBridges := [],
      pointBridges := [],
      airPermeabilityQ4 := env.airPermeabilityQ4,
      internalHeatGains := defaultInternalGains spec.category }
  { name := spec.name,
    category := spec.category,
    climateZone := spec.climateZone,
    groups := [thermalGroup],
    totalReferenceArea := spec.floorArea,
    airPermeabilityQ4 := env.airPermeabilityQ4 }

def ventilationProfile (spec : SimplifiedBuildingSpec) (hours : Nat) : Array Float :=
  Array.replicate hours (ventilationRate spec.ventilation)

def metricValue (metric : TargetMetric) (indicators : Indicators) : Float :=
  match metric with
  | .Bbio => indicators.bbio
  | .Cep => indicators.cep
  | .CepNr => indicators.cepNr
  | .Dh => indicators.dh

def targetSatisfied (metric : TargetMetric) (targetValue : Float) (indicators : Indicators) : Bool :=
  metricValue metric indicators <= targetValue

def envelopeRank (q : EnvelopeQuality) : Nat :=
  match q with
  | .Basic => 0
  | .Standard => 1
  | .Good => 2
  | .VeryGood => 3

def ventilationRank (q : VentilationQuality) : Nat :=
  match q with
  | .Natural => 0
  | .StandardMechanical => 1
  | .HeatRecovery => 2

def natDistance (a b : Nat) : Nat :=
  if a >= b then a - b else b - a

def nextBetterEnvelope (q : EnvelopeQuality) : EnvelopeQuality :=
  match q with
  | .Basic => .Standard
  | .Standard => .Good
  | .Good => .VeryGood
  | .VeryGood => .VeryGood

def nextBetterVentilation (q : VentilationQuality) : VentilationQuality :=
  match q with
  | .Natural => .StandardMechanical
  | .StandardMechanical => .HeatRecovery
  | .HeatRecovery => .HeatRecovery

def surroundingWindowRatios (base : Float) : List Float :=
  let x0 := max 0.08 (base - 0.04)
  let x1 := max 0.08 base
  let x2 := min 0.32 (base + 0.04)
  [x0, x1, x2]

def aggressiveWindowRatios : List Float :=
  [0.08, 0.10, 0.12, 0.14, 0.16, 0.18, 0.20, 0.22, 0.24, 0.26, 0.28, 0.30, 0.32]

def retrofitCost (base candidate : SimplifiedBuildingSpec) (weights : RetrofitCostWeights) : Float :=
  let envStep := Float.ofNat (natDistance (envelopeRank base.envelope) (envelopeRank candidate.envelope))
  let ventStep := Float.ofNat (natDistance (ventilationRank base.ventilation) (ventilationRank candidate.ventilation))
  let heatingStep := if base.heating == candidate.heating then 0.0 else 1.0
  let windowStep := Float.abs (base.windowRatio - candidate.windowRatio)
  let shadingStep := if base.shading == candidate.shading then 0.0 else 1.0
  weights.envelope * envStep
    + weights.ventilation * ventStep
    + weights.heating * heatingStep
    + weights.windowRatio * (windowStep / 0.02)
    + weights.shading * shadingStep

def candidateAdjustmentCount (base candidate : SimplifiedBuildingSpec) : Nat :=
  (if base.envelope == candidate.envelope then 0 else 1) +
  (if base.ventilation == candidate.ventilation then 0 else 1) +
  (if base.heating == candidate.heating then 0 else 1) +
  (if base.shading == candidate.shading then 0 else 1) +
  (if Float.abs (base.windowRatio - candidate.windowRatio) < 0.001 then 0 else 1)

def evaluateSimplifiedBuilding (spec : SimplifiedBuildingSpec) (climate : ClimateData) : SimplifiedEvaluation :=
  let building := simplifiedBuilding spec
  let ventProfile := ventilationProfile spec climate.hourlyData.size
  let results := simulateYear building climate (some ventProfile)
  let area := max 1.0 building.totalReferenceArea
  let heatingNeedsPerM2 := if area > 0 then results.totalHeatingNeeds / area else 0.0
  let coolingNeedsPerM2 := if area > 0 then results.totalCoolingNeeds / area else 0.0
  let lightingNeedsPerM2 := computeLightingNeeds building / area

  let scenario := getScenario spec.category
  let endUseProfile := getEndUseProfile spec.category
  let occupancyMean := max 0.1 (averageHourlyProfile scenario.occupation)
  let ventilationMean := max 0.2 (ventilationRate spec.ventilation)
  let dhwDailyNeeds := endUseProfile.dhwDailyNeedPerM2 * occupancyMean * area
  let dhwStorageLosses := endUseProfile.dhwStorageLossesPerM2 * area
  let dhwSystem : DHWSystem :=
    { dailyNeeds := dhwDailyNeeds,
      generator := simplifiedHeatingGenerator spec.heating,
      storageLosses := dhwStorageLosses }

  let heatingGenerator := simplifiedHeatingGenerator spec.heating
  let coolingGenerator := simplifiedCoolingGenerator spec.heating
  let auxiliaryGenerator := simplifiedHeatingGenerator spec.heating

  let heatingFinalEnergy := calculateFinalEnergyWithPartLoad results.totalHeatingNeeds 1800.0 heatingGenerator / area
  let coolingFinalEnergy := calculateCoolingFinalEnergy results.totalCoolingNeeds coolingGenerator / area
  let dhwFinalEnergy := calculateDHWFinalEnergy dhwSystem / area
  let auxiliaryFinalEnergy :=
    calculateAuxiliaryEnergy (endUseProfile.auxiliaryOperatingHours * ventilationMean) auxiliaryGenerator / area

  let modulations := simplifiedModulations building
  let bbio := calculateBbio heatingNeedsPerM2 coolingNeedsPerM2 lightingNeedsPerM2 modulations

  let finalEnergy : List (String × Float) :=
    [ ("heating", heatingFinalEnergy),
      ("dhw", dhwFinalEnergy),
      ("cooling", coolingFinalEnergy),
      ("lighting", lightingNeedsPerM2),
      ("auxiliaries", auxiliaryFinalEnergy) ]
  let primaryFactors := finalEnergy.map (fun (usage, _) => (usage, primaryEnergyFactorValue usage))
  let cep := calculateCep finalEnergy primaryFactors modulations
  let nonRenewFactors := finalEnergy.map (fun (usage, _) => (usage, nonRenewableEnergyFactorValue usage))
  let cepNr := calculateCepNr finalEnergy nonRenewFactors

  let occupancyMask := (List.range climate.hourlyData.size).foldl
    (fun acc h =>
      let occupied := scenario.occupation[h % 24]!
      acc.push (occupied > 0.0))
    #[]
  let dh := calculateDHFromCanicule
              results.hourlyIndoorTemps
              (climate.hourlyData.map (·.dryBulbTemp))
              occupancyMask

  let indicators : Indicators :=
    { bbio := bbio,
      cep := cep,
      cepNr := cepNr,
      dh := dh }

  { building := building,
    indicators := indicators,
    heatingFinalEnergy := heatingFinalEnergy,
    coolingFinalEnergy := coolingFinalEnergy,
    dhwFinalEnergy := dhwFinalEnergy,
    auxiliaryFinalEnergy := auxiliaryFinalEnergy }

def candidateSpecsWithProfile (base : SimplifiedBuildingSpec) (profile : SearchProfile) : List SimplifiedBuildingSpec :=
  let envelopeCandidates : List EnvelopeQuality :=
    match profile with
    | .Conservative => [base.envelope, nextBetterEnvelope base.envelope]
    | .Standard => [.Basic, .Standard, .Good, .VeryGood]
    | .Aggressive => [.Basic, .Standard, .Good, .VeryGood]
  let ventilationCandidates : List VentilationQuality :=
    match profile with
    | .Conservative => [base.ventilation, nextBetterVentilation base.ventilation]
    | .Standard => [.Natural, .StandardMechanical, .HeatRecovery]
    | .Aggressive => [.Natural, .StandardMechanical, .HeatRecovery]
  let heatingCandidates : List HeatingChoice :=
    match profile with
    | .Conservative => [base.heating, .AirWaterHeatPump, .DistrictHeating]
    | .Standard => [.GasBoiler, .AirWaterHeatPump, .AirAirHeatPump, .DistrictHeating, .ElectricHeating]
    | .Aggressive => [.GasBoiler, .AirWaterHeatPump, .AirAirHeatPump, .DistrictHeating, .ElectricHeating]
  let windowCandidates : List Float :=
    match profile with
    | .Conservative => surroundingWindowRatios base.windowRatio
    | .Standard => [0.10, 0.14, 0.18, 0.22, 0.26]
    | .Aggressive => aggressiveWindowRatios
  let shadingCandidates : List Bool :=
    match profile with
    | .Conservative => [base.shading, true]
    | .Standard => [true, false]
    | .Aggressive => [true, false]
  envelopeCandidates.foldl (fun acc envelope =>
    acc ++ ventilationCandidates.foldl (fun acc ventilation =>
      acc ++ heatingCandidates.foldl (fun acc heating =>
        acc ++ windowCandidates.foldl (fun acc windowRatio =>
          acc ++ shadingCandidates.map fun shading =>
            { base with
              envelope := envelope,
              ventilation := ventilation,
              heating := heating,
              windowRatio := windowRatio,
              shading := shading }
        ) []
      ) []
    ) []
  ) []

def candidateSpecs (base : SimplifiedBuildingSpec) : List SimplifiedBuildingSpec :=
  candidateSpecsWithProfile base .Standard

def betterResult (a b : SimplifiedOptimizationResult) : Bool :=
  if a.achieved && !b.achieved then true
  else if !a.achieved && b.achieved then false
  else if a.gap != b.gap then a.gap < b.gap
  else if a.changes != b.changes then a.changes < b.changes
  else a.evaluation.indicators.cep < b.evaluation.indicators.cep

def betterResultMinChanges (a b : SimplifiedOptimizationResult) : Bool :=
  if a.achieved && !b.achieved then true
  else if !a.achieved && b.achieved then false
  else if a.achieved && b.achieved then
    if a.changes != b.changes then a.changes < b.changes
    else if a.gap != b.gap then a.gap < b.gap
    else a.evaluation.indicators.cep < b.evaluation.indicators.cep
  else
    if a.gap != b.gap then a.gap < b.gap
    else if a.changes != b.changes then a.changes < b.changes
    else a.evaluation.indicators.cep < b.evaluation.indicators.cep

def betterResultWeighted
    (base : SimplifiedBuildingSpec)
    (weights : RetrofitCostWeights)
    (a b : SimplifiedOptimizationResult) : Bool :=
  let costA := retrofitCost base a.spec weights
  let costB := retrofitCost base b.spec weights
  if a.achieved && !b.achieved then true
  else if !a.achieved && b.achieved then false
  else if a.achieved && b.achieved then
    if costA != costB then costA < costB
    else if a.changes != b.changes then a.changes < b.changes
    else if a.gap != b.gap then a.gap < b.gap
    else a.evaluation.indicators.cep < b.evaluation.indicators.cep
  else
    if a.gap != b.gap then a.gap < b.gap
    else if costA != costB then costA < costB
    else if a.changes != b.changes then a.changes < b.changes
    else a.evaluation.indicators.cep < b.evaluation.indicators.cep

def bestTargetSuggestion
    (base : SimplifiedBuildingSpec)
    (request : SimplifiedTargetRequest)
    (climate : ClimateData) : Option SimplifiedOptimizationResult :=
  let results := (candidateSpecs base).map fun spec =>
    let evaluation := evaluateSimplifiedBuilding spec climate
    let value := metricValue request.metric evaluation.indicators
    let gap := max 0.0 (value - request.targetValue)
    { spec := spec,
      evaluation := evaluation,
      achieved := targetSatisfied request.metric request.targetValue evaluation.indicators,
      gap := gap,
      changes := candidateAdjustmentCount base spec }
  results.foldl
    (fun best candidate =>
      match best with
      | none => some candidate
      | some current => if betterResult candidate current then some candidate else best)
    none

def bestTargetSuggestionMinChanges
    (base : SimplifiedBuildingSpec)
    (request : SimplifiedTargetRequest)
    (climate : ClimateData) : Option SimplifiedOptimizationResult :=
  let results := (candidateSpecs base).map fun spec =>
    let evaluation := evaluateSimplifiedBuilding spec climate
    let value := metricValue request.metric evaluation.indicators
    let gap := max 0.0 (value - request.targetValue)
    { spec := spec,
      evaluation := evaluation,
      achieved := targetSatisfied request.metric request.targetValue evaluation.indicators,
      gap := gap,
      changes := candidateAdjustmentCount base spec }
  results.foldl
    (fun best candidate =>
      match best with
      | none => some candidate
      | some current => if betterResultMinChanges candidate current then some candidate else best)
    none

def bestTargetSuggestionWeighted
    (base : SimplifiedBuildingSpec)
    (request : SimplifiedTargetRequest)
    (climate : ClimateData)
    (profile : SearchProfile := .Standard)
    (weights : RetrofitCostWeights := {}) : Option SimplifiedOptimizationResult :=
  let results := (candidateSpecsWithProfile base profile).map fun spec =>
    let evaluation := evaluateSimplifiedBuilding spec climate
    let value := metricValue request.metric evaluation.indicators
    let gap := max 0.0 (value - request.targetValue)
    { spec := spec,
      evaluation := evaluation,
      achieved := targetSatisfied request.metric request.targetValue evaluation.indicators,
      gap := gap,
      changes := candidateAdjustmentCount base spec }
  results.foldl
    (fun best candidate =>
      match best with
      | none => some candidate
      | some current => if betterResultWeighted base weights candidate current then some candidate else best)
    none

def describeSimplifiedBuildingSpec (spec : SimplifiedBuildingSpec) : String :=
  s!"{spec.name} | {repr spec.category} | zone {repr spec.climateZone} | {spec.floorArea} m² | floors={spec.floors} | WWR={spec.windowRatio} | envelope={repr spec.envelope} | ventilation={repr spec.ventilation} | heating={repr spec.heating} | shading={spec.shading}"

def describeOptimizationResult (result : SimplifiedOptimizationResult) : String :=
  s!"target-achieved={result.achieved} | gap={result.gap} | changes={result.changes} | Bbio={result.evaluation.indicators.bbio} | Cep={result.evaluation.indicators.cep} | Cep,nr={result.evaluation.indicators.cepNr} | DH={result.evaluation.indicators.dh}"

def suggestTargetIO
    (base : SimplifiedBuildingSpec)
    (request : SimplifiedTargetRequest) : IO (Option SimplifiedOptimizationResult) := do
  let climate <- loadClimateDataProductionIO base.climateZone
  pure (bestTargetSuggestionWeighted base request climate .Standard {})

/-- Example of a simple non-CAD building input. -/
def exampleSimpleHouse : SimplifiedBuildingSpec :=
  { name := "Maison simple sans CAO",
    category := BuildingCategory.MaisonIndividuelle,
    climateZone := ClimateZone.H2c,
    floorArea := 110.0,
    floors := 2,
    windowRatio := 0.18,
    envelope := EnvelopeQuality.Standard,
    ventilation := VentilationQuality.StandardMechanical,
    heating := HeatingChoice.AirWaterHeatPump,
    shading := true }

end RE2020
