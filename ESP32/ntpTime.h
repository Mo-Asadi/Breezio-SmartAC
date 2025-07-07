#ifndef NTP_TIME_H
#define NTP_TIME_H


#include <WiFi.h>
#include "time.h"

extern const char* ntpServer;
extern const long  gmtOffset_sec;
extern const int   daylightOffset_sec;
extern struct tm timeinfo;

void initTime();
bool isNewDay(String& currentDayName);
int getCurrentHourMinute();

#endif