import Mathlib
import RE2020.Indicators
import RE2020.FormalRealBridge

namespace RE2020

/-- Abstract embedding used to interpret Float outputs in Real-valued proofs. -/
structure FloatEmbedding where
  toReal : Float → Real

/-- Exact Real indicator tuple used as proof target/reference. -/
structure IndicatorsR where
  bbio : Real
  cep : Real
  cepNr : Real
  dh : Real

/-- Pointwise approximation certificate between Float outputs and exact Real values. -/
structure IndicatorsApprox
    (E : FloatEmbedding)
    (iFloat : Indicators)
    (iReal : IndicatorsR) where
  epsBbio : Real
  epsCep : Real
  epsCepNr : Real
  epsDh : Real
  epsBbio_nonneg : 0 <= epsBbio
  epsCep_nonneg : 0 <= epsCep
  epsCepNr_nonneg : 0 <= epsCepNr
  epsDh_nonneg : 0 <= epsDh
  bbio_within : |E.toReal iFloat.bbio - iReal.bbio| <= epsBbio
  cep_within : |E.toReal iFloat.cep - iReal.cep| <= epsCep
  cepNr_within : |E.toReal iFloat.cepNr - iReal.cepNr| <= epsCepNr
  dh_within : |E.toReal iFloat.dh - iReal.dh| <= epsDh

/-- If exact DH satisfies a cap and approximation error is bounded, Float output satisfies a relaxed cap. -/
theorem dh_cap_with_margin
    (E : FloatEmbedding)
    (iFloat : Indicators)
    (iReal : IndicatorsR)
    (cert : IndicatorsApprox E iFloat iReal)
    (dhMax : Real)
    (hExactCap : iReal.dh <= dhMax) :
    E.toReal iFloat.dh <= dhMax + cert.epsDh := by
  have hDiff : E.toReal iFloat.dh - iReal.dh <= cert.epsDh :=
    (abs_sub_le_iff.mp cert.dh_within).1
  have hLe : E.toReal iFloat.dh <= cert.epsDh + iReal.dh :=
    (sub_le_iff_le_add.mp hDiff)
  have hCap : iReal.dh + cert.epsDh <= dhMax + cert.epsDh := by
    simpa [add_comm] using (add_le_add_right hExactCap cert.epsDh)
  have hCap' : cert.epsDh + iReal.dh <= dhMax + cert.epsDh := by
    simpa [add_comm, add_left_comm, add_assoc] using hCap
  exact le_trans hLe hCap'

/-- If exact DH is nonnegative, Float output is lower-bounded by minus the error margin. -/
theorem dh_nonneg_with_margin
    (E : FloatEmbedding)
    (iFloat : Indicators)
    (iReal : IndicatorsR)
    (cert : IndicatorsApprox E iFloat iReal)
    (hExactNonneg : 0 <= iReal.dh) :
    -cert.epsDh <= E.toReal iFloat.dh := by
  have hDiff : iReal.dh - E.toReal iFloat.dh <= cert.epsDh :=
    (abs_sub_le_iff.mp cert.dh_within).2
  have hLe : iReal.dh <= cert.epsDh + E.toReal iFloat.dh :=
    (sub_le_iff_le_add.mp hDiff)
  have hNonnegPlus : 0 <= cert.epsDh + E.toReal iFloat.dh :=
    le_trans hExactNonneg hLe
  have hNonnegPlus' : 0 <= E.toReal iFloat.dh + cert.epsDh := by
    simpa [add_comm] using hNonnegPlus
  exact (neg_le_iff_add_nonneg.mpr hNonnegPlus')

/-- If exact Cep satisfies a cap and approximation error is bounded, Float output satisfies a relaxed cap. -/
theorem cep_cap_with_margin
    (E : FloatEmbedding)
    (iFloat : Indicators)
    (iReal : IndicatorsR)
    (cert : IndicatorsApprox E iFloat iReal)
    (cepMax : Real)
    (hExactCap : iReal.cep <= cepMax) :
    E.toReal iFloat.cep <= cepMax + cert.epsCep := by
  have hDiff : E.toReal iFloat.cep - iReal.cep <= cert.epsCep :=
    (abs_sub_le_iff.mp cert.cep_within).1
  have hLe : E.toReal iFloat.cep <= cert.epsCep + iReal.cep :=
    (sub_le_iff_le_add.mp hDiff)
  have hCap : iReal.cep + cert.epsCep <= cepMax + cert.epsCep := by
    simpa [add_comm] using (add_le_add_right hExactCap cert.epsCep)
  have hCap' : cert.epsCep + iReal.cep <= cepMax + cert.epsCep := by
    simpa [add_comm, add_left_comm, add_assoc] using hCap
  exact le_trans hLe hCap'

/-- If exact CepNr satisfies a cap and approximation error is bounded, Float output satisfies a relaxed cap. -/
theorem cepNr_cap_with_margin
    (E : FloatEmbedding)
    (iFloat : Indicators)
    (iReal : IndicatorsR)
    (cert : IndicatorsApprox E iFloat iReal)
    (cepNrMax : Real)
    (hExactCap : iReal.cepNr <= cepNrMax) :
    E.toReal iFloat.cepNr <= cepNrMax + cert.epsCepNr := by
  have hDiff : E.toReal iFloat.cepNr - iReal.cepNr <= cert.epsCepNr :=
    (abs_sub_le_iff.mp cert.cepNr_within).1
  have hLe : E.toReal iFloat.cepNr <= cert.epsCepNr + iReal.cepNr :=
    (sub_le_iff_le_add.mp hDiff)
  have hCap : iReal.cepNr + cert.epsCepNr <= cepNrMax + cert.epsCepNr := by
    simpa [add_comm] using (add_le_add_right hExactCap cert.epsCepNr)
  have hCap' : cert.epsCepNr + iReal.cepNr <= cepNrMax + cert.epsCepNr := by
    simpa [add_comm, add_left_comm, add_assoc] using hCap
  exact le_trans hLe hCap'

/-- If exact Bbio satisfies a cap and approximation error is bounded, Float output satisfies a relaxed cap. -/
theorem bbio_cap_with_margin
    (E : FloatEmbedding)
    (iFloat : Indicators)
    (iReal : IndicatorsR)
    (cert : IndicatorsApprox E iFloat iReal)
    (bbioMax : Real)
    (hExactCap : iReal.bbio <= bbioMax) :
    E.toReal iFloat.bbio <= bbioMax + cert.epsBbio := by
  have hDiff : E.toReal iFloat.bbio - iReal.bbio <= cert.epsBbio :=
    (abs_sub_le_iff.mp cert.bbio_within).1
  have hLe : E.toReal iFloat.bbio <= cert.epsBbio + iReal.bbio :=
    (sub_le_iff_le_add.mp hDiff)
  have hCap : iReal.bbio + cert.epsBbio <= bbioMax + cert.epsBbio := by
    simpa [add_comm] using (add_le_add_right hExactCap cert.epsBbio)
  have hCap' : cert.epsBbio + iReal.bbio <= bbioMax + cert.epsBbio := by
    simpa [add_comm, add_left_comm, add_assoc] using hCap
  exact le_trans hLe hCap'

end RE2020
