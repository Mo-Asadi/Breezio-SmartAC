#include <WebServer.h>
#include <WiFi.h>
#include <ArduinoJson.h>
#include <IRutils.h>
#include <IRrecv.h>
#include <IRsend.h>
#include "initSetup.h"
#include "log.h"
#include "secrets.h"
#include "parameters.h"
#include "firestoreServices.h"
#include "sensors.h"

WebServer server(80);
IRrecv irrecv(IRREC);
IRsend irtest(IRLED);

Preferences prefs;

bool isProvisioned() {
    prefs.begin("setup", true);
    bool ready = prefs.getBool("provisioned", false);
    prefs.end();
    return debugssid == "" ? ready : true;
}

void initIRLearning() {
    irrecv.enableIRIn();
    irtest.begin();
    LOG_INFO("📥 IR receiver initialized (learning mode)");
}

bool captureAndSaveIR(const String &keyLabel) {
    decode_results results;
    LOGF("📡 Waiting for IR signal for: %s...", keyLabel.c_str());

    unsigned long start = millis();
    while (!irrecv.decode(&results)) {
        if (millis() - start > 10000) {
            LOG_ERROR("⏱️ Timeout: No IR signal received");
            return false;
        }
        delay(50);
    }

    String rawStr = "";
    for (uint16_t i = 1; i < results.rawlen && i < kRawBuf; i++) {
        rawStr += String(results.rawbuf[i] * kRawTick);
        if (i < results.rawlen - 1) rawStr += ",";
    }
    prefs.begin("setup", false);
    prefs.putString(keyLabel.c_str(), rawStr);
    prefs.end();

    LOGF("✅ Captured %s IR signal.", keyLabel.c_str());
    LOGF("📏 Captured length: %d entries", results.rawlen);
    LOGF("[Raw] %s", rawStr.c_str());
    irrecv.resume();
    return true;
}

void registerIRTestHandler() {
    server.on("/irtest", HTTP_GET, []() {
        if (!server.hasArg("key")) {
            server.send(400, "text/plain", "❌ Missing 'key' query param (e.g., ?key=on)");
            return;
        }
        String keyLabel = server.arg("key");

        prefs.begin("setup", true);
        String rawStr = prefs.getString(keyLabel.c_str(), "");
        prefs.end();

        if (rawStr.isEmpty()) {
            server.send(404, "text/plain", "❌ No signal found for " + keyLabel);
            return;
        }

        // Parse string into vector
        std::vector<uint16_t> rawVector;
        char* rawBuffer = strdup(rawStr.c_str());
        char* token = strtok(rawBuffer, ",");

        while (token != nullptr) {
            rawVector.push_back(atoi(token));
            token = strtok(nullptr, ",");
        }
        free(rawBuffer);

        if (rawVector.empty()) {
            server.send(500, "text/plain", "⚠️ Parsed IR signal is empty.");
            return;
        }

        // Convert vector to raw array
        uint16_t rawData[rawVector.size()];
        for (size_t i = 0; i < rawVector.size(); i++) {
            rawData[i] = rawVector[i];
        }

        noInterrupts();
        irtest.sendRaw(rawData, sizeof(rawData)/sizeof(rawData[0]), 38);  // 38 kHz carrier
        interrupts();

        // Debug print
        Serial.printf("📤 Sent test signal for key: %s\n", keyLabel.c_str());
        for (size_t i = 0; i < rawVector.size(); i += 10) {
            Serial.print("🔹 Signal [");
            Serial.print(i);
            Serial.print(" - ");
            Serial.print(min(i + 9, rawVector.size() - 1));
            Serial.print("]: ");
            for (size_t j = i; j < i + 10 && j < rawVector.size(); j++) {
                Serial.print(rawVector[j]);
                if (j < i + 9 && j < rawVector.size() - 1) Serial.print(",");
            }
            Serial.println();
        }

        server.send(200, "text/plain", "✅ IR test sent for key: " + keyLabel);
    });
}

void registerIRSetupHandlers() {
    initIRLearning();
    server.on("/irsetup/on", HTTP_GET, []() {
        if (captureAndSaveIR("on"))
            server.send(200, "text/plain", "✅ IR ON code captured");
        else
            server.send(408, "text/plain", "❌ Timeout: No IR signal received");
    });

    server.on("/irsetup/off", HTTP_GET, []() {
        if (captureAndSaveIR("off"))
            server.send(200, "text/plain", "✅ IR OFF code captured");
        else
            server.send(408, "text/plain", "❌ Timeout: No IR signal received");
    });

    server.on("/irsetup/tempUp", HTTP_GET, []() {
        if (captureAndSaveIR("tempUp"))
            server.send(200, "text/plain", "✅ IR Temp Up code captured");
        else
            server.send(408, "text/plain", "❌ Timeout: No IR signal received");
    });

    server.on("/irsetup/tempDown", HTTP_GET, []() {
        if (captureAndSaveIR("tempDown"))
            server.send(200, "text/plain", "✅ IR Temp Down code captured");
        else
            server.send(408, "text/plain", "❌ Timeout: No IR signal received");
    });
}

void startAPMode() {
    String apName = "Breezio-" + WiFi.macAddress();
    apName.replace(":", "");

    WiFi.softAP(apName.c_str(), "Breezio123");
    LOGF("📡 AP Mode Started: %s | IP address: %s", apName.c_str(), WiFi.softAPIP().toString().c_str());

    server.on("/", HTTP_GET, []() {
        server.send(200, "application/json", R"({"message": "Send POST to /model with AC's model, to/irsetup with ir control signals, to /limits with max and min temperature, and finally to /finalize with ssid, password, userId."})");
    });

    server.on("/setup", HTTP_POST, []() {
        if (!server.hasArg("plain")) {
            server.send(400, "text/plain", "Missing body");
            return;
        }

        JsonDocument doc;
        DeserializationError error = deserializeJson(doc, server.arg("plain"));
        if (error) {
            server.send(400, "text/plain", "Invalid JSON");
            return;
        }

        // Extract all required fields
        String model = doc["model"] | "";
        String name = doc["name"] | "Breezio";
        String ssid = doc["ssid"] | "";
        String password = doc["password"] | "";
        prefs.begin("setup", true);
        LOGF("📋 Setup request received: model=%s, IR keys: on=%d off=%d up=%d down=%d",model.c_str(), prefs.isKey("on"), prefs.isKey("off"),prefs.isKey("tempUp"), prefs.isKey("tempDown"));
        bool irReady = !(model == "custom" &&
                        (!prefs.isKey("on") || !prefs.isKey("off") || 
                        !prefs.isKey("tempUp") || !prefs.isKey("tempDown")));
        // Check for missing required values
        if (model == "" || ssid == "" || password == "") {
            server.send(400, "text/plain", "❌ Missing required fields.");
            return;
        }
        if(!irReady){
            server.send(400, "text/plain", "❌ Missing IR codes for custom model.");
            return;
        }
        prefs.end(); 

        prefs.begin("setup", false);
        prefs.putString("model", model);
        prefs.putString("name", name);
        prefs.putString("ssid", ssid);
        prefs.putString("pass", password);
        prefs.putBool("provisioned", true);
        prefs.end();

        // ✅ Return MAC in the response
        String mac = WiFi.macAddress();
        mac.replace(":", "");  // optional, if you want MAC without colons
        String responseJson = "{\"status\": \"✅ Setup complete.\", \"mac\": \"" + mac + "\"}";
        server.send(200, "application/json", responseJson);

        server.send(200, "text/plain", "✅ Setup complete. Rebooting...");
        delay(1000);
        ESP.restart();
    });

    // AC Custom Commands IR Signals
    registerIRSetupHandlers();
    registerIRTestHandler();
    
    server.begin();
}

void connectToWifi(){
    if (WiFi.status() == WL_CONNECTED) {
        LOG_INFO("✅ Already connected to Wi-Fi.");
        return;
    }
    WiFi.disconnect();  // Force stop any previous attempt
    delay(100); 
    const int maxRetries = 3;
    const unsigned long timeoutMs = 10000;
    prefs.begin("setup", true);
    String ssid = prefs.getString("ssid", "");
    String pass = prefs.getString("pass", "");
    prefs.end();
    if ((ssid == "" || pass == "") && debugssid == "") {
        LOG_ERROR("No stored Wi-Fi credentials found.");
        return;
    }
    for (int attempt = 1; attempt <= maxRetries; ++attempt) {
        if(debugssid != ""){
            ssid = debugssid;
            pass = debugpass;
        }
        LOGF("🔄 Attempt %d to connect to Wi-Fi: %s", attempt, ssid.c_str());
        WiFi.begin(ssid.c_str(), pass.c_str());

        unsigned long startTime = millis();
        while (WiFi.status() != WL_CONNECTED && millis() - startTime < timeoutMs) {
            Serial.print(".");
            delay(300);
        }

        if (WiFi.status() == WL_CONNECTED) {
            LOG_INFO("\n✅ Connected to Wi-Fi!");
            return;
        } else {
            LOG_WARN("\n⏱️ Connection attempt timed out.");
            WiFi.disconnect(true);  
            delay(1000);
        }
    }
    LOG_ERROR("❌ Failed to connect to Wi-Fi after multiple attempts.");
}

void initSetup(){
    initSensors();
    if (!isProvisioned()) {
        startAPMode();
        return;
    }
    connectToWifi();
    return;
}

void handleWebRequests() {
  server.handleClient();
}