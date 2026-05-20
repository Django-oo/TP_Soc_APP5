# ByteSwap Avalon-MM IP

This IP answers the control exercise by exposing a simple 32-bit byte-swap block as an Avalon-MM slave peripheral.

## Register Map

| Offset | Access | Description |
| --- | --- | --- |
| 0x00 | Write | Input word |
| 0x00 | Read | Output word selected by mode |
| 0x04 | Write | Mode bit 0: `0` = bypass, `1` = byte swap |
| 0x04 | Read | Current mode in bit 0 |

The Avalon address uses word addressing, so `IORD(BYTESWAP_BASE, 0)` reads offset `0x00` and `IORD(BYTESWAP_BASE, 1)` reads offset `0x04`.
The reset/default mode is `1`, so the IP behaves as a byte-swap block until software selects bypass mode.

## HAL Test

```c
#include "system.h"
#include "io.h"
#include <stdio.h>

int main(void)
{
    unsigned int input = 0xA1B2C3D4;
    unsigned int result;

    IOWR(BYTESWAP_AVALON_INTERFACE_0_BASE, 1, 1);
    IOWR(BYTESWAP_AVALON_INTERFACE_0_BASE, 0, input);
    result = IORD(BYTESWAP_AVALON_INTERFACE_0_BASE, 0);

    printf("Input  = 0x%08X\n", input);
    printf("Result = 0x%08X\n", result);

    while (1) {
    }
}
```

Expected result: `0xD4C3B2A1`.

To test bypass mode:

```c
IOWR(BYTESWAP_AVALON_INTERFACE_0_BASE, 1, 0);
IOWR(BYTESWAP_AVALON_INTERFACE_0_BASE, 0, 0xA1B2C3D4);
result = IORD(BYTESWAP_AVALON_INTERFACE_0_BASE, 0);
```

Expected result: `0xA1B2C3D4`.

Other useful tests:

| Input | Expected output |
| --- | --- |
| 0x11223344 | 0x44332211 |
| 0xAABBCCDD | 0xDDCCBBAA |
| 0x000000FF | 0xFF000000 |
