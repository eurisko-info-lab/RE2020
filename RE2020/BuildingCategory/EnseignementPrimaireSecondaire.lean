/-
  RE2020.BuildingCategory.EnseignementPrimaireSecondaire
  Surface publique pour l'enseignement primaire et secondaire.
-/

import RE2020.BuildingCategory.Common

namespace RE2020

/-- Delta d'indicateurs pour un batiment d'enseignement primaire/secondaire. -/
abbrev EnseignementPrimaireSecondaireIndicatorDelta := IndicatorDelta

/-- Comparaison avant/apres ajout de climatisation reversible. -/
abbrev EnseignementPrimaireSecondaireReversibleAcComparison := ReversibleAcIndicatorComparison

/-- Package systeme reutilise pour l'enseignement primaire/secondaire. -/
abbrev EnseignementPrimaireSecondaireSystemsPackage := ResilienceSystemsPackage

/-- Calcul des indicateurs pour un batiment d'enseignement avec un package systeme donne. -/
def computeEnseignementPrimaireSecondaireIndicatorsWithSystems
    (building : Building)
    (climate : ClimateData)
    (systems : EnseignementPrimaireSecondaireSystemsPackage := defaultResilienceSystemsPackage)
    (convention : CepConvention := .CurrentRE2020) : Indicators :=
  computeIndicatorsWithResilienceSystems building climate systems convention

/-- Compare les indicateurs avec et sans climatisation reversible pour un batiment d'enseignement. -/
def compareEnseignementPrimaireSecondaireWithoutVsWithReversibleAc
    (building : Building)
    (climate : ClimateData)
    (systemsWithAc : EnseignementPrimaireSecondaireSystemsPackage := defaultResilienceSystemsPackage)
    (convention : CepConvention := .CurrentRE2020) : EnseignementPrimaireSecondaireReversibleAcComparison :=
  compareIndicatorsWithoutVsWithReversibleAc building climate systemsWithAc convention

end RE2020
