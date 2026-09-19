# LinkOS 0.23 — Interaction polish

LinkOS 0.23 poursuit la reconstruction UI de 0.22 sans ajouter de bruit visuel.
L'objectif de cette release est de rendre les interactions quotidiennes plus
naturelles sur Computer et Advanced Monitor.

## Dialogues systeme

La saisie LinkOS n'efface plus l'OS pour retomber sur un ecran CraftOS brut.

Nouveau comportement :
- dialogue CCUI centre ;
- surface quasi pleine largeur sur Computer standard ;
- texte de l'application masque proprement derriere le dialogue ;
- saisie clavier ;
- collage ;
- Backspace ;
- Entree valide ;
- Echap annule ;
- mot de passe masque ;
- affichage sur l'ecran actif ;
- saisie depuis le Computer si l'UI principale est sur monitor.

Un nouveau choiceDialog gere les choix multiples avec :
- Gauche / Droite / Haut / Bas / Tab ;
- Entree ;
- Echap ;
- souris ;
- monitor_touch.

Les confirmations utilisent maintenant ANNULER / CONFIRMER au lieu de demander
de taper OUI.

Notes utilise un vrai dialogue a trois choix :
- ANNULER ;
- ABANDONNER ;
- SAUVER.

## Explorer

Explorer a ete corrige pour les dossiers longs.

Ameliorations :
- pagination basee sur la hauteur reellement visible de la fenetre ;
- boutons precedent / suivant accessibles sans scroller le canvas interne ;
- types de fichiers et icones adaptees ;
- reset de pagination quand on change de dossier ;
- breadcrumb conserve ;
- actions FERMER / EDITER / RENOMMER / SUPPRIMER en CCUI ;
- acces rapide uniquement sur les grands ecrans >= 60 colonnes ;
- espace libre affiche dans la sidebar large.

Types visuels principaux :
- dossier ;
- code Lua ;
- document texte / Markdown / log ;
- configuration JSON / cfg / conf ;
- fichier generique.

## Menus contextuels

Le clic droit utilise maintenant CCUI :
- largeur calculee selon le contenu ;
- identite et icone de l'application ciblee ;
- Ouvrir ;
- Epingler / Desepingler ;
- Ajouter / Retirer du bureau ;
- Voir dans Apps ;
- Parametres.

Le clic droit du bureau garde :
- Actualiser ;
- Fichiers ;
- Applications ;
- Personnaliser.

## Panneau Systeme

Le panneau Systeme utilise les memes composants que le reste de LinkOS :
- AstralNet ;
- Messages non lus ;
- Ecran actif ;
- Reglages ;
- Lock si disponible ;
- Bureau.

Les libelles sont verifies sur la resolution 51x19.

## Taskbar et notifications

Taskbar :
- START reste le repere principal ;
- chaque tache affiche une identite d'application compacte ;
- couleur d'icone + nom court ;
- etat actif / minimise conserve ;
- NET/OFF + heure a droite.

Notifications :
- toast multi-ligne ;
- deux lignes de message maximum ;
- bouton X ;
- clic pour fermer ;
- position au-dessus de la taskbar.

## LinkSec / Malcraft

Les vues Malcraft principales et secondaires utilisent maintenant CCUI.

Vues restructurees :
- Malcraft Control Center ;
- reseau infecte ;
- fiche cible ;
- outils cible ;
- systeme distant ;
- inventaires ;
- PC proches / cable ;
- peripheriques ;
- detail d'un peripherique ;
- redstone ;
- disques.

La fiche cible affiche clairement :
- Computer ID ;
- profil ROM / LinkOS ;
- online / offline ;
- propagation ;
- source ;
- position ;
- ecran distant ;
- outils ;
- systeme.

Le comportement Malcraft n'est pas modifie : seule la presentation et la
navigation changent.

## Qualite automatique

La CI valide :
- syntaxe Lua ;
- fichiers du manifeste ;
- resolutions / permissions ;
- workspace ;
- modales clavier/souris/tactile ;
- annulation Echap ;
- confirmation ;
- dialogue a trois choix ;
- pagination Explorer ;
- packages ;
- Malcraft agent/service.

Les frames 51x19 couvrent maintenant :
- bureau ;
- Demarrer ;
- panneau Systeme ;
- menu contextuel ;
- lockscreen ;
- Store ;
- Parametres ;
- Explorer ;
- Messages ;
- Calculatrice ;
- dialogue systeme ;
- LinkSec ;
- fiche cible Malcraft ;
- Alt+Tab.

Une release echoue si une de ces frames contient le marqueur de troncature "~".

## Compatibilite

Aucun changement de protocole :
- AstralNet inchange ;
- MER inchange ;
- Malcraft/GhostLink inchange ;
- Malcraft Bridge reste 0.11.0 ;
- datapack serveur reste 0.11.0 ;
- stockage /user inchange ;
- format Store inchange.
