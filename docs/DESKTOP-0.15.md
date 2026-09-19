# LinkOS Desktop 0.15

Refonte graphique du bureau Computer Link pour CC:Tweaked 1.20.1.

Cette version conserve le backend AstralNet, les autorisations serveur et les applications existantes. Le travail porte sur le shell graphique : bureau, fenetres, launcher, barre des taches, panneaux systeme et Link Store.

## Objectifs

- donner la priorite a l'espace utile sur les Computers 51x19 ;
- supprimer les informations systeme permanentes qui encombraient l'ecran ;
- rapprocher l'ergonomie d'un bureau moderne sans copier le code de LevelOS ;
- garder le fonctionnement clavier sur Computer normal et tactile sur Advanced Monitor ;
- conserver une seule fenetre persistante par application ;
- ne pas toucher au protocole AstralNet ni au backend MER.

## Nouveau bureau

- Plus de barre systeme permanente en haut.
- Fond beaucoup plus discret, avec les modes clean, dots, grid et lines.
- Icones compactes avec couleur par application.
- Selection et double-clic conserves.
- Glisser-deposer des icones conserve sur Advanced Computer.
- Pagination affichee uniquement lorsqu'elle est necessaire.

## Nouvelle barre des taches

La barre des taches occupe une seule ligne :

- bouton LinkOS a gauche ;
- applications ouvertes au centre ;
- etat AstralNet et heure a droite ;
- un clic sur l'etat ou l'heure ouvre le panneau Systeme ;
- cliquer l'application active la reduit ;
- cliquer une application reduite ou en arriere-plan la remet au premier plan.

Toutes les informations secondaires ont ete retirees de la barre principale.

## Fenetres

- Barre de titre compacte.
- Controles -, O et X.
- Bordure minimale.
- Plus de gros footer PgUp/PgDn permanent.
- Scrollbar verticale uniquement lorsqu'un contenu est plus grand que la fenetre.
- Positions et dimensions toujours sauvegardees.
- Double-clic sur la barre de titre : maximiser/restaurer.
- Glisser la barre de titre en haut : maximiser.
- Glisser a gauche ou a droite : snap demi-ecran quand la resolution le permet.
- Les nouvelles fenetres s'ouvrent en cascade.
- Une fenetre maximisee utilise tout l'ecran sauf la barre des taches.
- Le rendu reste compose hors ecran afin de limiter le scintillement.

## Launcher LinkOS

F10 ou le bouton LinkOS ouvre un launcher flottant :

- champ de recherche ;
- liste paginee ;
- selection clavier ;
- acces direct aux Parametres ;
- redemarrage depuis le footer.

La recherche accepte le nom visible et l'identifiant interne de l'application.

## Panneau Systeme

Le panneau rapide n'affiche plus une longue barre permanente. Il regroupe :

- etat AstralNet ;
- messages non lus ;
- affichage principal ;
- heure ;
- raccourcis Parametres et Bureau.

## Applications integrees

Les surfaces grises ont ete fortement reduites dans l'ensemble du theme.

- Reseau affiche d'abord le statut, le PC, le MER et le modem ; protocole/version passent dans DETAILS.
- Parametres est separe en STYLE / ECRANS / SYSTEME.
- Securite devient une page de statut concise avec les actions de mot de passe et LinkSec si le poste est autorise.
- Les autres applications conservent leurs fonctions existantes dans les nouvelles fenetres.

## Link Store

Le catalogue est presente sous forme de lignes compactes avec :

- nom ;
- description courte ;
- version ou etat INSTALLE ;
- INSTALLER / REINSTALL ;
- OUVRIR ;
- RETIRER quand l'espace le permet.

Le mecanisme de telechargement, les controles de taille/syntaxe et les sauvegardes .backup/.removed ne changent pas.

## Compatibilite des entrees

Computer normal :

- F10 : launcher ;
- Tab / Entree : navigation ;
- F12 : parcourir les fenetres ;
- Ctrl + fleches : deplacer la fenetre active ;
- Ctrl + Entree : maximiser/restaurer ;
- Ctrl + M : reduire ;
- Ctrl + W : fermer ;
- PgUp / PgDn : defiler.

Advanced Computer :

- souris, double-clic, glisser-deposer et redimensionnement.

Advanced Monitor :

- ouverture et boutons tactiles ;
- saisie clavier effectuee depuis le Computer associe ;
- le monitor reste automatiquement mis a l'echelle par src/ui/display.lua.

## References de conception

La refonte s'inspire de principes d'ergonomie vus dans LevelOS, OneOS, Opus et des frameworks UI CC:Tweaked, mais le shell LinkOS reste une implementation propre au projet Computer Link.

## Validation

La branche de travail ajoute la validation CI sur les branches ui/** et les pull requests.

Les tests couvrent notamment :

- 26x12 ;
- 39x13 ;
- 51x19 ;
- 82x26 ;
- pagination du launcher ;
- fenetres ;
- dialogues ;
- notes ;
- packages ;
- interactions clavier/souris simulees.
