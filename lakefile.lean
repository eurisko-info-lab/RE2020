import Lake
open Lake DSL

package RE2020 where
  version := v!"0.1.0"

@[default_target]
lean_lib RE2020 where
  roots := #[`RE2020]
  srcDir := "."

lean_exe re2020_optimize where
  root := `RE2020.OptimizeCli
