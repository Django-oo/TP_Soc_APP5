# IP capteurs sol Avalon-MM

Ce dossier contient l'IP custom pour lire les capteurs de sol du CuteCar depuis le Nios II.

L'organisation suit celle du PWM :

| Fichier | Role |
|---|---|
| `Sensor_avalon_interface.vhd` | Wrapper Avalon-MM 32 bits |
| `capteurs_sol.vhd` | Bloc original de lecture ADC/SPI |
| `capteurs_sol_seuil.vhd` | Bloc original avec seuillage des valeurs |

Le wrapper Avalon instancie `capteurs_sol_seuil`. Les fichiers originaux restent separes pour garder une structure claire dans `IP_Modules`.

## Interfaces

### Avalon-MM slave

Le composant expose un esclave Avalon-MM 32 bits :

| Signal | Direction | Taille |
|---|---:|---:|
| `address` | entree | 2 bits |
| `chipselect` | entree | 1 bit |
| `write` | entree | 1 bit |
| `read` | entree | 1 bit |
| `byteenable` | entree | 4 bits |
| `writedata` | entree | 32 bits |
| `readdata` | sortie | 32 bits |

Il y a un process d'ecriture pour les commandes et un process de lecture pour le polling.

### Conduit ADC

Le conduit exporte les signaux de l'ADC :

| Signal IP | Signal top-level DE0-Nano |
|---|---|
| `ADC_CONVST` | `ADC_CS_N` |
| `ADC_SCK` | `ADC_SCLK` |
| `ADC_SDI` | `ADC_SADDR` |
| `ADC_SDO` | `ADC_SDAT` |

## Carte des registres

L'adresse de base est choisie dans Platform Designer. Une adresse pratique apres le PWM est par exemple `0x04003040`.

| Offset | Registre | Acces | Description |
|---:|---|---|---|
| `0x00` | `CONTROL_STATUS` | R/W | Ecriture bit 0 = lancer une acquisition. Ecriture bit 1 = effacer `ready`. Lecture bit 0 = `ready`, bits 14..8 = capteurs seuilles. |
| `0x04` | `THRESHOLD` | R/W | Seuil sur 8 bits utilise par `capteurs_sol_seuil`. Valeur reset = `0x80`. |
| `0x08` | `RAW_0_3` | R | Valeurs brutes 8 bits des capteurs 0 a 3. |
| `0x0C` | `RAW_4_6` | R | Valeurs brutes 8 bits des capteurs 4 a 6. |

### Format de lecture

`CONTROL_STATUS` :

```text
bit 0      ready_latched
bits 7..1  0
bits 14..8 vect_capt(6 downto 0)
bits 31..15 0
```

`RAW_0_3` :

```text
bits 7..0    data0
bits 15..8   data1
bits 23..16  data2
bits 31..24  data3
```

`RAW_4_6` :

```text
bits 7..0    data4
bits 15..8   data5
bits 23..16  data6
bits 31..24  0
```

## Test par polling

Avec une base `SENSOR_BASE`, la sequence est :

1. Regler le seuil si necessaire :

```text
write SENSOR_BASE + 0x04 = 0x00000080
```

2. Lancer une acquisition :

```text
write SENSOR_BASE + 0x00 = 0x00000001
```

3. Polling sur `ready` :

```text
read SENSOR_BASE + 0x00 jusqu'a ce que bit 0 = 1
```

4. Lire les valeurs :

```text
read SENSOR_BASE + 0x08
read SENSOR_BASE + 0x0C
```

5. Effacer `ready` avant une nouvelle acquisition :

```text
write SENSOR_BASE + 0x00 = 0x00000002
```

Ecrire `0x00000001` pour lancer une nouvelle acquisition efface aussi l'ancien `ready`.

## HAL / BSP / system.h

Quand le systeme Qsys est regenere, il faut aussi regenerer le BSP. Le fichier `system.h` contiendra alors une macro de base pour l'instance capteur, par exemple :

```c
#define SENSOR_AVALON_INTERFACE_0_BASE 0x04003040
```

Le nom exact depend du nom de l'instance choisi dans Platform Designer.

Exemple HAL :

```c
#include "system.h"
#include "io.h"

#define SENSOR_BASE SENSOR_AVALON_INTERFACE_0_BASE

IOWR(SENSOR_BASE, 1, 0x80);
IOWR(SENSOR_BASE, 0, 0x01);

while ((IORD(SENSOR_BASE, 0) & 0x1) == 0) {
    /* polling */
}

unsigned status = IORD(SENSOR_BASE, 0);
unsigned raw03 = IORD(SENSOR_BASE, 2);
unsigned raw46 = IORD(SENSOR_BASE, 3);

IOWR(SENSOR_BASE, 0, 0x02);
```

Dans Altera Monitor Program, c'est la meme logique mais avec les adresses absolues :

```text
base + 0x00 : control/status
base + 0x04 : seuil
base + 0x08 : raw capteurs 0..3
base + 0x0C : raw capteurs 4..6
```
