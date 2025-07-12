#ifndef SENSORS_H
#define SENSORS_H

#include <Arduino.h>

void initSensors();
bool readMotionSensor();
float readTemperature ();
float readHumidity();
void buzz();
void switchLed();
void validateLedColor();
void switchRelay();
bool isButtonPressed();

#endif