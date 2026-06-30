# Moteur Lean RE2020

Implémentation Lean 4 d'un moteur de calcul réglementaire RE2020, avec un accent sur la traçabilité, le déterminisme des résultats et la provenance des tables réglementaires.

Statut publication:
- Le dépôt est structuré pour une publication technique du code et des artefacts.
- Licence retenue : Apache-2.0.
- Ce choix privilégie l'adoption large d'une implémentation de référence tout en apportant une concession explicite de brevets et des conditions de redistribution claires.

## Objectifs

- Encoder la logique métier RE2020 dans des modules Lean.
- Maintenir les constantes réglementaires critiques sous forme de tables traçables.
- Fournir des outils d'export et de vérification pour les workflows d'audit.

## Structure du dépôt

- `RE2020/` : modules Lean pour climat, simulation thermique, systèmes, indicateurs, éclairage, solaire et tables réglementaires.
- `RE2020/BuildingCategory/` : surfaces publiques par catégorie de bâtiment (`MaisonIndividuelle`, `LogementCollectif`, `Bureau`, `EnseignementPrimaireSecondaire`, `Autre`) et logique partagée dans `Common.lean`.
- `Example/` : cas d'exemple et dossiers démonstratifs, dont `MaisonPierre2011.lean`.
- `docs/` : documentation projet, publication, contribution et traçabilité réglementaire lisible par humain.
- `scripts/` : scripts utilitaires pour exporter les tables et contrôler les garde-fous de traçabilité.
- `RE2020/data/regulation_tables_export.json` : instantané JSON généré des coefficients pilotés par tables.
- `RE2020/data/regulation_traceability_matrix.json` : matrice de traçabilité lisible par machine.
- `docs/REGULATION_REFERENCES.md` : synthèse humaine des références réglementaires et techniques utilisées pour écrire le code.
- `docs/REGULATION_TRACEABILITY_MATRIX.md` : rapport de traçabilité lisible par humain.
- `docs/REGULATION_GAP_CLOSURE_ROADMAP.md` : feuille de route priorisée pour combler les écarts de conformité/fidélité.

## Prérequis

- Toolchain Lean 4 via `elan`.
- `lake` (installé avec la toolchain Lean).
- Python 3.10+ pour les scripts dans `scripts/`.

## Démarrage rapide

1. Compiler le projet Lean :

```bash
lake build
```

2. Régénérer l'export des tables réglementaires :

```bash
python3 scripts/export_regulation_tables.py
```

3. Exécuter le contrôle de traçabilité sur les priorités obligatoires (par défaut `P0`) :

```bash
python3 scripts/check_traceability_p0.py
```

4. Générer puis valider les jeux climatiques par zone :

```bash
python3 scripts/generate_climate_datasets.py
python3 scripts/validate_climate_datasets.py
```

5. Vérifier la couverture de traçabilité des facteurs d'usage Cep/Cep_nr :

```bash
python3 scripts/check_usage_factor_traceability.py
```

6. Vérifier la couverture des scénarios et profils d'usages finaux :

```bash
python3 scripts/check_scenario_profile_traceability.py
```

7. Exporter et vérifier la cohérence des scénarios (source Lean vs artefact JSON) :

```bash
python3 scripts/export_scenario_profiles.py
python3 scripts/check_scenario_export_consistency.py
```

8. Exécuter le gate de conformité global (fail-fast) :

```bash
python3 scripts/check_compliance_gate.py
python3 scripts/check_compliance_gate.py --include-build
python3 scripts/check_compliance_gate.py --include-build --strict-legal-catalog
scripts/run_compliance_modes.sh strict
scripts/run_compliance_modes.sh deep
scripts/run_compliance_modes.sh maintain
```

9. Vérifier la couverture des identifiants de référence légale :

```bash
python3 scripts/check_legal_reference_catalog.py
python3 scripts/check_legal_reference_catalog.py --require-finalized-used
```

10. Suggérer des ajustements pour atteindre une cible (sans CAO) :

```bash
# Entrée JSON (exemple)
python3 scripts/suggest_retrofit.py \
  --input examples/simple_building.json \
  --metric cep \
  --target 85 \
  --profile standard \
  --pareto \
  --top-k 3 \
  --json-out examples/result_cep.json

# Entrée CSV (une seule ligne bâtiment)
python3 scripts/suggest_retrofit.py \
  --input examples/simple_building.csv \
  --metric bbio \
  --target 60 \
  --profile aggressive \
  --cost-envelope 4.0 \
  --cost-window 1.0 \
  --max-weighted-cost 14.0

# Option stricte: retourner un code non-zero si la cible n'est pas atteinte
python3 scripts/suggest_retrofit.py \
  --input examples/simple_building.csv \
  --metric bbio \
  --target 60 \
  --strict-target

# Exiger uniquement des solutions qui atteignent la cible
python3 scripts/suggest_retrofit.py \
  --input examples/simple_building.csv \
  --metric bbio \
  --target 60 \
  --pareto \
  --max-weighted-cost 14 \
  --require-target

# Le JSON inclut recommendation.changeSummary / recommendation.changeSet
# et recommendations[] pour comparer plusieurs options classées.
# Avec --pareto, le pré-filtrage se fait sur la frontière de Pareto (gap vs coût pondéré)
# --max-weighted-cost limite les options aux budgets compatibles.
# --require-target force la faisabilité (sinon status=no_candidate).
# En status=no_candidate, le JSON inclut reason + diagnostics.* pour expliquer l'échec.
```

## Surface publique

Modules canoniques à importer selon le besoin :

- `RE2020` : surface agrégée du moteur.
- `RE2020.BuildingCategory.MaisonIndividuelle`
- `RE2020.BuildingCategory.LogementCollectif`
- `RE2020.BuildingCategory.Bureau`
- `RE2020.BuildingCategory.EnseignementPrimaireSecondaire`
- `RE2020.BuildingCategory.Autre`
- `Example.MaisonPierre2011` : exemple détaillé, non destiné à être la dépendance principale d'une intégration.

Exemple minimal :

```lean
import RE2020.BuildingCategory.MaisonIndividuelle

open RE2020
```

Exemple détaillé Maison Pierre :

```lean
import Example.MaisonPierre2011

open RE2020
```

## Workflow de développement

Ce dépôt est pensé pour être piloté principalement par prompts, scripts et génération contrôlée, pas pour une édition manuelle régulière du code source.

1. Décrire l'évolution souhaitée en français, avec la référence réglementaire ou l'artefact cible.
2. Faire produire ou ajuster la logique Lean dans `RE2020/*.lean` par l'assistant/outillage.
3. Maintenir les coefficients et références de `RE2020/RegulationTables.lean` sous forme de tables.
4. Exporter les tables et mettre à jour les artefacts de traçabilité après chaque changement réglementaire.
5. Vérifier qu'aucun placeholder critique de conformité n'est introduit.

## Prompts utiles

Exemples de prompts adaptés à ce dépôt :

- `Ajoute une référence réglementaire explicite pour les facteurs Cep,nr et mets à jour la documentation de traçabilité.`
- `Crée un nouveau cas d'exemple RE2020 pour un logement collectif en zone H1c et ajoute le dossier de validation associé.`
- `Compare l'impact de l'ajout d'une PAC réversible sur Bbio, Cep, Cep,nr et DH pour un bâtiment donné.`
- `Mets à jour les modules BuildingCategory pour refléter une nouvelle convention système issue de l'Annexe III.`
- `Régénère les artefacts de traçabilité et vérifie qu'ils restent cohérents avec le code Lean.`
- `Prépare un dossier de publication avec build, changelog, artefacts de validation et références réglementaires.`
- `Remplis le template Excel CSTB/RE2020 pour un cas d'exemple local et vérifie les écarts calculés.`

Prompts à privilégier pour éviter l'édition manuelle :

- demander une modification fonctionnelle avec la source réglementaire attendue ;
- demander la mise à jour simultanée du code, des artefacts générés et de la documentation ;
- demander explicitement la validation (`lake build`, gate de conformité, contrôles de traçabilité).

## Publication

Avant publication :

1. Vérifier que `lake build` est propre.
2. Exécuter `python3 scripts/check_compliance_gate.py --include-build --strict-legal-catalog`.
3. Vérifier que les exports et matrices générés sont à jour.
4. Mettre à jour `docs/CHANGELOG.md` avec les changements de version.
5. Vérifier que l'en-tête documentaire et la stratégie de redistribution restent cohérents avec la licence Apache-2.0.

Consulter `docs/PUBLISHING.md` pour la procédure détaillée.

## Conformité et traçabilité

Références utilisées pour écrire le code :

- Voir `docs/REGULATION_REFERENCES.md` pour la synthèse humaine.
- Voir `RE2020/data/legal_reference_catalog.json` pour le catalogue machine lisible des ancres légales.
- Voir `docs/REGULATION_TRACEABILITY_MATRIX.md` pour la cartographie code ↔ réglementation.

Lors d'une modification du comportement réglementaire :

- Relier les valeurs à des métadonnées de source explicites (section, identifiant table/équation, date de version).
- Mettre à jour les artefacts de traçabilité machine (`.json`) et humain (`.md`).
- Préférer un comportement déterministe aux heuristiques implicites.

Note climatique production:
- `loadClimateDataProductionIO` (dans `RE2020/Climate.lean`) impose un chargement strict depuis les CSV de `RE2020/data/climate` et échoue si un dataset est absent/invalide.
- `loadClimateDataIO` conserve un fallback synthétique pour expérimentation locale.

## Commandes utiles

```bash
# Compiler l'ensemble du projet
lake build

# Exporter l'instantané des tables
python3 scripts/export_regulation_tables.py \
  --input RE2020/RegulationTables.lean \
  --output RE2020/data/regulation_tables_export.json

# Enforcer la traçabilité P0 + P1
python3 scripts/check_traceability_p0.py --priorities P0,P1

# Générer et valider les datasets climatiques
python3 scripts/generate_climate_datasets.py
python3 scripts/validate_climate_datasets.py

# Vérifier la couverture des usages pour les facteurs + citations
python3 scripts/check_usage_factor_traceability.py

# Vérifier la couverture des scénarios et citations de profils d'usages
python3 scripts/check_scenario_profile_traceability.py

# Exporter et vérifier la cohérence source/artefact des scénarios
python3 scripts/export_scenario_profiles.py
python3 scripts/check_scenario_export_consistency.py

# Gate de conformité composite
python3 scripts/check_compliance_gate.py
python3 scripts/check_compliance_gate.py --include-build
python3 scripts/check_compliance_gate.py --include-build --strict-legal-catalog
scripts/run_compliance_modes.sh strict
scripts/run_compliance_modes.sh deep
scripts/run_compliance_modes.sh maintain

# Vérifier le catalogue d'identifiants de référence légale
python3 scripts/check_legal_reference_catalog.py
python3 scripts/check_legal_reference_catalog.py --require-finalized-used

# Optimisation cible depuis un fichier simple (JSON/CSV)
python3 scripts/suggest_retrofit.py --input examples/simple_building.json --metric cep --target 85
python3 scripts/suggest_retrofit.py --input examples/simple_building.csv --metric bbio --target 60
python3 scripts/suggest_retrofit.py --input examples/simple_building.json --metric cep --target 85 --profile conservative --json-out examples/result_cep.json
python3 scripts/suggest_retrofit.py --input examples/simple_building.json --metric cep --target 85 --profile standard --top-k 3 --json-out examples/result_cep.json
python3 scripts/suggest_retrofit.py --input examples/simple_building.json --metric cep --target 85 --profile standard --pareto --top-k 3 --json-out examples/result_cep.json
python3 scripts/suggest_retrofit.py --input examples/simple_building.csv --metric bbio --target 60 --profile aggressive --pareto --top-k 5 --max-weighted-cost 14 --json-out examples/result_cep.json
python3 scripts/suggest_retrofit.py --input examples/simple_building.csv --metric bbio --target 60 --profile aggressive --pareto --top-k 5 --max-weighted-cost 14 --require-target --json-out examples/result_cep.json
```

## État actuel

Le dépôt contient déjà une base RE2020 significative ainsi qu'un travail de provenance des tables. Il reste toutefois en phase de durcissement pour atteindre une fidélité de niveau certification. Consulter la feuille de route et la matrice de traçabilité pour le détail des écarts et priorités.