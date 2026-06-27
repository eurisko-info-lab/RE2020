/-
  RE2020.Climate
  Données climatiques et scénarios conventionnels RE2020
  (fichiers météo Météo-France actualisés 2000-2018 + séquence de canicule)
-/

import RE2020.Types

namespace RE2020

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
  deriving Repr

/-- Jeu de données climatiques complet pour une année type -/
structure ClimateData where
  zone           : ClimateZone
  hourlyData     : Array HourlyClimate   -- 8760 valeurs
  caniculeSequence : Array HourlyClimate -- séquence des 5 jours de canicule
  deriving Repr

/-- Chargement / génération des données climatiques (à implémenter avec vrais fichiers) -/
def loadClimateData (zone : ClimateZone) : ClimateData :=
  -- Placeholder : à remplacer par lecture de fichiers officiels
  { zone := zone,
    hourlyData := Array.replicate 8760 {
      hour := 0, dryBulbTemp := 10.0, relativeHumidity := 70.0,
      globalHorizontalRadiation := 0.0, directNormalRadiation := 0.0,
      diffuseHorizontalRadiation := 0.0, windSpeed := 2.0, windDirection := 180.0
    },
    caniculeSequence := Array.replicate (5*24) {
      hour := 0, dryBulbTemp := 30.0, relativeHumidity := 50.0,
      globalHorizontalRadiation := 800.0, directNormalRadiation := 600.0,
      diffuseHorizontalRadiation := 200.0, windSpeed := 1.5, windDirection := 200.0
    }
  }

end RE2020
