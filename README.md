# Computer Link — AstralNet / MER

Réseau ComputerCraft/CC:Tweaked pour Astralium.

## Objectif

Computer Link transforme les ordinateurs ComputerCraft en véritable réseau en jeu :

- serveur central **MER** (Module d'Extension Réseau) ;
- comptes liés aux Computer IDs ;
- messagerie privée ;
- boîte de réception persistante ;
- annuaire des utilisateurs ;
- mise à jour depuis GitHub ;
- base prête pour économie, marché, actualités, nations, radar, Create et Create Big Cannons.

## Installation

### Serveur mère MER

Sur le Computer qui doit devenir le serveur central :

```text
wget run https://raw.githubusercontent.com/nexox9official-source/computer-link/main/install.lua server
```

### Ordinateur client

Sur un Computer joueur :

```text
wget run https://raw.githubusercontent.com/nexox9official-source/computer-link/main/install.lua client
```

### Menu interactif

Tu peux aussi lancer simplement :

```text
wget run https://raw.githubusercontent.com/nexox9official-source/computer-link/main/install.lua
```

Puis choisir **MER SERVER** ou **CLIENT**.

L'installateur :

1. télécharge automatiquement tous les fichiers ;
2. crée `/computer-link` ;
3. sauvegarde un éventuel ancien `startup.lua` ;
4. installe le démarrage automatique ;
5. conserve le rôle du Computer.

> Chaque ordinateur qui communique sans câble doit avoir un **Wireless Modem**. HTTP doit être activé côté CC:Tweaked pour l'installation et les mises à jour.

## Commandes client

```text
help
register <pseudo>
whoami
users
msg <pseudo> <message>
inbox
ping
stats
update
quit
```

## Mise à jour

Depuis un Computer déjà installé :

```text
/computer-link/update.lua
```

ou utilise simplement la commande `update` depuis le client.

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
    client.lua
```

Les données du MER sont enregistrées localement dans :

```text
/computer-link/data/mer.db
```

## Version

**0.1.0 — fondation réseau**

Cette version fournit le cœur du MER, l'inscription des Computers, la messagerie et les mises à jour. Les prochaines étapes prévues sont l'interface Advanced Computer, les services économiques, les nations, le radar et les intégrations Create.
