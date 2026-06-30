# Références Réglementaires Utilisées Dans Ce Code

## Objet

Ce document explicite les références réglementaires et techniques utilisées pour écrire l'implémentation Lean présente dans ce dépôt.

Il complète, sous une forme lisible par un humain :

- `RE2020/data/legal_reference_catalog.json`
- `docs/REGULATION_TRACEABILITY_MATRIX.md`
- les tables et commentaires porteurs de citations embarqués dans `RE2020/*.lean`

## Références normatives principales

L'implémentation est écrite en se référant aux sources principales suivantes, telles qu'elles sont déclarées par le dépôt :

1. `Arrêté du 4 août 2021` relatif aux exigences de performance énergétique et environnementale des constructions de bâtiments en France métropolitaine.
2. `Annexe II` de cet arrêté, utilisée comme ancre juridique principale pour les coefficients de modulation et l'encadrement des indicateurs.
3. `Annexe III` de cet arrêté, utilisée comme ancre juridique principale pour les conventions de calcul thermique, les facteurs énergétiques, les scénarios, les systèmes et la logique d'inconfort.
4. `Méthode Th-BCE 2020`, utilisée comme base technique pour la simulation horaire, les conventions d'exploitation et la chaîne de calcul des indicateurs énergétiques.
5. `Guide RE2020`, utilisé comme source d'interprétation technique complémentaire lors de l'encodage des tables, conventions ou hypothèses de modélisation décrites dans les commentaires du code.

## Références secondaires de validation

Le dépôt utilise également des références de validation externes pour calibrer et comparer le comportement du moteur :

1. les `cas de référence CSTB / RE2020`, utilisés comme ancres de benchmark ;
2. les fichiers locaux de benchmark stockés dans `RE2020/data/validation/cases/` ;
3. une copie locale du classeur Excel de validation pour l'exemple Maison Pierre : `examples/Validation_CSTB_RE2020_MaisonPierre2011.xlsx`.

Ces références de validation ne constituent pas elles-mêmes le texte normatif, mais elles servent à vérifier que l'implémentation se comporte de façon cohérente avec des cas de référence reconnus.

## Utilisation de chaque famille de référence

### Annexe II

Utilisée dans le dépôt pour :

- les coefficients de modulation géographique ;
- les coefficients de modulation par catégorie ;
- les coefficients liés aux surfaces ;
- les coefficients liés au bruit ;
- les entrées de cadrage Bbio/Cep raccordées aux tables de modulation.

Les ancres machine-lisibles sont cataloguées dans `RE2020/data/legal_reference_catalog.json` avec notamment les sections :

- `Annexe II.B`
- `Annexe II.C`

Exemples d'identifiants de table suivis dans le catalogue :

- `MBGEO-*`
- `MBCOMBLES-*`
- `MBBRUIT-*`
- `MCCAT-*`
- `MBSURFMOY-*`
- `MBSURFTOT-*`

Ancrages directs dans l'implémentation :

- `RE2020/RegulationTables.lean` pour les valeurs tabulées de modulation ;
- `RE2020/BuildingCategory/Common.lean` pour la sélection des modulations dans la chaîne détaillée ;
- `RE2020/Indicators.lean` pour l'agrégation Bbio/Cep utilisant ces modulations.

### Annexe III

Utilisée dans le dépôt pour :

- les facteurs d'énergie primaire ;
- les facteurs d'énergie non renouvelable ;
- les scénarios horaires et profils d'usages finaux ;
- les conventions systèmes et comportements à charge partielle ;
- les conventions thermiques et d'inconfort ;
- les données conventionnelles d'éclairage et de solaire.

Exemples d'identifiants suivis :

- `PEF-*`
- `PENR-*`
- `SCEN-HOURLY-*`
- `SCEN-ENDUSE-*`
- les identifiants de conventions systèmes embarqués dans `Systems.lean`

Ancrages directs dans l'implémentation :

- `RE2020/Systems.lean` pour les conventions générateurs, auxiliaires et courbes de charge partielle ;
- `RE2020/Scenarios.lean` pour les scénarios horaires et profils d'usages ;
- `RE2020/BuildingCategory/Common.lean` pour l'assemblage des indicateurs, la logique systèmes/résilience et les comparaisons calibrées ;
- `RE2020/Indicators.lean` pour les calculs `Cep`, `Cep,nr` et inconfort ;
- `RE2020/Lighting.lean` et `RE2020/Solar.lean` pour les paramètres d'éclairage et conventions solaires.

### Méthode Th-BCE 2020

Utilisée comme base technique pour :

- la structure de simulation annuelle horaire ;
- la progression de température intérieure ;
- l'estimation des besoins de chauffage et de refroidissement ;
- la modélisation de la ventilation et des auxiliaires ;
- les régimes d'occupation et d'exploitation pilotés par scénario.

Dans le code, cette référence se reflète principalement dans :

- `RE2020/Thermal.lean`
- `RE2020/Scenarios.lean`
- `RE2020/Systems.lean`
- `RE2020/Indicators.lean`
- `RE2020/BuildingCategory/Common.lean`

Ancrages directs dans l'implémentation :

- `RE2020/Thermal.lean` pour la mise à jour horaire des états et la boucle annuelle de simulation ;
- `RE2020/Building.lean` pour les données d'entrée de composition thermique ;
- `RE2020/BuildingCategory/Common.lean` pour la transformation des sorties de simulation en composants énergétiques détaillés puis en indicateurs.

### Guide RE2020

Utilisé comme source d'interprétation complémentaire pour :

- l'alignement explicatif des formules et conventions ;
- la dénomination des tables et l'intention de traçabilité ;
- l'aide à la conversion des tables réglementaires en structures de données exécutables.

Le guide est traité comme document d'appui, et non comme substitut à l'arrêté ou à ses annexes.

Ancrages directs d'interprétation :

- `RE2020/Indicators.lean` pour les commentaires de formule d'indicateurs et de logique d'inconfort ;
- `RE2020/Thermal.lean` pour les commentaires décrivant le modèle thermique dynamique ;
- `RE2020/Systems.lean` pour les commentaires décrivant la modélisation des générateurs et systèmes ;
- `docs/REGULATION_TRACEABILITY_MATRIX.md` pour la synthèse dépôt des domaines implémentés, partiels ou manquants.

## Artefacts du dépôt qui encodent ces références

Les principaux artefacts qui portent ou structurent ces références sont :

1. `RE2020/data/legal_reference_catalog.json`
2. `docs/REGULATION_TRACEABILITY_MATRIX.md`
3. `RE2020/data/regulation_traceability_matrix.json`
4. `RE2020/data/regulation_tables_export.json`
5. les définitions porteuses de citations dans `RE2020/RegulationTables.lean`, `RE2020/Systems.lean`, `RE2020/Scenarios.lean`, `RE2020/Lighting.lean` et les modules associés

Carte rapide d'implémentation :

- climat et simulation annuelle : `RE2020/Climate.lean`, `RE2020/Thermal.lean` ;
- surfaces publiques par catégorie : `RE2020/BuildingCategory/*.lean` ;
- logique détaillée partagée par catégorie : `RE2020/BuildingCategory/Common.lean` ;
- exemples et dossiers de validation locale : `Example/*.lean`, `examples/*` ;
- artefacts juridiques et de traçabilité : `RE2020/data/legal_reference_catalog.json`, `RE2020/data/regulation_traceability_matrix.json`, `docs/REGULATION_TRACEABILITY_MATRIX.md`.

## Qualification importante

Ce dépôt explicite et structure les références qu'il utilise, mais ne prétend pas que chaque exigence juridique a été parsée automatiquement, de manière indépendante, directement depuis les textes officiels.

La position actuelle du projet, cohérente avec la matrice de traçabilité, est la suivante :

- l'implémentation est ancrée sur des sources et orientée traçabilité ;
- le dépôt enregistre explicitement des ancres juridiques et des ancres de benchmark ;
- la publication comme implémentation de référence ne transforme pas le code en publication réglementaire officielle.

## Ordre de lecture recommandé pour les auditeurs et les intégrateurs

1. `README.md`
2. `docs/REGULATION_REFERENCES.md`
3. `docs/REGULATION_TRACEABILITY_MATRIX.md`
4. `RE2020/data/legal_reference_catalog.json`
5. le module Lean pertinent sous `RE2020/`