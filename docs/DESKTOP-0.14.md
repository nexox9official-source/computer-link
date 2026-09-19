# LinkOS Desktop 0.14

Implementation native Computer Link. Le code LevelOS n'est pas copie et son
magasin n'est pas utilise. Priorite au format Computer 51x19.

## Installation

Poste joueur (ne pas utiliser `client` sur le MER) :

```text
wget run https://raw.githubusercontent.com/nexox9official-source/computer-link/main/install.lua client
```

Un poste deja installe recupere la version au redemarrage. Aucun nouveau JAR ou
datapack n'est requis pour cette interface : le backend existant est conserve.

## Bureau et fenetres

- Double-clic sur une icone pour ouvrir une application ; un clic la selectionne.
- Glisser une icone sur une autre pour reorganiser la grille. Ordre sauvegarde.
- Glisser la barre de titre pour deplacer une fenetre, le `+` en bas a droite pour redimensionner.
- `_` reduit, `[]` agrandit/restaure, `X` ferme. Une fenetre par application.
- Cliquer une fenetre la place devant les autres. Les zones masquees ne recoivent pas les clics.
- START ouvre la recherche ; HOME reduit toutes les fenetres.
- La barre des taches affiche les fenetres qui tiennent dans la largeur disponible.
  Les autres restent accessibles avec F12 ou en rouvrant l'application via START.
- Le contenu des applications defile independamment dans chaque fenetre, avec
  molette, PgUp/PgDn ou les boutons `^` / `v` de son pied de page.
- Positions et dimensions sont sauvegardees apres un glisser-deposer ; elles sont
  bornees de nouveau quand la taille de l'ecran change.
- L'image du bureau est composee hors ecran avant affichage pour limiter le scintillement.

## Computer normal, sans souris

Le Computer normal n'emet pas les interactions souris d'un Advanced Computer.
Le bureau reste utilisable au clavier :

| Touche | Action |
| --- | --- |
| F10 | Menu des applications, taper pour chercher |
| Haut / Bas, Entree | Selection et ouverture dans le menu |
| Tab, Entree sur le bureau | Selection et ouverture d'une icone |
| M puis Gauche / Droite puis M | Reordonner l'icone selectionnee |
| Gauche / Droite hors mode M | Pages du bureau |
| Tab puis Entree dans une fenetre | Parcourir puis activer ses boutons visibles |
| F12 | Parcourir les fenetres ouvertes, y compris reduites |
| Ctrl + fleches | Deplacer la fenetre active |
| Ctrl + Entree | Agrandir / sortir du mode agrandi |
| Ctrl + M | Reduire la fenetre active |
| Ctrl + W | Fermer la fenetre active |
| PgUp / PgDn | Defiler dans la fenetre active |

Sur Advanced Monitor, utiliser les boutons tactiles et le clavier du Computer.
Le monitor ne fournit pas de glisser-deposer souris. Toucher deux fois une icone
rapidement l'ouvre ; START offre aussi une ouverture en une selection.

## Notes et fichiers

L'explorateur reste limite a `/user`. Il permet de creer des dossiers, ouvrir un
texte et preparer un nouveau document. Aucun bouton de suppression destructive.

Notes est un editeur multiligne integre : EDITER, taper, Entree pour une nouvelle
ligne, fleches pour deplacer le curseur, Ctrl+S pour sauvegarder, Echap pour finir
l'edition. Le bouton SAUVEGARDER est egalement disponible par defilement.
La fermeture d'un document modifie demande de sauver, abandonner ou annuler.
Une sauvegarde conserve la version precedente dans `.backup`.
Limites : lecture 64 Ko, ajout jusqu'a 500 lignes, 500 caracteres par ligne.
Les fichiers non textuels ne sont pas des documents pris en charge.

## Link Store

Quatre paquets officiels, telecharges uniquement apres confirmation :

- Mes taches : checklist paginee et sauvegardee dans `/user/tasks.db`.
- Chronometre : demarrer, pause et remise a zero ; etat de session seulement.
- Convertisseur : metres/kilometres, Celsius/Fahrenheit, minutes/secondes.
- Peripheriques : appareils connectes et contenu des inventaires en lecture seule.

La source est le dossier `packages/` de ce depot, pas un catalogue public tiers.
La reception est limitee a 64 Ko ; syntaxe et marqueur de version sont controles
avant installation. Le paquet n'est pas execute pendant le telechargement.
Une mise a jour garde `.backup`. RETIRER deplace le programme vers `.removed`
sans supprimer ses documents. Ces suffixes sont des copies locales recuperables.
Les applications du catalogue sont du code de confiance : ceci n'est PAS un bac
a sable de securite et un marqueur de version n'est pas une signature numerique.

## Limites et validation

Les fenetres integrees restent ouvertes et gardent leur etat, mais il ne s'agit
pas encore d'un ordonnanceur general de programmes CraftOS en parallele.
Le terminal CraftOS et certains outils historiques utilisent encore le mode
natif au premier plan. Les applications reseau conservent leurs composants
existants dans les nouvelles fenetres. MER et les autorisations ROM LinkSec
ne sont pas modifies.

Tests hors Minecraft : syntaxe Lua, six tailles pour le lanceur, quatre tailles
pour le gestionnaire et les rendus des applications, interactions de fenetres,
editeur, dialogues, installation/reinstallation/retrait, erreurs reseau et paquets
invalides. Rendu 51x19 inspecte a partir du terminal simule. Une verification
reelle sur le serveur Minecraft reste necessaire.
