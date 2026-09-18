# Computer Link — AstralNet / MER

Réseau ComputerCraft/CC:Tweaked pour Astralium.

## Objectif

Computer Link transforme les ordinateurs ComputerCraft en véritable réseau en jeu :

- serveur central **MER** (Module d'Extension Réseau) ;
- comptes liés aux Computer IDs ;
- messagerie privée en temps réel ;
- boîte de réception persistante ;
- annuaire des utilisateurs ;
- base prête pour économie, marché, actualités, nations, radar, Create et Create Big Cannons.

## Installation rapide

Sur un ordinateur CC:Tweaked avec HTTP activé :

```text
wget run https://raw.githubusercontent.com/nexox9official-source/computer-link/main/install.lua
```

L'installateur demande si l'ordinateur doit être configuré en **MER SERVER** ou en **CLIENT**.

> Chaque ordinateur qui communique par Rednet doit avoir accès à un modem. Pour un réseau sans câble, utilise un Wireless Modem.

## Commandes client

Une fois le client installé :

```text
help
register <pseudo>
whoami
users
msg <pseudo> <message>
inbox
ping
update
quit
```

## Structure

```text
install.lua
manifest.lua
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
update.lua
```

## État

Version initiale : **0.1.0**.

Le protocole réseau est volontairement versionné pour permettre d'ajouter les futurs services AstralNet sans casser les anciens ordinateurs.
