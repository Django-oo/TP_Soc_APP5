# V0 — Tutoriel Qsys : création d’un composant spécifique Avalon-MM

## 1. Objectif du tutoriel

L’objectif de ce tutoriel est de comprendre comment créer un **composant matériel spécifique** dans **Qsys / Platform Designer** et comment l’intégrer dans un système embarqué basé sur un processeur **Nios II**.

Le composant réalisé dans ce tutoriel est volontairement simple : il s’agit d’un registre 16 bits accessible par logiciel. Le processeur Nios II peut écrire une valeur dans ce registre via le bus **Avalon Memory-Mapped**, puis cette valeur est exportée vers l’extérieur du système Qsys afin d’être affichée sur les afficheurs 7 segments de la carte.

Ce tutoriel permet donc de comprendre les notions suivantes :

- création d’un composant spécifique dans Qsys ;
- séparation entre la logique matérielle interne et l’interface Avalon ;
- utilisation d’une interface **Avalon-MM Slave** ;
- export de signaux matériels avec une interface **Avalon Conduit** ;
- accès logiciel au composant depuis le Nios II ;
- connexion des signaux du système Qsys au top-level Quartus ;
- affectation des broches physiques de la carte FPGA.

## Différence entre composant spécifique et instruction spécifique

Le tutoriel porte sur un **composant spécifique Qsys**, et non sur une instruction spécifique du Nios II.

Une instruction spécifique est ajoutée directement dans le processeur.  
Elle sert principalement à accélérer un calcul.

Un composant spécifique Qsys est ajouté comme un périphérique dans le système.  
Il est accessible par le bus Avalon et possède une adresse mémoire.

| Critère | Instruction spécifique | Composant spécifique Qsys |
|---|---|---|
| Position | Dans le processeur Nios II | Sur le bus Avalon |
| Utilisation | Accélération de calcul | Périphérique matériel |
| Accès logiciel | Appel d’une instruction spéciale | Lecture/écriture mémoire |
| Adresse mémoire | Non | Oui |
| Interface | Interface custom instruction | Avalon-MM, Conduit, Clock, Reset |
| Exemple | Addition spéciale, multiplication optimisée | Registre, PIO, contrôleur, périphérique matériel |

Dans ce tutoriel, le registre 16 bits est un composant spécifique, car il est intégré comme un périphérique mémoire-mappé dans le système Qsys.

---

---

## 2. Architecture générale du système

L’architecture réalisée dans le tutoriel est centrée autour d’un processeur **Nios II**.  
Le processeur exécute un programme logiciel et communique avec un composant matériel personnalisé grâce à l’interconnexion Avalon.

Le composant personnalisé s’appelle :

```text
reg16_avalon_interface
```

Il contient un registre 16 bits.  
Le Nios II peut écrire dans ce registre ou le lire.  
La valeur contenue dans le registre est ensuite exportée vers l’extérieur de Qsys et utilisée pour piloter les afficheurs 7 segments.

L’architecture globale peut être représentée ainsi :

```text
+-------------------+        Avalon-MM         +--------------------------+
|                   |  read / write / address  |                          |
|      Nios II      | -----------------------> |  reg16_avalon_interface |
|                   |                          |                          |
|  data_master      | <----------------------- |  readdata                |
+-------------------+                          +------------+-------------+
                                                            |
                                                            |
                                                    Avalon Conduit
                                                            |
                                                            v
                                                  +-------------------+
                                                  |  HEX0 ... HEX3    |
                                                  |  7-segment display|
                                                  +-------------------+
```

Dans cette architecture :

- le **Nios II** est le maître ;
- le composant `reg16_avalon_interface` est un esclave **Avalon-MM** ;
- la sortie du registre vers les afficheurs est une interface **Avalon Conduit** ;
- les afficheurs 7 segments sont connectés au top-level Quartus par des affectations de broches.

---

## 3. Description des blocs de l’architecture

### 3.1 Processeur Nios II

Le processeur **Nios II** exécute le programme logiciel.  
Dans ce tutoriel, son rôle est principalement d’écrire une valeur dans le composant spécifique.

Le Nios II ne pilote pas directement les signaux internes du registre.  
Il effectue simplement une écriture mémoire à l’adresse du composant.

L’interconnexion Avalon transforme ensuite cette écriture mémoire en signaux matériels :

- `chipselect` ;
- `write` ;
- `writedata` ;
- `byteenable`.

Le Nios II possède une interface maître Avalon-MM appelée généralement :

```text
data_master
```

Cette interface permet au processeur d’accéder aux périphériques mémoire-mappés.

---

### 3.2 Interconnexion Avalon-MM

L’interconnexion Avalon-MM est générée automatiquement par Qsys.  
Elle relie le maître, ici le Nios II, aux différents esclaves du système.

Dans ce tutoriel, le composant spécifique `reg16_avalon_interface` est ajouté comme périphérique esclave.

Quand le processeur écrit à l’adresse de base du composant, l’interconnexion Avalon :

1. décode l’adresse ;
2. sélectionne le bon périphérique ;
3. active `chipselect` ;
4. transmet la donnée sur `writedata` ;
5. active le signal `write`.

Le développeur n’a donc pas à créer manuellement le bus entre le Nios II et le composant : Qsys génère cette interconnexion.

---

### 3.3 Composant spécifique `reg16_avalon_interface`

Le composant `reg16_avalon_interface` est le composant personnalisé créé dans le tutoriel.

Il joue deux rôles :

1. recevoir les accès Avalon-MM venant du Nios II ;
2. piloter le registre 16 bits interne.

Ce composant est donc une interface entre le monde logiciel du processeur et le monde matériel du registre.

Il contient les signaux suivants :

| Signal | Taille | Direction | Rôle |
|---|---:|---|---|
| `clock` | 1 bit | entrée | Horloge du composant |
| `resetn` | 1 bit | entrée | Reset actif à 0 |
| `writedata` | 16 bits | entrée | Donnée écrite par le Nios II |
| `readdata` | 16 bits | sortie | Donnée lue par le Nios II |
| `read` | 1 bit | entrée | Demande de lecture |
| `write` | 1 bit | entrée | Demande d’écriture |
| `byteenable` | 2 bits | entrée | Sélection des octets écrits |
| `chipselect` | 1 bit | entrée | Sélection du composant |
| `Q_export` | 16 bits | sortie | Valeur exportée vers l’extérieur de Qsys |

Le composant est déclaré dans Qsys comme un esclave **Avalon Memory-Mapped** pour la partie accessible par le Nios II.

La sortie `Q_export`, elle, est déclarée comme une interface **Avalon Conduit**, car elle correspond à un signal matériel exporté vers le top-level Quartus.

---

### 3.4 Registre 16 bits interne

La fonction matérielle interne est un registre 16 bits.  
Ce registre mémorise la valeur écrite par le processeur.

Le registre est mis à jour au front d’horloge lorsque les conditions d’écriture sont valides :

```text
chipselect = 1
write      = 1
```

Le signal `byteenable` permet de choisir quel octet du registre est modifié.

Pour un registre 16 bits, il y a deux octets :

| `byteenable` | Effet |
|---|---|
| `01` | écriture de l’octet bas |
| `10` | écriture de l’octet haut |
| `11` | écriture des deux octets |
| `00` | aucune écriture |

Le registre peut aussi être lu par le processeur via le signal `readdata`.

---

### 3.5 Interface vers les afficheurs 7 segments

La valeur du registre est exportée vers l’extérieur de Qsys par le signal :

```text
Q_export
```

Ce signal ne fait pas partie du bus Avalon-MM.  
Il s’agit d’un signal matériel direct.

Il est donc déclaré comme une interface **Avalon Conduit**.

Dans le top-level Quartus, ce signal est connecté à la logique d’affichage permettant de piloter :

```text
HEX0, HEX1, HEX2, HEX3
```

Les afficheurs 7 segments permettent de visualiser la valeur écrite dans le registre par le processeur Nios II.

---

## 4. Interfaces Avalon utilisées

### 4.1 Avalon Clock

L’interface **Avalon Clock** fournit l’horloge au composant.

Dans le tutoriel, le signal utilisé est :

```text
clock
```

Cette horloge est nécessaire car le registre est un élément séquentiel.  
La valeur du registre change au front d’horloge.

Dans le projet Quartus, cette horloge est reliée à l’horloge physique de la carte :

```text
CLOCK_50
```

---

### 4.2 Avalon Reset

L’interface **Avalon Reset** remet le composant dans un état initial.

Le signal de reset utilisé est :

```text
resetn
```

Le suffixe `n` indique que le reset est actif à l’état bas.

Quand `resetn = 0`, le registre est remis à zéro.  
Dans le top-level Quartus, ce reset est généralement relié au bouton :

```text
KEY0
```

---

### 4.3 Avalon Memory-Mapped Slave

L’interface **Avalon Memory-Mapped Slave** est l’interface principale du composant.

Elle permet au processeur Nios II d’accéder au registre comme à une adresse mémoire.

Les signaux principaux sont :

| Signal | Rôle |
|---|---|
| `chipselect` | indique que le composant est sélectionné |
| `write` | indique une écriture |
| `read` | indique une lecture |
| `writedata` | contient la donnée envoyée par le processeur |
| `readdata` | contient la donnée renvoyée au processeur |
| `byteenable` | indique quels octets doivent être écrits |

Dans ce tutoriel, le composant ne contient qu’un seul registre.  
Il n’y a donc pas besoin d’un signal `address`.

Si le composant contenait plusieurs registres, il faudrait ajouter un signal `address` pour choisir le registre à lire ou à écrire.

---

### 4.4 Avalon Conduit

L’interface **Avalon Conduit** est utilisée pour les signaux qui doivent sortir du système Qsys mais qui ne sont pas des transactions mémoire.

Ici, la sortie du registre est exportée vers le top-level avec :

```text
Q_export
```

Cette sortie est ensuite utilisée pour l’affichage sur les 7 segments.

Le conduit est donc adapté car il transporte un signal matériel direct, et non une lecture ou écriture mémoire.

---

## 5. Fonctionnement en écriture

Lorsqu’un programme C exécuté par le Nios II écrit dans le composant, le déroulement est le suivant :

```text
Programme C
   |
   | IOWR ou IOWR_32DIRECT
   v
Nios II data_master
   |
   | Transaction Avalon-MM
   v
Avalon Interconnect
   |
   | chipselect = 1
   | write      = 1
   | writedata  = valeur à écrire
   | byteenable = octets à modifier
   v
reg16_avalon_interface
   |
   v
Registre 16 bits mis à jour
   |
   v
Q_export
   |
   v
Affichage sur HEX0 ... HEX3
```

Le processeur ne manipule donc jamais directement les signaux `chipselect`, `write` ou `writedata`.  
Ces signaux sont générés automatiquement par l’interconnexion Avalon à partir de l’accès mémoire logiciel.

---

## 6. Fonctionnement en lecture

Lorsqu’un programme C lit le composant, le déroulement est le suivant :

```text
Programme C
   |
   | IORD ou IORD_32DIRECT
   v
Nios II data_master
   |
   | Transaction Avalon-MM
   v
Avalon Interconnect
   |
   | chipselect = 1
   | read       = 1
   v
reg16_avalon_interface
   |
   | readdata = contenu du registre
   v
Nios II
```

La valeur renvoyée par le composant est la valeur actuellement stockée dans le registre 16 bits.

---

## 7. Création du composant dans Qsys

La création du composant se fait dans le **Component Editor** de Qsys / Platform Designer.

Les étapes principales sont :

1. créer les fichiers VHDL du composant ;
2. ouvrir Qsys / Platform Designer ;
3. créer un nouveau composant ;
4. ajouter les fichiers HDL ;
5. analyser les fichiers ;
6. sélectionner le top-level ;
7. associer les ports aux interfaces Avalon ;
8. configurer les propriétés des interfaces ;
9. ajouter le composant au système ;
10. connecter le composant au Nios II ;
11. générer le système.

---

### 7.1 Fichiers VHDL

Le tutoriel sépare la logique en deux niveaux :

```text
reg16.vhd
reg16_avalon_interface.vhd
```

Le fichier `reg16.vhd` décrit la fonction matérielle interne : le registre 16 bits.

Le fichier `reg16_avalon_interface.vhd` décrit l’adaptation du registre au bus Avalon.  
C’est ce fichier qui est utilisé comme top-level du composant Qsys.

Cette séparation est importante, car elle permet de distinguer :

- la logique métier du composant ;
- la logique d’interfaçage avec le système Avalon.

---

### 7.2 Déclaration des interfaces dans Qsys

Dans le Component Editor, les ports du composant sont associés aux interfaces suivantes :

| Port VHDL | Interface Qsys | Type |
|---|---|---|
| `clock` | Clock Input | Avalon Clock |
| `resetn` | Reset Input | Avalon Reset |
| `chipselect` | Avalon-MM Slave | `chipselect` |
| `write` | Avalon-MM Slave | `write` |
| `read` | Avalon-MM Slave | `read` |
| `writedata` | Avalon-MM Slave | `writedata` |
| `readdata` | Avalon-MM Slave | `readdata` |
| `byteenable` | Avalon-MM Slave | `byteenable` |
| `Q_export` | Conduit | export |

Il faut également associer l’interface Avalon-MM à l’horloge et au reset du composant.

---

### 7.3 Ajout dans le système Qsys

Une fois le composant créé, il apparaît dans la bibliothèque Qsys.  
Il peut alors être ajouté au système comme un périphérique classique.

Dans le système, il faut connecter :

- `clock` à l’horloge du système ;
- `resetn` au reset du système ;
- l’interface Avalon-MM Slave au bus contrôlé par le Nios II ;
- `Q_export` vers l’extérieur du système.

Qsys attribue aussi une adresse de base au composant.  
Cette adresse permet au logiciel d’accéder au registre.

---

## 8. Accès logiciel avec la HAL

Une fois le système généré et le BSP logiciel créé, l’adresse du composant est disponible dans le fichier :

```text
system.h
```

---

## 9. Ce que j’ai compris

Ce tutoriel montre comment passer d’un bloc VHDL classique à un composant utilisable dans un système SoC.

Le point important est qu’un composant Qsys doit avoir des interfaces clairement définies.

Dans ce tutoriel :

- le Nios II écrit une valeur depuis le logiciel ;
- l’interconnexion Avalon transforme cette écriture en signaux Avalon-MM ;
- le composant `reg16_avalon_interface` reçoit ces signaux ;
- le registre 16 bits mémorise la valeur ;
- la valeur est exportée par une interface Conduit ;
- le top-level Quartus relie cette sortie aux afficheurs 7 segments.

J’ai aussi compris que les signaux n’ont pas tous le même rôle :

- `writedata`, `readdata`, `read`, `write`, `chipselect` et `byteenable` appartiennent à l’interface Avalon-MM ;
- `clock` appartient à l’interface d’horloge ;
- `resetn` appartient à l’interface de reset ;
- `Q_export` appartient à l’interface Conduit.

Cette séparation permet à Qsys de générer correctement l’interconnexion entre le processeur et le composant.

---


