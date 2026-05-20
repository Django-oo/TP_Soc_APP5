# ByteSwap Avalon-MM IP

This IP answers the control exercise by exposing a simple 32-bit byte-swap block as an Avalon-MM slave peripheral.

## Register Map

| Offset | Access | Description |
| --- | --- | --- |
| 0x00 | Write | Input word to swap |
| 0x00 | Read | Swapped output word |
| 0x04 | Read | Input word mirror for debug |

The Avalon address uses word addressing, so `IORD(BYTESWAP_BASE, 0)` reads offset `0x00` and `IORD(BYTESWAP_BASE, 1)` reads offset `0x04`.

## HAL Test

```c
#include "system.h"
#include "io.h"
#include <stdio.h>

int main(void)
{
    unsigned int input = 0xA1B2C3D4;
    unsigned int result;

    IOWR(BYTESWAP_AVALON_INTERFACE_0_BASE, 0, input);
    result = IORD(BYTESWAP_AVALON_INTERFACE_0_BASE, 0);

    printf("Input  = 0x%08X\n", input);
    printf("Result = 0x%08X\n", result);

    while (1) {
    }
}
```

Expected result: `0xD4C3B2A1`.

Other useful tests:

| Input | Expected output |
| --- | --- |
| 0x11223344 | 0x44332211 |
| 0xAABBCCDD | 0xDDCCBBAA |
| 0x000000FF | 0xFF000000 |
