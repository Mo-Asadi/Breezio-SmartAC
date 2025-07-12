#ifndef FIRESTORE_SERVICES_H
#define FIRESTORE_SERVICES_H

#include <Arduino.h> 
#include <ArduinoJson.h>

extern bool testMode;
extern bool lights_on;
extern bool relay_on;
extern String model;
extern String mode;
extern bool acPowered;
extern float totalHours;
extern int duration;
extern bool shouldBuzz;
extern float currTemp;
extern String idleFlag;
extern bool ecoCanTurnOn;

struct DaySchedule {
  bool active;
  int startHour;
  int endHour;
};

struct WeeklySchedule {
  DaySchedule sun;
  DaySchedule mon;
  DaySchedule tue;
  DaySchedule wed;
  DaySchedule thu;
  DaySchedule fri;
  DaySchedule sat;
};

extern WeeklySchedule schedule;

void initFirebase();
void handleFirebaseStream();
void updateOnlineStatus();
void updateSensorReadings();
void updateTotalHours();
void resetDevice();
void notifyUser(const String& prompt);
#endif