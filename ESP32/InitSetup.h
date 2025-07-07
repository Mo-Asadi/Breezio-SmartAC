#ifndef INIT_SETUP_H
#define INIT_SETUP_H

#include <Arduino.h> 
#include <Preferences.h>

void InitSetup(); 
bool isProvisioned();
void handleWebRequests();
void checkResetButton();

#endif