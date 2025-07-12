#ifndef AC_MODE_HANDLER_H
#define AC_MODE_HANDLER_H

#include <Arduino.h> 

extern unsigned long lastMotionMillis;
extern bool alreadyTurnedOn;
extern bool alreadyTurnedOff;

void handleMode();

#endif