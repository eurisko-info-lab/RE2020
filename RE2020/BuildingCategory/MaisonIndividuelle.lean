/-
  RE2020.BuildingCategory.MaisonIndividuelle
  Surface publique pour les maisons individuelles.
-/

import RE2020.BuildingCategory.Common

namespace RE2020

/-- Delta d'indicateurs pour une maison individuelle. -/
abbrev MaisonIndividuelleIndicatorDelta := IndicatorDelta

/-- Comparaison avant/apres ajout de climatisation reversible. -/
abbrev MaisonIndividuelleReversibleAcComparison := ReversibleAcIndicatorComparison

/-- Package systeme maison individuelle utilisant le modele reversible. -/
abbrev MaisonIndividuelleSystemsPackage := ResilienceSystemsPackage

/-- Calcul des indicateurs pour une maison individuelle avec un package systeme donne. -/
def computeMaisonIndividuelleIndicatorsWithSystems
    (building : Building)
    (climate : ClimateData)
    (systems : MaisonIndividuelleSystemsPackage := defaultResilienceSystemsPackage)
    (convention : CepConvention := .CurrentRE2020) : Indicators :=
  computeIndicatorsWithResilienceSystems building climate systems convention

/-- Compare les indicateurs avec et sans climatisation reversible pour une maison individuelle. -/
def compareMaisonIndividuelleWithoutVsWithReversibleAc
    (building : Building)
    (climate : ClimateData)
    (systemsWithAc : MaisonIndividuelleSystemsPackage := defaultResilienceSystemsPackage)
    (convention : CepConvention := .CurrentRE2020) : MaisonIndividuelleReversibleAcComparison :=
  compareIndicatorsWithoutVsWithReversibleAc building climate systemsWithAc convention

end RE2020
