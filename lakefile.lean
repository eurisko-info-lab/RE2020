import Lake
open Lake DSL

package RE2020 where
  version := v!"0.1.0"

require mathlib from git
  "https://github.com/leanprover-community/mathlib4.git" @ "v4.31.0"

@[default_target]
lean_lib RE2020 where
  roots := #[`RE2020, `Example]
  srcDir := "."

lean_exe re2020_optimize where
  root := `RE2020.OptimizeCli
