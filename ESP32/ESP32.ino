#include <Arduino.h> 
#include <WiFi.h>
#include <Firebase_ESP_Client.h>
#include "InitSetup.h"
#include "FirestoreServices.h"
#include "IRCommand.h"
#include "modeHandler.h"
#include "ntpTime.h"

// ----------------------- Setup -----------------------
void setup() {
  Serial.begin(115200);
  InitSetup();
  if(WiFi.status() == WL_CONNECTED){
    initTime();
    initFirebase();
    initIR();
  }
}

void loop() {
  checkResetButton();
  if (WiFi.getMode() == WIFI_AP) {
    handleWebRequests();
  } else if (WiFi.status() == WL_CONNECTED) {
    Firebase.ready();
    updateOnlineStatus();
    updateSensorReadings();
    handleFirebaseStream();
    handleMode();
  }
}