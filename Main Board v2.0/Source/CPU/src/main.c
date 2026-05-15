/* main.c - required C entry point
 *
 * This function is called by crt0.asm after hardware init.
 * It must be named 'main' - the assembler startup calls _main
 * which maps to this function.
 *
 * There is no return value - if main() returns, crt0.asm halts.
 */

#include "sys/Stream.h"

void main(void)
{
    /* initialise subsystems here */
    Stream stream;
    uint8_t buf[32];
    Stream_Construct(&stream, buf, sizeof(buf));

    /* main loop */
    for (;;)
    {
    }
}
