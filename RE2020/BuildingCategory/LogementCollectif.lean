/-
  RE2020.BuildingCategory.LogementCollectif
  Surface publique pour les logements collectifs.
-/

import RE2020.BuildingCategory.Common

namespace RE2020

/-- Delta d'indicateurs pour un logement collectif. -/
abbrev LogementCollectifIndicatorDelta := IndicatorDelta

/-- Comparaison avant/apres ajout de climatisation reversible. -/
abbrev LogementCollectifReversibleAcComparison := ReversibleAcIndicatorComparison

/-- Package systeme reutilise pour les logements collectifs. -/
abbrev LogementCollectifSystemsPackage := ResilienceSystemsPackage

/-- Calcul des indicateurs pour un logement collectif avec un package systeme donne. -/
def computeLogementCollectifIndicatorsWithSystems
    (building : Building)
    (climate : ClimateData)
    (systems : LogementCollectifSystemsPackage := defaultResilienceSystemsPackage)
    (convention : CepConvention := .CurrentRE2020) : Indicators :=
  computeIndicatorsWithResilienceSystems building climate systems convention

/-- Compare les indicateurs avec et sans climatisation reversible pour un logement collectif. -/
def compareLogementCollectifWithoutVsWithReversibleAc
    (building : Building)
    (climate : ClimateData)
    (systemsWithAc : LogementCollectifSystemsPackage := defaultResilienceSystemsPackage)
    (convention : CepConvention := .CurrentRE2020) : LogementCollectifReversibleAcComparison :=
  compareIndicatorsWithoutVsWithReversibleAc building climate systemsWithAc convention

end RE2020
