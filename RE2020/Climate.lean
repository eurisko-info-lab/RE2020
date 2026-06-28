/-
  RE2020.Climate
  Données climatiques et scénarios conventionnels RE2020
  (fichiers météo Météo-France actualisés 2000-2018 + séquence de canicule)
-/

import RE2020.Types
import Std

namespace RE2020

/-- Provenance d'un jeu de donnees climatiques. -/
structure ClimateProvenance where
  sourceFileId : String
  datasetVersion : String
  checksum : String
  method : String
  isOfficialDataset : Bool
  deriving Repr

/-- Donnée horaire climatique de base -/
structure HourlyClimate where
  hour           : Nat          -- 0 .. 8759
  dryBulbTemp    : Float        -- °C
  relativeHumidity : Float
  globalHorizontalRadiation : Float  -- Wh/m²
  directNormalRadiation     : Float
  diffuseHorizontalRadiation : Float
  windSpeed      : Float        -- m/s
  windDirection  : Float        -- degrés
  deriving Repr, Inhabited

/-- Jeu de données climatiques complet pour une année type -/
structure ClimateData where
  zone           : ClimateZone
  hourlyData     : Array HourlyClimate   -- 8760 valeurs
  caniculeSequence : Array HourlyClimate -- séquence des 5 jours de canicule
  provenance     : ClimateProvenance
  deriving Repr

/-- Identifiant de source attendu pour chaque zone climatique. -/
def climateSourceIdForZone (zone : ClimateZone) : String :=
  match zone with
  | .H1a => "FR-RE2020-H1a"
  | .H1b => "FR-RE2020-H1b"
  | .H1c => "FR-RE2020-H1c"
  | .H2a => "FR-RE2020-H2a"
  | .H2b => "FR-RE2020-H2b"
  | .H2c => "FR-RE2020-H2c"
  | .H2d => "FR-RE2020-H2d"
  | .H3  => "FR-RE2020-H3"

/-- Code texte stable d'une zone climatique. -/
def climateZoneCode (zone : ClimateZone) : String :=
  match zone with
  | .H1a => "H1a"
  | .H1b => "H1b"
  | .H1c => "H1c"
  | .H2a => "H2a"
  | .H2b => "H2b"
  | .H2c => "H2c"
  | .H2d => "H2d"
  | .H3 => "H3"

/-- Chemin CSV attendu pour une zone climatique. -/
def climateDatasetCsvPath (zone : ClimateZone) : String :=
  s!"RE2020/data/climate/{climateZoneCode zone}.csv"

/-- Chemin du manifeste de datasets climatiques. -/
def climateDatasetManifestPath : String :=
  "RE2020/data/climate/manifest.json"

/-- Construit des metadonnees de provenance deterministes pour un profil climatique. -/
def mkSyntheticClimateProvenance (zone : ClimateZone) : ClimateProvenance :=
  let sourceId := climateSourceIdForZone zone
  { sourceFileId := sourceId,
    datasetVersion := "synthetic-profile-v1",
    checksum := sourceId ++ ":synthetic-profile-v1",
    method := "deterministic-seasonal-profile",
    isOfficialDataset := false }

/-- Provenance pour un dataset charge depuis fichier CSV. -/
def mkCsvClimateProvenance
    (zone : ClimateZone)
  (_csvPath : String)
    (datasetVersion : String)
    (checksum : String) : ClimateProvenance :=
  { sourceFileId := climateSourceIdForZone zone,
    datasetVersion := datasetVersion,
    checksum := checksum,
    method := "csv-loader-v1",
    isOfficialDataset := true }

private def extractJsonStringAfter? (needle : String) (src : String) : Option String :=
  match src.splitOn needle with
  | _ :: suffix :: _ =>
    match suffix.splitOn "\"" with
    | value :: _ => some value
    | _ => none
  | _ => none

private def loadManifestProvenance? (zone : ClimateZone) : IO (Option (String × String)) := do
  try
    let content <- IO.FS.readFile climateDatasetManifestPath
    let datasetVersion? := extractJsonStringAfter? "\"datasetVersion\": \"" content
    let zoneNeedle := s!"\"{climateZoneCode zone}\":"
    let zoneSection? :=
      match content.splitOn zoneNeedle with
      | _ :: suffix :: _ => some suffix
      | _ => none
    let checksum? := zoneSection?.bind (fun sec => extractJsonStringAfter? "\"sha256\": \"" sec)
    match datasetVersion?, checksum? with
    | some datasetVersion, some checksum =>
      pure (some (datasetVersion, checksum))
    | _, _ =>
      pure none
  catch _ =>
    pure none

private def parseNat? (s : String) : Option Nat :=
  s.trimAscii.toString.toNat?

private def parseInt? (s : String) : Option Int :=
  s.trimAscii.toString.toInt?

private def parseHourlyCsvLine? (line : String) : Option HourlyClimate :=
  let cols := line.splitOn ","
  match cols with
  | [h, tMilli, rhMilli, ghiMilli, dniMilli, dhiMilli, windMilli, windDirMilli] =>
    match parseNat? h, parseInt? tMilli, parseInt? rhMilli, parseInt? ghiMilli,
          parseInt? dniMilli, parseInt? dhiMilli, parseInt? windMilli, parseInt? windDirMilli with
    | some hour, some dryBulbMilli, some relHumMilli, some globalMilli,
      some directMilli, some diffuseMilli, some windSpeedMilli, some windDirectionMilli =>
      some {
        hour := hour,
        dryBulbTemp := Float.ofInt dryBulbMilli / 1000.0,
        relativeHumidity := Float.ofInt relHumMilli / 1000.0,
        globalHorizontalRadiation := Float.ofInt globalMilli / 1000.0,
        directNormalRadiation := Float.ofInt directMilli / 1000.0,
        diffuseHorizontalRadiation := Float.ofInt diffuseMilli / 1000.0,
        windSpeed := Float.ofInt windSpeedMilli / 1000.0,
        windDirection := Float.ofInt windDirectionMilli / 1000.0
      }
    | _, _, _, _, _, _, _, _ => none
  | _ => none

private def parseClimateCsvContent (content : String) : Option (Array HourlyClimate) :=
  let lines :=
    content.splitOn "\n"
    |>.map (fun s => s.trimAscii.toString)
    |>.filter (fun l => !l.isEmpty)
  match lines with
  | _header :: dataLines =>
    let parsed := dataLines.map parseHourlyCsvLine?
    if parsed.any Option.isNone then
      none
    else
      some <| parsed.foldl (fun acc e => acc.push e.get!) #[]
  | [] => none

/-- Paramètres climatiques de base par zone. -/
def zoneClimateParams (zone : ClimateZone) : Float × Float × Float × Float :=
  match zone with
  | .H1a | .H1b | .H1c => (8.5, 10.5, 45.0, 4.0)
  | .H2a | .H2b | .H2c | .H2d => (12.0, 9.0, 43.0, 3.0)
  | .H3 => (16.0, 7.0, 41.0, 2.2)

/-- Génère une donnée climatique horaire à partir d'un profil saisonnier + journalier. -/
def climateAtHour (zone : ClimateZone) (hour : Nat) : HourlyClimate :=
  let day := hour / 24
  let hourOfDay := hour % 24
  let (tMean, seasonalAmp, latitudeDeg, windMean) := zoneClimateParams zone
  let dayF := Float.ofNat day
  let hourF := Float.ofNat hourOfDay
  let pi := 3.141592653589793
  let twoPi := 2.0 * pi

  -- Température extérieure: composante saisonnière + oscillation diurne.
  let seasonal := seasonalAmp * Float.sin (twoPi * (dayF - 81.0) / 365.0)
  let diurnal := 4.0 * Float.sin (twoPi * (hourF - 8.0) / 24.0)
  let dryBulb := tMean + seasonal + diurnal

  let humidityBase := 62.0 - 0.65 * (dryBulb - tMean)
  let relativeHumidity := max 20.0 (min 98.0 humidityBase)

  let daylight := max 0.0 (Float.sin (pi * (hourF - 6.0) / 12.0))
  let summerBoost := max 0.15 (0.65 + 0.35 * Float.sin (twoPi * (dayF - 81.0) / 365.0))
  let global := 900.0 * daylight * summerBoost
  let direct := global * 0.72
  let diffuse := global * 0.28

  let windSpeed := max 0.2 (windMean + 1.1 * Float.sin (twoPi * hourF / 24.0))
  let windDirection := (180.0 + 30.0 * Float.sin (twoPi * dayF / 7.0) + latitudeDeg / 10.0)

  { hour := hour,
    dryBulbTemp := dryBulb,
    relativeHumidity := relativeHumidity,
    globalHorizontalRadiation := global,
    directNormalRadiation := direct,
    diffuseHorizontalRadiation := diffuse,
    windSpeed := windSpeed,
    windDirection := windDirection }

/-- Extrait une fenêtre de 5 jours consécutifs la plus chaude de l'année. -/
def extractCaniculeSequence (hourlyData : Array HourlyClimate) : Array HourlyClimate :=
  let window := 5 * 24
  if _h : hourlyData.size <= window then
    hourlyData
  else
    let lastStart := hourlyData.size - window
    let starts := List.range (lastStart + 1)
    let (bestStart, _) :=
      starts.foldl
        (fun (best : Nat × Float) s =>
          let avg :=
            (List.range window).foldl
              (fun acc k => acc + hourlyData[s + k]!.dryBulbTemp)
              0.0 / Float.ofNat window
          if avg > best.2 then (s, avg) else best)
        (0, -1000.0)
    hourlyData.extract bestStart (bestStart + window)

/-- Validation physique minimale d'un point climatique horaire. -/
def validateHourlyClimate (h : HourlyClimate) : List String :=
  let errors := ([] : List String)
  let errors :=
    if h.hour < 8760 then errors else "hour out of range [0,8759]" :: errors
  let errors :=
    if h.relativeHumidity >= 0.0 && h.relativeHumidity <= 100.0 then errors
    else "relativeHumidity out of range [0,100]" :: errors
  let errors :=
    if h.globalHorizontalRadiation >= 0.0 then errors
    else "globalHorizontalRadiation must be >= 0" :: errors
  let errors :=
    if h.directNormalRadiation >= 0.0 then errors
    else "directNormalRadiation must be >= 0" :: errors
  let errors :=
    if h.diffuseHorizontalRadiation >= 0.0 then errors
    else "diffuseHorizontalRadiation must be >= 0" :: errors
  let errors :=
    if h.windSpeed >= 0.0 then errors
    else "windSpeed must be >= 0" :: errors
  let errors :=
    if h.windDirection >= 0.0 && h.windDirection <= 360.0 then errors
    else "windDirection out of range [0,360]" :: errors
  errors.reverse

/-- Vérifie la structure attendue d'un jeu de donnees climatiques annuel RE2020. -/
def validateClimateData (data : ClimateData) : List String :=
  let errors := ([] : List String)
  let errors :=
    if data.hourlyData.size == 8760 then errors
    else s!"hourlyData size must be 8760, got {data.hourlyData.size}" :: errors
  let errors :=
    if data.caniculeSequence.size == 120 then errors
    else s!"caniculeSequence size must be 120, got {data.caniculeSequence.size}" :: errors
  let errors :=
    if data.provenance.sourceFileId.isEmpty then "sourceFileId is empty" :: errors else errors
  let errors :=
    if data.provenance.datasetVersion.isEmpty then "datasetVersion is empty" :: errors else errors
  let errors :=
    if data.provenance.checksum.isEmpty then "checksum is empty" :: errors else errors
  let sampleStep := 2190
  let sampledHours := [0, sampleStep, sampleStep * 2, sampleStep * 3, 8759]
  let sampledErrors :=
    sampledHours.foldl
      (fun acc i =>
        if _h : i < data.hourlyData.size then
          acc ++ (validateHourlyClimate data.hourlyData[i]!).map (fun e => s!"hour {i}: {e}")
        else
          acc)
      ([] : List String)
  (errors.reverse) ++ sampledErrors

/-- Predicate utilitaire pour gate binaire pass/fail. -/
def isClimateDataValid (data : ClimateData) : Bool :=
  (validateClimateData data).isEmpty

/-- Génère des données climatiques complètes et cohérentes pour la simulation annuelle. -/
def loadClimateData (zone : ClimateZone) : ClimateData :=
  let hourlyData := (List.range 8760).foldl (fun acc h => acc.push (climateAtHour zone h)) #[]
  let caniculeSequence := extractCaniculeSequence hourlyData
  { zone := zone,
    hourlyData := hourlyData,
    caniculeSequence := caniculeSequence,
    provenance := mkSyntheticClimateProvenance zone }

/-- Charge les donnees climatiques depuis CSV (IO) avec validation structurelle. -/
def loadClimateDataFromCsv? (zone : ClimateZone) : IO (Option ClimateData) := do
  let path := climateDatasetCsvPath zone
  try
    let content <- IO.FS.readFile path
    match parseClimateCsvContent content with
    | none =>
      pure none
    | some hourlyData =>
      let manifestProv? <- loadManifestProvenance? zone
      let some (datasetVersion, checksum) := manifestProv? | pure none
      let climate : ClimateData :=
        { zone := zone,
          hourlyData := hourlyData,
          caniculeSequence := extractCaniculeSequence hourlyData,
          provenance := mkCsvClimateProvenance zone path datasetVersion checksum }
      if isClimateDataValid climate then
        pure (some climate)
      else
        pure none
  catch _ =>
    pure none

/-- Charge depuis CSV et échoue si le dataset est absent/invalide. -/
def loadClimateDataIO (zone : ClimateZone) : IO ClimateData := do
  let maybeCsv <- loadClimateDataFromCsv? zone
  match maybeCsv with
  | some climate => pure climate
  | none =>
    throw <| IO.userError s!
      "Climate dataset missing or invalid for zone {climateZoneCode zone} at {climateDatasetCsvPath zone}"

/-- Charge strictement depuis CSV pour le chemin de production (pas de fallback). -/
def loadClimateDataProductionIO (zone : ClimateZone) : IO ClimateData := do
  let maybeCsv <- loadClimateDataFromCsv? zone
  match maybeCsv with
  | some climate => pure climate
  | none =>
    throw <| IO.userError s!
      "Climate dataset missing or invalid for zone {climateZoneCode zone} at {climateDatasetCsvPath zone}"

end RE2020
