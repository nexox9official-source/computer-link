# LinkOS 0.23.1 — Lisibilite sur ComputerCraft

Les applications paginees utilisent maintenant la hauteur visible du Computer :
Repondre, les pages du catalogue et les lignes de Notes restent accessibles.
Les longues pages conservent leur defilement. Sur les tres petits ecrans, une
hauteur minimale de 12 lignes reste necessaire pour les applications paginees.

- Bureau organise en colonnes, icones et titres centres, fond simplifie.
- Demarrer plus large, six raccourcis visibles en 51x19, recherche et commandes en francais.
- Bouton reduire sur Computer, libelles lisibles dans la barre des taches en 51x19.
- Application active toujours presente dans la barre, liste de fenetres paginee et cliquable.
- Descriptions du catalogue sur deux lignes.
- Notes adapte le nombre de lignes a la fenetre.

Validation hors jeu : tests de disposition (six resolutions, deux permissions),
integration (quatre resolutions), pagination, reponse aux messages, reduction,
debordement des taches, clics du selecteur et saisie de Notes sur plusieurs pages.
Tests reseau existants conserves. Rendus des terminaux verifies visuellement.
Une verification dans Minecraft reste necessaire pour le rendu final des polices
et les interactions avec les peripheriques reels.

Installation de la branche de test sur un Computer client :

```lua
wget run https://raw.githubusercontent.com/nexox9official-source/computer-link/main/install.lua client ui/readable-computercraft-desktop
```

L'installateur conserve les donnees utilisateur et memorise la branche pour les
mises a jour suivantes. Pour revenir a la branche principale, relancer cette
commande en remplacant le dernier argument par `main`.
