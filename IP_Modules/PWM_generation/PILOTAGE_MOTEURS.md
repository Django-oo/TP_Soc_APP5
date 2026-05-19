# Pilotage des moteurs CuteCar

Ce projet expose le coeur PWM comme un peripherique Avalon-MM 32 bits.

## Registres Avalon-MM

Adresse de base du coeur PWM dans Qsys :

```text
BASE = 0x04003030
```

| Adresse | Registre | Acces | Description |
|---|---|---|---|
| `BASE + 0x00` = `0x04003030` | `RIGHT_COMMAND` | R/W 32 bits | Commande du moteur droit |
| `BASE + 0x04` = `0x04003034` | `LEFT_COMMAND` | R/W 32 bits | Commande du moteur gauche |

Dans Altera Monitor Program, utiliser des ecritures **Word / 32 bits**.

## Format d'une commande moteur

Chaque registre utilise les bits suivants :

| Bits | Nom | Description |
|---|---|---|
| `13` | `GO` | `1` active le moteur, `0` l'arrete |
| `12` | `DIR` | Direction du moteur |
| `11 downto 0` | `SPEED` | Rapport cyclique PWM |

Formule :

```text
commande = GO * 0x2000 + DIR * 0x1000 + SPEED
```

La periode PWM vaut environ :

```text
50 MHz / 16 kHz = 3125 cycles
```

Donc `SPEED` est une valeur entre `0` et environ `3125`.

## Valeurs utiles

| Action | Valeur decimale speed | Valeur hex |
|---|---:|---:|
| Stop | 0 | `0x00000000` |
| Avant lent | 1000 | `0x000023E8` |
| Avant moyen | 1500 | `0x000025DC` |
| Avant fort | 2500 | `0x000029C4` |
| Avant max approx. | 3125 | `0x00002C35` |
| Arriere lent | 1000 | `0x000033E8` |
| Arriere moyen | 1500 | `0x000035DC` |
| Arriere fort | 2500 | `0x000039C4` |
| Arriere max approx. | 3125 | `0x00003C35` |

## Exemples dans Altera Monitor Program

Faire avancer les deux moteurs avec une vitesse de 2500 :

```text
Write word 0x000029C4 at 0x04003030
Write word 0x000029C4 at 0x04003034
```

Lire les registres pour verifier :

```text
Read word at 0x04003030 -> doit retourner 0x000029C4
Read word at 0x04003034 -> doit retourner 0x000029C4
```

Arreter les deux moteurs :

```text
Write word 0x00000000 at 0x04003030
Write word 0x00000000 at 0x04003034
```

Faire reculer les deux moteurs avec une vitesse de 2500 :

```text
Write word 0x000039C4 at 0x04003030
Write word 0x000039C4 at 0x04003034
```

## Sorties vers le CuteCar

Le coeur PWM exporte un conduit 4 bits :

| Signal | Role |
|---|---|
| `motor_out(3)` | moteur droit positif |
| `motor_out(2)` | moteur droit negatif |
| `motor_out(1)` | moteur gauche positif |
| `motor_out(0)` | moteur gauche negatif |

Dans `lights.vhd`, ces signaux sont relies aux broches GPIO du DE0-Nano :

| GPIO | Signal CuteCar |
|---|---|
| `GPIO_0(2)` | `MTRR_N` |
| `GPIO_0(3)` | `MTRR_P` |
| `GPIO_0(4)` | `MTRL_P` |
| `GPIO_0(5)` | `MTRL_N` |
| `GPIO_0(6)` | `MTR_Sleep_n` |

`GPIO_0(6)` doit etre force a `1`, sinon le driver moteur reste en veille.
