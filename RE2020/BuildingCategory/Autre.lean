/-
  RE2020.BuildingCategory.Autre
  Surface publique pour les categories residuelles.
-/

import RE2020.BuildingCategory.Common

namespace RE2020

/-- Delta d'indicateurs pour une categorie autre. -/
abbrev AutreIndicatorDelta := IndicatorDelta

/-- Comparaison avant/apres ajout de climatisation reversible. -/
abbrev AutreReversibleAcComparison := ReversibleAcIndicatorComparison

/-- Package systeme reutilise pour la categorie autre. -/
abbrev AutreSystemsPackage := ResilienceSystemsPackage

/-- Calcul des indicateurs pour une categorie autre avec un package systeme donne. -/
def computeAutreIndicatorsWithSystems
    (building : Building)
    (climate : ClimateData)
    (systems : AutreSystemsPackage := defaultResilienceSystemsPackage)
    (convention : CepConvention := .CurrentRE2020) : Indicators :=
  computeIndicatorsWithResilienceSystems building climate systems convention

/-- Compare les indicateurs avec et sans climatisation reversible pour une categorie autre. -/
def compareAutreWithoutVsWithReversibleAc
    (building : Building)
    (climate : ClimateData)
    (systemsWithAc : AutreSystemsPackage := defaultResilienceSystemsPackage)
    (convention : CepConvention := .CurrentRE2020) : AutreReversibleAcComparison :=
  compareIndicatorsWithoutVsWithReversibleAc building climate systemsWithAc convention

end RE2020
