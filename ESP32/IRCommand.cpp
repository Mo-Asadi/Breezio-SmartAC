#include <IRremoteESP8266.h>
#include <IRutils.h>
#include <IRsend.h>
#include <IRrecv.h>   
#include <ir_Electra.h>
#include <ir_Samsung.h>
#include <ir_LG.h>
#include <Preferences.h>
#include <Firebase_ESP_Client.h>
#include "FirestoreServices.h"
#include "IRCommand.h"
#include "parameters.h"
#include "log.h"
#include "led.h"
#include "relay.h"


IRsend irsend(IRLED);
IRElectraAc acElectra(IRLED);
IRSamsungAc acSamsung(IRLED);
IRLgAc acLG(IRLED);



void initIR() {
    String model = deviceData["config"]["model"];
    LOGF(" AC Model: %s", model);

    if (model == "electra") {
        acElectra.begin();
        acElectra.setMode(kElectraAcCool);
        acElectra.setFan(kElectraAcFanAuto);
        LOG_INFO("✅ Electra IR initialized and default state initialized.");

    } else if (model == "samsung") {
        acSamsung.begin();
        acSamsung.setMode(kSamsungAcCool);
        acSamsung.setFan(kSamsungAcFanAuto);
        LOG_INFO("✅ Samsung IR initialized and default state initialized.");

    } else if (model == "lg") {
        acLG.begin();
        acLG.setMode(kLgAcCool);
        acLG.setFan(kLgAcFanAuto);
        LOG_INFO("✅ LG IR initialized and default state initialized.");

    } else if (model == "custom") {
        irsend.begin();
        LOG_INFO("🛠️ Manual IR mode activated — waiting for commands.");
    } else {
        LOGF("🚫 Unknown AC model: '%s'. IR not initialized.", model.c_str());
    }
}

bool isValidScheduleCommand(JsonDocument& command){
    if(!command.containsKey("sunday") || !command.containsKey("monday") || !command.containsKey("tuesday") || !command.containsKey("wednesday") || !command.containsKey("thursday") || !command.containsKey("friday") || !command.containsKey("saturday")) return false;
    return true;
}

void applySchedule(String& uid){
    deviceData["schedule"] = deviceData["users"][uid]["schedule"];
    deviceData["command"] = "waiting";
    deviceData["result"] = "Success";
    return;
}

void setSchedule(JsonDocument& command){
    if(!isValidScheduleCommand(command)){
        LOG_ERROR("❌ Command format for set_schedule is not correct");
        deviceData["command"] = "waiting";
        deviceData["result"] = "MalformedCommand";
        return;
    }
    String uid = command["uid"];
    deviceData["users"][uid]["schedule"]["sunday"] = command["sunday"];
    deviceData["users"][uid]["schedule"]["monday"] = command["monday"];
    deviceData["users"][uid]["schedule"]["tuesday"] = command["tuesday"];
    deviceData["users"][uid]["schedule"]["wednesday"] = command["wednesday"];
    deviceData["users"][uid]["schedule"]["thursday"] = command["thursday"];
    deviceData["users"][uid]["schedule"]["friday"] = command["friday"];
    deviceData["users"][uid]["schedule"]["saturday"] = command["saturday"];
    deviceData["command"] = "waiting";
    deviceData["result"] = "Success";
    return;
}

void addNewUser(JsonDocument& command){
    if(!command.containsKey("new_uid")){
        LOG_ERROR("❌ Command format for add_user is not correct");
        deviceData["command"] = "waiting";
        deviceData["result"] = "MalformedCommand";
        return;
    }
    String newUid = command["new_uid"];
    deviceData["users"][newUid]["role"] = "admin";
    deviceData["users"][newUid]["favorites"]["temperature"] = DEFAULT_TEMP;
    deviceData["users"][newUid]["favorites"]["lightsOn"] = false;
    deviceData["users"][newUid]["favorites"]["mode"] = "regular";
    deviceData["users"][newUid]["favorites"]["relayOn"] = false;
    deviceData["users"][newUid]["schedule"]["sunday"]["active"] = false;
    deviceData["users"][newUid]["schedule"]["monday"]["active"] = false;
    deviceData["users"][newUid]["schedule"]["tuesday"]["active"] = false;
    deviceData["users"][newUid]["schedule"]["wednesday"]["active"] = false;
    deviceData["users"][newUid]["schedule"]["thursday"]["active"] = false;
    deviceData["users"][newUid]["schedule"]["friday"]["active"] = false;
    deviceData["users"][newUid]["schedule"]["saturday"]["active"] = false;
    deviceData["command"] = "waiting";
    deviceData["result"] = "Success";
    return;
}

void resetMaintenance(){
    deviceData["maintenance"]["totalHours"] = 0.0;
    deviceData["maintenance"]["buzz"] = true;
    deviceData["command"] = "waiting";
    deviceData["result"] = "Success";
    return;
}

void setFavorites(JsonDocument& command){
    String uid = command["uid"];
    if(!command.containsKey("temperature") || !command.containsKey("mode") ||!command.containsKey("lights") || !command.containsKey("scent")){
        LOG_ERROR("❌ Command format for set_favorites is not correct");
        deviceData["command"] = "waiting";
        deviceData["result"] = "MalformedCommand";
        return;
    }
    float favTemp = command["temperature"];
    String favMode = command["mode"];
    bool favScent = command["scent"];
    bool favLights = command["lights"];
    deviceData["users"][uid]["favorites"]["temperature"] = favTemp;
    deviceData["users"][uid]["favorites"]["lightsOn"] = favLights;
    deviceData["users"][uid]["favorites"]["mode"] = "favMode";
    deviceData["users"][uid]["favorites"]["relayOn"] = favScent;
    deviceData["command"] = "waiting";
    deviceData["result"] = "Success";
}

bool controlACScent(){
    bool relayOn = deviceData["status"]["relayOn"];
    if(!switchRelay(!relayOn)){
        LOG_ERROR("❌ Could Not Control Relay");
        deviceData["command"] = "waiting";
        deviceData["result"] = "HardwareError";
        return false;
    }
    deviceData["status"]["relayOn"] = !relayOn;
    deviceData["command"] = "waiting";
    deviceData["result"] = "Success";
    return true;

}

bool controlACLights(){
    bool lightsOn = deviceData["status"]["lightsOn"];
    if(!switchLed(!lightsOn)){
        LOG_ERROR("❌ Could Not Control Led Lights");
        deviceData["command"] = "waiting";
        deviceData["result"] = "HardwareError";
        return false;
    }
    deviceData["status"]["lightsOn"] = !lightsOn;
    deviceData["command"] = "waiting";
    deviceData["result"] = "Success";
    return true;

}

bool controlACMode(JsonDocument& command){
    bool acIsOn = deviceData["status"]["powered"];
    String model = deviceData["config"]["model"];
    String currentMode = deviceData["status"]["mode"];
    if(!command.containsKey("mode")){
        LOG_ERROR("❌ Missing Mode Type To Activate");
        deviceData["command"] = "waiting";
        deviceData["result"] = "MalformedCommand";
        return false;
    }
    String mode = command["mode"];
    if(mode != "eco" || mode != "timer" || mode != "motion" || mode != "regular"){
        LOG_ERROR("❌ Mode Type is Unknown");
        deviceData["command"] = "waiting";
        deviceData["result"] = "MalformedCommand";
        return false;
    }
    if(!acIsOn){
        LOG_ERROR("❌ AC is not powered on");
        deviceData["command"] = "waiting";
        deviceData["result"] = "ACIsOff";
        return false;
    }
    if (mode == currentMode){
        LOG_WARN("Mode type is already active");
        deviceData["command"] = "waiting";
        deviceData["result"] = "RepeatedCommand";
        return false;
    }
    deviceData["status"]["mode"] = mode;
    deviceData["command"] = "waiting";
    deviceData["result"] = "Success";
    return true;

}

bool transmitSignal(const String& signal){
    std::vector<uint16_t> rawVector;
    char* rawBuffer = strdup(signal.c_str());
    char* token = strtok(rawBuffer, ",");

    while (token != nullptr) {
        rawVector.push_back(atoi(token));
        token = strtok(nullptr, ",");
    }
    free(rawBuffer);
    if (rawVector.empty()) {
        LOG_ERROR("⚠️ Parsed raw IR signal is empty.");
        deviceData["command"] = "waiting";
        deviceData["result"] = "NoIRSignal";
        return false;
    }
    else{
        uint16_t rawData[rawVector.size()];
        for (size_t i = 0; i < rawVector.size(); i++) {
            rawData[i] = rawVector[i];
        }
        irsend.sendRaw(rawData, sizeof(rawData)/sizeof(rawData[0]), 38);   // 38kHz
        return true;
    }
}

bool controlACTemp(const String& action){
    bool acIsOn = deviceData["status"]["powered"];
    String model = deviceData["config"]["model"];
    float currentTemp = deviceData["status"]["currentTemperature"];
    float maxTemp = deviceData["config"]["maxTemperature"];
    float minTemp = deviceData["config"]["minTemperature"];
    if(!acIsOn){
        LOG_ERROR("❌ AC is not powered on");
        deviceData["command"] = "waiting";
        deviceData["result"] = "ACIsOff";
        return false;
    }
    if ((action == "temp_up" && currentTemp > maxTemp) || (action == "temp_down" && currentTemp < minTemp)){
        LOG_WARN("🌡 AC reached temperature limit");
        deviceData["command"] = "waiting";
        deviceData["result"] = "ACTempLimit";
        return false;
    }
    if (action == "temp_up") {
        currentTemp += 1;
    } else {
        currentTemp -= 1;
    }
    if(model == "electra"){
        acElectra.setTemp(currentTemp);
        acElectra.send();
    }
    else if(model == "samsung"){
        acSamsung.setTemp(currentTemp);
        acSamsung.send();
    }
    else if(model == "lg"){
        acLG.setTemp(currentTemp);
        acLG.send();
    }
    else if(model == "custom"){
        Preferences prefs;
        prefs.begin("setup", true);
        String signal = action == "temp_up" ? prefs.getString("tempUp", "") : prefs.getString("tempDown", "");
        prefs.end();
        if (!transmitSignal(signal)) return false;
    }
    else{
        LOG_ERROR("❌ Model of AC is unknown/unsupported");
        deviceData["command"] = "waiting";
        deviceData["result"] = "UnsupportedModel";
        return false;
    }
    deviceData["status"]["currentTemperature"] = currentTemp;
    deviceData["command"] = "waiting";
    deviceData["result"] = "Success";
    switchLed(deviceData["status"]["lightsOn"].as<bool>());
    return true;
}

void controlACPower(const String& uid){
    bool acIsOn = deviceData["status"]["powered"];
    String model = deviceData["config"]["model"];
    if (model == "electra"){
        acElectra.setPower(!acIsOn);
        acElectra.send();
        deviceData["status"]["powered"] = !acIsOn;
        deviceData["command"] = "waiting";
        deviceData["result"] = "Success";
        if(uid != "system" && acIsOn) deviceData["status"]["manualTurnOff"] = true;
        if(!acIsOn) deviceData["status"]["manualTurnOff"] = false;
    }
    else if (model == "samsung"){
        acSamsung.setPower(!acIsOn);
        acSamsung.send();
        deviceData["status"]["powered"] = !acIsOn;
        deviceData["command"] = "waiting";
        deviceData["result"] = "Success";
        if(uid != "system" && acIsOn) deviceData["status"]["manualTurnOff"] = true;
        if(!acIsOn) deviceData["status"]["manualTurnOff"] = false;
    }
    else if (model == "lg"){
        acLG.setPower(!acIsOn);
        acLG.send();
        deviceData["status"]["powered"] = !acIsOn;
        deviceData["command"] = "waiting";
        deviceData["result"] = "Success";
        if(uid != "system" && acIsOn) deviceData["status"]["manualTurnOff"] = true;
        if(!acIsOn) deviceData["status"]["manualTurnOff"] = false;
    }
    else if (model == "custom"){
        Preferences prefs;
        prefs.begin("setup", true);
        String signal = acIsOn ? prefs.getString("off", "") : prefs.getString("on", "");
        prefs.end();
        if (transmitSignal(signal)){
            deviceData["status"]["powered"] = !acIsOn;
            deviceData["command"] = "waiting";
            deviceData["result"] = "Success";
            if(uid != "system" && acIsOn) deviceData["status"]["manualTurnOff"] = true;
            if(!acIsOn) deviceData["status"]["manualTurnOff"] = false;
        }
    }
    else{
        LOG_ERROR("❌ Model of AC is unknown/unsupported");
        deviceData["command"] = "waiting";
        deviceData["result"] = "UnsupportedModel";
    }
}

void applyFavorites(JsonDocument& command){
    String uid = command["uid"];
    bool acIsOn = deviceData["status"]["powered"];
    if(!acIsOn){
        LOG_ERROR("❌ AC is not powered on");
        deviceData["command"] = "waiting";
        deviceData["result"] = "ACIsOff";
        return;
    }
    float favTemp = deviceData["users"][uid]["temperature"];
    String favMode = deviceData["users"][uid]["mode"];
    bool favScent = deviceData["users"][uid]["scent"];
    bool favLights = deviceData["users"][uid]["lights"];
    float currentTemp = deviceData["status"]["currentTemperature"];
    while (favTemp != currentTemp){
        if(favTemp > currentTemp){
            if(!controlACTemp("temp_up")) return;
        }
        else{
            if(!controlACTemp("temp_down")) return;
        }
        delay(100);
    }
    JsonDocument acMode;
    acMode["mode"] = favMode;
    if(!controlACMode(acMode)) return;
    bool currLights = deviceData["status"]["lightsOn"];
    bool currScent = deviceData["status"]["relayOn"];
    if(currLights != favLights){
        if(!controlACLights()) return;
    }
    if(currScent != favScent){
        if(!controlACScent()) return;
    }
    deviceData["command"] = "waiting";
    deviceData["result"] = "Success";
    return;
}

bool isPrivileged(const String& action){
    if(action == "reset_maintenance" || action == "add_user") return true;
    return false;
}

void PerformAction(JsonDocument& command) {
    if (!command.containsKey("action") || !command.containsKey("uid")) {
        LOG_ERROR("❌ Command format is not correct");
        deviceData["command"] = "waiting";
        deviceData["result"] = "MalformedCommand";
    }
    else if (!deviceData["users"].containsKey(command["uid"].as<String>())){
        LOG_ERROR("❌ User is not authorized to use the device");
        deviceData["command"] = "waiting";
        deviceData["result"] = "UserNotAuthorized";
    }
    else if (deviceData["users"][command["uid"].as<String>()]["role"].as<String>() != "admin" && isPrivileged(command["action"].as<String>())){
        LOG_ERROR("❌ User is not authorized to perform this command");
        deviceData["command"] = "waiting";
        deviceData["result"] = "UserNotPrivileged";
    }
    else{
        String action = command["action"];
        String uid = command["uid"];
        if(action == "switch_power") controlACPower(uid);
        else if(action == "temp_up" || action == "temp_down") controlACTemp(action);
        else if(action == "set_mode") controlACMode(command);
        else if(action == "switch_lights") controlACLights();
        else if(action == "switch_relay") controlACScent();
        else if(action == "set_favorites") setFavorites(command);
        else if(action == "apply_favorites") applyFavorites(command);
        else if(action == "reset_maintenance") resetMaintenance();
        else if(action == "add_user") addNewUser(command);
        else if(action == "set_schedule") setSchedule(command);
        else if(action == "apply_schedule") applySchedule(uid);
        else{
            LOG_ERROR("❌ Unsupported Command");
            deviceData["command"] = "waiting";
            deviceData["result"] = "UnsupportedCommand";
        }
    }
    saveDeviceData();
}
