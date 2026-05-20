# IP capteurs sol Avalon-MM

Ce dossier contient l'IP custom pour lire l'ADC LTC2308 du CuteCar depuis le Nios II.

Le registre Avalon suit maintenant une carte proche de l'exemple fonctionnel de Maxime : un registre de controle, un registre de selection de canal, un registre de donnee et un registre de statut. Le but est d'eviter l'ancien registre unique qui servait a la fois de commande et de statut.

## Conduit ADC CuteCar

| Signal IP | Signal top-level |
|---|---|
| `ADC_CONVST` | `GPIO_0(8)` |
| `ADC_SCK` | `GPIO_0(9)` |
| `ADC_SDO` | `GPIO_0(10)` |
| `ADC_SDI` | `GPIO_0(11)` |

Dans `lights.vhd`, les signaux de support de la carte capteurs restent forces :

| Signal | Valeur |
|---|---|
| `GPIO_0(32)` / `IR_LED_ON` | `1` |
| `GPIO_0(33)` / `VCC3P3_PWRON_n` | `0` actif bas |

## Carte des registres

L'instance recreree `Sensor_generation1_0` est actuellement mappee a la base `0x00000000` dans Platform Designer.

| Offset | Registre | Acces | Description |
|---:|---|---|---|
| `0x00` | `CONTROL` | R/W | Ecriture bit 0 = lancer une conversion. Bit 1 conserve une valeur compatible `IR_LED_ON`, meme si l'IR est force dans `lights.vhd`. Lecture bit 0 = 0 pour eviter la confusion avec un statut. |
| `0x04` | `CHANNEL` | R/W | Bits 2..0 = canal ADC a lire, de 0 a 7. |
| `0x08` | `DATA` | R | Bits 11..0 = derniere valeur ADC 12 bits lue. |
| `0x0C` | `STATUS` | R/W | Lecture bit 0 = `busy`, bit 1 = `done`, bit 2 = etat brut `ADC_SDO`. Ecriture bit 1 = effacer `done`. |

## Test Altera Monitor Program

Exemple pour lire le canal 0 avec la base actuelle `0x00000000` :

```text
write 0x00000004 = 0x00000000   # channel 0
write 0x00000000 = 0x00000003   # START + IR bit compatible
read  0x0000000C                # attendre bit 1 = 1, done
read  0x00000008                # valeur ADC 12 bits
```

Pour lire le canal 1 :

```text
write 0x00000004 = 0x00000001
write 0x00000000 = 0x00000003
read  0x0000000C
read  0x00000008
```

Repeter avec `CHANNEL = 0..6` pour les sept capteurs de ligne. Les valeurs utiles sont les 12 bits bas de `DATA`.
