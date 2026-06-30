# Contributing

## Pré requis

- Lean 4 via `elan`
- `lake`
- Python 3.10+

## Flux recommandé

1. Modifier la logique Lean ou les scripts de contrôle dans une branche dédiée.
2. Exécuter `lake build`.
3. Exécuter `python3 scripts/check_compliance_gate.py --include-build --strict-legal-catalog`.
4. Mettre à jour les artefacts générés si un changement réglementaire ou de table les impacte.
5. Ajouter une entrée dans `docs/CHANGELOG.md` si le changement est destiné à une publication.

## Attentes de contribution

- Préserver le déterminisme des calculs.
- Maintenir la traçabilité des constantes réglementaires.
- Éviter d'introduire des exemples ou scripts qui deviennent des dépendances de la surface publique principale.