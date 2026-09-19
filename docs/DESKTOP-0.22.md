# LinkOS 0.22 — Reference-driven UI rebuild

LinkOS 0.22 remplace une grande partie de la couche UI maison par une architecture
de composants construite a partir de patterns eprouves dans des OS ComputerCraft
existants.

## Sources

### OneOS — MIT
Repository: https://github.com/oeed/OneOS

Patterns adaptes:
- application rows / cards;
- collection layouts;
- 4x3 icon asset model;
- preference pour une interface plein ecran sur les petites resolutions.

### Opus OS — MIT
Repository: https://github.com/kepler155c/opus

Patterns adaptes:
- buttons avec etats normal / selected / inactive / primary / danger;
- tabs avec une page active;
- scrolling list model et scrollbar;
- controles reutilisables au lieu de layouts dessines au cas par cas.

### Basalt — MIT
Repository: https://github.com/Pyroxenium/Basalt

Utilise comme reference d'architecture pour:
- composants;
- themes;
- evenements;
- etats UI.

Voir THIRD_PARTY_UI.md pour les notices de licence.

LevelOS peut servir de reference visuelle, mais aucun code LevelOS n'est integre
sans licence compatible verifiee.

## Nouvelle couche CCUI

Fichier: src/ui/ccui.lua

Composants:
- panel
- button
- tabs
- appRow
- page
- scrollbar
- breadcrumb

Ces composants deviennent la base commune des applications LinkOS.

## Applications migrees

- Demarrer
- Applications / Store
- Fichiers
- Parametres
- Messages
- Contacts
- Reseau
- Securite
- Calculatrice
- Terminal
- Notes
- A propos
- accueil LinkSec

Le comportement reseau et Malcraft n'est pas modifie par cette refonte.

## Icones

src/ui/icons.lua fournit des assets 4x3 dedies aux applications principales.
Le principe reprend le modele d'assets compacts de OneOS au lieu de representer
chaque application avec une simple lettre.

## Navigation

Sur un Computer standard:
- les applications restent plein ecran;
- START et la taskbar restent les reperes principaux;
- Demarrer utilise Recherche + tabs Epinglees/Toutes + liste;
- les grands Advanced Monitors conservent davantage de capacites de fenetrage.

## Qualite visuelle automatique

La CI produit des frames 51x19 pour:
- Demarrer
- Store
- Parametres
- Fichiers
- Messages
- Calculatrice
- LinkSec
- Alt+Tab

La release echoue si ces frames contiennent le caractere "~" genere par le
systeme de troncature LinkOS. Cela empeche un bouton ou texte principal coupe
d'arriver sur main.

## Compatibilite

Cette refonte ne change pas:
- AstralNet;
- MER;
- Malcraft/GhostLink;
- Malcraft Bridge;
- stockage des messages;
- fichiers /user;
- format des apps Store.
