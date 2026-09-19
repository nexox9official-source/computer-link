# LinkOS 0.21 — Simple Windows preview

Cette preview corrige un probleme devenu visible avec la refonte 0.20 :
l'interface ressemblait davantage a Windows, mais elle demandait encore trop
d'effort pour comprendre ou cliquer.

0.21 privilegie donc la navigation evidente avant les effets visuels.

## Regle principale

Sur un Computer CC:Tweaked standard :
- une application s'ouvre en plein ecran ;
- une application n'affiche plus Reduire/Agrandir ;
- seul X reste visible dans la barre de titre ;
- START, la barre des taches et le bouton X suffisent pour naviguer.

Les vraies fenetres deplacables restent disponibles sur les grands Advanced
Monitors ou les resolutions suffisamment larges.

## Menu Demarrer

Le premier ecran contient seulement :
- Recherche ;
- Applications epinglees ;
- TOUTES ;
- Reglages ;
- Power.

Les applications recentes, descriptions longues et badges PIN/RECENT ne sont
plus affiches dans la vue principale.

TOUTES ouvre une liste alphabetique de toutes les applications avec pagination
visible si necessaire.

START revient toujours sur la vue Epinglees lors d'une nouvelle ouverture.

## Barre des taches

La barre des taches est volontairement plus explicite :
- START ecrit a gauche ;
- noms courts des applications epinglees/ouvertes ;
- NET/OFF a droite ;
- heure a droite.

Le but est que le joueur comprenne la navigation sans connaitre les icones.

## Applications

### Store
Sur un Computer standard, le Store utilise une seule colonne.
Les cartes ont donc assez de largeur pour afficher :
- nom ;
- version ;
- description ;
- action Installer/Ouvrir.

Deux colonnes restent disponibles sur les grands displays.

### Messages
Les textes d'aide sont plus courts et lisibles.

### Parametres
Les anciens boutons couleur B/C/L/O/P/R sont supprimes.
Un seul controle explicite fait defiler :
COULEUR: BLEU -> CYAN -> VERT -> ORANGE -> VIOLET -> ROUGE.

### Menus contextuels
Les libelles trop longs sont remplaces par :
- Retirer bureau ;
- Ajouter bureau ;
- Voir dans Apps.

## Sessions existantes

Sur les Computers standards, les anciennes fenetres restaurees depuis 0.20
sont forcees en plein ecran. Une vieille session ne peut donc plus recreer une
pile de petites fenetres confuses apres la mise a jour.

## Compatibilite

0.21 ne change pas :
- AstralNet ;
- MER ;
- Malcraft/GhostLink ;
- stockage des messages ;
- apps Store ;
- fichiers /user ;
- format reseau.

## Validation

La CI verifie :
- syntaxe Lua ;
- navigation Epinglees -> TOUTES ;
- pagination souris/tactile ;
- resolutions multiples ;
- workspace/session ;
- applications integrees ;
- packages ;
- Malcraft agent/service ;
- frames UI 51x19.

Cette version doit etre testee en preview avant promotion sur main.
