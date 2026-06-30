import RE2020.Types

namespace RE2020

/-
  Formal theorem layer (fully proved, no sorry) over a discrete energy model.

  We model annual quantities as natural numbers (e.g. Wh or deci-kWh units).
  This keeps proofs robust in core Lean while preserving the key invariants:
  non-negativity, monotonicity, and boundedness.
-/

abbrev E := Nat

/-- Net imported energy after local production allocation. -/
def netUse (gross localProduction : E) : E :=
  gross - localProduction

/-- Discomfort accumulation with unmet cooling contribution. -/
def discomfortWithUnmetCooling (baseDh unmetCooling dhPerUnmet : E) : E :=
  baseDh + unmetCooling * dhPerUnmet

/-- RE2020-like Cep surrogate over fixed end uses. -/
def cepLike
    (heating dhw cooling lighting auxiliaries : E)
    (fHeating fDhw fCooling fLighting fAux : E)
    (modulation : E) : E :=
  modulation *
    (heating * fHeating +
      dhw * fDhw +
      cooling * fCooling +
      lighting * fLighting +
      auxiliaries * fAux)

/-- Non-renewable Cep surrogate over fixed end uses. -/
def cepNrLike
    (heating dhw cooling lighting auxiliaries : E)
    (fHeating fDhw fCooling fLighting fAux : E) : E :=
  heating * fHeating +
    dhw * fDhw +
    cooling * fCooling +
    lighting * fLighting +
    auxiliaries * fAux

/-- Bbio surrogate with additive needs and weights. -/
def bbioLike
    (heatingNeed coolingNeed lightingNeed wHeating wCooling wLighting modulation : E) : E :=
  modulation * (wHeating * heatingNeed + wCooling * coolingNeed + wLighting * lightingNeed)

/-- Net imported energy is always bounded above by gross energy. -/
theorem netUse_le_gross (gross localProduction : E) :
    netUse gross localProduction <= gross := by
  unfold netUse
  exact Nat.sub_le _ _

/-- If local production covers gross needs, imported energy is zero. -/
theorem netUse_zero_if_production_covers
  (gross localProduction : E)
  (hCover : gross <= localProduction) :
    netUse gross localProduction = 0 := by
  unfold netUse
  exact Nat.sub_eq_zero_of_le hCover

/-- More local production cannot increase imported energy. -/
theorem netUse_monotone_localProduction
  (gross p1 p2 : E)
  (hProd : p1 <= p2) :
    netUse gross p2 <= netUse gross p1 := by
  unfold netUse
  exact Nat.sub_le_sub_left hProd _

/-- Imported energy sum is bounded by gross sum. -/
theorem netUse_split_bound (gross1 local1 gross2 local2 : E) :
    netUse gross1 local1 + netUse gross2 local2 <= gross1 + gross2 := by
  have h1 : netUse gross1 local1 <= gross1 := netUse_le_gross gross1 local1
  have h2 : netUse gross2 local2 <= gross2 := netUse_le_gross gross2 local2
  exact Nat.add_le_add h1 h2

/-- Without local production, imported energy equals gross energy. -/
theorem netUse_eq_gross_if_no_localProduction (gross : E) :
    netUse gross 0 = gross := by
  unfold netUse
  simp

/-- If local production does not exceed gross demand, subtraction preserves balance. -/
theorem netUse_add_local_eq_gross
    (gross localProduction : E)
    (hLe : localProduction <= gross) :
    netUse gross localProduction + localProduction = gross := by
  unfold netUse
  exact Nat.sub_add_cancel hLe

/-- Net imported energy is monotone in gross demand. -/
theorem netUse_monotone_gross
    (g1 g2 localProduction : E)
    (hGross : g1 <= g2) :
    netUse g1 localProduction <= netUse g2 localProduction := by
  unfold netUse
  exact Nat.sub_le_sub_right hGross _

/-- Discomfort is monotone in unmet cooling. -/
theorem discomfort_monotone_unmet
  (baseDh u1 u2 dhPerUnmet : E)
  (hUnmet : u1 <= u2) :
    discomfortWithUnmetCooling baseDh u1 dhPerUnmet <=
      discomfortWithUnmetCooling baseDh u2 dhPerUnmet := by
  unfold discomfortWithUnmetCooling
  have hMul : u1 * dhPerUnmet <= u2 * dhPerUnmet := Nat.mul_le_mul_right _ hUnmet
  exact Nat.add_le_add_left hMul _

/-- Discomfort is monotone in penalty coefficient. -/
theorem discomfort_monotone_penalty
  (baseDh unmetCooling c1 c2 : E)
  (hCoeff : c1 <= c2) :
    discomfortWithUnmetCooling baseDh unmetCooling c1 <=
      discomfortWithUnmetCooling baseDh unmetCooling c2 := by
  unfold discomfortWithUnmetCooling
  have hMul : unmetCooling * c1 <= unmetCooling * c2 := Nat.mul_le_mul_left _ hCoeff
  exact Nat.add_le_add_left hMul _

/-- No unmet cooling means no additional discomfort penalty. -/
theorem discomfort_no_unmet
    (baseDh dhPerUnmet : E) :
    discomfortWithUnmetCooling baseDh 0 dhPerUnmet = baseDh := by
  unfold discomfortWithUnmetCooling
  simp

/-- Discomfort is always at least the base discomfort level. -/
theorem discomfort_ge_base
    (baseDh unmetCooling dhPerUnmet : E) :
    baseDh <= discomfortWithUnmetCooling baseDh unmetCooling dhPerUnmet := by
  unfold discomfortWithUnmetCooling
  exact Nat.le_add_right _ _

/-- Cep-like indicator is monotone in heating end-use. -/
theorem cepLike_monotone_heating
  (h1 h2 dhw cooling lighting auxiliaries fHeating fDhw fCooling fLighting fAux modulation : E)
  (hHeat : h1 <= h2) :
    cepLike h1 dhw cooling lighting auxiliaries fHeating fDhw fCooling fLighting fAux modulation <=
      cepLike h2 dhw cooling lighting auxiliaries fHeating fDhw fCooling fLighting fAux modulation := by
  unfold cepLike
  have hTerm : h1 * fHeating <= h2 * fHeating := Nat.mul_le_mul_right _ hHeat
  have hInner :
      h1 * fHeating + dhw * fDhw + cooling * fCooling + lighting * fLighting + auxiliaries * fAux <=
      h2 * fHeating + dhw * fDhw + cooling * fCooling + lighting * fLighting + auxiliaries * fAux := by
    exact Nat.add_le_add_right (Nat.add_le_add_right (Nat.add_le_add_right (Nat.add_le_add_right hTerm _) _) _) _
  exact Nat.mul_le_mul_left _ hInner

/-- Cep-like indicator is monotone in modulation factor. -/
theorem cepLike_monotone_modulation
    (heating dhw cooling lighting auxiliaries fHeating fDhw fCooling fLighting fAux m1 m2 : E)
    (hMod : m1 <= m2) :
    cepLike heating dhw cooling lighting auxiliaries fHeating fDhw fCooling fLighting fAux m1 <=
      cepLike heating dhw cooling lighting auxiliaries fHeating fDhw fCooling fLighting fAux m2 := by
  unfold cepLike
  exact Nat.mul_le_mul_right _ hMod

/-- Zero modulation cancels Cep-like contribution. -/
theorem cepLike_eq_zero_if_modulation_zero
    (heating dhw cooling lighting auxiliaries fHeating fDhw fCooling fLighting fAux : E) :
    cepLike heating dhw cooling lighting auxiliaries fHeating fDhw fCooling fLighting fAux 0 = 0 := by
  unfold cepLike
  simp

/-- Unit modulation makes Cep-like equal to the inner weighted sum. -/
theorem cepLike_eq_inner_if_modulation_one
    (heating dhw cooling lighting auxiliaries fHeating fDhw fCooling fLighting fAux : E) :
    cepLike heating dhw cooling lighting auxiliaries fHeating fDhw fCooling fLighting fAux 1 =
      (heating * fHeating + dhw * fDhw + cooling * fCooling + lighting * fLighting + auxiliaries * fAux) := by
  unfold cepLike
  simp

/-- Unit modulation makes Cep-like equal to CepNr-like. -/
theorem cepLike_eq_cepNrLike_if_modulation_one
    (heating dhw cooling lighting auxiliaries fHeating fDhw fCooling fLighting fAux : E) :
    cepLike heating dhw cooling lighting auxiliaries fHeating fDhw fCooling fLighting fAux 1 =
      cepNrLike heating dhw cooling lighting auxiliaries fHeating fDhw fCooling fLighting fAux := by
  unfold cepLike cepNrLike
  simp

/-- Cep-like indicator is monotone in cooling end-use. -/
theorem cepLike_monotone_cooling
    (cool1 cool2 heating dhw lighting auxiliaries fHeating fDhw fCooling fLighting fAux modulation : E)
    (hCool : cool1 <= cool2) :
    cepLike heating dhw cool1 lighting auxiliaries fHeating fDhw fCooling fLighting fAux modulation <=
      cepLike heating dhw cool2 lighting auxiliaries fHeating fDhw fCooling fLighting fAux modulation := by
  unfold cepLike
  have hTerm : cool1 * fCooling <= cool2 * fCooling := Nat.mul_le_mul_right _ hCool
  have hMid :
      (heating * fHeating + dhw * fDhw) + cool1 * fCooling <=
      (heating * fHeating + dhw * fDhw) + cool2 * fCooling :=
    Nat.add_le_add_left hTerm _
  have hInner :
      ((heating * fHeating + dhw * fDhw) + cool1 * fCooling) +
          (lighting * fLighting + auxiliaries * fAux) <=
        ((heating * fHeating + dhw * fDhw) + cool2 * fCooling) +
          (lighting * fLighting + auxiliaries * fAux) :=
    Nat.add_le_add_right hMid _
  have hInner' :
      heating * fHeating + dhw * fDhw + cool1 * fCooling + lighting * fLighting + auxiliaries * fAux <=
      heating * fHeating + dhw * fDhw + cool2 * fCooling + lighting * fLighting + auxiliaries * fAux := by
    simpa [Nat.add_assoc] using hInner
  exact Nat.mul_le_mul_left _ hInner'

/-- Cep-like indicator is monotone in DHW end-use. -/
theorem cepLike_monotone_dhw
    (dhw1 dhw2 heating cooling lighting auxiliaries fHeating fDhw fCooling fLighting fAux modulation : E)
    (hDhw : dhw1 <= dhw2) :
    cepLike heating dhw1 cooling lighting auxiliaries fHeating fDhw fCooling fLighting fAux modulation <=
      cepLike heating dhw2 cooling lighting auxiliaries fHeating fDhw fCooling fLighting fAux modulation := by
  unfold cepLike
  have hTerm : dhw1 * fDhw <= dhw2 * fDhw := Nat.mul_le_mul_right _ hDhw
  have hMid :
      (heating * fHeating + dhw1 * fDhw) + cooling * fCooling <=
      (heating * fHeating + dhw2 * fDhw) + cooling * fCooling := by
    have hLeft : heating * fHeating + dhw1 * fDhw <= heating * fHeating + dhw2 * fDhw :=
      Nat.add_le_add_left hTerm _
    exact Nat.add_le_add_right hLeft _
  have hInner :
      ((heating * fHeating + dhw1 * fDhw) + cooling * fCooling) +
          (lighting * fLighting + auxiliaries * fAux) <=
        ((heating * fHeating + dhw2 * fDhw) + cooling * fCooling) +
          (lighting * fLighting + auxiliaries * fAux) :=
    Nat.add_le_add_right hMid _
  have hInner' :
      heating * fHeating + dhw1 * fDhw + cooling * fCooling + lighting * fLighting + auxiliaries * fAux <=
      heating * fHeating + dhw2 * fDhw + cooling * fCooling + lighting * fLighting + auxiliaries * fAux := by
    simpa [Nat.add_assoc] using hInner
  exact Nat.mul_le_mul_left _ hInner'

/-- Cep-like indicator is monotone in lighting end-use. -/
theorem cepLike_monotone_lighting
    (l1 l2 heating dhw cooling auxiliaries fHeating fDhw fCooling fLighting fAux modulation : E)
    (hLight : l1 <= l2) :
    cepLike heating dhw cooling l1 auxiliaries fHeating fDhw fCooling fLighting fAux modulation <=
      cepLike heating dhw cooling l2 auxiliaries fHeating fDhw fCooling fLighting fAux modulation := by
  unfold cepLike
  have hTerm : l1 * fLighting <= l2 * fLighting := Nat.mul_le_mul_right _ hLight
  have hInner :
      (heating * fHeating + dhw * fDhw + cooling * fCooling) + (l1 * fLighting + auxiliaries * fAux) <=
      (heating * fHeating + dhw * fDhw + cooling * fCooling) + (l2 * fLighting + auxiliaries * fAux) := by
    have hRight : l1 * fLighting + auxiliaries * fAux <= l2 * fLighting + auxiliaries * fAux :=
      Nat.add_le_add_right hTerm _
    exact Nat.add_le_add_left hRight _
  have hInner' :
      heating * fHeating + dhw * fDhw + cooling * fCooling + l1 * fLighting + auxiliaries * fAux <=
      heating * fHeating + dhw * fDhw + cooling * fCooling + l2 * fLighting + auxiliaries * fAux := by
    simpa [Nat.add_assoc] using hInner
  exact Nat.mul_le_mul_left _ hInner'

/-- Cep-like indicator is monotone in auxiliaries end-use. -/
theorem cepLike_monotone_auxiliaries
    (a1 a2 heating dhw cooling lighting fHeating fDhw fCooling fLighting fAux modulation : E)
    (hAux : a1 <= a2) :
    cepLike heating dhw cooling lighting a1 fHeating fDhw fCooling fLighting fAux modulation <=
      cepLike heating dhw cooling lighting a2 fHeating fDhw fCooling fLighting fAux modulation := by
  unfold cepLike
  have hTerm : a1 * fAux <= a2 * fAux := Nat.mul_le_mul_right _ hAux
  have hInner :
      (heating * fHeating + dhw * fDhw + cooling * fCooling + lighting * fLighting) + a1 * fAux <=
      (heating * fHeating + dhw * fDhw + cooling * fCooling + lighting * fLighting) + a2 * fAux :=
    Nat.add_le_add_left hTerm _
  have hInner' :
      heating * fHeating + dhw * fDhw + cooling * fCooling + lighting * fLighting + a1 * fAux <=
      heating * fHeating + dhw * fDhw + cooling * fCooling + lighting * fLighting + a2 * fAux := by
    simpa [Nat.add_assoc] using hInner
  exact Nat.mul_le_mul_left _ hInner'

/-- Cep-like is bounded above by modulation times the sum with zeroed factors replaced by one-step upper factors. -/
theorem cepLike_le_modulation_times_cepNrLike
    (heating dhw cooling lighting auxiliaries fHeating fDhw fCooling fLighting fAux modulation : E) :
    cepLike heating dhw cooling lighting auxiliaries fHeating fDhw fCooling fLighting fAux modulation <=
      modulation * cepNrLike heating dhw cooling lighting auxiliaries fHeating fDhw fCooling fLighting fAux := by
  unfold cepLike cepNrLike
  exact Nat.le_refl _

/-- CepNr-like indicator is monotone in heating end-use. -/
theorem cepNrLike_monotone_heating
  (h1 h2 dhw cooling lighting auxiliaries fHeating fDhw fCooling fLighting fAux : E)
  (hHeat : h1 <= h2) :
    cepNrLike h1 dhw cooling lighting auxiliaries fHeating fDhw fCooling fLighting fAux <=
      cepNrLike h2 dhw cooling lighting auxiliaries fHeating fDhw fCooling fLighting fAux := by
  unfold cepNrLike
  have hTerm : h1 * fHeating <= h2 * fHeating := Nat.mul_le_mul_right _ hHeat
  have hRest :
      dhw * fDhw + cooling * fCooling + lighting * fLighting + auxiliaries * fAux <=
      dhw * fDhw + cooling * fCooling + lighting * fLighting + auxiliaries * fAux := Nat.le_refl _
  have hInner :
      h1 * fHeating + (dhw * fDhw + cooling * fCooling + lighting * fLighting + auxiliaries * fAux) <=
      h2 * fHeating + (dhw * fDhw + cooling * fCooling + lighting * fLighting + auxiliaries * fAux) :=
    Nat.add_le_add hTerm hRest
  simpa [Nat.add_assoc] using hInner

/-- Bbio-like indicator is monotone in heating need. -/
theorem bbioLike_monotone_heatingNeed
  (n1 n2 coolingNeed lightingNeed wHeating wCooling wLighting modulation : E)
  (hNeed : n1 <= n2) :
    bbioLike n1 coolingNeed lightingNeed wHeating wCooling wLighting modulation <=
      bbioLike n2 coolingNeed lightingNeed wHeating wCooling wLighting modulation := by
  unfold bbioLike
  have hTerm : wHeating * n1 <= wHeating * n2 := Nat.mul_le_mul_left _ hNeed
  have hInner :
      wHeating * n1 + wCooling * coolingNeed + wLighting * lightingNeed <=
      wHeating * n2 + wCooling * coolingNeed + wLighting * lightingNeed := by
    exact Nat.add_le_add_right (Nat.add_le_add_right hTerm _) _
  exact Nat.mul_le_mul_left _ hInner

/-- Bbio-like indicator is monotone in cooling need. -/
theorem bbioLike_monotone_coolingNeed
    (c1 c2 heatingNeed lightingNeed wHeating wCooling wLighting modulation : E)
    (hCool : c1 <= c2) :
    bbioLike heatingNeed c1 lightingNeed wHeating wCooling wLighting modulation <=
      bbioLike heatingNeed c2 lightingNeed wHeating wCooling wLighting modulation := by
  unfold bbioLike
  have hTerm : wCooling * c1 <= wCooling * c2 := Nat.mul_le_mul_left _ hCool
  have hInner :
      wHeating * heatingNeed + wCooling * c1 + wLighting * lightingNeed <=
      wHeating * heatingNeed + wCooling * c2 + wLighting * lightingNeed := by
    exact Nat.add_le_add_right (Nat.add_le_add_left hTerm _) _
  exact Nat.mul_le_mul_left _ hInner

/-- Bbio-like indicator is monotone in lighting need. -/
theorem bbioLike_monotone_lightingNeed
    (l1 l2 heatingNeed coolingNeed wHeating wCooling wLighting modulation : E)
    (hLight : l1 <= l2) :
    bbioLike heatingNeed coolingNeed l1 wHeating wCooling wLighting modulation <=
      bbioLike heatingNeed coolingNeed l2 wHeating wCooling wLighting modulation := by
  unfold bbioLike
  have hTerm : wLighting * l1 <= wLighting * l2 := Nat.mul_le_mul_left _ hLight
  have hInner :
      wHeating * heatingNeed + wCooling * coolingNeed + wLighting * l1 <=
      wHeating * heatingNeed + wCooling * coolingNeed + wLighting * l2 := by
    have hMid :
        (wHeating * heatingNeed + wCooling * coolingNeed) + wLighting * l1 <=
        (wHeating * heatingNeed + wCooling * coolingNeed) + wLighting * l2 :=
      Nat.add_le_add_left hTerm _
    simpa [Nat.add_assoc] using hMid
  exact Nat.mul_le_mul_left _ hInner

/-- Zero modulation cancels Bbio-like contribution. -/
theorem bbioLike_eq_zero_if_modulation_zero
    (heatingNeed coolingNeed lightingNeed wHeating wCooling wLighting : E) :
    bbioLike heatingNeed coolingNeed lightingNeed wHeating wCooling wLighting 0 = 0 := by
  unfold bbioLike
  simp

/-- Turning off a use never increases Cep-like indicator. -/
theorem cepLike_drop_cooling
    (heating dhw cooling lighting auxiliaries fHeating fDhw fCooling fLighting fAux modulation : E) :
    cepLike heating dhw 0 lighting auxiliaries fHeating fDhw fCooling fLighting fAux modulation <=
      cepLike heating dhw cooling lighting auxiliaries fHeating fDhw fCooling fLighting fAux modulation := by
  exact cepLike_monotone_cooling 0 cooling heating dhw lighting auxiliaries
    fHeating fDhw fCooling fLighting fAux modulation (Nat.zero_le _)

end RE2020
