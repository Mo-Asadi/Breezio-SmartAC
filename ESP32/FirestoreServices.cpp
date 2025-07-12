#include <Arduino.h> 
#include <Firebase_ESP_Client.h>
#include <addons/RTDBHelper.h>
#include <addons/TokenHelper.h>
#include <Preferences.h>
#include "firestoreServices.h"
#include "command.h"
#include "log.h"
#include "secrets.h"
#include "parameters.h"
#include "sensors.h"
#include "modeHandler.h"


FirebaseAuth auth;
FirebaseConfig config;
FirebaseData commandFbdo;
FirebaseData accessFbdo;
FirebaseData statusFbdo;
FirebaseData resultFbdo;
FirebaseData notifyFbdo;
FirebaseData maintenanceFbdo;
FirebaseData sensorFbdo;
FirebaseJson commandData;
String deviceMacPath;

bool testMode = false;
bool lights_on = false;
bool relay_on = false;
String model = "Electra";
String mode = "regular";
bool acPowered = false;
float totalHours = 0.0;
int duration = 30;
bool shouldBuzz = true;
float currTemp = 24;
bool ecoCanTurnOn = true;
String idleFlag = "active";
WeeklySchedule schedule;



void onCommandDataChange(FirebaseStream data);
void onCommandStreamTimeout(bool timeout);
void updateTotalHours();
void initLastState(FirebaseJson& json);
void loadScheduleFromJson(FirebaseJson &json);
void handleFirebaseStream();
void updateOnlineStatus();
void updateSensorReadings();
void fetchSchedule();
void notifyUser(const String& prompt);
void resetDevice();


void initFirebase() {
    #if defined(ESP32)
    accessFbdo.setBSSLBufferSize(4096, 1024);
    commandFbdo.setBSSLBufferSize(4096, 1024);
    #endif
    config.api_key = ApiKey;
    config.database_url = DbUrl;
    config.timeout.wifiReconnect = 10 * 1000;
    config.timeout.socketConnection = 30 * 1000;
    config.timeout.sslHandshake = 2 * 60 * 1000;
    config.timeout.serverResponse = 10 * 1000;
    config.timeout.rtdbKeepAlive = 45 * 1000;
    config.timeout.rtdbStreamReconnect = 1 * 1000;
    config.timeout.rtdbStreamError = 3 * 1000;
    config.token_status_callback = tokenStatusCallback; 

    auth.user.email = AuthEmail;
    auth.user.password = AuthPass;

    Firebase.begin(&config, &auth);
    Firebase.reconnectWiFi(true);
    LOG_INFO("\nFirebase Authenticating");
    while (auth.token.uid == "") {
        Serial.print(".");
        delay(200);
    }
    LOG_INFO("\nFirebase Authenticated!");
    String mac = WiFi.macAddress();
    mac.replace(":", "");
    deviceMacPath = "/devices/" + mac;

    // 🔍 Check if the device node exists
    accessFbdo.clear();
    if (!Firebase.RTDB.getJSON(&accessFbdo, deviceMacPath)) {
        LOG_WARN("📭 Device data does not exist — Initializing...");
        return;
    } else {
        LOG_INFO("📦 Device data already exists - Recovering Last State...");
        initLastState(accessFbdo.to<FirebaseJson>());
    }
    accessFbdo.clear();
    // 🎧 Start stream
    if (!Firebase.RTDB.beginStream(&commandFbdo, deviceMacPath + "/command")) {
        LOGF("⚠️ Failed to start command stream: %s", commandFbdo.errorReason().c_str());
        return;
    }
    else {
        Firebase.RTDB.setStreamCallback(&commandFbdo, onCommandDataChange, onCommandStreamTimeout);
    }
}

void loadScheduleFromJson(FirebaseJson &json) {
  FirebaseJsonData result;
  const char* days[] = {"sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"};
  DaySchedule* dayPtrs[] = {
    &schedule.sun, &schedule.mon, &schedule.tue, &schedule.wed,
    &schedule.thu, &schedule.fri, &schedule.sat
  };

  for (int i = 0; i < 7; ++i) {
    String path = "schedule/" + String(days[i]) + "/active";
    json.get(result, path);  dayPtrs[i]->active = result.to<bool>();

    path = "schedule/" + String(days[i]) + "/start";
    json.get(result, path);  dayPtrs[i]->startHour = result.to<int>();

    path = "schedule/" + String(days[i]) + "/end";
    json.get(result, path);  dayPtrs[i]->endHour = result.to<int>();
  }
    alreadyTurnedOn = false;
    alreadyTurnedOff = false;
}

void initLastState(FirebaseJson& json){
    FirebaseJsonData result;
    json.get(result, "config/model");
    model = result.stringValue;
    json.get(result, "status/currentTemperature");
    currTemp = result.floatValue;
    json.get(result, "status/idleFlag");
    idleFlag = result.stringValue;
    json.get(result, "status/mode");
    mode = result.stringValue;
    json.get(result, "config/testing");
    testMode = result.boolValue;
    json.get(result, "status/currentTimer");
    duration = testMode ? 1 : result.intValue;
    json.get(result, "status/lightsOn");
    lights_on = result.boolValue;
    json.get(result, "status/relayOn");
    relay_on = result.boolValue;
    json.get(result, "status/powered");
    acPowered = result.boolValue;
    json.get(result, "maintenance/totalHours");
    totalHours = result.floatValue;
    Preferences prefs;
    prefs.begin("eco", true);
    ecoCanTurnOn = prefs.getBool("ecoCanTurnOn", true);
    prefs.end();
    loadScheduleFromJson(json);
    if(lights_on){
        lights_on= false;
        switchLed();
        lights_on = true;
    }
    if(relay_on){
        relay_on = false;
        switchRelay();
        relay_on = true;
    }
    float capacityHours = testMode ? 1 : 250;
    if(totalHours >= capacityHours){
        shouldBuzz = false;
    }
}

void handleFirebaseStream() {
    if (!Firebase.RTDB.readStream(&commandFbdo)) {
        delay(500);
    }
}

void onCommandDataChange(FirebaseStream data) {
    if (data.dataType() != "json") {
        return;
    }
    FirebaseJsonData result;
    commandData.clear();
    commandData = data.to<FirebaseJson>();
    commandData.get(result, "action");
    String action = result.stringValue;
    LOG_INFO("📦 Received New Command - Executing...");
    String commandResult = "Success";
    if(action == "set_mode"){
        result.clear();
        commandData.get(result, "mode");
        if(mode != result.stringValue){
            mode = result.stringValue;
            if(mode == "timer" && !testMode){
                commandData.get(result, "duration");
                duration = result.intValue;
            }
            if(mode == "motion"){
                lastMotionMillis = millis();
           }
        }
    }
    else if(action == "apply_schedule"){
        fetchSchedule();
    }
    else if(action == "reset_maintenance"){
        shouldBuzz = true;
        totalHours = 0.0;
    }
    else if(action == "ignore_motion"){
        idleFlag = "continue";
    }
    else if(action == "switch_lights"){
        switchLed();
        lights_on = !lights_on;
    }
    else if(action == "switch_relay"){
        switchRelay();
        relay_on = !relay_on;
    }
    else if(action == "reset_device"){
        resetDevice();
    }
    else{
        commandResult = execute(action) ? "Success" : "Failed";
    }
    resultFbdo.clear();
    if(Firebase.RTDB.setString(&resultFbdo, deviceMacPath + "/result", commandResult)){
        LOG_INFO("Command Executed");
    }
    else{
        LOGF("❌ Failed To Send Result: %s", resultFbdo.errorReason().c_str());
    }
    commandData.clear();
    resultFbdo.clear();
    return;
}

void onCommandStreamTimeout(bool timeout) {
    static unsigned long lastReconnectAttempt = 0;
    static int retryCount = 0;
    const unsigned long RECONNECT_COOLDOWN_MS = 5000;
    const int MAX_RETRIES = 3;

    if (!timeout) return;

    LOG_WARN("⚠️ Stream timed out — attempting to reconnect...");

    unsigned long now = millis();
    if (now - lastReconnectAttempt < RECONNECT_COOLDOWN_MS) {
        LOG_WARN("⏳ Reconnect attempt skipped — waiting for cooldown.");
        return;
    }

    lastReconnectAttempt = now;
    retryCount++;

    if (Firebase.RTDB.beginStream(&commandFbdo, deviceMacPath + "/command")) {
        LOG_INFO("🔄 Stream reconnected successfully.");
        retryCount = 0;  // reset on success
    } else {
        LOGF("❌ Stream reconnect failed (Attempt %d): %s", retryCount, commandFbdo.errorReason().c_str());
        if (retryCount >= MAX_RETRIES) {
            LOG_ERROR("🚨 Max stream retry attempts reached. Consider resetting the device or switching to AP mode.");
            delay(100);
            LOG_INFO("Restarting ESP...");
            ESP.restart();
        }
    }
}

void updateOnlineStatus() {
    unsigned long now = millis();
    static unsigned long lastPush = 0;
    if (now - lastPush >= HEARTBEAT_INTERVAL) {
        unsigned long timestamp = time(nullptr);
        statusFbdo.clear();
        if (Firebase.RTDB.setInt(&statusFbdo, deviceMacPath + "/status/online", timestamp)) {
            lastPush = now;
            LOG_INFO("📶 Online heartbeat sent");
        } else {
            LOGF("❌ Failed to send heartbeat: %s", statusFbdo.errorReason().c_str());
        }
        statusFbdo.clear();
    }
}

void updateSensorReadings() {
    unsigned long now = millis();
    static unsigned long lastRead = 0;
    static unsigned long lastPush = 0;
    static bool motion = false;
    static float roomTemp = 0.0;
    static float roomHum = 0.0;
    static bool currMotion = false;
    static float currRoomTemp = 0.0;
    static float currRoomHum = 0.0;
    static bool shouldUpdate = false;
    if(now - lastRead > READ_INTERVAL){
        lastRead = now;
        currMotion = readMotionSensor();
        currRoomTemp = readTemperature();
        currRoomHum = readHumidity();
        if(currMotion != motion){
            motion = currMotion;
            shouldUpdate = true;
        }
        if(abs(currRoomTemp - roomTemp) >= TEMP_CHANGE_THRESHOLD){
            roomTemp = currRoomTemp;
            shouldUpdate = true;;
        }
        if(abs(currRoomHum - roomHum) >= HUM_CHANGE_THRESHOLD){
            roomHum = currRoomHum;
            shouldUpdate = true;
        }
    }
    if (now - lastPush >= SENSORS_INTERVAL && shouldUpdate) {
        FirebaseJson json;
        json.set("roomHumidity", currRoomHum);
        json.set("roomTemperature", currRoomTemp);
        json.set("motion", currMotion);
        sensorFbdo.clear();
        if (Firebase.RTDB.updateNode(&sensorFbdo, deviceMacPath + "/sensors", &json)) {
            lastPush = now;
            shouldUpdate = false;
            LOG_INFO("📶 Sensor Readings sent");
        } else {
            LOGF("❌ Failed to send sensor readings: %s", sensorFbdo.errorReason().c_str());
        }
        sensorFbdo.clear();
    }
}

void fetchSchedule() {
  accessFbdo.clear();
  if (Firebase.RTDB.getJSON(&accessFbdo, deviceMacPath)) {
    loadScheduleFromJson(accessFbdo.to<FirebaseJson>());
    LOG_INFO("📥 Schedule fetched");
  } else {
    LOGF("❌ Failed to load schedule: %s", accessFbdo.errorReason().c_str());
  }
  accessFbdo.clear();
}

void updateTotalHours(){
  // Track total working hours
  static unsigned long acOnStartMillis = 0;
  float capacityHours = testMode ? 1 : 250;
  static bool wasACOn = false;
  if (shouldBuzz && totalHours >= capacityHours) {
    buzz();
    shouldBuzz = false;
    notifyUser("maintenance");
  }
  if (acPowered) {
    if (!wasACOn) { 
      acOnStartMillis = millis();  // AC just turned on
    } else {
      unsigned long elapsed = millis() - acOnStartMillis;
      int  hoursUpdateInterval = testMode ? 1 : 15;
      if (elapsed >= hoursUpdateInterval * MINUTES_CONVERT) {
        acOnStartMillis = millis();  // reset timer
        totalHours += 0.25;
        maintenanceFbdo.clear();
        if (Firebase.RTDB.setFloat(&maintenanceFbdo, deviceMacPath + "/maintenance/totalHours", totalHours)) {
            LOG_INFO("Total Hours increased in 15 minutes");
        } else {
            LOGF("❌ Failed to update maintenance hours: %s", maintenanceFbdo.errorReason().c_str());
        }
        maintenanceFbdo.clear();
      }
    }
  } else {
    acOnStartMillis = millis();  // Reset if turned off
  }
  wasACOn = acPowered;

}

void notifyUser(const String& prompt){
    notifyFbdo.clear();
    if(prompt == "motion"){
        if (Firebase.RTDB.setString(&notifyFbdo, deviceMacPath + "/status/idleFlag", idleFlag)) {
            LOG_INFO("Notified RTDB About Motion");
        } else {
            LOGF("❌ Failed to Notify RTDB About Motion: %s", notifyFbdo.errorReason().c_str());
        }
    }
    else if (prompt == "maintenance"){
        if (Firebase.RTDB.setBool(&notifyFbdo, deviceMacPath + "/status/maintenanceFlag", !shouldBuzz)) {
            LOG_INFO("Notified RTDB About Maintenance");
        } else {
            LOGF("❌ Failed to Notify RTDB About Maintenance: %s", notifyFbdo.errorReason().c_str());
        }

    }
    else if (prompt == "system_switch_power"){
        if (Firebase.RTDB.setBool(&notifyFbdo, deviceMacPath + "/status/powered", acPowered)) {
            LOG_INFO("Notified RTDB About System Turn Off");
        } else {
            LOGF("❌ Failed to Notify RTDB About System Turn Off: %s", notifyFbdo.errorReason().c_str());
        }
    }
    else if (prompt == "reset_mode"){
        if (Firebase.RTDB.setString(&notifyFbdo, deviceMacPath + "/status/mode", mode)) {
            LOG_INFO("Notified RTDB About Resetting Mode");
        } else {
            LOGF("❌ Failed to Notify RTDB About Resetting Mode: %s", notifyFbdo.errorReason().c_str());
        }
    }
    else if (prompt == "system_switch_power_due_to_motion"){
        if (Firebase.RTDB.setBool(&notifyFbdo, deviceMacPath + "/status/powered", acPowered)) {
            LOG_INFO("Notified RTDB About System Turn Off");
        } else {
            LOGF("❌ Failed to Notify RTDB About System Turn Off: %s", notifyFbdo.errorReason().c_str());
        }
        idleFlag = "active";
        if (Firebase.RTDB.setString(&notifyFbdo, deviceMacPath + "/status/idleFlag", idleFlag)) {
            LOG_INFO("Notified RTDB About Motion Auto Off");
        } else {
            LOGF("❌ Failed to Notify RTDB About Motion Auto Off: %s", notifyFbdo.errorReason().c_str());
        }
    }
    notifyFbdo.clear();
    return;
}

void resetDevice(){
    Preferences prefs;
    prefs.begin("setup", false);
    prefs.clear();
    prefs.end();
    prefs.begin("daytrack", false);
    prefs.clear();
    prefs.end();
    prefs.begin("eco", false);
    prefs.clear();
    prefs.end();
    delay(2000);
    ESP.restart();
}