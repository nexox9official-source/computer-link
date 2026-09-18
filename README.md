# Computer Link — AstralNet / MER

Réseau ComputerCraft / CC:Tweaked pour Astralium.

## Version 0.3.0 — serveur intégré + réseau par Computer ID

Computer Link n'utilise plus de "comptes" pour la messagerie. **L'identité réseau principale est directement l'ID du ComputerCraft**.

Exemple :

```text
PC #12  ->  PC #47
```

Le serveur MER sert de routeur central et de boîte d'attente. Il ne fournit aucune commande permettant à un joueur normal de lire les messages d'un autre PC.

Les historiques de conversation sont enregistrés localement sur chaque Computer dans :

```text
/computer-link/data/history.db
```

Le MER conserve uniquement les messages encore en attente de récupération et journalise le routage sans afficher leur contenu dans sa console.

> C'est un système de confidentialité **dans l'univers ComputerCraft**. Ce n'est pas une implémentation cryptographique destinée à protéger de vraies données sensibles hors du jeu.

## Installation serveur recommandée

Pour Astralium, la méthode recommandée est maintenant le **datapack serveur Computer Link**.

Place le ZIP du datapack dans :

```text
<monde>/datapacks/
```

puis exécute :

```text
/reload
```

CC:Tweaked charge alors depuis le serveur :

- le programme ROM `link` ;
- un petit message d'aide sur les PC non configurés ;
- la politique serveur Computer Link (dont les Computer IDs autorisés pour le hacking).

Sur n'importe quel nouveau PC, plus besoin de recopier l'URL GitHub :

```text
link
```

ou directement :

```text
link client
```

Pour créer le serveur mère :

```text
link server
```

Autres commandes de bootstrap :

```text
link status
link update
link start
link help
```

Les fichiers placés dans la ROM CraftOS par le datapack sont côté serveur et ne sont pas modifiables depuis le disque normal d'un ComputerCraft.

### Installation manuelle de secours


### Serveur mère MER

```text
wget run https://raw.githubusercontent.com/nexox9official-source/computer-link/main/install.lua server
```

Puis :

```text
reboot
```

### PC client

```text
wget run https://raw.githubusercontent.com/nexox9official-source/computer-link/main/install.lua client
```

Puis :

```text
reboot
```

Chaque machine doit avoir un **Wireless Modem** pour utiliser le réseau radio.

## Commandes réseau privées

Afficher l'identité du PC :

```text
id
```

Donner un label lisible au PC :

```text
label QG-NORD
```

Envoyer un message privé directement à un autre Computer ID :

```text
msg 47 Rendez-vous au bunker a 22h
```

Récupérer les messages :

```text
inbox
```

Voir uniquement sa propre conversation locale avec un PC :

```text
history 47
```

Vérifier qu'un ID est connu du MER :

```text
device 47
```

Aucune commande normale ne permet d'obtenir la liste complète des PC enregistrés.

## Module d'intrusion — gameplay ComputerCraft

### Autorisation

Les commandes spéciales d'intrusion sont réservées au **Computer ID #1**. Avec le datapack serveur, cette autorisation est fournie par la ROM serveur plutôt que par un simple fichier local modifiable.

Les autres PC peuvent utiliser AstralNet normalement et peuvent être ciblés, mais ils ne peuvent pas lancer `scan`, `hack` ou `remote`.

La restriction est vérifiée côté attaquant **et côté cible** : même si un autre joueur modifie son client, une cible Computer Link refusera les commandes d'intrusion provenant d'un ID non autorisé.

La version 0.2.0 ajoute un premier système de hacking **entièrement dans Minecraft/ComputerCraft**.

Il ne cible ni Windows, ni le serveur hôte, ni des machines réelles : seulement les Computers CC:Tweaked qui exécutent Computer Link.

### Scanner les machines proches

```text
scan
```

Le scan radio ne découvre que les Computers Computer Link présents dans la portée configurée (64 blocs actuellement).

Exemple :

```text
#47 | 18.2 blocs | SEC 2 | QG-NORD
#82 | 41.7 blocs | SEC 2 | PC-LABO
```

### Tenter une intrusion

```text
hack 47
```

La cible génère un challenge local. L'attaquant doit être à proximité pour obtenir une session temporaire.

Voir les sessions obtenues :

```text
sessions
```

### Une fois connecté à une cible

Informations :

```text
remote 47 info
```

Lire un extrait des conversations conservées sur ce PC :

```text
remote 47 conversations
```

Lister ses fichiers ComputerCraft :

```text
remote 47 ls /
```

Lire un fichier texte :

```text
remote 47 cat /startup.lua
```

Provoquer un crash **du ComputerCraft ciblé uniquement** :

```text
remote 47 crash
```

Le PC redémarre ensuite en mode récupération pendant quelques secondes.

Le dossier ROM de CC:Tweaked n'est pas exposé par le terminal distant.

## Architecture

```text
install.lua
manifest.lua
boot.lua
update.lua

src/
  common/
    config.lua
    util.lua
    network.lua

  server/
    database.lua
    server.lua

  client/
    storage.lua
    hack.lua
    client.lua
```

## Mise à jour automatique

À partir de la **v0.2.3**, chaque Computer vérifie automatiquement GitHub **à chaque démarrage**, aussi bien le MER que les clients.

Au boot :

```text
COMPUTER LINK
AUTO UPDATE

Verification des mises a jour...
Local  : 0.2.3
Remote : 0.2.4

Nouvelle version detectee.
Mise a jour automatique...
```

Si une nouvelle version existe, elle est téléchargée avant le lancement de Computer Link. Si GitHub/HTTP est indisponible, le Computer continue simplement avec sa version locale.

Pour les machines installées avant la v0.2.3, il faut faire **une dernière mise à jour manuelle** afin de récupérer le nouveau boot automatique :

Client :

```text
update
reboot
```

MER :

```text
Ctrl+T
/computer-link/update.lua
reboot
```

Après cette migration, un simple `reboot` suffit pour récupérer automatiquement les futures versions.

## Suite prévue

La fondation actuelle permet maintenant de construire au-dessus :

- interface graphique Advanced Computer ;
- carnet d'adresses local (alias -> Computer ID) sans comptes centraux ;
- canaux de groupe/pays ;
- chiffrement de gameplay et clés tournantes ;
- niveaux de sécurité, antivirus et pare-feu ;
- exploits différents selon le matériel ;
- terminal pirate plus visuel avec progression ;
- brouilleur radio ;
- interception temporaire après compromission ;
- fausses données / honeypots ;
- économie et commerce à distance ;
- réseau militaire ;
- radar et alertes ;
- Create / Create Big Cannons.


## Architecture cible

Computer Link doit évoluer vers un véritable OS réseau pour Astralium, pas seulement un terminal de commandes. La base 0.3.0 est organisée pour accueillir :

- bureau graphique sur Advanced Computer ;
- application Messages avec conversations privées par Computer ID ;
- carnet de contacts et alias locaux ;
- groupes, pays, coalitions et canaux militaires ;
- système de fichiers et pièces jointes ComputerCraft ;
- notifications temps réel ;
- statut en ligne/hors ligne ;
- chiffrement de gameplay des communications ;
- niveaux de sécurité et pare-feu ;
- logs d'intrusion et antivirus ;
- hacking de proximité avec plusieurs exploits/minijeux ;
- backdoors et sessions temporaires ;
- économie, banque, boutiques et marché ;
- actualités et faux sites AstralNet ;
- cartes/radar et alertes militaires ;
- contrôle Create, Create Big Cannons et autres périphériques compatibles ;
- permissions serveur centralisées ;
- mises à jour automatiques à chaque démarrage.

Le serveur **MER** reste le cœur de routage et de services, tandis que les conversations privées sont adressées par Computer ID.
