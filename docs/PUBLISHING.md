# Publishing

## Objectif

Ce document décrit la procédure minimale pour publier le dépôt dans un état cohérent et reproductible.

## Checklist de publication

1. Vérifier la version dans `lakefile.lean`.
2. Mettre à jour `docs/CHANGELOG.md`.
3. Exécuter :

```bash
lake build
python3 scripts/check_compliance_gate.py --include-build --strict-legal-catalog
```

4. Vérifier que les fichiers générés attendus sont commités si leur évolution est intentionnelle.
5. Vérifier que la documentation (`README.md`, `docs/CONTRIBUTING.md`) reflète la surface publique actuelle.
6. Vérifier que la licence Apache-2.0 reste adaptée au mode de diffusion visé.
7. Créer un tag de version au format `vX.Y.Z` pour déclencher la publication GitHub.

## Artefacts utiles

- Surface publique moteur : `RE2020.lean`
- Modules canoniques : `RE2020/BuildingCategory/*`
- Exemples : `Example/*`
- Validation locale Excel Maison Pierre : `examples/Validation_CSTB_RE2020_MaisonPierre2011.xlsx`
- Workflow de release : `.github/workflows/re2020-release.yml`

## Remarque licence

Le dépôt est publié sous licence Apache-2.0. Ce choix est adapté à une implémentation de référence technique : adoption large, compatibilité industrielle et concession explicite de brevets.