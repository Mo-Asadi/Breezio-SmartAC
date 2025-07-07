#include <Arduino.h> 
#include <Firebase_ESP_Client.h>
#include <addons/RTDBHelper.h>
#include <addons/TokenHelper.h>
#include <Preferences.h>
#include "FirestoreServices.h"
#include "IRCommand.h"
#include "log.h"
#include "secrets.h"
#include "parameters.h"
#include "pirSensor.h"
#include "dhtSensor.h"


FirebaseAuth auth;
FirebaseConfig config;
FirebaseData commandFbdo;
FirebaseData accessFbdo;
FirebaseData idleFlagFbdo;
String deviceMacPath;
String idlePath;
JsonDocument deviceData;

//Online Hearbeat Flags
unsigned long lastHeartbeat = 0;

void initData();
void onCommandDataChange(FirebaseStream data);
void onIdleFlagChange(FirebaseStream data);
void onCommandStreamTimeout(bool timeout);
void onIdleStreamTimeout(bool timeout);

void initFirebase() {
    #if defined(ESP32)
    accessFbdo.setBSSLBufferSize(4096, 1024);
    commandFbdo.setBSSLBufferSize(4096, 1024);
    idleFlagFbdo.setBSSLBufferSize(4096, 1024);
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
    idlePath = deviceMacPath + "/status/idleFlag";

    // 🔍 Check if the device node exists
    accessFbdo.clear();
    if (!Firebase.RTDB.getJSON(&accessFbdo, deviceMacPath)) {
        LOG_WARN("📭 Device data does not exist — initializing...");
        initData();
    } else {
        LOG_INFO("📦 Device node already exists in RTDB");
    }
    // 🎧 Start stream
    if (!Firebase.RTDB.beginStream(&commandFbdo, deviceMacPath + "/command")) {
        LOGF("⚠️ Failed to start command stream: %s", commandFbdo.errorReason().c_str());
        return;
    }
    if (!Firebase.RTDB.beginStream(&idleFlagFbdo, idlePath)) {
        LOGF("⚠️ Failed to start idleFlag stream: %s", idleFlagFbdo.errorReason().c_str());
    } else {
        Firebase.RTDB.setStreamCallback(&commandFbdo, onCommandDataChange, onCommandStreamTimeout);
        Firebase.RTDB.setStreamCallback(&idleFlagFbdo, onIdleFlagChange, onIdleStreamTimeout);
    }
    loadDeviceData();
    deviceData["status"]["lightsOn"] = false;
    deviceData["status"]["relayOn"] = false;
    delay(1000);
    saveDeviceData();
}

void initData(){
    Preferences prefs;
    prefs.begin("setup", true);
    String adminUID = prefs.getString("uid", "debug");
    String model = prefs.getString("model", "");
    int minTemp = prefs.getInt("minTemp", -1);
    int maxTemp = prefs.getInt("maxTemp", -1);
    prefs.end();
    deviceData.clear();

    deviceData["command"] = "waiting";

    //  AC Configuration Defaults
    deviceData["config"]["model"] = model;
    deviceData["config"]["maxTemperature"] = maxTemp;
    deviceData["config"]["minTemperature"] = minTemp;

    // 🌡️ AC Status Defaults
    deviceData["status"]["powered"] = false;
    deviceData["status"]["currentTemperature"] = DEFAULT_TEMP;
    deviceData["status"]["currentTimer"] = DEFAULT_TIMER;
    deviceData["status"]["mode"] = "regular";
    deviceData["status"]["lightsOn"] = false;
    deviceData["status"]["relayOn"] = false;
    deviceData["status"]["manualTurnOff"] = false;
    deviceData["status"]["idleFlag"] = "active";
    deviceData["status"]["online"] = static_cast<int>(millis() / 1000);

    // 🛠️ AC Maintenance Defaults
    deviceData["maintenance"]["totalHours"] = 0.0;
    deviceData["maintenance"]["capacityHours"] = 250;
    deviceData["maintenance"]["buzz"] = true;

    // 📊 Sensor Readings Defaults
    deviceData["sensors"]["roomTemperature"] = 0.0;
    deviceData["sensors"]["roomHumidity"] = 0.0;
    deviceData["sensors"]["motion"] = false;

    // Setting Up AC Default Schedule
    deviceData["schedule"]["sunday"]["active"] = false;
    deviceData["schedule"]["monday"]["active"] = false;
    deviceData["schedule"]["tuesday"]["active"] = false;
    deviceData["schedule"]["wednesday"]["active"] = false;
    deviceData["schedule"]["thursday"]["active"] = false;
    deviceData["schedule"]["friday"]["active"] = false;
    deviceData["schedule"]["saturday"]["active"] = false;

    // 🛠️ Setting Up Users
    deviceData["users"]["system"]["role"] = "admin";
    deviceData["users"]["scheduler"]["role"] = "admin";
    deviceData["users"][adminUID]["role"] = "admin";
    deviceData["users"][adminUID]["favorites"]["temperature"] = DEFAULT_TEMP;
    deviceData["users"][adminUID]["favorites"]["lightsOn"] = false;
    deviceData["users"][adminUID]["favorites"]["mode"] = "regular";
    deviceData["users"][adminUID]["favorites"]["relayOn"] = false;
    deviceData["users"][adminUID]["schedule"]["sunday"]["active"] = false;
    deviceData["users"][adminUID]["schedule"]["monday"]["active"] = false;
    deviceData["users"][adminUID]["schedule"]["tuesday"]["active"] = false;
    deviceData["users"][adminUID]["schedule"]["wednesday"]["active"] = false;
    deviceData["users"][adminUID]["schedule"]["thursday"]["active"] = false;
    deviceData["users"][adminUID]["schedule"]["friday"]["active"] = false;
    deviceData["users"][adminUID]["schedule"]["saturday"]["active"] = false;

    saveDeviceData();
}

void loadDeviceData() {
    accessFbdo.clear();
    if (Firebase.RTDB.getJSON(&accessFbdo, deviceMacPath)) {
        FirebaseJson fbJson = accessFbdo.to<FirebaseJson>();
        String jsonStr;
        fbJson.toString(jsonStr);
        deviceData.clear();
        deserializeJson(deviceData, jsonStr);
        delay(1000);

    } else {
        LOG_ERROR("Failed to get device data");
    }
}

void saveDeviceData(){
    accessFbdo.clear();
    // Convert to FirebaseJson
    String jsonStr;
    serializeJson(deviceData, jsonStr);

    FirebaseJson fbJson;
    fbJson.setJsonData(jsonStr);

    if (Firebase.RTDB.setJSON(&accessFbdo, deviceMacPath, &fbJson)) {
        LOG_INFO("✅ Device data uploaded to RTDB");
    } else {
        LOGF("❌ Device data upload failed: %s", accessFbdo.errorReason().c_str());
    }
    delay(1000);
}

void handleFirebaseStream() {
    if (!Firebase.RTDB.readStream(&commandFbdo)) {
        LOG_ERROR("\nCommand Stream read failed");
        LOGF("\n🔍 Reason: %s", commandFbdo.errorReason().c_str());
        delay(500);
    }
    if (!Firebase.RTDB.readStream(&idleFlagFbdo)) {
        LOG_ERROR("\nIdle Flag Stream read failed");
        LOGF("\n🔍 Reason: %s", idleFlagFbdo.errorReason().c_str());
        delay(500);
    }
}

void onCommandDataChange(FirebaseStream data) {
    if (data.dataType() == "string") {
        String value = data.stringData();
        if (value == "waiting") {
            LOG_INFO("⏳ Waiting for new command — nothing to do.");
        }
        return;
    }
    else if (data.dataType() != "json") {
        LOG_ERROR("❌ Invalid or missing JSON command");
        return;
    }
    deviceData["command"] = "busy";
    FirebaseJson &commandData = data.to<FirebaseJson>();
    String jsonStr;
    commandData.toString(jsonStr);
    JsonDocument command;
    deserializeJson(command, jsonStr);
    LOG_INFO("📦 Received JSON Command");
    PerformAction(command);
    return;
}

void onIdleFlagChange(FirebaseStream data) {
    if (data.dataType() != "string") return;
    String newFlag = data.stringData();
    if (newFlag == "turn_off" || newFlag == "continue") {
        LOGF("🔄 idleFlag changed: %s", newFlag.c_str());
        loadDeviceData();
        return;
    }
    else {
        return;
    }
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

void onIdleStreamTimeout(bool timeout) {
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
    if (Firebase.RTDB.beginStream(&idleFlagFbdo, idlePath)) {
        LOG_INFO("🔄 Idle Flag Stream reconnected successfully.");
        retryCount = 0;  // reset on success
    } else {
        LOGF("❌ Idle Flag Stream reconnect failed (Attempt %d): %s", retryCount, idleFlagFbdo.errorReason().c_str());
        if (retryCount >= MAX_RETRIES) {
            LOG_ERROR("🚨 Max stream retry attempts reached. Consider resetting the device or switching to AP mode.");
            delay(100);
            LOG_INFO("Restarting ESP...");
            ESP.restart();
        }
    }
}

void resetData() {
    String path = deviceMacPath;

    if (WiFi.status() != WL_CONNECTED) {
        LOG_ERROR("❌ Cannot reset: Wi-Fi not connected.");
        return;
    }

    const int maxRetries = 3;
    Firebase.RTDB.endStream(&commandFbdo);
    Firebase.RTDB.endStream(&idleFlagFbdo);
    LOG_INFO("ended fbdo stream");
    delay(100);
    for (int attempt = 1; attempt <= maxRetries; ++attempt) {
        LOGF("🔁 Attempt %d to delete RTDB device data: %s", attempt, path.c_str());
        accessFbdo.clear();
        if (Firebase.RTDB.deleteNode(&accessFbdo, path)) {
            LOG_INFO("🗑️ RTDB node deleted successfully.");
            return;
        } else {
            LOGF("⚠️ Delete failed (Attempt %d): %s", attempt, accessFbdo.errorReason().c_str());
            delay(1000);  // wait before retry
        }
    }

    LOG_ERROR("❌ Failed to delete RTDB node after multiple attempts.");
}

void updateOnlineStatus() {
    if(millis() - lastHeartbeat > HEARTBEAT_INTERVAL){
        lastHeartbeat = millis();
        unsigned long now = millis();
        unsigned long timestamp = now / 1000; // convert to seconds
        String path = deviceMacPath + "/status/online";
        accessFbdo.clear();
        if (Firebase.RTDB.setInt(&accessFbdo, path, timestamp)) {
        LOG_INFO("📶 Online heartbeat sent");
        } else {
            LOGF("❌ Failed to send heartbeat: %s", accessFbdo.errorReason().c_str());
        }
    }
}

void updateSensorReadings(){
    if(readTemperature() || readHumidity() || readMotionSensor()){
        LOG_INFO("Saving New Sensors Readings");
        saveDeviceData();
    }
}