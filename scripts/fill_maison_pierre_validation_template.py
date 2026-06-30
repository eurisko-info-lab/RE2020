#!/usr/bin/env python3
"""Fill a local CSTB/RE2020 validation workbook for the Maison Pierre example.

This script runs the canonical Lean example module, extracts the current
Maison Pierre base results, and writes a filled copy of the Excel template.
The workbook is a local validation artifact, not an official CSTB benchmark.
"""

from __future__ import annotations

import argparse
import shutil
import subprocess
import tempfile
import xml.etree.ElementTree as ET
import zipfile
from pathlib import Path


NS = {"x": "http://schemas.openxmlformats.org/spreadsheetml/2006/main"}
ET.register_namespace("", NS["x"])


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Fill Maison Pierre validation template")
    parser.add_argument(
        "--template",
        default="Validation_CSTB_RE2020_Template.xlsx",
        help="Path to the source Excel template",
    )
    parser.add_argument(
        "--output",
        default="examples/Validation_CSTB_RE2020_MaisonPierre2011.xlsx",
        help="Path to the filled workbook to generate",
    )
    return parser.parse_args()


def run_maison_pierre_example(repo_root: Path) -> dict[str, str]:
    command = """
cat <<'EOF' | lake env lean --stdin
import Example.MaisonPierre2011
open RE2020
#eval do
  let climate <- loadClimateDataProductionIO ClimateZone.H1c
  let base := computeDetailedIndicators maisonPierre2011DetailedBuilding climate
  IO.println s!"bbio={base.bbio}"
  IO.println s!"cep={base.cep}"
EOF
""".strip()
    result = subprocess.run(
        command,
        cwd=repo_root,
        shell=True,
        check=True,
        capture_output=True,
        text=True,
    )
    values: dict[str, str] = {}
    for line in result.stdout.splitlines():
        if "=" not in line:
            continue
        key, value = line.strip().split("=", 1)
        values[key] = value
    required = {"bbio", "cep"}
    missing = required - values.keys()
    if missing:
        raise RuntimeError(f"Missing Lean outputs: {sorted(missing)}")
    return values


def set_inline_string(cell: ET.Element, value: str) -> None:
    cell.attrib["t"] = "inlineStr"
    for child in list(cell):
      cell.remove(child)
    inline = ET.SubElement(cell, f"{{{NS['x']}}}is")
    text = ET.SubElement(inline, f"{{{NS['x']}}}t")
    text.text = value


def set_number(cell: ET.Element, value: str) -> None:
    cell.attrib["t"] = "n"
    for child in list(cell):
      cell.remove(child)
    node = ET.SubElement(cell, f"{{{NS['x']}}}v")
    node.text = value


def set_formula(cell: ET.Element, formula: str) -> None:
    if "t" in cell.attrib:
        del cell.attrib["t"]
    for child in list(cell):
      cell.remove(child)
    formula_node = ET.SubElement(cell, f"{{{NS['x']}}}f")
    formula_node.text = formula
    ET.SubElement(cell, f"{{{NS['x']}}}v")


def fill_sheet(sheet_path: Path, bbio: str, cep: str) -> None:
    tree = ET.parse(sheet_path)
    root = tree.getroot()
    sheet_data = root.find("x:sheetData", NS)
    if sheet_data is None:
        raise RuntimeError("sheetData not found in template sheet")

    for row in list(sheet_data):
        if row.attrib.get("r") not in {"1", "2"}:
            sheet_data.remove(row)

    row2 = sheet_data.find("x:row[@r='2']", NS)
    if row2 is None:
        raise RuntimeError("Row 2 not found in template sheet")

    cells = {cell.attrib["r"]: cell for cell in row2.findall("x:c", NS)}
    set_inline_string(cells["A2"], "Maison Pierre 2011 - Modèle détaillé local")
    set_inline_string(cells["B2"], "Validation locale du cas exemple Maison Pierre 2011 en zone H1c à partir du moteur Lean")
    set_inline_string(cells["C2"], "H1c")
    set_number(cells["D2"], bbio)
    set_number(cells["E2"], cep)
    set_number(cells["F2"], "5")
    set_number(cells["G2"], bbio)
    set_number(cells["H2"], cep)
    set_formula(cells["I2"], 'IF(D2=0,"",IF(G2="","",ROUND((G2-D2)/D2*100,2)))')
    set_formula(cells["J2"], 'IF(E2=0,"",IF(H2="","",ROUND((H2-E2)/E2*100,2)))')
    set_formula(cells["K2"], 'IF(OR(I2="",J2=""),"",IF(AND(ABS(I2)<=F2,ABS(J2)<=F2),"✅ VALIDE","❌ NON VALIDE"))')
    set_inline_string(cells["L2"], "Copie locale du template CSTB/RE2020 remplie avec les sorties actuelles du cas exemple Maison Pierre; valeurs attendues non officielles.")

    dimension = root.find("x:dimension", NS)
    if dimension is not None:
        dimension.attrib["ref"] = "A1:L2"

    tree.write(sheet_path, encoding="utf-8", xml_declaration=False)


def main() -> None:
    args = parse_args()
    repo_root = Path(__file__).resolve().parent.parent
    template_path = (repo_root / args.template).resolve()
    output_path = (repo_root / args.output).resolve()

    if not template_path.exists():
        raise FileNotFoundError(f"Template not found: {template_path}")

    values = run_maison_pierre_example(repo_root)

    output_path.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(template_path, output_path)

    with tempfile.TemporaryDirectory() as tmp_dir:
        tmp_path = Path(tmp_dir)
        with zipfile.ZipFile(output_path, "r") as archive:
            archive.extractall(tmp_path)

        fill_sheet(tmp_path / "xl" / "worksheets" / "sheet1.xml", values["bbio"], values["cep"])

        with zipfile.ZipFile(output_path, "w", compression=zipfile.ZIP_DEFLATED) as archive:
            for path in sorted(tmp_path.rglob("*")):
                if path.is_file():
                    archive.write(path, path.relative_to(tmp_path))

    print(f"Filled workbook written to {output_path}")
    print(f"expected_Bbio={values['bbio']}")
    print(f"expected_Cep={values['cep']}")


if __name__ == "__main__":
    main()