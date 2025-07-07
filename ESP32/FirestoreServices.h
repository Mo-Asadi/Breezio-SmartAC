#ifndef FIRESTORE_SERVICES_H
#define FIRESTORE_SERVICES_H

#include <Arduino.h> 
#include <ArduinoJson.h>

extern JsonDocument deviceData;

void initFirebase();
void handleFirebaseStream();
void loadDeviceData();
void saveDeviceData();
void resetData();
void updateOnlineStatus();
void updateSensorReadings();
#endif