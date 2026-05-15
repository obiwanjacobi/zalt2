#pragma once

class Interupts
{
public:
    static void Enable(bool enable = true)
    {
        if (enable)
            sei();
        else
            cli();
    }

private:
    Interupts() {}
};
