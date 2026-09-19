# LinkOS 0.18 / Malcraft Bridge 0.11

Cette release reconstruit la couche Malcraft/GhostLink pour le gameplay Minecraft CC:Tweaked.

Important : tout ce systeme est limite aux Computers CC:Tweaked du serveur Minecraft. Il n'accede pas au PC reel du joueur.

## Objectif

Une cible n'a plus besoin d'avoir installe LinkOS pour etre visible, contaminee et controlee.

Le systeme repose maintenant sur deux couches complementaires :
- la ROM ComputerCraft injectee par le datapack serveur ;
- Malcraft Bridge 0.11, mod Forge serveur uniquement.

LinkOS ajoute l'interface operateur LinkSec, mais n'est pas requis sur les cibles.

## Infection sans LinkOS

Un Computer vanilla CraftOS peut etre contamine par :
- un disque CC:Tweaked portant le carrier Malcraft ;
- la propagation de proximite depuis un poste infecte ;
- une contamination demandee par le PC operateur autorise ;
- une propagation via un autre Computer infecte autorise a propager.

Le daemon ROM demarre avant le shell CraftOS et reste actif en arriere-plan.

## Persistance

Une fois infecte :
- retirer le disque ne nettoie pas le poste ;
- redemarrer le Computer ne nettoie pas le poste ;
- l'etat est conserve localement dans les settings CraftOS ;
- l'etat est aussi conserve par Malcraft Bridge dans les donnees du monde ;
- le dernier label, la dimension, la position et la derniere presence sont conserves cote serveur.

Si un Computer infecte est casse puis remplace au meme bloc avec un nouvel ID CC:Tweaked, le Bridge peut migrer l'infection de l'ancien ID vers le nouveau tant que l'ancien poste infecte est hors ligne.

## Nettoyage fiable

Le nettoyage distant cree un tombstone serveur.

Au prochain boot de la cible, cet etat propre est applique AVANT le scan des disques.

Cas important :
- cible eteinte ;
- disque contamine encore insere ;
- nettoyage demande depuis LinkSec ;
- cible rallumee.

Le disque ne peut plus reinfecter la machine avant l'application du nettoyage.

Tant que ce meme carrier reste insere, le tombstone reste actif. Quand le disque est retire, la cible accuse reception du nettoyage et le tombstone peut etre supprime. Une reinsertion ulterieure compte alors comme une nouvelle contamination.

## Decouverte des PCs sans OS

LinkSec > Malcraft contient maintenant :
- RESEAU INFECTE : registre persistant des machines infectees ;
- PCS CHARGES : Computers actuellement charges par le serveur, LinkOS ou modem non requis ;
- DISQUES LOCAUX : gestion des carriers branches sur le poste operateur ;
- CIBLE PAR ID : verification/contamination directe d'un ID connu.

Les listes indiquent notamment :
- ID ;
- label ;
- online/offline ;
- propagation ;
- source de contamination ;
- position/dimension quand disponible.

## Controle ROM-only

Une cible infectee sans LinkOS expose l'agent ROM Malcraft :
- capture d'ecran CraftOS ;
- observation ou controle clavier/souris ;
- reboot, arret et crash RP ;
- inventaires exposes a CC:Tweaked ;
- redstone ;
- lecteurs/disques ;
- peripheriques CC:Tweaked ;
- Computers proches/cables.

Le statut de cible affiche clairement :
- LINKOS + ROM ;
- ROM SEUL ;
- ONLINE/OFFLINE ;
- source de contamination ;
- position connue.

Les coordonnees de souris distantes sont maintenant limitees a la vraie surface capturee de la cible.

## Compatibilite reseau

Malcraft Bridge est traite separement d'AstralNet/MER.

Le registre Bridge et les commandes ROM-only restent utilisables meme si le MER AstralNet est hors ligne. Le MER reste disponible comme fallback de compatibilite quand le Bridge n'est pas installe.

## Securite de l'interface

LinkSec reste une application operateur uniquement.

La politique ROM actuelle autorise PC #0 comme poste operateur et le rend immunise a Malcraft. Les PCs standards ne voient pas l'application LinkSec/MAL dans leur launcher.

## Tests automatiques

La CI verifie :
- syntaxe Lua ;
- layouts et fenetres LinkOS ;
- cycle des packages ;
- etat ROM-only sans LinkOS ;
- nettoyage distant sans carrier ;
- nettoyage distant avec carrier encore insere ;
- contamination initiale par carrier ;
- restauration d'une infection persistante serveur ;
- compilation Forge Java 17 de Malcraft Bridge ;
- creation du JAR, du datapack et du pack serveur complet.

## Installation serveur

Le pack CI Malcraft 0.11 contient :
- malcraft-bridge-0.11.0.jar ;
- Computer-Link-Server-Datapack-1.20.1-v0.11.0.zip ;
- Computer-Link-Malcraft-Server-v0.11.0.zip.

Arreter le serveur avant remplacement et supprimer les anciens malcraft-bridge-*.jar pour eviter de charger deux versions du mod.
