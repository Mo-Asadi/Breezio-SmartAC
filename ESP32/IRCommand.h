#ifndef IR_COMMAND_H
#define IR_COMMAND_H

#include <Arduino.h> 
#include <ArduinoJson.h>

void initIR();
void PerformAction(JsonDocument& command);

#endif