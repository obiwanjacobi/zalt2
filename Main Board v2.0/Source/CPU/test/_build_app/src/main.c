/* main.c - application entry point
 * if function returns, the app is deleted.
 */

// #include "ApiDispatch.h"
// #include "sys/Stream.h"
#include "os/os_api.h"

#pragma section code_app_main

int main(void)
{
    /* initialise subsystems here */
    // Stream stream;
    // uint8_t buf[32];
    // Api_Stream_Construct(&stream, buf, sizeof(buf));

    os_func_args args = { .arg1 = 42, .arg2 = 12345 };
    uint16_t result = os_struct_func(&args);

    /* main loop */
    for (;;)
    {
        // probably some os_event-loop kinda thing...?
    }

    return 0; // negative indicates error.
}
