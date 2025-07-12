#include <Arduino.h> 
#include <WiFi.h>
#include <Firebase_ESP_Client.h>
#include "initSetup.h"
#include "firestoreServices.h"
#include "command.h"
#include "modeHandler.h"
#include "ntpTime.h"
#include "sensors.h"
#include "log.h"

//unsigned long countyy = 0;

// --- Firebase Task ---
/*
void firebaseTask(void* parameter) {
  initFirebase();  // Init stream, load state
  initIR();        // IR init

  while (true) {
    if (WiFi.status() == WL_CONNECTED) {
      Firebase.ready();             // Refresh Firebase token
      updateOnlineStatus();        // Heartbeat
      updateSensorReadings();      // Push sensors
      updateTotalHours();          // Maintenance
      handleFirebaseStream();      // Stream listen
      handleMode();                // Mode handler
    }
    delay(200); // Avoid CPU overload
  }
}
*/

// ----------------------- Setup -----------------------
void setup() {
  Serial.begin(115200);
  initSetup();
/*
  if (WiFi.status() == WL_CONNECTED) {
    initTime(); // NTP time

    // 🎯 Launch Firebase task with bigger stack
    xTaskCreatePinnedToCore(
      firebaseTask,       // Task function
      "FirebaseTask",     // Name
      10000,              // Stack size in words (10,000 * 4 = 40 KB)
      NULL,               // Parameters
      1,                  // Priority
      NULL,               // Task handle
      1                   // Core (typically 1 for WiFi/Firebase)
    );
  }
  */
  if(WiFi.status() == WL_CONNECTED){
    initTime();
    delay(5000);
    initFirebase();
    initIR();
  }
}

void loop() {
/*  if (millis() - countyy > 5000) {
    countyy = millis();
    LOGF("Free heap: %u", ESP.getFreeHeap());
    LOGF("Free stack: %u", uxTaskGetStackHighWaterMark(NULL));
  }*/
  if (isButtonPressed()) resetDevice(); // Factory reset
  if (WiFi.getMode() == WIFI_AP) {
    handleWebRequests(); // Setup mode handler
  }
  else if (WiFi.status() == WL_CONNECTED) {
    Firebase.ready();
    updateOnlineStatus();
    updateSensorReadings();
    handleFirebaseStream();
    updateTotalHours();
    handleMode();
  }
}