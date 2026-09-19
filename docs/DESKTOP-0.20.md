# LinkOS Desktop 0.20 — Windows polish

LinkOS 0.20 affine la refonte Fluent de 0.19 avec un objectif simple : rendre
la navigation encore plus proche d'un desktop moderne, surtout sur les
resolutions standard de CC:Tweaked.

## Start

- tuiles d'applications avec vraies icones pixel 3x3 sur les ecrans standard ;
- titre, statut epingle/recent et description courte ;
- pagination visible avec boutons precedent/suivant ;
- pagination utilisable a la souris et au toucher ;
- mode compact conserve sur les petits Computers ;
- recherche et navigation clavier de 0.19 conservees.

## Bureau

Le wallpaper Fluent utilise maintenant un symbole LinkOS en quatre panneaux,
plus identifiable au premier coup d'oeil tout en gardant une zone de bureau
lisible pour les raccourcis.

## Alt+Tab

Le switcher de fenetres devient une surface modale dediee :
- fond nettoye pour eviter le chevauchement visuel des fenetres ;
- grandes icones pixel ;
- etat Active / Ouverte / Minimise ;
- marqueur d'accent sur la fenetre courante.

## Notifications

Les anciens messages sur une seule ligne deviennent des cartes toast :
- accent semantique ;
- titre LinkOS ;
- message ;
- position au-dessus de la taskbar.

## Messages

La colonne Conversations est plus large sur les ecrans standards afin de garder
les titres et etats lisibles. L'etat vide utilise maintenant un texte court qui
ne se tronque pas.

## Explorateur

La barre d'outils emploie des libelles plus courts et stables :
- DOSSIER ;
- TEXTE.

Le chemin conserve la priorite visuelle, comme dans un mini File Explorer.

## Compatibilite

Cette version ne modifie pas :
- AstralNet ;
- MER ;
- Malcraft / GhostLink ;
- stockage des conversations ;
- format des fichiers utilisateur ;
- sessions/fenetres persistantes ;
- apps Store 1.1.

## Validation

La CI verifie toujours :
- syntaxe Lua ;
- 12 cas resolution/permission ;
- navigation Start clavier ;
- pagination Start souris/tactile ;
- workspace, fenetres et restauration de session ;
- lifecycle des packages ;
- tests Malcraft agent/service ;
- captures UI 51x19.
