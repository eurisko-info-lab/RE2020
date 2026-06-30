import Mathlib
import RE2020.FormalTheorems

namespace RE2020

/-
  Mathlib-powered bridge layer:
  - keeps the fully proved Nat model from FormalTheorems,
  - provides Real-valued counterparts with richer order lemmas,
  - links both via coercions.
-/

/-- Real-valued net imported energy with physical floor at zero. -/
def netUseR (gross localProduction : Real) : Real :=
  max 0 (gross - localProduction)

/-- Real-valued discomfort accumulation with unmet cooling. -/
def discomfortR (baseDh unmetCooling dhPerUnmet : Real) : Real :=
  baseDh + unmetCooling * dhPerUnmet

/-- Real-valued Cep-like indicator. -/
def cepLikeR
    (heating dhw cooling lighting auxiliaries : Real)
    (fHeating fDhw fCooling fLighting fAux : Real)
    (modulation : Real) : Real :=
  modulation *
    (heating * fHeating +
      dhw * fDhw +
      cooling * fCooling +
      lighting * fLighting +
      auxiliaries * fAux)

/-- Real-valued non-renewable Cep-like indicator. -/
def cepNrLikeR
    (heating dhw cooling lighting auxiliaries : Real)
    (fHeating fDhw fCooling fLighting fAux : Real) : Real :=
  heating * fHeating +
    dhw * fDhw +
    cooling * fCooling +
    lighting * fLighting +
    auxiliaries * fAux

/-- Real-valued Bbio-like indicator. -/
def bbioLikeR
    (heatingNeed coolingNeed lightingNeed wHeating wCooling wLighting modulation : Real) : Real :=
  modulation * (wHeating * heatingNeed + wCooling * coolingNeed + wLighting * lightingNeed)

/-- Real net use is always nonnegative by construction. -/
theorem netUseR_nonneg (gross localProduction : Real) :
    0 <= netUseR gross localProduction := by
  unfold netUseR
  exact le_max_left _ _

/-- Real net use is bounded above by gross when local production is nonnegative. -/
theorem netUseR_le_gross
    (gross localProduction : Real)
    (hLocalNonneg : 0 <= localProduction) :
    netUseR gross localProduction <= max 0 gross := by
  unfold netUseR
  have hSub : gross - localProduction <= gross := by linarith
  exact max_le_max (le_rfl) hSub

/-- Real discomfort is monotone in unmet cooling when penalty is nonnegative. -/
theorem discomfortR_monotone_unmet
    (baseDh u1 u2 dhPerUnmet : Real)
    (hUnmet : u1 <= u2)
    (hPenaltyNonneg : 0 <= dhPerUnmet) :
    discomfortR baseDh u1 dhPerUnmet <= discomfortR baseDh u2 dhPerUnmet := by
  unfold discomfortR
  nlinarith [mul_le_mul_of_nonneg_right hUnmet hPenaltyNonneg]

/-- Real Cep-like equals Real CepNr-like when modulation is one. -/
theorem cepLikeR_eq_cepNrLikeR_if_modulation_one
    (heating dhw cooling lighting auxiliaries fHeating fDhw fCooling fLighting fAux : Real) :
    cepLikeR heating dhw cooling lighting auxiliaries fHeating fDhw fCooling fLighting fAux 1 =
      cepNrLikeR heating dhw cooling lighting auxiliaries fHeating fDhw fCooling fLighting fAux := by
  unfold cepLikeR cepNrLikeR
  ring

/-- Nat-model netUse theorem transported to Real via coercion. -/
theorem nat_netUse_cast_le
    (gross localProduction : E) :
    ((netUse gross localProduction : Nat) : Real) <= (gross : Real) := by
  exact_mod_cast netUse_le_gross gross localProduction

/-- Nat-model discomfort theorem transported to Real via coercion. -/
theorem nat_discomfort_cast_ge_base
    (baseDh unmetCooling dhPerUnmet : E) :
    (baseDh : Real) <= ((discomfortWithUnmetCooling baseDh unmetCooling dhPerUnmet : Nat) : Real) := by
  exact_mod_cast discomfort_ge_base baseDh unmetCooling dhPerUnmet

end RE2020
