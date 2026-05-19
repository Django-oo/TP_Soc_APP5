# PWM Motor IP Core

This folder contains the custom PWM IP core for the CuteCar motors.

`PWM_generation.vhd` generates the PWM signals.
`PWM_avalon_interface.vhd` is the Avalon-MM wrapper used by Qsys / Platform Designer.

## Avalon-MM Register Map

The slave is 32-bit wide.

| Offset | Register | Access | Description |
|---|---|---|---|
| `BASE + 0x00` | `RIGHT_COMMAND` | R/W | Right motor command. |
| `BASE + 0x04` | `LEFT_COMMAND` | R/W | Left motor command. |

Command word format:

| Bits | Meaning |
|---|---|
| `13` | Go/stop: `1` = go, `0` = stop. |
| `12` | Direction. |
| `11 downto 0` | PWM duty value / speed. |

Examples for speed 2500:

| Direction | Value |
|---|---|
| Forward | `0x000029C4` |
| Backward | `0x000039C4` |

## Motor Conduit

The IP exports a single 4-bit conduit named `motor_out`.

| Bit | Signal |
|---|---|
| `motor_out(3)` | Right motor positive |
| `motor_out(2)` | Right motor negative |
| `motor_out(1)` | Left motor positive |
| `motor_out(0)` | Left motor negative |

After changing the IP, refresh the component in Platform Designer, regenerate the Qsys system, recompile Quartus, and program the new `.sof`.
