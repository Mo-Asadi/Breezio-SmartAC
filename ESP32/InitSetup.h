#ifndef INIT_SETUP_H
#define INIT_SETUP_H

#include <Arduino.h> 
#include <Preferences.h>

void initSetup(); 
bool isProvisioned();
void handleWebRequests();

#endif