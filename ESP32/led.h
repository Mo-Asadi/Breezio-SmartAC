#ifndef LED_H
#define LED_H

#include <Arduino.h>

void InitLed();
bool switchLed(bool switchOn);
void validateColor();

#endif