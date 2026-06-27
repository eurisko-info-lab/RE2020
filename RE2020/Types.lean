/-
  RE2020.Types
  Types de base et énumérations conformes à la réglementation RE2020 / Th-BCE 2020
-/

namespace RE2020

/-- Zones climatiques officielles (France métropolitaine) -/
inductive ClimateZone where
  | H1a | H1b | H1c
  | H2a | H2b | H2c | H2d
  | H3
  deriving Repr, DecidableEq

/-- Catégories de bâtiment selon la réglementation -/
inductive BuildingCategory where
  | MaisonIndividuelle
  | LogementCollectif
  | Bureau
  | EnseignementPrimaireSecondaire
  | Autre
  deriving Repr, DecidableEq

/-- Type d'occupation / usage principal -/
inductive UsageType where
  | Residentiel
  | Tertiaire
  deriving Repr, DecidableEq

/-- Surface de référence utilisée selon le type de bâtiment -/
def referenceSurfaceType (cat : BuildingCategory) : String :=
  match cat with
  | BuildingCategory.MaisonIndividuelle | BuildingCategory.LogementCollectif => "SHAB"
  | _ => "SU"

/-- Coefficients de modulation pour Bbio et Cep (à compléter avec les tables exactes du Guide) -/
structure ModulationCoefficients where
  geo     : Float  -- Mbgéo / Mcgéo
  combles : Float
  surfMoy : Float
  surfTot : Float
  bruit   : Float  -- pour Bbio
  cat     : Float  -- pour Cep (contraintes extérieures)
  deriving Repr

end RE2020
