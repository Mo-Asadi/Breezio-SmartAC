#include <Preferences.h>
#include "ntpTime.h"
#include "log.h"

const char* ntpServer = "time.google.com";
const long  gmtOffset_sec = 3 * 3600;   // Israel = UTC+3
const int   daylightOffset_sec = 0;     // Adjust if daylight saving
struct tm timeinfo;

void initTime() {
  configTime(gmtOffset_sec, daylightOffset_sec, ntpServer);
  
  for (int i = 0; i < 10; i++) {  // Retry for up to ~5 seconds
    if (getLocalTime(&timeinfo)) {
      char timeString[64];
      strftime(timeString, sizeof(timeString), "%A, %Y-%m-%d %H:%M:%S", &timeinfo);
      Serial.println("✅ Time synchronized");
      Serial.print("🕒 Current time: ");
      Serial.println(timeString);
      return;
    }
    delay(500);
  }

  LOG_ERROR("❌ Failed to obtain time");
}

int dayNameToIndex(const String& dayName) {
  if (dayName == "Sunday") return 0;
  if (dayName == "Monday") return 1;
  if (dayName == "Tuesday") return 2;
  if (dayName == "Wednesday") return 3;
  if (dayName == "Thursday") return 4;
  if (dayName == "Friday") return 5;
  if (dayName == "Saturday") return 6;
  return -1; // error fallback
}

bool isNewDay(String& currentDayName) {
  static int lastDay = -1;
  static bool firstRun = true;
  static unsigned long lastCheck = 0;
  const unsigned long checkInterval = 30UL * 60UL * 1000UL; // 30 minutes

  // Throttle time check
  unsigned long now = millis();
  if ((now - lastCheck < checkInterval) && !firstRun) return false;
  lastCheck = now;

  if (!getLocalTime(&timeinfo)) {
    LOG_ERROR("❌ Failed to get current time in isNewDay()");
    return false;
  }

  int today = timeinfo.tm_wday;
  char dayBuffer[16];
  strftime(dayBuffer, sizeof(dayBuffer), "%A", &timeinfo);
  currentDayName = String(dayBuffer);

  if (firstRun) {
    Preferences prefs;
    prefs.begin("daytrack", true); // read-only
    lastDay = prefs.getInt("lastDay", -1);
    prefs.end();
    firstRun = false;
  }

  if (today != lastDay) {
    Preferences prefs;
    prefs.begin("daytrack", false); // write mode
    prefs.putInt("lastDay", today);
    prefs.end();

    lastDay = today;
    return true;
  }

  return false;
}

int getCurrentHourMinute() {
  static unsigned long lastCheck = 0;
  const unsigned long checkInterval = 60000; // 1 minute
  static int lastResult = -1;

  unsigned long now = millis();
  if ((now - lastCheck < checkInterval) && lastResult != -1) {
    return lastResult; // return cached value
  }

  lastCheck = now;

  struct tm timeinfo;
  if (!getLocalTime(&timeinfo)) {
    LOG_ERROR("❌ Failed to get local time.");
    return -1;
  }

  int hhmm = timeinfo.tm_hour * 100 + timeinfo.tm_min;
  lastResult = hhmm;
  return hhmm;
}