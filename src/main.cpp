// Core Overrides must come before Core is included

#include "espcore.h"
#include "rk3k.h"

void setup() {
    ecc.begin();
    rvkc.begin();
}

void loop() {
    ecc.loop();
    rvkc.loop();
}

