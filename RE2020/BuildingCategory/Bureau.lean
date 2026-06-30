/-
  RE2020.BuildingCategory.Bureau
  Surface publique pour les bureaux.
-/

import RE2020.BuildingCategory.Common

namespace RE2020

/-- Delta d'indicateurs pour un bureau. -/
abbrev BureauIndicatorDelta := IndicatorDelta

/-- Comparaison avant/apres ajout de climatisation reversible. -/
abbrev BureauReversibleAcComparison := ReversibleAcIndicatorComparison

/-- Package systeme reutilise pour les bureaux. -/
abbrev BureauSystemsPackage := ResilienceSystemsPackage

/-- Calcul des indicateurs pour un bureau avec un package systeme donne. -/
def computeBureauIndicatorsWithSystems
    (building : Building)
    (climate : ClimateData)
    (systems : BureauSystemsPackage := defaultResilienceSystemsPackage)
    (convention : CepConvention := .CurrentRE2020) : Indicators :=
  computeIndicatorsWithResilienceSystems building climate systems convention

/-- Compare les indicateurs avec et sans climatisation reversible pour un bureau. -/
def compareBureauWithoutVsWithReversibleAc
    (building : Building)
    (climate : ClimateData)
    (systemsWithAc : BureauSystemsPackage := defaultResilienceSystemsPackage)
    (convention : CepConvention := .CurrentRE2020) : BureauReversibleAcComparison :=
  compareIndicatorsWithoutVsWithReversibleAc building climate systemsWithAc convention

end RE2020
