# LinkOS Desktop 0.17

LinkOS 0.17 pousse le multitache et la gestion des fenetres afin que le bureau se comporte comme une vraie session de travail persistante.

Cette version repart de LinkOS 0.16 et ne modifie pas le protocole AstralNet/MER.

## Restauration de session

LinkOS sauvegarde maintenant les applications ouvertes et leur etat.

Au redemarrage, il peut restaurer :
- les applications ouvertes ;
- les fenetres minimisees ;
- les fenetres maximisees ;
- la position de scroll ;
- l'application active.

La geometrie des fenetres continue d'etre sauvegardee separement afin de survivre aux redemarrages.

Les applications Link Store supprimees ne sont pas restaurees si elles ne sont plus installees.

## Parametres de session

Dans Parametres > Systeme :

- RESTAURATION: OUI/NON permet d'activer ou desactiver la restauration automatique ;
- OUBLIER SESSION efface l'etat actuellement memorise.

Le schema des preferences passe a 5.

Nouvelles preferences :
- restore_session ;
- workspace_session.

## Alt+Tab

Alt+Tab parcourt les fenetres ouvertes, y compris les applications minimisees.

Pendant que Alt reste maintenu, LinkOS affiche un switcher central avec :
- l'icone ;
- le nom de l'application ;
- l'etat ACT pour l'application active ;
- l'etat MIN pour une application minimisee.

Le switcher disparait au relachement de Alt.

F12 reste disponible comme raccourci simple pour passer a la fenetre suivante.

## Afficher le bureau

Un bouton discret se trouve tout a droite de la barre des taches.

Il permet :
- de minimiser toutes les fenetres ;
- de restaurer leur etat precedent au second clic.

Ctrl+D effectue la meme action.

## Raccourcis de fenetres

- Alt+Tab : switcher ;
- F12 : fenetre suivante ;
- Ctrl+D : afficher/restaurer le bureau ;
- Ctrl+M : reduire la fenetre active ;
- Ctrl+W : fermer la fenetre active ;
- Ctrl+Entree : maximiser/restaurer ;
- Ctrl+fleches : deplacer la fenetre active ;
- PgUp/PgDn : defiler le contenu.

## Nettoyage du code UI

0.17 corrige une duplication historique importante :

L'Explorateur Fichiers avait encore un ancien renderer dans desktop.lua qui remplacait silencieusement le renderer moderne de linkos.lua.

Cette copie a ete supprimee.

Il n'existe donc plus qu'une seule implementation active de l'Explorateur moderne :
- creation de dossiers ;
- creation de fichiers texte ;
- previsualisation ;
- edition ;
- renommage ;
- suppression ;
- navigation dans /user.

L'editeur Notes integre au workspace est volontairement conserve.

## Persistance

La session est enregistree lors des actions importantes :
- ouverture ;
- fermeture ;
- focus ;
- minimisation ;
- maximisation ;
- snap ;
- deplacement ;
- redimensionnement ;
- afficher le bureau.

La restauration ne modifie pas artificiellement la liste des applications recentes et ne declenche pas le rafraichissement distant du Store.

## Validation

Les tests automatiques couvrent maintenant :
- restauration entre deux instances LinkOS distinctes ;
- etats minimise/maximise ;
- application active ;
- Alt+Tab ;
- ouverture/fermeture du switcher ;
- afficher/restaurer le bureau ;
- raccourcis existants ;
- layouts multi-resolution ;
- applications integrees ;
- Link Store et packages.

La CI genere aussi une frame linkos-task-switcher.frame pour la revue visuelle 51x19.
