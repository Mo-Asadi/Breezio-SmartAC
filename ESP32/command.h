#ifndef IR_COMMAND_H
#define IR_COMMAND_H

#include <Arduino.h> 
#include <ArduinoJson.h>

void initIR();
bool execute(const String& action);

#endif