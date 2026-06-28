import RE2020.Optimization

namespace RE2020

def parseBool (s : String) : Option Bool :=
  match s.toLower with
  | "true" | "yes" | "1" => some true
  | "false" | "no" | "0" => some false
  | _ => none

def parseClimateZone (s : String) : Option ClimateZone :=
  match s with
  | "H1a" => some .H1a
  | "H1b" => some .H1b
  | "H1c" => some .H1c
  | "H2a" => some .H2a
  | "H2b" => some .H2b
  | "H2c" => some .H2c
  | "H2d" => some .H2d
  | "H3" => some .H3
  | _ => none

def parseBuildingCategory (s : String) : Option BuildingCategory :=
  match s.toLower with
  | "maisonindividuelle" | "maison" => some .MaisonIndividuelle
  | "logementcollectif" | "collectif" => some .LogementCollectif
  | "bureau" => some .Bureau
  | "enseignementprimairesecondaire" | "enseignement" => some .EnseignementPrimaireSecondaire
  | "autre" => some .Autre
  | _ => none

def parseEnvelopeQuality (s : String) : Option EnvelopeQuality :=
  match s.toLower with
  | "basic" => some .Basic
  | "standard" => some .Standard
  | "good" => some .Good
  | "verygood" | "very_good" => some .VeryGood
  | _ => none

def parseVentilationQuality (s : String) : Option VentilationQuality :=
  match s.toLower with
  | "natural" => some .Natural
  | "standardmechanical" | "standard_mechanical" => some .StandardMechanical
  | "heatrecovery" | "heat_recovery" => some .HeatRecovery
  | _ => none

def parseHeatingChoice (s : String) : Option HeatingChoice :=
  match s.toLower with
  | "gasboiler" | "gas_boiler" => some .GasBoiler
  | "airwaterheatpump" | "air_water_heatpump" | "air_water_heat_pump" => some .AirWaterHeatPump
  | "airairheatpump" | "air_air_heatpump" | "air_air_heat_pump" => some .AirAirHeatPump
  | "districtheating" | "district_heating" => some .DistrictHeating
  | "electricheating" | "electric_heating" => some .ElectricHeating
  | _ => none

def parseTargetMetric (s : String) : Option TargetMetric :=
  match s.toLower with
  | "bbio" => some .Bbio
  | "cep" => some .Cep
  | "cepnr" | "cep_nr" => some .CepNr
  | "dh" => some .Dh
  | _ => none

def parseSearchProfile (s : String) : Option SearchProfile :=
  match s.toLower with
  | "conservative" => some .Conservative
  | "standard" => some .Standard
  | "aggressive" => some .Aggressive
  | _ => none

def usage : String :=
  String.intercalate "\n"
    [ "Usage: re2020_optimize --name <name> --category <cat> --zone <zone> --area <m2>",
      "                      [--floors <n>] [--window-ratio <0..1>] [--envelope <basic|standard|good|verygood>]",
      "                      [--ventilation <natural|standardmechanical|heatrecovery>]",
      "                      [--heating <gasboiler|airwaterheatpump|airairheatpump|districtheating|electricheating>]",
      "                      [--shading <true|false>] [--profile <conservative|standard|aggressive>]",
      "                      [--cost-envelope <v>] [--cost-ventilation <v>] [--cost-heating <v>] [--cost-window <v>] [--cost-shading <v>]",
      "                      [--json-out <path>] [--strict-target true|false] --metric <bbio|cep|cepnr|dh> --target <value>",
      "",
      "Example:",
      "  re2020_optimize --name MaisonA --category maison --zone H2c --area 120 --floors 2 --window-ratio 0.18",
      "    --envelope standard --ventilation standardmechanical --heating airwaterheatpump --shading true",
      "    --metric cep --target 80" ]

def pow10 (n : Nat) : Nat :=
  Nat.rec 1 (fun _ acc => acc * 10) n

def parsePositiveDecimal? (raw : String) : Option Float :=
  if raw.isEmpty then
    none
  else
    let parts := raw.splitOn "."
    match parts with
    | [intPart] =>
        intPart.toNat?.map Float.ofNat
    | [intPart, fracPart] =>
        match intPart.toNat?, fracPart.toNat? with
        | some intVal, some fracVal =>
            let denom := Float.ofNat (pow10 fracPart.length)
            some (Float.ofNat intVal + (Float.ofNat fracVal / denom))
        | _, _ => none
    | _ => none

def parseArgPairs (args : List String) : Except String (List (String × String)) :=
  let rec go (rest : List String) (acc : List (String × String)) : Except String (List (String × String)) :=
    match rest with
    | [] => pure acc.reverse
    | key :: value :: tail =>
        if key.startsWith "--" then
          go tail ((((key.drop 2).toString), value) :: acc)
        else
          throw s!"Invalid argument key: {key}"
    | _ => throw "Arguments must be provided as --key value pairs"
  go args []

def findArg (pairs : List (String × String)) (key : String) : Option String :=
  (pairs.find? (fun p => p.1 == key)).map (·.2)

def requireArg (pairs : List (String × String)) (key : String) : Except String String :=
  match findArg pairs key with
  | some value => pure value
  | none => throw s!"Missing required argument --{key}"

def parseNatArg (pairs : List (String × String)) (key : String) (default : Nat) : Except String Nat :=
  match findArg pairs key with
  | none => pure default
  | some raw =>
      match raw.toNat? with
      | some value => pure value
      | none => throw s!"Invalid Nat for --{key}: {raw}"

def parseFloatArg (pairs : List (String × String)) (key : String) (default : Float) : Except String Float :=
  match findArg pairs key with
  | none => pure default
  | some raw =>
  match parsePositiveDecimal? raw with
      | some value => pure value
      | none => throw s!"Invalid Float for --{key}: {raw}"

def parseBoolArg (pairs : List (String × String)) (key : String) (default : Bool) : Except String Bool :=
  match findArg pairs key with
  | none => pure default
  | some raw =>
      match parseBool raw with
      | some value => pure value
      | none => throw s!"Invalid Bool for --{key}: {raw}"

def buildSpecAndRequest (pairs : List (String × String)) : Except String (SimplifiedBuildingSpec × SimplifiedTargetRequest) := do
  let name <- requireArg pairs "name"
  let categoryRaw <- requireArg pairs "category"
  let zoneRaw <- requireArg pairs "zone"
  let areaRaw <- requireArg pairs "area"
  let metricRaw <- requireArg pairs "metric"
  let targetRaw <- requireArg pairs "target"

  let category <-
    match parseBuildingCategory categoryRaw with
    | some c => pure c
    | none => throw s!"Invalid category: {categoryRaw}"

  let zone <-
    match parseClimateZone zoneRaw with
    | some z => pure z
    | none => throw s!"Invalid climate zone: {zoneRaw}"

  let area <-
    match parsePositiveDecimal? areaRaw with
    | some v => pure v
    | none => throw s!"Invalid floor area: {areaRaw}"

  let metric <-
    match parseTargetMetric metricRaw with
    | some m => pure m
    | none => throw s!"Invalid target metric: {metricRaw}"

  let targetValue <-
    match parsePositiveDecimal? targetRaw with
    | some v => pure v
    | none => throw s!"Invalid target value: {targetRaw}"

  let floors <- parseNatArg pairs "floors" 1
  let windowRatio <- parseFloatArg pairs "window-ratio" 0.18
  let shading <- parseBoolArg pairs "shading" true

  let envelope <-
    match findArg pairs "envelope" with
    | none => pure EnvelopeQuality.Standard
    | some raw =>
        match parseEnvelopeQuality raw with
        | some v => pure v
        | none => throw s!"Invalid envelope quality: {raw}"

  let ventilation <-
    match findArg pairs "ventilation" with
    | none => pure VentilationQuality.StandardMechanical
    | some raw =>
        match parseVentilationQuality raw with
        | some v => pure v
        | none => throw s!"Invalid ventilation quality: {raw}"

  let heating <-
    match findArg pairs "heating" with
    | none => pure HeatingChoice.AirWaterHeatPump
    | some raw =>
        match parseHeatingChoice raw with
        | some v => pure v
        | none => throw s!"Invalid heating choice: {raw}"

  let spec : SimplifiedBuildingSpec :=
    { name := name,
      category := category,
      climateZone := zone,
      floorArea := area,
      floors := floors,
      windowRatio := windowRatio,
      envelope := envelope,
      ventilation := ventilation,
      heating := heating,
      shading := shading }

  let request : SimplifiedTargetRequest :=
    { metric := metric,
      targetValue := targetValue }

  pure (spec, request)

def buildProfileAndWeights (pairs : List (String × String)) : Except String (SearchProfile × RetrofitCostWeights) := do
  let profile <-
    match findArg pairs "profile" with
    | none => pure SearchProfile.Standard
    | some raw =>
        match parseSearchProfile raw with
        | some p => pure p
        | none => throw s!"Invalid search profile: {raw}"

  let costEnvelope <- parseFloatArg pairs "cost-envelope" 3.0
  let costVentilation <- parseFloatArg pairs "cost-ventilation" 2.0
  let costHeating <- parseFloatArg pairs "cost-heating" 4.0
  let costWindow <- parseFloatArg pairs "cost-window" 1.5
  let costShading <- parseFloatArg pairs "cost-shading" 0.5

  let weights : RetrofitCostWeights :=
    { envelope := costEnvelope,
      ventilation := costVentilation,
      heating := costHeating,
      windowRatio := costWindow,
      shading := costShading }
  pure (profile, weights)

def toJsonMetric (m : TargetMetric) : String :=
  match m with
  | .Bbio => "bbio"
  | .Cep => "cep"
  | .CepNr => "cepnr"
  | .Dh => "dh"

def toJsonProfile (p : SearchProfile) : String :=
  match p with
  | .Conservative => "conservative"
  | .Standard => "standard"
  | .Aggressive => "aggressive"

def toJsonCategory (c : BuildingCategory) : String :=
  match c with
  | .MaisonIndividuelle => "maisonIndividuelle"
  | .LogementCollectif => "logementCollectif"
  | .Bureau => "bureau"
  | .EnseignementPrimaireSecondaire => "enseignementPrimaireSecondaire"
  | .Autre => "autre"

def toJsonClimateZone (z : ClimateZone) : String :=
  match z with
  | .H1a => "H1a"
  | .H1b => "H1b"
  | .H1c => "H1c"
  | .H2a => "H2a"
  | .H2b => "H2b"
  | .H2c => "H2c"
  | .H2d => "H2d"
  | .H3 => "H3"

def toJsonEnvelope (e : EnvelopeQuality) : String :=
  match e with
  | .Basic => "basic"
  | .Standard => "standard"
  | .Good => "good"
  | .VeryGood => "verygood"

def toJsonVentilation (v : VentilationQuality) : String :=
  match v with
  | .Natural => "natural"
  | .StandardMechanical => "standardmechanical"
  | .HeatRecovery => "heatrecovery"

def toJsonHeating (h : HeatingChoice) : String :=
  match h with
  | .GasBoiler => "gasboiler"
  | .AirWaterHeatPump => "airwaterheatpump"
  | .AirAirHeatPump => "airairheatpump"
  | .DistrictHeating => "districtheating"
  | .ElectricHeating => "electricheating"

def jsonEscape (s : String) : String :=
  (s.replace "\\" "\\\\").replace "\"" "\\\""

def jsonQuoted (s : String) : String :=
  s!"\"{jsonEscape s}\""

def specToJson (spec : SimplifiedBuildingSpec) : String :=
  let category := toJsonCategory spec.category
  let climateZone := toJsonClimateZone spec.climateZone
  let envelope := toJsonEnvelope spec.envelope
  let ventilation := toJsonVentilation spec.ventilation
  let heating := toJsonHeating spec.heating
  let shading := if spec.shading then "true" else "false"
  "{" ++
    "\"name\":" ++ jsonQuoted spec.name ++
    ",\"category\":" ++ jsonQuoted category ++
    ",\"climateZone\":" ++ jsonQuoted climateZone ++
    ",\"floorArea\":" ++ s!"{spec.floorArea}" ++
    ",\"floors\":" ++ s!"{spec.floors}" ++
    ",\"windowRatio\":" ++ s!"{spec.windowRatio}" ++
    ",\"envelope\":" ++ jsonQuoted envelope ++
    ",\"ventilation\":" ++ jsonQuoted ventilation ++
    ",\"heating\":" ++ jsonQuoted heating ++
    ",\"shading\":" ++ shading ++
  "}"

def indicatorsToJson (i : Indicators) : String :=
  "{" ++
    "\"bbio\":" ++ s!"{i.bbio}" ++
    ",\"cep\":" ++ s!"{i.cep}" ++
    ",\"cepnr\":" ++ s!"{i.cepNr}" ++
    ",\"dh\":" ++ s!"{i.dh}" ++
  "}"

def printResult
    (baseSpec : SimplifiedBuildingSpec)
    (request : SimplifiedTargetRequest)
    (profile : SearchProfile)
    (weights : RetrofitCostWeights)
    (jsonOut? : Option String)
    (strictTarget : Bool) : IO UInt32 := do
  let climate <- loadClimateDataProductionIO baseSpec.climateZone
  let baseEval := evaluateSimplifiedBuilding baseSpec climate
  let recommendation? := bestTargetSuggestionWeighted baseSpec request climate profile weights

  IO.println "=== RE2020 Target Optimization ==="
  IO.println s!"Base spec: {describeSimplifiedBuildingSpec baseSpec}"
  IO.println s!"Base indicators: Bbio={baseEval.indicators.bbio}, Cep={baseEval.indicators.cep}, CepNr={baseEval.indicators.cepNr}, DH={baseEval.indicators.dh}"

  match recommendation? with
  | none =>
      IO.println "No candidate could be generated."
      match jsonOut? with
      | some path =>
          let payload :=
            "{" ++
              "\"status\":\"no_candidate\"," ++
              "\"target\":{" ++
                "\"metric\":" ++ jsonQuoted (toJsonMetric request.metric) ++
                ",\"value\":" ++ s!"{request.targetValue}" ++
              "}," ++
              "\"profile\":" ++ jsonQuoted (toJsonProfile profile) ++ "," ++
              "\"base\":{" ++
                "\"spec\":" ++ specToJson baseSpec ++
                ",\"indicators\":" ++ indicatorsToJson baseEval.indicators ++
              "}" ++
            "}"
          IO.FS.writeFile path payload
      | none => pure ()
      pure 1
  | some recommendation =>
      let recommendationCost := retrofitCost baseSpec recommendation.spec weights
      IO.println s!"Request: metric={repr request.metric}, target={request.targetValue}"
      IO.println s!"Recommendation summary: {describeOptimizationResult recommendation}"
      IO.println s!"Recommendation weighted retrofit cost: {recommendationCost}"
      IO.println s!"Suggested spec: {describeSimplifiedBuildingSpec recommendation.spec}"
      match jsonOut? with
      | some path =>
          let achieved := if recommendation.achieved then "true" else "false"
          let payload :=
            "{" ++
              "\"status\":\"ok\"," ++
              "\"target\":{" ++
                "\"metric\":" ++ jsonQuoted (toJsonMetric request.metric) ++
                ",\"value\":" ++ s!"{request.targetValue}" ++
              "}," ++
              "\"profile\":" ++ jsonQuoted (toJsonProfile profile) ++ "," ++
              "\"weights\":{" ++
                "\"envelope\":" ++ s!"{weights.envelope}" ++
                ",\"ventilation\":" ++ s!"{weights.ventilation}" ++
                ",\"heating\":" ++ s!"{weights.heating}" ++
                ",\"windowRatio\":" ++ s!"{weights.windowRatio}" ++
                ",\"shading\":" ++ s!"{weights.shading}" ++
              "}," ++
              "\"base\":{" ++
                "\"spec\":" ++ specToJson baseSpec ++
                ",\"indicators\":" ++ indicatorsToJson baseEval.indicators ++
              "}," ++
              "\"recommendation\":{" ++
                "\"achieved\":" ++ achieved ++
                ",\"gap\":" ++ s!"{recommendation.gap}" ++
                ",\"changes\":" ++ s!"{recommendation.changes}" ++
                ",\"weightedCost\":" ++ s!"{recommendationCost}" ++
                ",\"spec\":" ++ specToJson recommendation.spec ++
                ",\"indicators\":" ++ indicatorsToJson recommendation.evaluation.indicators ++
              "}" ++
            "}"
          IO.FS.writeFile path payload
      | none => pure ()
      if recommendation.achieved then
        IO.println "Result: target achieved."
        pure 0
      else
        IO.println "Result: target not achieved with current discrete search space."
        if strictTarget then pure 2 else pure 0

end RE2020

open RE2020

def main (args : List String) : IO UInt32 := do
  if args.isEmpty || args.contains "--help" || args.contains "-h" then
    IO.println usage
    return 0

  match parseArgPairs args with
  | Except.error err =>
      IO.eprintln s!"ERROR: {err}"
      IO.eprintln usage
      pure 2
  | Except.ok pairs =>
      match buildSpecAndRequest pairs with
      | Except.error err =>
          IO.eprintln s!"ERROR: {err}"
          IO.eprintln usage
          pure 2
      | Except.ok (spec, request) =>
        match buildProfileAndWeights pairs with
        | Except.error err =>
          IO.eprintln s!"ERROR: {err}"
          IO.eprintln usage
          pure 2
        | Except.ok (profile, weights) =>
          let jsonOut? := findArg pairs "json-out"
          let strictTarget :=
          match findArg pairs "strict-target" with
          | none => false
          | some raw => (parseBool raw).getD false
          printResult spec request profile weights jsonOut? strictTarget
