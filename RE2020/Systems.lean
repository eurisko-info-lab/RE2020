/-
  RE2020.Systems
  Modélisation des systèmes énergétiques (générateurs)
  selon les règles de la méthode Th-BCE 2020.

  Ce module permet de calculer la consommation finale d'énergie
  à partir des besoins thermiques, en tenant compte des rendements
  et performances des générateurs (chaudières, PAC, etc.).
-/

import RE2020.Types

namespace RE2020

/-- Types de générateurs supportés -/
inductive GeneratorType where
  | GasBoilerCondensing
  | OilBoiler
  | WoodBoiler
  | HeatPumpAirAir
  | HeatPumpAirWater
  | HeatPumpWaterWater
  | DistrictHeating
  | ElectricHeating
  deriving Repr, DecidableEq

/-- Paramètres d'un générateur -/
structure Generator where
  genType            : GeneratorType
  nominalEfficiency  : Float     -- Rendement nominal (0..1) ou COP nominal
  seasonalPerformance : Float    -- SCOP / SPF / rendement saisonnier
  auxiliaryPower     : Float     -- Puissance auxiliaires (W)
  primaryEnergyFactor : Float    -- Facteur d'énergie primaire (par défaut)
  deriving Repr

/-- Générateurs par défaut conformes aux conventions RE2020 -/
def defaultGasBoiler : Generator :=
  { genType := GeneratorType.GasBoilerCondensing,
    nominalEfficiency := 0.92,
    seasonalPerformance := 0.90,
    auxiliaryPower := 50.0,
    primaryEnergyFactor := 1.0 }

def defaultAirWaterHeatPump : Generator :=
  { genType := GeneratorType.HeatPumpAirWater,
    nominalEfficiency := 3.5,      -- COP nominal
    seasonalPerformance := 3.0,    -- SCOP moyen
    auxiliaryPower := 100.0,
    primaryEnergyFactor := 2.3 }   -- électricité

def defaultDistrictHeating : Generator :=
  { genType := GeneratorType.DistrictHeating,
    nominalEfficiency := 0.95,
    seasonalPerformance := 0.90,
    auxiliaryPower := 30.0,
    primaryEnergyFactor := 1.0 }

/-- Calcule la consommation finale d'énergie pour un besoin thermique donné -/
def calculateFinalEnergy (thermalNeeds : Float) (generator : Generator) : Float :=
  if generator.seasonalPerformance > 0 then
    thermalNeeds / generator.seasonalPerformance
  else
    thermalNeeds / generator.nominalEfficiency

/-- Consommation auxiliaires (simplifiée) -/
def calculateAuxiliaryEnergy (operatingHours : Float) (generator : Generator) : Float :=
  generator.auxiliaryPower * operatingHours / 1000.0   -- kWh

/-- Consommation totale finale (générateur + auxiliaires) -/
def calculateTotalFinalEnergy
    (thermalNeeds : Float)
    (operatingHours : Float)
    (generator : Generator) : Float :=
  let generatorConsumption := calculateFinalEnergy thermalNeeds generator
  let auxConsumption := calculateAuxiliaryEnergy operatingHours generator
  generatorConsumption + auxConsumption

/-- Conversion en énergie primaire -/
def toPrimaryEnergy (finalEnergy : Float) (generator : Generator) : Float :=
  finalEnergy * generator.primaryEnergyFactor

/-- Modélisation simplifiée du rendement à charge partielle
    (modèle linéaire simple - peut être enrichi) -/
def partLoadEfficiency (loadRatio : Float) (generator : Generator) : Float :=
  let base := generator.seasonalPerformance
  if generator.genType == GeneratorType.HeatPumpAirWater ||
     generator.genType == GeneratorType.HeatPumpAirAir then
    -- Les PAC perdent généralement en efficacité à faible charge
    base * (0.7 + 0.3 * loadRatio)
  else
    -- Chaudières : souvent meilleur rendement à charge partielle (condensation)
    base * (0.85 + 0.15 * loadRatio)

/-- Calcul de la consommation finale avec prise en compte de la charge partielle -/
def calculateFinalEnergyWithPartLoad
    (thermalNeeds : Float)
    (fullLoadHours : Float)
    (generator : Generator) : Float :=
  let avgLoadRatio := if fullLoadHours > 0 then thermalNeeds / (generator.nominalEfficiency * fullLoadHours) else 0.5
  let effectivePerf := partLoadEfficiency (max 0.1 (min 1.0 avgLoadRatio)) generator
  thermalNeeds / effectivePerf

/-! ### Générateurs avancés -/

/-- Courbe de rendement à charge partielle (polynôme de degré 2 ou 3) -/
structure PartLoadCurve where
  a0 : Float  -- coefficient constant
  a1 : Float  -- coefficient du ratio de charge
  a2 : Float  -- coefficient du ratio²
  a3 : Float := 0.0  -- coefficient optionnel du ratio³

/-- Évalue une courbe polynomiale de rendement -/
def evaluatePartLoadCurve (curve : PartLoadCurve) (loadRatio : Float) : Float :=
  let r := max 0.0 (min 1.0 loadRatio)
  curve.a0 + curve.a1 * r + curve.a2 * r*r + curve.a3 * r*r*r

/-- Courbes typiques pour PAC et chaudières (valeurs indicatives) -/
def defaultHeatPumpPartLoadCurve : PartLoadCurve :=
  { a0 := 0.65, a1 := 0.8, a2 := -0.45 }   -- typique des PAC air-eau

def defaultBoilerPartLoadCurve : PartLoadCurve :=
  { a0 := 0.82, a1 := 0.25, a2 := -0.07 }  -- chaudière condensation

/-- Version avancée avec courbe polynomiale -/
def calculateFinalEnergyWithPolynomialCurve
    (thermalNeeds : Float)
    (fullLoadHours : Float)
    (generator : Generator)
    (curve : PartLoadCurve) : Float :=
  let avgLoadRatio := if fullLoadHours > 0 then
    thermalNeeds / (generator.nominalEfficiency * fullLoadHours) else 0.6
  let r := max 0.1 (min 1.0 avgLoadRatio)
  let perf := evaluatePartLoadCurve curve r * generator.seasonalPerformance
  thermalNeeds / (max 0.5 perf)

/-- Système bivalent (ex: PAC + chaudière gaz en relève) -/
structure BivalentSystem where
  mainGenerator : Generator      -- ex: PAC
  backupGenerator : Generator    -- ex: Chaudière gaz
  switchTemperature : Float      -- température extérieure de basculement (°C)
  bivalentRatio : Float          -- part de couverture par le générateur principal

def calculateBivalentFinalEnergy
    (thermalNeeds : Float)
    (avgOutdoorTemp : Float)
    (system : BivalentSystem) : Float :=
  if avgOutdoorTemp >= system.switchTemperature then
    -- PAC couvre tout
    calculateFinalEnergy thermalNeeds system.mainGenerator
  else
    -- Partage entre PAC et relève
    let mainPart := thermalNeeds * system.bivalentRatio
    let backupPart := thermalNeeds * (1.0 - system.bivalentRatio)
    calculateFinalEnergy mainPart system.mainGenerator +
    calculateFinalEnergy backupPart system.backupGenerator

/-- Régulation simple (compensation climatique) -/
def applyWeatherCompensation
    (baseSetpoint : Float)
    (outdoorTemp : Float)
    (slope : Float := 0.5) : Float :=
  baseSetpoint + slope * (20.0 - outdoorTemp)  -- exemple de loi d'eau

/-- Modélisation simplifiée de l'ECS (Eau Chaude Sanitaire) -/
structure DHWSystem where
  dailyNeeds : Float          -- litres/jour ou kWh/jour
  generator : Generator
  storageLosses : Float       -- kWh/an

def calculateDHWFinalEnergy (dhw : DHWSystem) (days : Float := 365.0) : Float :=
  let annualNeeds := dhw.dailyNeeds * days
  let generatorConsumption := calculateFinalEnergy annualNeeds dhw.generator
  generatorConsumption + dhw.storageLosses

/-- Support basique pour le refroidissement -/
def calculateCoolingFinalEnergy
    (coolingNeeds : Float)
    (coolingGenerator : Generator) : Float :=
  if coolingGenerator.genType == GeneratorType.HeatPumpAirAir ||
     coolingGenerator.genType == GeneratorType.HeatPumpAirWater then
    coolingNeeds / coolingGenerator.seasonalPerformance
  else
    coolingNeeds / 3.0

/-! ### Fonctionnalités avancées supplémentaires -/

/-- Courbes de rendement plus détaillées par type de générateur -/
def getDefaultPartLoadCurve (genType : GeneratorType) : PartLoadCurve :=
  match genType with
  | GeneratorType.HeatPumpAirWater | GeneratorType.HeatPumpAirAir =>
      { a0 := 0.60, a1 := 0.95, a2 := -0.55 }
  | GeneratorType.GasBoilerCondensing =>
      { a0 := 0.80, a1 := 0.30, a2 := -0.10 }
  | GeneratorType.WoodBoiler =>
      { a0 := 0.70, a1 := 0.40, a2 := -0.10 }
  | _ => defaultBoilerPartLoadCurve

/-- Stockage thermique (ballon tampon ou ballon ECS) -/
structure ThermalStorage where
  volume : Float           -- litres
  deltaT : Float           -- °C (plage de température utile)
  lossesPerDay : Float     -- kWh/jour

def storageCapacity (storage : ThermalStorage) : Float :=
  storage.volume * 4.18 * storage.deltaT / 3600.0   -- kWh approx

/-- Impact simplifié du stockage sur les performances (réduction des cycles) -/
def applyStorageEffect
    (baseConsumption : Float)
    (storage : ThermalStorage)
    (cyclingLossFactor : Float := 0.05) : Float :=
  -- Le stockage réduit les pertes de cyclage
  baseConsumption * (1.0 - cyclingLossFactor)

/-- Générateur hybride avancé (ex: PAC + résistance électrique + stockage) -/
structure AdvancedHybridSystem where
  heatPump : Generator
  backup : Generator
  storage : ThermalStorage
  heatPumpCoverage : Float   -- part couverte par la PAC en moyenne

def calculateAdvancedHybridEnergy
    (thermalNeeds : Float)
    (system : AdvancedHybridSystem) : Float :=
  let hpNeeds := thermalNeeds * system.heatPumpCoverage
  let backupNeeds := thermalNeeds * (1.0 - system.heatPumpCoverage)
  let hpEnergy := calculateFinalEnergyWithPartLoad hpNeeds 1800.0 system.heatPump
  let backupEnergy := calculateFinalEnergy backupNeeds system.backup
  let storageAdjusted := applyStorageEffect (hpEnergy + backupEnergy) system.storage
  storageAdjusted

/-! ### Stockage d’énergie et priorité ECS avancés -/

/-- État du stockage avec suivi temporel -/
structure StorageState where
  currentEnergy : Float
  maxEnergy : Float
  lossesPerHour : Float

def chargeStorage (state : StorageState) (energy : Float) : StorageState :=
  let newEnergy := min state.maxEnergy (state.currentEnergy + energy - state.lossesPerHour)
  { state with currentEnergy := max 0.0 newEnergy }

def dischargeStorage (state : StorageState) (energy : Float) : (Float × StorageState) :=
  let available := min energy state.currentEnergy
  let newState := { state with currentEnergy := state.currentEnergy - available }
  (available, newState)

/-- Priorité ECS avancée avec stockage -/
def calculateWithDHWPriorityAndStorage
    (spaceHeatingNeeds : Float)
    (dhwNeeds : Float)
    (mainGenerator : Generator)
    (storage : StorageState)
    (dhwPriority : Bool := true) : (Float × Float × StorageState) :=
  if dhwPriority then
    -- ECS prioritaire
    let (dhwFromStorage, newStorage) := dischargeStorage storage dhwNeeds
    let remainingDHW := max 0.0 (dhwNeeds - dhwFromStorage)
    let dhwConso := calculateFinalEnergy remainingDHW mainGenerator
    let heatingConso := calculateFinalEnergy spaceHeatingNeeds mainGenerator
    (heatingConso, dhwConso + dhwFromStorage, newStorage)
  else
    let heatingConso := calculateFinalEnergy spaceHeatingNeeds mainGenerator
    let (dhwFromStorage, newStorage) := dischargeStorage storage dhwNeeds
    let remainingDHW := max 0.0 (dhwNeeds - dhwFromStorage)
    let dhwConso := calculateFinalEnergy remainingDHW mainGenerator
    (heatingConso, dhwConso + dhwFromStorage, newStorage)

/-! ### Émetteurs et distribution (Étape 3) -/

/-- Types d'émetteurs -/
inductive EmitterType where
  | UnderfloorHeating     -- Plancher chauffant (basse température)
  | Radiators             -- Radiateurs classiques
  | FanCoils              -- Ventilo-convecteurs
  | RadiantPanels
  deriving Repr, DecidableEq

/-- Émetteur de chauffage -/
structure HeatingEmitter where
  emitterType : EmitterType
  nominalPower : Float          -- W à ΔT = 50K
  designDeltaT : Float          -- K (différence eau / air en régime nominal)
  emissionCoefficient : Float   -- exposant (1.3 pour radiateurs, ~1.0 pour plancher)

def emitterEfficiency (emitter : HeatingEmitter) (actualDeltaT : Float) : Float :=
  (actualDeltaT / emitter.designDeltaT) ^ emitter.emissionCoefficient

/-- Pertes de distribution (réseau de chauffage) -/
structure DistributionLosses where
  linearLoss : Float      -- W/m.K
  length : Float          -- m de réseau
  insulationFactor : Float := 0.8

def calculateDistributionLoss (losses : DistributionLosses) (meanWaterTemp : Float) (indoorTemp : Float) : Float :=
  losses.linearLoss * losses.length * (meanWaterTemp - indoorTemp) * losses.insulationFactor

/-- Système complet avec émetteur et distribution -/
structure CompleteHeatingSystem where
  generator : Generator
  emitter : HeatingEmitter
  distribution : DistributionLosses
  emitterInletTemp : Float   -- °C (température de départ d'eau)

def calculateCompleteHeatingEnergy
    (thermalNeeds : Float)
    (indoorTemp : Float)
    (system : CompleteHeatingSystem) : Float :=
  let deltaT := system.emitterInletTemp - indoorTemp
  let emitterEff := emitterEfficiency system.emitter deltaT
  let requiredWaterPower := thermalNeeds / emitterEff
  let distributionLoss := calculateDistributionLoss system.distribution system.emitterInletTemp indoorTemp
  let generatorNeeds := requiredWaterPower + distributionLoss
  calculateFinalEnergy generatorNeeds system.generator

/-- Auxiliaires (pompes de circulation, ventilateurs) -/
structure Auxiliary where
  power : Float           -- W
  controlFactor : Float   -- 0..1
  efficiency : Float := 0.55

def calculateAuxiliarySystemEnergy (aux : Auxiliary) (hours : Float) (partLoad : Float) : Float :=
  aux.power * aux.controlFactor * partLoad * hours / 1000.0 / aux.efficiency

/-- Priorité ECS vs Chauffage avec émetteurs -/
structure HeatingWithDHWSystem where
  generator : Generator
  emitter : HeatingEmitter
  dhwGenerator : Generator
  dhwPriority : Bool := true
  emitterMinTemp : Float := 25.0   -- température minimale de l'émetteur (ex: plancher)

def calculateHeatingWithDHW
    (spaceHeatingNeeds : Float)
    (dhwNeeds : Float)
    (indoorTemp : Float)
    (system : HeatingWithDHWSystem) : (Float × Float) :=
  if system.dhwPriority then
    -- ECS prioritaire
    let dhwConso := calculateFinalEnergy dhwNeeds system.dhwGenerator
    let remainingForHeating := max 0.0 (1.0 - dhwNeeds / (dhwNeeds + spaceHeatingNeeds + 0.001))
    let heatingConso := calculateFinalEnergy (spaceHeatingNeeds * remainingForHeating) system.generator
    (heatingConso, dhwConso)
  else
    let heatingConso := calculateCompleteHeatingEnergy spaceHeatingNeeds indoorTemp
      { generator := system.generator,
        emitter := system.emitter,
        distribution := { linearLoss := 0.1, length := 50.0, insulationFactor := 0.85 },
        emitterInletTemp := 35.0 }
    let dhwConso := calculateFinalEnergy dhwNeeds system.dhwGenerator
    (heatingConso, dhwConso)

/-! ### Annexe III - Algorithmes détaillés supplémentaires -/

/-- Performance des émetteurs en régime variable -/
def emitterVariablePerformance
    (emitter : HeatingEmitter)
    (actualDeltaT : Float)
    (loadRatio : Float) : Float :=
  let baseEff := emitterEfficiency emitter actualDeltaT
  -- Partial load efficiency: ~1.0 at design, reduced at lower loads
  let partLoadEff := max 0.8 (0.2 + 0.8 * loadRatio)
  baseEff * partLoadEff

/-- Pertes de distribution détaillées (température fluide + isolation) -/
structure DetailedDistribution where
  length : Float
  pipeDiameter : Float
  insulationThickness : Float
  fluidTemp : Float
  indoorTemp : Float
  insulationLambda : Float := 0.04

def calculateDetailedDistributionLoss (d : DetailedDistribution) : Float :=
  let resistance := d.insulationThickness / d.insulationLambda
  let deltaT := d.fluidTemp - d.indoorTemp
  let lossPerMeter := 2.0 * 3.1415926535 * deltaT /
                      (1.0 / d.pipeDiameter + resistance)
  lossPerMeter * d.length

/-- Stockage thermique avec stratification simplifiée -/
structure StratifiedStorage where
  volume : Float
  upperTemp : Float
  lowerTemp : Float
  lossesPerHour : Float

def calculateStratifiedStorageLoss (s : StratifiedStorage) : Float :=
  let avgTemp := (s.upperTemp + s.lowerTemp) / 2.0
  s.lossesPerHour * (avgTemp - 20.0) / 10.0

/-- Régulation (loi d'eau + consigne variable) -/
structure HeatingRegulation where
  baseSetpoint : Float
  weatherSlope : Float
  minSupply : Float
  maxSupply : Float

def calculateSupplyTemp (reg : HeatingRegulation) (outdoorTemp : Float) : Float :=
  let temp := reg.baseSetpoint + reg.weatherSlope * (20.0 - outdoorTemp)
  max reg.minSupply (min reg.maxSupply temp)

/-! ### Validation Annexe III -/

def runAnnexIIIValidation : (Float × Float × Float) :=
  let plancher : HeatingEmitter := {
    emitterType := EmitterType.UnderfloorHeating,
    nominalPower := 70.0,
    designDeltaT := 20.0,
    emissionCoefficient := 1.1
  }

  let regulation : HeatingRegulation := {
    baseSetpoint := 35.0,
    weatherSlope := 0.8,
    minSupply := 25.0,
    maxSupply := 45.0
  }

  let storage : StratifiedStorage := {
    volume := 300.0,
    upperTemp := 45.0,
    lowerTemp := 30.0,
    lossesPerHour := 0.8
  }

  let dist : DetailedDistribution := {
    length := 80.0,
    pipeDiameter := 0.025,
    insulationThickness := 0.03,
    fluidTemp := 38.0,
    indoorTemp := 20.0
  }

  let supply := calculateSupplyTemp regulation 5.0
  let emitterPerf := emitterVariablePerformance plancher 18.0 0.65
  let losses := calculateDetailedDistributionLoss dist + calculateStratifiedStorageLoss storage

  (supply, emitterPerf, losses)

/-! ### Algorithmes Annexe III manquants ajoutés -/

/-- Performance des systèmes de refroidissement (Annexe III) -/
def coolingPerformance
    (coolingNeeds : Float)
    (sourceTemp : Float)
    (sinkTemp : Float)
    (loadRatio : Float)
    (nominalEER : Float) : Float :=
  let tempFactor := max 0.55 (1.0 - (sinkTemp - sourceTemp - 8.0) / 35.0)
  let partLoad := 0.65 + 0.35 * loadRatio
  nominalEER * tempFactor * partLoad

/-- Ventilation mécanique détaillée (VMC, hygroréglable) -/
structure DetailedVentilation where
  nominalAirflow : Float
  heatRecovery : Float
  specificPower : Float     -- Wh/m³
  isDemandControlled : Bool

def calculateVentilationConsumption
    (vent : DetailedVentilation)
    (hours : Float)
    (averageLoad : Float) : Float :=
  vent.specificPower * vent.nominalAirflow * averageLoad * hours / 1000.0

/-- ECS solaire thermique simplifié (Annexe III) -/
structure SolarThermalDHW where
  collectorArea : Float
  efficiency : Float
  storageVolume : Float
  backup : Generator

def calculateSolarThermalDHW
    (system : SolarThermalDHW)
    (dhwNeeds : Float)
    (annualSolarRadiation : Float) : Float :=
  let solarYield := system.collectorArea * system.efficiency * annualSolarRadiation / 1000.0 * 0.7
  min (dhwNeeds * 0.65) solarYield

/-! ### Algorithmes Annexe III spécifiques et rares -/

/-- Capacité de remise en température (Φ_RH selon NF EN 12831) -/
def heatingUpCapacity
    (heatLoss : Float)
    (thermalCapacity : Float)
    (heatingHoursPerDay : Float)
    (targetRise : Float := 3.0) : Float :=
  let dailyDeficit := heatLoss * (24.0 - heatingHoursPerDay)
  let heatUp := (thermalCapacity * targetRise) / 3.0
  max 0.0 (heatUp - dailyDeficit * 0.25)

/-- Système hybride avancé avec régulation -/
structure RegulatedHybridHeatingSystem where
  heatPump : Generator
  backup : Generator
  emitter : HeatingEmitter
  regulation : HeatingRegulation
  switchTemp : Float

def calculateAdvancedHybrid
    (sys : RegulatedHybridHeatingSystem)
    (needs : Float)
    (outdoor : Float)
    (indoor : Float) : Float :=
  let supply := calculateSupplyTemp sys.regulation outdoor
  if outdoor >= sys.switchTemp then
    calculateFinalEnergyWithPartLoad needs 1600.0 sys.heatPump
  else
    calculateFinalEnergyWithPartLoad (needs * 0.55) 1600.0 sys.heatPump +
    calculateFinalEnergy (needs * 0.45) sys.backup

end RE2020
