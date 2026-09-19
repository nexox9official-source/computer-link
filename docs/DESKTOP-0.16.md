# LinkOS Desktop 0.16

LinkOS 0.16 transforme la refonte graphique 0.15 en un environnement de travail plus proche d'un vrai OS desktop.

Le backend AstralNet/MER ne change pas. Cette version travaille surtout sur la productivite, la personnalisation du bureau, la barre des taches, les notifications, l'Explorateur et le Link Store.

## Barre des taches

Les applications peuvent maintenant etre epinglees meme lorsqu'elles sont fermees.

Par defaut :
- Messages
- Fichiers
- Applications

Le clic gauche :
- ouvre une app epinglee fermee ;
- remet au premier plan une app ouverte ;
- reduit l'app active.

Le clic droit ouvre un menu contextuel permettant notamment d'epingler ou de desepingler l'application.

Les epingles sont configurables dans Parametres > Style.

## Bureau

Le bureau n'affiche plus automatiquement toutes les applications installees.

Raccourcis par defaut :
- Messages
- Fichiers
- Applications
- Notes

Toutes les autres apps restent disponibles depuis le launcher LinkOS.

Un clic droit sur une app permet :
- Ouvrir ;
- Epingler / Desepingler de la barre des taches ;
- Ajouter / Retirer du bureau ;
- Ouvrir Applications ;
- Ouvrir Parametres.

Le clic droit sur le fond du bureau donne acces a :
- Actualiser ;
- Fichiers ;
- Applications ;
- Parametres.

Le meme menu d'application est accessible par clic droit depuis le launcher et la taskbar.

## Launcher

Quand aucune recherche n'est active, l'ordre devient :
1. applications epinglees ;
2. applications recentes ;
3. toutes les autres applications.

Les lignes sont marquees PIN ou RECENT lorsque pertinent.

La recherche reste disponible au clavier.

## Centre Systeme et notifications

Les notifications temporaires restent affichees sous forme de toast pendant quelques secondes.

Le panneau Systeme conserve maintenant un historique court des dernieres notifications avec leur heure.

Il continue d'afficher :
- etat AstralNet ;
- messages non lus ;
- ecran actif ;
- heure ;
- acces aux Parametres et au Bureau.

## Explorateur de fichiers

L'Explorateur travaille exclusivement dans /user.

Nouvelles actions :
- creer un dossier ;
- creer un fichier texte ;
- editer un fichier ;
- renommer un fichier ;
- supprimer un fichier avec confirmation ;
- previsualiser le contenu ;
- naviguer dans les dossiers.

Les noms recus par l'interface sont verifies afin d'eviter de sortir de l'espace utilisateur.

## Link Store

Le catalogue officiel distant de 0.15 reste valide avant utilisation et conserve son fallback local.

0.16 ajoute :
- recherche par nom ;
- recherche par identifiant ;
- recherche dans la description ;
- remise a zero du filtre ;
- contenu scrollable dimensionne selon tout le catalogue.

Un catalogue de plusieurs dizaines d'applications peut donc etre affiche sans perdre les entrees situees apres la premiere page.

## Preferences et migration

Le schema UI passe a 4.

Correction importante : les preferences de type liste copient maintenant reellement leurs valeurs par defaut au premier lancement.

Nouvelles preferences :
- taskbar_pins ;
- desktop_shortcuts ;
- recent_apps.

Les anciennes preferences existantes restent chargees puis completees avec les nouvelles valeurs absentes.

## Validation

La CI execute toujours :
- syntaxe de tous les fichiers Lua ;
- shell sur plusieurs resolutions ;
- vrais renderers des apps integrees ;
- workspace/fenetres ;
- dialogues ;
- snap ;
- packages ;
- echec reseau et paquets invalides.

Les tests couvrent en plus les apps epinglees et les menus contextuels.

Les frames UI produites par le workflow restent disponibles comme artefacts GitHub Actions.
