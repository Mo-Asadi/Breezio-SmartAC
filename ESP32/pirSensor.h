#ifndef PIR_SENSOR_H
#define PIR_SENSOR_H

#include <Arduino.h> 

void InitPir(); 
bool isMotionDetected();
bool readMotionSensor();

#endif