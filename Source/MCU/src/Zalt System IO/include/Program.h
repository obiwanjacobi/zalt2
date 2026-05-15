#pragma once

#include "Delays.h"
#include "Time.h"

#include <stdint.h>

const uint8_t MaxItems = 5;
#define TimeRes TimeResolution::Milliseconds
typedef Delays<Time<TimeRes>, MaxItems> Scheduler;
