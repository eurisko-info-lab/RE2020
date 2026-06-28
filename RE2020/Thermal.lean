/-
  RE2020.Thermal
  Cœur de la simulation thermique dynamique (méthode Th-BCE 2020)

  Implémentation d'un modèle de bilan thermique horaire
  fidèle aux principes de l'Annexe III de l'arrêté du 4 août 2021.

  Modèle : Capacitance concentrée (lumped) par groupe thermique
  avec pas de temps horaire et résolution explicite.

  Ce module calcule :
  - Températures intérieures heure par heure
  - Besoins en chauffage et refroidissement
  - Apports et déperditions
-/

import RE2020.Types
import RE2020.Building
import RE2020.Climate
import RE2020.Solar
import RE2020.Scenarios

namespace RE2020

/-- État thermique à un instant donné pour un groupe -/
structure ThermalState where
  indoorTemp     : Float    -- °C
  heatingPower   : Float    -- W (puissance de chauffage fournie)
  coolingPower   : Float    -- W (puissance de refroidissement fournie)
  deriving Repr

/-- Résultats d'une simulation sur une période -/
structure SimulationResults where
  hourlyIndoorTemps   : Array Float
  hourlyHeatingNeeds  : Array Float    -- kWh par heure
  hourlyCoolingNeeds  : Array Float
  totalHeatingNeeds   : Float          -- kWh/an
  totalCoolingNeeds   : Float
  deriving Repr

/-- Paramètres de consigne (conventionnels RE2020) -/
structure Setpoints where
  heatingSetpoint : Float := 20.0   -- °C (valeur conventionnelle)
  coolingSetpoint : Float := 26.0   -- °C
  deriving Repr

/-- Calcul des déperditions par transmission pour un groupe -/
def transmissionLosses (group : ThermalGroup) (deltaT : Float) : Float :=
  let uA_walls := group.opaqueWalls.foldl (fun acc w => acc + w.uValue * w.area) 0.0
  let uA_windows := group.windows.foldl (fun acc w => acc + w.uValue * w.area) 0.0
  let psiL := group.linearBridges.foldl (fun acc b => acc + b.psi * b.length) 0.0
  let chiN := group.pointBridges.foldl (fun acc b => acc + b.chi * Float.ofNat b.count) 0.0
  (uA_walls + uA_windows + psiL + chiN) * deltaT

/-- Calcul des déperditions par ventilation avec récupération de chaleur -/
def ventilationLosses
    (group : ThermalGroup)
    (deltaT : Float)
    (ventRate : Float := 0.6)           -- m³/h par m² (conventionnel)
    (heatRecoveryEfficiency : Float := 0.0) : Float :=  -- 0 = naturelle, 0.85 = VMC double flux performante
  let volume := group.volume
  let qv := ventRate * group.referenceArea   -- m³/h
  let effectiveDeltaT := deltaT * (1.0 - heatRecoveryEfficiency)
  0.34 * qv * effectiveDeltaT

/-- Gains internes (conventionnels) -/
def internalGains (group : ThermalGroup) : Float :=
  group.internalHeatGains * group.referenceArea

/-- Simulation d'une heure pour un groupe thermique (modèle 2 nœuds amélioré) -/
def simulateOneHour
    (group : ThermalGroup)
    (prevAirTemp : Float)
    (prevMassTemp : Float)
    (outdoorTemp : Float)
    (solarGainsValue : Float)
    (setpoints : Setpoints)
    (ventRate : Float := 0.6)
    (heatRecovery : Float := 0.0)
    (dt : Float := 3600.0)
    : ThermalState × Float :=   -- retourne (état, nouvelle température de masse)
  let deltaT := prevAirTemp - outdoorTemp
  let ventLosses := ventilationLosses group deltaT ventRate heatRecovery
  let transLosses := transmissionLosses group deltaT
  let totalLosses := transLosses + ventLosses

  let gainsInternal := internalGains group

  -- Répartition des gains (plus physique)
  let airGains := solarGainsValue * 0.20 + gainsInternal * 0.55
  let massGains := solarGainsValue * 0.80 + gainsInternal * 0.45

  -- Capacité thermique des murs (multi-couches)
  let massCapacity := group.opaqueWalls.foldl (fun acc w =>
    acc + w.thermalCapacity * w.area
  ) 0.0

  -- Capacité de l'air + mobilier léger
  let airCapacity := 45000.0 + group.referenceArea * 25000.0

  -- Couplage thermique air ↔ masse (W/K) - valeur plus physique
  let coupling := 6.0 * group.referenceArea

  -- Équation du nœud air
  let airNet := airGains - totalLosses - coupling * (prevAirTemp - prevMassTemp)
  let newAirTemp := prevAirTemp + (airNet * dt) / airCapacity

  -- Équation du nœud masse (inertie)
  let massNet := massGains + coupling * (prevAirTemp - prevMassTemp)
  let newMassTemp := prevMassTemp + (massNet * dt) / massCapacity

  -- HVAC sur le nœud air
  let (finalAirTemp, heating, cooling) :=
    if newAirTemp < setpoints.heatingSetpoint then
      (setpoints.heatingSetpoint, (setpoints.heatingSetpoint - newAirTemp) * airCapacity / dt, 0.0)
    else if newAirTemp > setpoints.coolingSetpoint then
      (setpoints.coolingSetpoint, 0.0, (newAirTemp - setpoints.coolingSetpoint) * airCapacity / dt)
    else
      (newAirTemp, 0.0, 0.0)

  ({ indoorTemp := finalAirTemp, heatingPower := heating, coolingPower := cooling }, newMassTemp)

/-- Simulation d'une heure pour tous les groupes thermiques du bâtiment. -/
def simulateBuildingHour
    (groups : List ThermalGroup)
    (prevAirTemps : List Float)
    (prevMassTemps : List Float)
    (climateHour : HourlyClimate)
    (dayOfYear : Nat)
    (hourOfDay : Nat)
    (setpoints : Setpoints)
    (ventRate : Float)
    (heatRecovery : Float := 0.0)
    : (List Float × List Float × Float × Float × Float × Float) :=
  let rec go
      (remainingGroups : List ThermalGroup)
      (air : List Float)
      (mass : List Float)
      (newAirRev : List Float)
      (newMassRev : List Float)
      (heatingPowerAcc : Float)
      (coolingPowerAcc : Float)
      (weightedIndoorAcc : Float)
      (areaAcc : Float)
      : (List Float × List Float × Float × Float × Float × Float) :=
    match remainingGroups with
    | [] =>
      (newAirRev.reverse, newMassRev.reverse, heatingPowerAcc, coolingPowerAcc, weightedIndoorAcc, areaAcc)
    | group :: tail =>
      let prevAir := match air with | a :: _ => a | [] => setpoints.heatingSetpoint
      let prevMass := match mass with | m :: _ => m | [] => setpoints.heatingSetpoint
      let nextAir := match air with | _ :: t => t | [] => []
      let nextMass := match mass with | _ :: t => t | [] => []
      let solar := solarGainsAtHour group climateHour 46.0 dayOfYear hourOfDay
      let (state, newMassTemp) :=
        simulateOneHour group prevAir prevMass climateHour.dryBulbTemp solar setpoints ventRate heatRecovery
      go tail
        nextAir
        nextMass
        (state.indoorTemp :: newAirRev)
        (newMassTemp :: newMassRev)
        (heatingPowerAcc + state.heatingPower)
        (coolingPowerAcc + state.coolingPower)
        (weightedIndoorAcc + state.indoorTemp * group.referenceArea)
        (areaAcc + group.referenceArea)
  go groups prevAirTemps prevMassTemps [] [] 0.0 0.0 0.0 0.0

/-- Simulation complète sur une année (8760 heures) pour un bâtiment -/
def simulateYear
    (building : Building)
    (climate : ClimateData)
    (scenario : Option (Array Float) := none)
    (setpoints : Setpoints := {})
    : SimulationResults :=
  let hours := climate.hourlyData.size
  let initialTemps := building.groups.map (fun _ => setpoints.heatingSetpoint)
  let initialState :=
    (initialTemps, initialTemps, #[], #[], #[], 0.0, 0.0)

  let (_, _, indoorArr, heatingArr, coolingArr, totalHeating, totalCooling) :=
    (List.range hours).foldl
      (fun (st : List Float × List Float × Array Float × Array Float × Array Float × Float × Float) i =>
        let (airTemps, massTemps, indoorAcc, heatingAcc, coolingAcc, heatSum, coolSum) := st
        let climateHour := climate.hourlyData[i]!
        let dayOfYear := (i / 24) + 1
        let hourOfDay := i % 24
        let ventRate :=
          match scenario with
          | some profile =>
            if h : profile.size > 0 then
              profile[(i % profile.size)]!
            else
              0.6
          | none => 0.6
        let (newAir, newMass, heatingPowerW, coolingPowerW, weightedIndoor, areaSum) :=
          simulateBuildingHour building.groups airTemps massTemps climateHour dayOfYear hourOfDay setpoints ventRate
        let avgIndoor :=
          if areaSum > 0 then weightedIndoor / areaSum else setpoints.heatingSetpoint
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

  { hourlyIndoorTemps := indoorArr,
    hourlyHeatingNeeds := heatingArr,
    hourlyCoolingNeeds := coolingArr,
    totalHeatingNeeds := totalHeating,
    totalCoolingNeeds := totalCooling }

/-- Exemple d'utilisation -/
def exampleSimulation : IO Unit := do
  let building := {
    name := "Exemple thermique",
    category := BuildingCategory.MaisonIndividuelle,
    climateZone := ClimateZone.H2c,
    groups := [{
      name := "Zone unique",
      volume := 250.0,
      referenceArea := 100.0,
      opaqueWalls := [{
        name := "Mur",
        area := 180.0,
        layers := [],
        uValue := 0.25,
        thermalCapacity := 120000.0,
        solarAbsorptivity := 0.6
      }],
      windows := [{
        name := "Baie sud",
        area := 18.0,
        uValue := 1.2,
        gValue := 0.55,
        frameRatio := 0.25,
        orientation := 0.0,
        tilt := 90.0,
        shadingFactor := 0.8
      }],
      linearBridges := [],
      pointBridges := [],
      airPermeabilityQ4 := 0.6,
      internalHeatGains := 4.0
    }],
    totalReferenceArea := 100.0,
    airPermeabilityQ4 := 0.6
  }
  let climate <- loadClimateDataProductionIO ClimateZone.H2c
  let results := simulateYear building climate
  IO.println s!"Simulation annuelle terminee: chauffage={results.totalHeatingNeeds} kWh, refroidissement={results.totalCoolingNeeds} kWh"

/-- Calcul détaillé des déperditions via ponts thermiques ponctuels (NF EN 12831) -/
def pointThermalBridgesLoss
    (pointBridges : List PointThermalBridge)
    (indoorTemp : Float)
    (outdoorDesignTemp : Float)
    (chiReductionFactor : Float := 1.0) : Float :=
  let deltaT := indoorTemp - outdoorDesignTemp
  pointBridges.foldl (fun acc b =>
    acc + b.chi * Float.ofNat b.count * deltaT * chiReductionFactor
  ) 0.0

end RE2020
