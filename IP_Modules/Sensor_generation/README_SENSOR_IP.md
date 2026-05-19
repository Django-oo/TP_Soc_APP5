# IP capteurs sol Avalon-MM

Ce dossier contient l'IP custom pour lire les capteurs de sol du CuteCar depuis le Nios II.

Le wrapper Avalon-MM garde l'ancienne carte de registres du projet, mais la lecture ADC suit maintenant le timing du design de reference qui fonctionne : horloge systeme 50 MHz, SCK ADC lent autour de 100 kHz, deux trames LTC2308 par canal, puis balayage des canaux 0 a 6.

| Fichier | Role |
|---|---|
| `Sensor_avalon_interface.vhd` | Wrapper Avalon-MM 32 bits + machine SPI LTC2308 |
| `capteurs_sol.vhd` | Bloc original conserve pour reference |
| `capteurs_sol_seuil.vhd` | Bloc original conserve pour reference |

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

### Conduit ADC CuteCar

Le conduit exporte les signaux de l'ADC CuteCar. Attention : ces signaux ne vont pas sur l'ADC interne DE0-Nano, mais sur GPIO0.

| Signal IP | Signal top-level |
|---|---|
| `ADC_CONVST` | `GPIO_0(8)` |
| `ADC_SCK` | `GPIO_0(9)` |
| `ADC_SDO` | `GPIO_0(10)` |
| `ADC_SDI` | `GPIO_0(11)` |

Dans `lights.vhd`, les signaux support de la carte capteurs sont aussi forces :

| Signal | Valeur |
|---|---|
| `GPIO_0(32)` / `IR_LED_ON` | `1` |
| `GPIO_0(33)` / `VCC3P3_PWRON_n` | `0` actif bas |

## Carte des registres

L'adresse de base actuelle dans Platform Designer est `0x04003040`.

| Offset | Registre | Acces | Description |
|---:|---|---|---|
| `0x00` | `CONTROL_STATUS` | R/W | Ecriture bit 0 = lancer une acquisition. Ecriture bit 1 = effacer `ready`. Lecture bit 0 = `ready`, bit 1 = `busy`, bits 14..8 = capteurs seuilles, bit 16 = etat brut `ADC_SDO`. |
| `0x04` | `THRESHOLD` | R/W | Seuil sur 8 bits compare aux bits 11..4 de chaque valeur ADC. Valeur reset = `0x80`. |
| `0x08` | `RAW_0_3` | R | Valeurs brutes 8 bits des capteurs 0 a 3. |
| `0x0C` | `RAW_4_6` | R | Valeurs brutes 8 bits des capteurs 4 a 6. |

### Format de lecture

`CONTROL_STATUS` :

```text
bit 0       ready_latched
bit 1       busy
bits 7..2   0
bits 14..8  vect_capt(6 downto 0)
bit 16      ADC_SDO brut
bits 31..17 0
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

Dans Altera Monitor Program avec la base actuelle :

```text
0x04003040 : control/status
0x04003044 : seuil
0x04003048 : raw capteurs 0..3
0x0400304C : raw capteurs 4..6
```
