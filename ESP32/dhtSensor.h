#ifndef DHT_SENSOR_H
#define DHT_SENSOR_H

#include <Arduino.h> 

void InitDHT(); 
bool readTemperature ();
bool readHumidity();

#endif