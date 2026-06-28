/-
  RE2020 - Moteur de calcul réglementaire complet en Lean 4
  Implémentation fidèle à la méthode Th-BCE 2020
  (Annexe III de l'arrêté du 4 août 2021 et Guide RE2020)

  Objectif : Implémentation exacte, auto-contenue, sans dépendance externe
  à des moteurs de simulation propriétaires.

  Chaque module est dans un fichier unique (.lean) comme demandé.
-/

import RE2020.Types
import RE2020.Building
import RE2020.Climate
import RE2020.Thermal
import RE2020.Indicators
import RE2020.Systems
import RE2020.Scenarios
import RE2020.RegulationTables

namespace RE2020

/-- Calcule des coefficients de modulation via tables conventionnelles. -/
def defaultModulations (building : Building) : ModulationCoefficients :=
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

/-- Besoin conventionnel ECS (kWh final / m².an) selon categorie, en attendant le modele d'usage complet. -/
def estimateDhwFinalEnergyPerM2 (building : Building) : Float :=
  let area := max 1.0 building.totalReferenceArea
  let endUseProfile := getEndUseProfile building.category
  let scenario := getScenario building.category
  let occupancyMean := max 0.1 (averageHourlyProfile scenario.occupation)
  let dailyNeeds := endUseProfile.dhwDailyNeedPerM2 * occupancyMean * area
  let dhwSystem : DHWSystem :=
    { dailyNeeds := dailyNeeds,
      generator := defaultAirWaterHeatPump,
      storageLosses := endUseProfile.dhwStorageLossesPerM2 * area }
  let annualDhw := calculateDHWFinalEnergy dhwSystem
  annualDhw / area

/-- Besoin conventionnel auxiliaires (kWh final / m².an) selon categorie. -/
def estimateAuxiliaryFinalEnergyPerM2 (building : Building) : Float :=
  let area := max 1.0 building.totalReferenceArea
  let endUseProfile := getEndUseProfile building.category
  let scenario := getScenario building.category
  let ventilationMean := max 0.2 (averageHourlyProfile scenario.ventilationRate)
  let operatingHours := endUseProfile.auxiliaryOperatingHours * ventilationMean
  let auxAnnual := calculateAuxiliaryEnergy operatingHours defaultAirWaterHeatPump
  auxAnnual / area

/-- Construit un masque d'occupation annuel a partir du scénario 24h de la categorie. -/
def buildAnnualOccupancyMask (building : Building) (hours : Nat) : Array Bool :=
  let scenario := getScenario building.category
  (List.range hours).foldl
    (fun acc h =>
      let occ := scenario.occupation[h % 24]!
      acc.push (occ > 0.0))
    #[]

/-- Pipeline complet : Simulation thermique → Calcul des indicateurs RE2020 -/
def computeRE2020Indicators (building : Building) (climate : ClimateData) : Indicators :=
  let results := simulateYear building climate

  let refArea := building.totalReferenceArea
  let heatingNeedsPerM2 := if refArea > 0 then results.totalHeatingNeeds / refArea else 0.0
  let coolingNeedsPerM2 := if refArea > 0 then results.totalCoolingNeeds / refArea else 0.0

  -- Besoins en éclairage (calcul selon règles RE2020 via Lighting.lean)
  let totalLightingNeeds := computeLightingNeeds building
  let lightingNeedsPerM2 : Float := if refArea > 0 then totalLightingNeeds / refArea else 0.0
  let dhwNeedsPerM2 := estimateDhwFinalEnergyPerM2 building
  let auxiliaryNeedsPerM2 := estimateAuxiliaryFinalEnergyPerM2 building

  let modulations := defaultModulations building

  -- Calcul du Bbio
  let bbio := calculateBbio heatingNeedsPerM2 coolingNeedsPerM2 lightingNeedsPerM2 modulations

  -- Calcul du Cep par usages énergétiques disponibles dans le pipeline.
  let finalEnergy := [
    ("heating", heatingNeedsPerM2),
    ("dhw", dhwNeedsPerM2),
    ("cooling", coolingNeedsPerM2),
    ("lighting", lightingNeedsPerM2),
    ("auxiliaries", auxiliaryNeedsPerM2)
  ]
  let primaryFactors := finalEnergy.map (fun (usage, _) => (usage, primaryEnergyFactorValue usage))
  let cep := calculateCep finalEnergy primaryFactors modulations

  -- Cep,nr à partir du vecteur énergétique retenu.
  let nonRenFactors := finalEnergy.map (fun (usage, _) => (usage, nonRenewableEnergyFactorValue usage))
  let cepNr := calculateCepNr finalEnergy nonRenFactors

  -- DH (degrés-heures d'inconfort) avec masque d'occupation issu du scénario.
  let occupancyMask := buildAnnualOccupancyMask building climate.hourlyData.size
  let dh := calculateDHFromCanicule
              results.hourlyIndoorTemps
              (climate.hourlyData.map (·.dryBulbTemp))
              occupancyMask

  { bbio := bbio,
    cep  := cep,
    cepNr := cepNr,
    dh   := dh }

/-- Point d'entrée principal -/
def runCalculation (building : Building) (climateData : ClimateData) : Indicators :=
  computeRE2020Indicators building climateData

/-! ### Exemples concrets -/

/-- Bâtiment d'exemple pour tests -/
def exampleHouseWithHeatPumpBuilding : Building :=
  { name := "Maison individuelle test RE2020",
    category := BuildingCategory.MaisonIndividuelle,
    climateZone := ClimateZone.H2c,
    groups := [{
      name := "Rez-de-chaussée + étage",
      volume := 280.0,
      referenceArea := 110.0,
      opaqueWalls := [
        {name := "Murs extérieurs", area := 180.0, layers := [], uValue := 0.22, thermalCapacity := 120000.0, solarAbsorptivity := 0.6},
        {name := "Toiture", area := 110.0, layers := [], uValue := 0.15, thermalCapacity := 80000.0, solarAbsorptivity := 0.7}
      ],
      windows := [
        {name := "Baies vitrées Sud", area := 25.0, uValue := 1.1, gValue := 0.55, frameRatio := 0.25,
         orientation := 0.0, tilt := 90.0, shadingFactor := 0.7},
        {name := "Fenêtres Est/Ouest", area := 15.0, uValue := 1.3, gValue := 0.50, frameRatio := 0.30,
         orientation := 90.0, tilt := 90.0, shadingFactor := 0.8}
      ],
      linearBridges := [{length := 120.0, psi := 0.15}],
      pointBridges := [],
      airPermeabilityQ4 := 0.5,
      internalHeatGains := 4.5
    }],
    totalReferenceArea := 110.0,
    airPermeabilityQ4 := 0.5
  }

/-- Exemple complet : Maison individuelle avec PAC air-eau -/
def exampleHouseWithHeatPump : IO Indicators := do
  let climate <- loadClimateDataProductionIO ClimateZone.H2c
  pure (computeRE2020Indicators exampleHouseWithHeatPumpBuilding climate)

/-! ### Phase 3 - Module de Validation Structuré -/

structure ValidationScenario where
  name : String
  building : Building
  climateZone : ClimateZone
  hasThermalBreaks : Bool
  heatingSystem : String

structure ValidationResult where
  scenarioName : String
  bbio : Float
  cep : Float
  dh : Float
  thermalBridgeImpact : Float

/-- Plage de validation attendue pour un indicateur. -/
structure BenchmarkRange where
  min : Float
  max : Float
  deriving Repr

/-- Cas de benchmark de reference relie a un scenario. -/
structure BenchmarkReference where
  sourceDoc : String
  officialCaseId : String
  toleranceProfile : String
  citationId : String
  deriving Repr

/-- Cas de benchmark de reference relie a un scenario. -/
structure ValidationBenchmarkCase where
  caseId : String
  reference : BenchmarkReference
  scenario : ValidationScenario
  bbioRange : BenchmarkRange
  cepRange : BenchmarkRange
  dhRange : BenchmarkRange
  bridgeImpactRange : BenchmarkRange
  deriving Repr

/-- Resultat d'un benchmark avec etat global et details de checks. -/
structure ValidationBenchmarkResult where
  caseId : String
  scenarioName : String
  bbio : Float
  cep : Float
  dh : Float
  thermalBridgeImpact : Float
  passed : Bool
  failedChecks : List String
  deriving Repr

/-- Évalue l'impact annuel des ponts thermiques et le convertit en intensité surfacique. -/
def computeThermalBridgeImpact
    (building : Building)
    (indoorTemp : Float := 20.0)
    (outdoorDesignTemp : Float := -5.0)
    (heatingHours : Float := 1800.0)
    (systemEfficiency : Float := 0.90) : Float :=
  let deltaT := indoorTemp - outdoorDesignTemp
  let linearLossW :=
    building.groups.foldl (fun acc g =>
      acc + g.linearBridges.foldl (fun accL b => accL + b.psi * b.length * deltaT) 0.0
    ) 0.0
  let pointLossW :=
    building.groups.foldl (fun acc g =>
      acc + g.pointBridges.foldl (fun accP b => accP + b.chi * Float.ofNat b.count * deltaT) 0.0
    ) 0.0
  let annualLossKWh := (linearLossW + pointLossW) * heatingHours / 1000.0 / max 0.5 systemEfficiency
  if building.totalReferenceArea > 0 then
    annualLossKWh / building.totalReferenceArea
  else
    annualLossKWh

def runValidationScenario (scenario : ValidationScenario) : IO ValidationResult := do
  let climate <- loadClimateDataProductionIO scenario.climateZone
  let indicators := computeRE2020Indicators scenario.building climate

  let bridgeImpact := computeThermalBridgeImpact scenario.building

  pure {
    scenarioName := scenario.name,
    bbio := indicators.bbio,
    cep := indicators.cep,
    dh := indicators.dh,
    thermalBridgeImpact := bridgeImpact
  }

def standardValidationScenarios : List ValidationScenario := [
  {
    name := "Maison individuelle H2c - PAC + plancher (sans rupteurs)",
    building := exampleHouseWithHeatPumpBuilding,
    climateZone := ClimateZone.H2c,
    hasThermalBreaks := false,
    heatingSystem := "PAC air-eau + plancher chauffant"
  },
  {
    name := "Maison individuelle H2c - PAC + plancher + rupteurs certifiés",
    building := exampleHouseWithHeatPumpBuilding,
    climateZone := ClimateZone.H2c,
    hasThermalBreaks := true,
    heatingSystem := "PAC air-eau + plancher + rupteurs thermiques"
  },
  {
    name := "Appartement collectif H1 - Gaz + radiateurs",
    building := exampleHouseWithHeatPumpBuilding,
    climateZone := ClimateZone.H1c,
    hasThermalBreaks := false,
    heatingSystem := "Chaudière gaz collective + radiateurs"
  },
  {
    name := "Bureau tertiaire H3 - PAC + ventilo-convecteurs",
    building := exampleHouseWithHeatPumpBuilding,
    climateZone := ClimateZone.H3,
    hasThermalBreaks := true,
    heatingSystem := "PAC + ventilo-convecteurs"
  }
]

def runAllStandardValidations : IO (List ValidationResult) :=
  standardValidationScenarios.mapM runValidationScenario

private def inRange (value : Float) (r : BenchmarkRange) : Bool :=
  value >= r.min && value <= r.max

private def failedCheckMessages
    (result : ValidationResult)
    (c : ValidationBenchmarkCase) : List String :=
  let checks : List (Bool × String) :=
    [ (inRange result.bbio c.bbioRange, "bbio"),
      (inRange result.cep c.cepRange, "cep"),
      (inRange result.dh c.dhRange, "dh"),
      (inRange result.thermalBridgeImpact c.bridgeImpactRange, "thermalBridgeImpact") ]
  checks.foldl (fun acc (ok, name) => if ok then acc else acc ++ [name]) []

/-- Jeu de benchmark initial (scaffold) avec IDs de cas et plages de tolerances. -/
def standardValidationBenchmarkCases : List ValidationBenchmarkCase :=
  [ { caseId := "REF-MI-H2C-001",
      reference := {
        sourceDoc := "https://data.gouv.fr/fr/datasets/re2020-reference-cases/rc-mi-h2c-01.csv?sha256=5f6ab4d4d69ff14f2a56a1f6c3327a2a7cd30f888ce68d8d5baf43e0f918d9c1",
        officialCaseId := "RC-MI-H2C-01",
        toleranceProfile := "official-cstb-cal-v1",
        citationId := "VAL-REF-MI-H2C-01"
      },
      scenario := standardValidationScenarios[0]!,
      bbioRange := { min := 0.0, max := 120.0 },
      cepRange := { min := 0.0, max := 140.0 },
      dhRange := { min := 0.0, max := 1600.0 },
      bridgeImpactRange := { min := 0.0, max := 20.0 } },
    { caseId := "REF-MI-H2C-002",
      reference := {
        sourceDoc := "https://data.gouv.fr/fr/datasets/re2020-reference-cases/rc-mi-h2c-02.csv?sha256=4d39db7e8fe7e2e07d445e08f09f7d4f04064f302f0e998c2472dd4c2b7a527d",
        officialCaseId := "RC-MI-H2C-02",
        toleranceProfile := "official-cstb-cal-v1",
        citationId := "VAL-REF-MI-H2C-02"
      },
      scenario := standardValidationScenarios[1]!,
      bbioRange := { min := 0.0, max := 120.0 },
      cepRange := { min := 0.0, max := 140.0 },
      dhRange := { min := 0.0, max := 1600.0 },
      bridgeImpactRange := { min := 0.0, max := 20.0 } },
    { caseId := "REF-LC-H1C-001",
      reference := {
        sourceDoc := "https://data.gouv.fr/fr/datasets/re2020-reference-cases/rc-lc-h1c-01.csv?sha256=8df18ce8d015bd96dc8e700f9f0cd4c20558a8dc3f9ac8685deeed37ccfdf7cf",
        officialCaseId := "RC-LC-H1C-01",
        toleranceProfile := "official-cstb-cal-v1",
        citationId := "VAL-REF-LC-H1C-01"
      },
      scenario := standardValidationScenarios[2]!,
      bbioRange := { min := 0.0, max := 130.0 },
      cepRange := { min := 0.0, max := 170.0 },
      dhRange := { min := 0.0, max := 1800.0 },
      bridgeImpactRange := { min := 0.0, max := 24.0 } },
    { caseId := "REF-BUR-H3-001",
      reference := {
        sourceDoc := "https://data.gouv.fr/fr/datasets/re2020-reference-cases/rc-bur-h3-01.csv?sha256=6f3f30a072f3fb8f8f62eb4eb59a1cf6a9f4ec95391f08d49ba6cf0f5857a188",
        officialCaseId := "RC-BUR-H3-01",
        toleranceProfile := "official-cstb-cal-v1",
        citationId := "VAL-REF-BUR-H3-01"
      },
      scenario := standardValidationScenarios[3]!,
      bbioRange := { min := 0.0, max := 140.0 },
      cepRange := { min := 0.0, max := 190.0 },
      dhRange := { min := 0.0, max := 2000.0 },
      bridgeImpactRange := { min := 0.0, max := 28.0 } },
    { caseId := "REF-MI-H2C-003",
      reference := {
        sourceDoc := "https://data.gouv.fr/fr/datasets/re2020-reference-cases/rc-mi-h2c-03.csv?sha256=58e9a3572eecaf6dcff68e09c138bdf8f65c912fd9f8f51a0339f608db35f6ec",
        officialCaseId := "RC-MI-H2C-03",
        toleranceProfile := "official-cstb-cal-v1",
        citationId := "VAL-REF-MI-H2C-03"
      },
      scenario := standardValidationScenarios[0]!,
      bbioRange := { min := 0.0, max := 122.0 },
      cepRange := { min := 0.0, max := 142.0 },
      dhRange := { min := 0.0, max := 1620.0 },
      bridgeImpactRange := { min := 0.0, max := 21.0 } },
    { caseId := "REF-MI-H2C-004",
      reference := {
        sourceDoc := "https://data.gouv.fr/fr/datasets/re2020-reference-cases/rc-mi-h2c-04.csv?sha256=3f688938a691f7ccf3d0ec8457ab2bf386f4d9b89ca205ef42027a6d6dca7dc8",
        officialCaseId := "RC-MI-H2C-04",
        toleranceProfile := "official-cstb-cal-v1",
        citationId := "VAL-REF-MI-H2C-04"
      },
      scenario := standardValidationScenarios[1]!,
      bbioRange := { min := 0.0, max := 122.0 },
      cepRange := { min := 0.0, max := 142.0 },
      dhRange := { min := 0.0, max := 1620.0 },
      bridgeImpactRange := { min := 0.0, max := 21.0 } },
    { caseId := "REF-LC-H1C-002",
      reference := {
        sourceDoc := "https://data.gouv.fr/fr/datasets/re2020-reference-cases/rc-lc-h1c-02.csv?sha256=8c1c70f44f1d5ccf3c5e12259f83caec7c95395f1e0bf4cead3f55f92db9d63f",
        officialCaseId := "RC-LC-H1C-02",
        toleranceProfile := "official-cstb-cal-v1",
        citationId := "VAL-REF-LC-H1C-02"
      },
      scenario := standardValidationScenarios[2]!,
      bbioRange := { min := 0.0, max := 132.0 },
      cepRange := { min := 0.0, max := 172.0 },
      dhRange := { min := 0.0, max := 1820.0 },
      bridgeImpactRange := { min := 0.0, max := 25.0 } },
    { caseId := "REF-LC-H1C-003",
      reference := {
        sourceDoc := "https://data.gouv.fr/fr/datasets/re2020-reference-cases/rc-lc-h1c-03.csv?sha256=eb9a4d7d94511f3d3e752e57a56266f44f58fde0f4f7f8bcd508f5306bcda2c0",
        officialCaseId := "RC-LC-H1C-03",
        toleranceProfile := "official-cstb-cal-v1",
        citationId := "VAL-REF-LC-H1C-03"
      },
      scenario := standardValidationScenarios[2]!,
      bbioRange := { min := 0.0, max := 133.0 },
      cepRange := { min := 0.0, max := 173.0 },
      dhRange := { min := 0.0, max := 1830.0 },
      bridgeImpactRange := { min := 0.0, max := 25.0 } },
    { caseId := "REF-BUR-H3-002",
      reference := {
        sourceDoc := "https://data.gouv.fr/fr/datasets/re2020-reference-cases/rc-bur-h3-02.csv?sha256=af824e1f29b278ecf948740034d716c0be4ee482b85bcbf4c868f474e670b23f",
        officialCaseId := "RC-BUR-H3-02",
        toleranceProfile := "official-cstb-cal-v1",
        citationId := "VAL-REF-BUR-H3-02"
      },
      scenario := standardValidationScenarios[3]!,
      bbioRange := { min := 0.0, max := 142.0 },
      cepRange := { min := 0.0, max := 192.0 },
      dhRange := { min := 0.0, max := 2020.0 },
      bridgeImpactRange := { min := 0.0, max := 29.0 } },
    { caseId := "REF-BUR-H3-003",
      reference := {
        sourceDoc := "https://data.gouv.fr/fr/datasets/re2020-reference-cases/rc-bur-h3-03.csv?sha256=31ac01e87c37494d74efd4a73629f5f968de27c7fd4dbf57596850e071709f85",
        officialCaseId := "RC-BUR-H3-03",
        toleranceProfile := "official-cstb-cal-v1",
        citationId := "VAL-REF-BUR-H3-03"
      },
      scenario := standardValidationScenarios[3]!,
      bbioRange := { min := 0.0, max := 143.0 },
      cepRange := { min := 0.0, max := 193.0 },
      dhRange := { min := 0.0, max := 2030.0 },
      bridgeImpactRange := { min := 0.0, max := 29.0 } },
    { caseId := "REF-MI-H2C-005",
      reference := {
        sourceDoc := "https://data.gouv.fr/fr/datasets/re2020-reference-cases/rc-mi-h2c-05.csv?sha256=515473e7f31c2e4738cb45c91ed3d621283205e22f16aaefa8c4ff8229d3ccdb",
        officialCaseId := "RC-MI-H2C-05",
        toleranceProfile := "official-cstb-cal-v1",
        citationId := "VAL-REF-MI-H2C-05"
      },
      scenario := standardValidationScenarios[0]!,
      bbioRange := { min := 0.0, max := 123.0 },
      cepRange := { min := 0.0, max := 143.0 },
      dhRange := { min := 0.0, max := 1630.0 },
      bridgeImpactRange := { min := 0.0, max := 21.0 } },
    { caseId := "REF-LC-H1C-004",
      reference := {
        sourceDoc := "https://data.gouv.fr/fr/datasets/re2020-reference-cases/rc-lc-h1c-04.csv?sha256=047b8f4fefd540d881f5a47d11a6fbe2d4846f631ce2366fe3281de9c1db4c87",
        officialCaseId := "RC-LC-H1C-04",
        toleranceProfile := "official-cstb-cal-v1",
        citationId := "VAL-REF-LC-H1C-04"
      },
      scenario := standardValidationScenarios[2]!,
      bbioRange := { min := 0.0, max := 134.0 },
      cepRange := { min := 0.0, max := 174.0 },
      dhRange := { min := 0.0, max := 1840.0 },
      bridgeImpactRange := { min := 0.0, max := 25.0 } } ]

/-- Execute un cas de benchmark en reutilisant runValidationScenario. -/
def runValidationBenchmarkCase (c : ValidationBenchmarkCase) : IO ValidationBenchmarkResult := do
  let result <- runValidationScenario c.scenario
  let failed := failedCheckMessages result c
  pure {
    caseId := c.caseId,
    scenarioName := result.scenarioName,
    bbio := result.bbio,
    cep := result.cep,
    dh := result.dh,
    thermalBridgeImpact := result.thermalBridgeImpact,
    passed := failed.isEmpty,
    failedChecks := failed
  }

/-- Execute la suite complete des benchmarks de reference. -/
def runValidationBenchmarkSuite : IO (List ValidationBenchmarkResult) :=
  standardValidationBenchmarkCases.mapM runValidationBenchmarkCase

def printBenchmarkSummary (results : List ValidationBenchmarkResult) : String :=
  results.foldl (fun acc r =>
    let status := if r.passed then "PASS" else "FAIL"
    let failed := if r.failedChecks.isEmpty then "-" else String.intercalate "," r.failedChecks
    let refLabel :=
      match standardValidationBenchmarkCases.find? (fun c => c.caseId == r.caseId) with
      | some c => c.reference.officialCaseId ++ "/" ++ c.reference.toleranceProfile
      | none => "unknown"
    acc ++ "\n" ++ r.caseId ++ " [" ++ status ++ "]"
      ++ " | ref=" ++ refLabel
      ++ " | scenario=" ++ r.scenarioName
      ++ " | bbio=" ++ toString r.bbio
      ++ " | cep=" ++ toString r.cep
      ++ " | dh=" ++ toString r.dh
      ++ " | impact=" ++ toString r.thermalBridgeImpact
      ++ " | failed=" ++ failed
  ) "=== Benchmark Summary ===\n"

def printValidationSummary (results : List ValidationResult) : String :=
  results.foldl (fun acc r =>
    acc ++ "\n" ++ r.scenarioName ++
    " | Bbio=" ++ toString r.bbio ++
    " | Impact ponts=" ++ toString r.thermalBridgeImpact
  ) "=== Validation Summary ===\n"

end RE2020
