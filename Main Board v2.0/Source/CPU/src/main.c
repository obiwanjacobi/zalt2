/* main.c - required C entry point
 *
 * This function is called by crt0.asm after hardware init.
 * It must be named 'main' - the assembler startup calls _main
 * which maps to this function.
 *
 * There is no return value - if main() returns, crt0.asm halts.
 */

#include "ApiDispatch.h"
#include "sys/Stream.h"
#include "sys/os_api.h"

void main(void)
{
    /* initialise subsystems here */
    Stream stream;
    uint8_t buf[32];
    Api_Stream_Construct(&stream, buf, sizeof(buf));

    os_func_args args = { .arg1 = 42, .arg2 = 12345 };
    uint16_t result = os_struct_func(&args);

    /* main loop */
    for (;;)
    {
    }
}
