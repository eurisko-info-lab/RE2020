import Example.MaisonPierre2011Building

namespace RE2020

/--
Equipment and system-set variants for the Maison Pierre 2011 building model,
plus scenario/calibration helper entrypoints.
-/

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

/-- New variant: same building details, with resilience-oriented systems package. -/
def maisonPierre2011ResilienceBuilding : Building :=
  { maisonPierre2011DetailedBuilding with
    name := "Maison Pierre 2011 (AC + double flux + bois secours + PV batterie)" }

def exampleMaisonPierre2011Resilience : IO Indicators := do
  let climate <- loadClimateDataProductionIO ClimateZone.H1c
  pure (computeIndicatorsWithResilienceSystems maisonPierre2011ResilienceBuilding climate)

def compareMaisonPierre2011BaseVsResilience : IO Unit := do
  let climate <- loadClimateDataProductionIO ClimateZone.H1c
  let base := computeDetailedIndicators maisonPierre2011DetailedBuilding climate
  let resilient := computeIndicatorsWithResilienceSystems maisonPierre2011ResilienceBuilding climate
  let baseComponents := computeDetailedEnergyComponents maisonPierre2011DetailedBuilding climate
  let baseClimate := climateKgCO2FromDetailedComponents baseComponents
  let resilientClimate := resilienceClimateKgCO2 maisonPierre2011ResilienceBuilding climate
  let baseDpe := mkDpeLikeIndicators base.cep baseClimate
  let resilientDpe := mkDpeLikeIndicators resilient.cep resilientClimate
  IO.println s!"Base:       Bbio={base.bbio}, Cep={base.cep}, CepNr={base.cepNr}, DH={base.dh}"
  IO.println s!"Resilience: Bbio={resilient.bbio}, Cep={resilient.cep}, CepNr={resilient.cepNr}, DH={resilient.dh}"
  IO.println s!"Delta:      dBbio={resilient.bbio - base.bbio}, dCep={resilient.cep - base.cep}, dCepNr={resilient.cepNr - base.cepNr}, dDH={resilient.dh - base.dh}"
  IO.println s!"Base DPE-like: classe={energyClimateClassLabel baseDpe.overallClass}, energie={baseDpe.energyKWhEPm2}, climat={baseDpe.climateKgCO2m2}, statut={baseDpe.typicalStatus}"
  IO.println s!"Resilience DPE-like: classe={energyClimateClassLabel resilientDpe.overallClass}, energie={resilientDpe.energyKWhEPm2}, climat={resilientDpe.climateKgCO2m2}, statut={resilientDpe.typicalStatus}"

def reportMaisonPierre2011CalibrationDossier (targetCep : Float := 85.0) : IO Unit := do
  let climate <- loadClimateDataProductionIO ClimateZone.H1c
  let testedProfiles := certificateCalibrationProfiles.length
  let baseComponents := computeDetailedEnergyComponents maisonPierre2011DetailedBuilding climate
  let retroComponents := computeDetailedEnergyComponents maisonPierre2011RetrofitBBCBuilding climate
  let baseRaw := computeDetailedIndicators maisonPierre2011DetailedBuilding climate
  let retroRaw := computeDetailedIndicators maisonPierre2011RetrofitBBCBuilding climate
  let baseRawDpe := mkDpeLikeIndicators baseRaw.cep (climateKgCO2FromDetailedComponents baseComponents)
  let retroRawDpe := mkDpeLikeIndicators retroRaw.cep (climateKgCO2FromDetailedComponents retroComponents)

  IO.println "=== Maison Pierre 2011 Calibration Dossier ==="
  IO.println s!"Target Cep: {targetCep}"
  IO.println s!"Profiles tested: {testedProfiles}"
  IO.println s!"Raw base:    Cep={baseRaw.cep}, CepNr={baseRaw.cepNr}, Bbio={baseRaw.bbio}, DH={baseRaw.dh}"
  IO.println s!"Raw retrofit: Cep={retroRaw.cep}, CepNr={retroRaw.cepNr}, Bbio={retroRaw.bbio}, DH={retroRaw.dh}"
  IO.println s!"Raw base DPE-like: classe={energyClimateClassLabel baseRawDpe.overallClass}, energie={baseRawDpe.energyKWhEPm2}, climat={baseRawDpe.climateKgCO2m2}, statut={baseRawDpe.typicalStatus}"
  IO.println s!"Raw retrofit DPE-like: classe={energyClimateClassLabel retroRawDpe.overallClass}, energie={retroRawDpe.energyKWhEPm2}, climat={retroRawDpe.climateKgCO2m2}, statut={retroRawDpe.typicalStatus}"

  match calibrateComponentsToCepTarget baseComponents targetCep with
  | none =>
    IO.println "Calibrated base: no feasible profile found"
  | some bestBase =>
    let p := bestBase.profile
    let calibratedBaseDpe := mkDpeLikeIndicators bestBase.indicators.cep (climateKgCO2FromCalibratedComponents baseComponents p)
    IO.println s!"Calibrated base: Cep={bestBase.indicators.cep}, CepNr={bestBase.indicators.cepNr}, absError={bestBase.absoluteError}"
    IO.println s!"Base profile: hScale={p.heatingNeedsScale}, dhwScale={p.dhwNeedsScale}, lightScale={p.lightingNeedsScale}, auxScale={p.auxiliaryNeedsScale}, elecPEF={p.electricPrimaryFactor}, modCep={p.applyCepModulations}"
    IO.println s!"Calibrated base DPE-like: classe={energyClimateClassLabel calibratedBaseDpe.overallClass}, energie={calibratedBaseDpe.energyKWhEPm2}, climat={calibratedBaseDpe.climateKgCO2m2}, statut={calibratedBaseDpe.typicalStatus}"

  match calibrateComponentsToCepTarget retroComponents targetCep with
  | none =>
    IO.println "Calibrated retrofit: no feasible profile found"
  | some bestRetro =>
    let p := bestRetro.profile
    let calibratedRetroDpe := mkDpeLikeIndicators bestRetro.indicators.cep (climateKgCO2FromCalibratedComponents retroComponents p)
    IO.println s!"Calibrated retrofit: Cep={bestRetro.indicators.cep}, CepNr={bestRetro.indicators.cepNr}, absError={bestRetro.absoluteError}"
    IO.println s!"Retro profile: hScale={p.heatingNeedsScale}, dhwScale={p.dhwNeedsScale}, lightScale={p.lightingNeedsScale}, auxScale={p.auxiliaryNeedsScale}, elecPEF={p.electricPrimaryFactor}, modCep={p.applyCepModulations}"
    IO.println s!"Calibrated retrofit DPE-like: classe={energyClimateClassLabel calibratedRetroDpe.overallClass}, energie={calibratedRetroDpe.energyKWhEPm2}, climat={calibratedRetroDpe.climateKgCO2m2}, statut={calibratedRetroDpe.typicalStatus}"

end RE2020
