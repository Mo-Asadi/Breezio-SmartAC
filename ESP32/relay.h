#ifndef RELAY_H
#define RELAY_H

#include <Arduino.h>

void InitRelay();
bool switchRelay(bool switchOn);    // Closes the switch (activates relay)

#endif