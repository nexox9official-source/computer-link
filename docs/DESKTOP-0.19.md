# LinkOS Desktop 0.19 — Fluent Shell

LinkOS 0.19 est une refonte graphique complete du shell et des applications principales.

L'objectif n'est pas de copier Windows pixel par pixel, mais de retrouver ses reperes de navigation :
- barre des taches centree ;
- menu Start avec recherche, apps epinglees et recentes ;
- fenetres coherentes ;
- panneaux et cartes ;
- centre systeme ;
- explorateur ;
- parametres a navigation laterale ;
- icones visuelles coherentes.

## Design system Fluent

Le nouveau module `src/ui/fluent.lua` devient la source de verite graphique.

Il fournit :
- palette RGB LinkOS ;
- surfaces et elevations ;
- cartes ;
- boutons ;
- champs de recherche ;
- titres de sections ;
- icones miniatures ;
- icones pixel 3x3 ;
- couleurs semantiques succes / warning / danger.

La palette est appliquee aux Advanced Computers et Advanced Monitors avec l'API de palette CC:Tweaked.

Le bleu Fluent par defaut utilise un accent proche du bleu Windows et les autres accents restent configurables.

## Icones

Les anciennes lettres simples ne sont plus l'identite visuelle principale.

Chaque app systeme et app officielle du Store possede une icone pixel et un glyphe compact pour la taskbar :
- Bureau ;
- Messages ;
- Contacts ;
- Reseau ;
- Securite ;
- Fichiers ;
- Notes ;
- Calculatrice ;
- Terminal ;
- Parametres ;
- A propos ;
- LinkSec ;
- Applications ;
- Taches ;
- Chronometre ;
- Convertisseur ;
- Peripheriques ;
- Calendrier ;
- Infos systeme ;
- Redstone ;
- GPS.

## Barre des taches

La taskbar utilise maintenant un groupe central proche de Windows 11.

Elle contient :
- bouton Start ;
- applications epinglees ;
- applications ouvertes ;
- etat actif/minimise ;
- reseau ;
- compteur de messages ;
- heure ;
- bouton Afficher le bureau.

Le mode texte des apps reste disponible dans Parametres sur les grands ecrans.

## Menu Start

Le menu Start est centre et organise en grille.

Il propose :
- recherche ;
- apps epinglees ;
- apps recentes ;
- toutes les applications ;
- compte/identite du Computer ;
- Reglages ;
- Lock si la securite est active ;
- Power.

La navigation clavier suit la grille : gauche/droite, haut/bas, Home/End, Entree et Echap.

## Fenetres

Les fenetres utilisent des barres de titre neutres et une bordure d'accent uniquement sur la fenetre active.

Les controles restent :
- reduire ;
- maximiser/restaurer ;
- fermer ;
- drag ;
- resize ;
- snap haut/gauche/droite ;
- Alt+Tab ;
- session persistante.

## Applications systeme

Messages : vue conversations + chat en deux panneaux.

Explorateur : command bar, chemin, creation, dossiers/fichiers, preview, edition, renommage et suppression.

Parametres : navigation laterale Style / Ecrans / Systeme avec cartes.

Applications : catalogue sous forme de cartes, recherche, installation, mise a jour, ouverture et retrait.

Contacts : cartes de contacts.

Reseau : etat AstralNet/MER/modem/Malcraft Bridge sous forme de panneau de statut.

Securite : session, mot de passe et acces LinkSec.

Calculatrice : affichage et keypad complet sans scroll obligatoire.

Terminal : surface terminal dediee.

Notes : editeur focalise avec barre d'actions.

A propos : cartes version/navigation/securite.

LinkSec : accueil Fluent avec Malcraft comme chemin principal et outils LinkOS secondaires.

## Apps Store 1.1

Les huit apps officielles passent en version 1.1 et adoptent le meme design :
- Mes taches ;
- Chronometre ;
- Convertisseur ;
- Peripheriques ;
- Calendrier ;
- Infos systeme ;
- Controle Redstone ;
- GPS.

Elles heritent maintenant de l'accent choisi dans LinkOS.

## Boot, lockscreen et saisie

Le boot utilise la palette Fluent et un logo quatre tuiles adapte au terminal.

Le lockscreen reprend les memes surfaces et la meme identite.

Les prompts ne basculent plus sur un ecran CraftOS brut : ils s'affichent sous forme de dialogue Fluent sur le Computer.

## Advanced Monitors

Le display principal conserve tout le desktop.

Les displays secondaires deviennent des dashboards Fluent avec :
- heure ;
- identite du poste ;
- AstralNet ;
- messages ;
- app active ;
- update disponible ;
- activation tactile.

## Validation

Les tests CI continuent de verifier syntaxe, resolutions, navigation, fenetres, session, packages et Malcraft.

Les artefacts CI produisent des frames 51x19 isolees pour :
- bureau ;
- Start ;
- quick settings ;
- Store ;
- Calculatrice ;
- Fichiers ;
- Parametres ;
- Messages ;
- menu contextuel ;
- Alt+Tab.

LinkOS 0.19 reste une implementation propre a Computer Link. Les principes de navigation et de hierarchie sont inspires de Fluent/Windows, sans reprendre le code de Windows.
