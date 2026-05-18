# PWM Motor IP Core

This folder contains the first custom IP core for the CuteCar motors.

`PWM_generation.vhd` is the provided PWM component and must stay unchanged.
`PWM_avalon_interface.vhd` is the Avalon-MM wrapper used by Qsys / Platform Designer.

## Avalon-MM Register Map

Use a 16-bit Avalon-MM slave with word addressing.

| Word address | Register | Access | Description |
|---|---|---|---|
| `0x0` | `RIGHT_COMMAND` | R/W | Command word connected to `s_writedataR`. |
| `0x1` | `LEFT_COMMAND` | R/W | Command word connected to `s_writedataL`. |
| `0x2` | `STATUS` | R | Current enable and direction bits. |
| `0x3` | Reserved | R | Reads as zero. |

Command word format:

| Bits | Meaning |
|---|---|
| `13` | Go/stop: `1` = go, `0` = stop. |
| `12` | Direction: `0` = forward, `1` = backward. |
| `11 downto 0` | PWM duty value / speed. |

Suggested Qsys base address: `0x04003030`.
