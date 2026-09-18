# Computer Link — LinkOS / AstralNet

Computer Link transforme les Computers **CC:Tweaked** d'Astralium en véritables postes réseau avec une interface graphique adaptative.

## LinkOS 0.7.1

Le client n'est plus seulement un terminal de commandes. Il démarre maintenant sur **LinkOS**, un environnement graphique inspiré d'un OS desktop moderne :

- bureau avec barre des tâches ;
- applications graphiques ;
- souris sur Advanced Computer ;
- interaction tactile sur Advanced Monitor ;
- navigation clavier avec raccourcis F1–F7 ;
- interface responsive selon la résolution ;
- support des moniteurs multi-blocs ;
- gestion de plusieurs moniteurs séparés ;
- changement d'écran principal par simple toucher ;
- affichages secondaires avec statut temps réel ;
- mode CLI classique conservé en secours.

L'identité réseau reste le **Computer ID**. Il n'existe pas de compte central obligatoire.

```text
PC #0  <---- AstralNet / MER ---->  PC #42
```

## Interface adaptative

LinkOS mesure automatiquement la taille réelle de l'écran.

Il utilise quatre présentations :

```text
COMPACT   petit écran / Computer
STANDARD  petit moniteur
WIDE      moniteur moyen
WALL      grand mur de moniteurs
```

Pour un moniteur, LinkOS ajuste aussi automatiquement `setTextScale` afin de conserver un bon compromis entre lisibilité et espace disponible.

Un grand mur ne reçoit donc pas une interface simplement étirée : il affiche davantage d'informations et davantage de colonnes.

### Plusieurs moniteurs

Si plusieurs moniteurs sont connectés :

- LinkOS choisit automatiquement un affichage principal adapté ;
- les autres deviennent des écrans compagnons ;
- ils affichent l'état MER, l'ID du PC, l'heure et les notifications ;
- toucher un **Advanced Monitor** secondaire le transforme immédiatement en écran principal.

L'écran peut aussi être choisi dans **Paramètres**.

## Applications intégrées

### Bureau

Le bureau affiche l'état général du PC et donne accès aux applications.

La barre des tâches reste disponible sur les écrans suffisamment grands.

### Messages

Messagerie privée adressée directement à un Computer ID.

```text
PC #12 -> PC #47
```

Les conversations sont conservées localement dans :

```text
/computer-link/data/history.db
```

Fonctions :

- nouvelles conversations ;
- historique local ;
- notifications ;
- réponse rapide ;
- alias locaux.

### Contacts

Un carnet d'adresses local permet d'associer un nom humain à un Computer ID :

```text
QG Nord      -> #42
Banque UCS   -> #58
Radar Est    -> #71
```

Les alias restent locaux au PC et ne changent jamais l'adresse réseau réelle.

### Réseau

Tableau de bord AstralNet :

- Computer ID ;
- label du PC ;
- MER connecté ;
- modem utilisé ;
- version ;
- protocole ;
- ping ;
- synchronisation ;
- reconnexion manuelle ;
- renommage du PC.

### Sécurité

Centre de sécurité de LinkOS.

### Mot de passe LinkOS

Chaque joueur peut activer un mot de passe local depuis **Sécurité**.

- mot de passe de 4 à 32 caractères ;
- saisie masquée ;
- écran de verrouillage au démarrage ;
- verrouillage manuel ;
- verrouillage automatique après inactivité ;
- changement et désactivation protégés par l'ancien mot de passe.

CC:Tweaked n'expose pas directement un événement fiable indiquant qu'un joueur vient de fermer l'interface du Computer. LinkOS reproduit donc ce comportement avec un verrouillage automatique après une courte période d'inactivité.

Les mots de passe ne sont pas stockés en clair : LinkOS conserve un sel et un hash local.

Un opérateur LinkSec ayant déjà compromis le PC peut récupérer ce hash de gameplay et lancer :

```text
auth
crackpass auto
crackpass pin
crackpass short
```

Le mode `auto` teste les mots de passe courants, les PIN à 4 chiffres et les petits mots en lettres minuscules.

Les postes standards voient uniquement leur état de protection. Les outils d'intrusion ne sont pas affichés sur leur interface.

## LinkSec CMD

Sur un Computer autorisé par la politique serveur — actuellement **PC #0** — LinkOS ajoute une application supplémentaire : **LinkSec CMD**.

Elle n'existe visuellement que pour les opérateurs autorisés. Elle se comporte comme un terminal d'administration/intrusion intégré à l'OS et permet notamment :

```text
help
scan
targets
hack <id>
use <id>
sessions
info
conversations
ls [chemin]
cat <fichier>
write <fichier> <texte>
delete <chemin>
lock [message]
message <texte>
unlock
label <nom>
reboot
crash
disconnect
```

Le prompt affiche toujours l'opérateur et la cible active :

```text
root@pc1[-]$
root@pc1[#42]$
```

Le raccourci **F8** ouvre directement LinkSec CMD sur un poste autorisé.

Le terminal est maintenant **persistant** : après une commande, le résultat reste affiché et le prompt revient juste en dessous, comme dans un vrai terminal. On reste dans LinkSec jusqu'à la commande :

```text
exit
```

`help` et `hlp` affichent les commandes avec des exemples.

La partie graphique Sécurité reste volontairement simple : état du poste, politique serveur, puis un accès au terminal LinkSec uniquement lorsqu'il est disponible.

### Gameplay d'intrusion ComputerCraft

Le **Computer #0** est l'opérateur spécial autorisé par la politique serveur.

Les commandes et boutons d'intrusion ne sont affichés **que** sur un PC autorisé. Sur les autres postes, le Centre de sécurité reste une simple interface de protection sans commandes de hacking.

La politique peut être fournie par la ROM côté serveur grâce au datapack, donc elle ne dépend pas uniquement d'un fichier local facilement modifiable.

Le système actuel permet notamment :

- scan de proximité ;
- challenge d'intrusion ;
- sessions temporaires ;
- inspection des informations d'un PC compromis ;
- lecture de son historique Computer Link ;
- exploration et lecture de fichiers ComputerCraft ;
- écriture et suppression de fichiers distants ;
- changement du label du PC ;
- message forcé plein écran ;
- verrouillage distant ;
- écran rouge **YOU HAVE BEEN HACKED** avec une grande tête de mort ASCII adaptée du visuel fourni, plus une version compacte pour les petits écrans ;
- déverrouillage distant ;
- reboot et crash simulé du ComputerCraft ciblé.

Un PC verrouillé reste connecté au service réseau afin que l'opérateur puisse continuer à le contrôler ou le déverrouiller. L'écran de verrouillage est persistant après reboot tant qu'il n'a pas été retiré à distance.

Tout cela reste **strictement dans Minecraft/CC:Tweaked**.

### Fichiers

Explorateur de fichiers local :

### Fichiers utilisateur protégés

L'application **Fichiers** n'affiche plus les fichiers internes de LinkOS. Les dossiers système, le code Computer Link, la ROM et les fichiers de démarrage sont masqués de l'explorateur graphique afin de garder une interface propre et de ne pas exposer l'implémentation interne de sécurité aux joueurs.

- navigation dans les dossiers ;
- aperçu de fichiers texte ;
- taille des fichiers ;
- espace disponible.

### Paramètres

Gestion de LinkOS :

- écran principal ;
- moniteurs détectés ;
- résolution ;
- mode responsive ;
- support tactile ;
- couleur d'accent ;
- mise à jour ;
- mode CLI ;
- reboot ;
- arrêt ;
- vérification des mises à jour ;
- reboot et arrêt.

### Mise à jour rapide

Un bouton **MAJ** est maintenant présent directement dans la barre supérieure du Computer et du moniteur principal. Il devient jaune lorsqu'une nouvelle version est disponible. Les moniteurs tactiles secondaires affichent aussi un bouton **MISE A JOUR** lorsque nécessaire.

### Indicateur de mise à jour

LinkOS vérifie périodiquement la version GitHub pendant qu'il fonctionne. Le bouton **MISE À JOUR** reste discret quand le PC est à jour et devient **jaune** lorsqu'une nouvelle version est détectée.

La désinstallation n'est volontairement plus proposée dans l'interface graphique. Elle reste disponible manuellement après avoir quitté/arrêté LinkOS.

## Contrôles

Sur **Advanced Computer**, utilise la souris.

Sur **Advanced Monitor**, touche directement les boutons.

Le clavier reste utilisable :

```text
F1  Bureau
F2  Messages
F3  Réseau
F4  Sécurité
F5  Fichiers
F6  Paramètres
F7  Contacts
F8  LinkSec CMD (opérateurs uniquement)
ESC Bureau
```

Lorsqu'un champ texte doit être saisi alors que l'interface est affichée sur un moniteur, LinkOS demande la saisie sur le terminal du Computer puis revient automatiquement sur le moniteur.

## MER

Le MER est le serveur central de routage AstralNet.

Il gère notamment :

- découverte des PC ;
- présence ;
- routage des messages ;
- messages en attente pour les PC hors ligne ;
- statistiques réseau.

Le contenu des conversations n'est pas affiché dans la console normale du MER.

## Installation serveur recommandée

Installe le datapack Computer Link dans :

```text
<monde>/datapacks/
```

puis :

```text
/reload
```

Le datapack ajoute la commande CraftOS :

```text
link
```

Sur un nouveau Computer :

```text
link
```

ou directement :

```text
link install
```

L'installation du **MER n'est pas proposée aux joueurs**. Le MER est provisionné uniquement par l'administration Astralium.

Autres commandes :

```text
link
link status
link update
link start
link uninstall
link help
```

## Installation manuelle de secours

Client :

```text
wget run https://raw.githubusercontent.com/nexox9official-source/computer-link/main/install.lua client
```

Une demande d'installation MER est refusée par défaut sauf sur un MER déjà provisionné ou explicitement autorisé par la politique serveur.

## Mises à jour

Les installations récentes vérifient GitHub automatiquement à chaque démarrage.

```text
COMPUTER LINK
AUTO UPDATE

Local  : 0.7.1
Remote : 0.7.2

Mise a jour automatique...
```

Si GitHub est indisponible, LinkOS démarre avec sa copie locale.

## Désinstallation

Depuis LinkOS :

```text
uninstall
```

ou depuis CraftOS avec le datapack :

```text
link uninstall
```

L'ancien `startup.lua` est restauré lorsqu'une sauvegarde existe.

Le Computer ID ne change pas.

## Architecture

```text
install.lua
update.lua
uninstall.lua
boot.lua
manifest.lua

src/
  common/
    config.lua
    util.lua
    network.lua

  client/
    client.lua
    service.lua
    storage.lua
    hack.lua
    cli.lua

  ui/
    draw.lua
    display.lua
    prefs.lua

  os/
    linkos.lua

  server/
    database.lua
    server.lua
```

## Direction du projet

La base graphique est maintenant en place. Les prochaines couches prévues peuvent inclure :

- vraies fenêtres déplaçables/minimisables ;
- écran de verrouillage ;
- centre de notifications ;
- navigateur AstralNet et faux sites ;
- banque et économie ;
- boutique et marché ;
- groupes, pays et coalitions ;
- canaux militaires ;
- chiffrement de gameplay ;
- firewall, antivirus et journaux de sécurité ;
- outils de hacking plus variés ;
- radar/cartographie ;
- Create et Create Big Cannons ;
- programmes installables comme de véritables applications LinkOS.


## Bootstrap serveur dynamique

À partir du datapack LinkOS 0.5.0, la commande ROM `link` ne contient plus le menu complet. Elle charge le bootstrap officiel depuis GitHub à chaque utilisation.

Conséquence : les futures modifications du menu d'installation ne nécessitent plus de remplacer le datapack. Le datapack conserve uniquement les éléments qui doivent rester côté serveur, notamment la politique de sécurité.
