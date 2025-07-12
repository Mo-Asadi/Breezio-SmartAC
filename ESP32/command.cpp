#include <IRremoteESP8266.h>
#include <IRutils.h>
#include <IRsend.h>
#include <IRrecv.h>   
#include <ir_Electra.h>
#include <ir_Samsung.h>
#include <ir_LG.h>
#include <Preferences.h>
#include <Firebase_ESP_Client.h>
#include "initSetup.h"
#include "firestoreServices.h"
#include "command.h"
#include "parameters.h"
#include "log.h"
#include "sensors.h"
#include "modeHandler.h"


IRsend irsend(IRLED);
IRElectraAc acElectra(IRLED);
IRSamsungAc acSamsung(IRLED);
IRLgAc acLG(IRLED);



void initIR() {
    if (model == "Electra") {
        acElectra.begin();
        acElectra.setMode(kElectraAcCool);
        acElectra.setFan(kElectraAcFanAuto);
        LOG_INFO("✅ Electra IR initialized and default state initialized.");

    } else if (model == "Samsung") {
        acSamsung.begin();
        acSamsung.setMode(kSamsungAcCool);
        acSamsung.setFan(kSamsungAcFanAuto);
        LOG_INFO("✅ Samsung IR initialized and default state initialized.");

    } else if (model == "LG") {
        acLG.begin();
        acLG.setMode(kLgAcCool);
        acLG.setFan(kLgAcFanAuto);
        LOG_INFO("✅ LG IR initialized and default state initialized.");

    } else if (model == "Custom") {
        irsend.begin();
        LOG_INFO("🛠️ Manual IR mode activated — waiting for commands.");
    } else {
        LOGF("🚫 Unknown AC model: '%s'. IR not initialized.", model.c_str());
    }
}

void transmitSignal(const String& signal){
    std::vector<uint16_t> rawVector;
    char* rawBuffer = strdup(signal.c_str());
    char* token = strtok(rawBuffer, ",");

    while (token != nullptr) {
        rawVector.push_back(atoi(token));
        token = strtok(nullptr, ",");
    }
    free(rawBuffer);
    uint16_t rawData[rawVector.size()];
    for (size_t i = 0; i < rawVector.size(); i++) {
        rawData[i] = rawVector[i];
    }
    noInterrupts();
    irsend.sendRaw(rawData, sizeof(rawData)/sizeof(rawData[0]), 38);   // 38kHz
    interrupts();
    return;
}

void controlACTemp(const String& action){
    if (action == "temp_up") {
        currTemp += 1;
    } else {
        currTemp -= 1;
    }
    if(model == "Electra"){
        acElectra.setTemp(currTemp);
        acElectra.send();
    }
    else if(model == "Samsung"){
        acSamsung.setTemp(currTemp);
        acSamsung.send();
    }
    else if(model == "LG"){
        acLG.setTemp(currTemp);
        acLG.send();
    }
    else{ //Custom mode
        Preferences prefs;
        prefs.begin("setup", true);
        String signal = action == "temp_up" ? prefs.getString("tempUp", "") : prefs.getString("tempDown", "");
        prefs.end();
        transmitSignal(signal);
    }
    validateLedColor();
    return;
}

void controlACPower(const String& action){
    if(action == "eco_switch_power" && !acPowered && ecoCanTurnOn == false){
        return;
    }
    if (model == "Electra"){
        acElectra.setPower(!acPowered);
        acElectra.send();
    }
    else if (model == "Samsung"){
        acSamsung.setPower(!acPowered);
        acSamsung.send();
    }
    else if (model == "LG"){
        acLG.setPower(!acPowered);
        acLG.send();
    }
    else{ //Custom model
        Preferences prefs;
        prefs.begin("setup", true);
        String signal = acPowered ? prefs.getString("off", "") : prefs.getString("on", "");
        prefs.end();
        transmitSignal(signal);
    }
    if(action != "eco_switch_power" && acPowered){
        ecoCanTurnOn = false;
        Preferences prefs;
        prefs.begin("eco", false);
        prefs.putBool("ecoCanTurnOn", ecoCanTurnOn);
        prefs.end();
    }
    else if (!acPowered){
        ecoCanTurnOn = true;
        Preferences prefs;
        prefs.begin("eco", false);
        prefs.putBool("ecoCanTurnOn", ecoCanTurnOn);
        prefs.end();
        lastMotionMillis = millis();
    }
    acPowered = !acPowered;
}

bool execute(const String& action) {
    if(action == "switch_power" || action == "eco_switch_power") controlACPower(action);
    else if(action == "temp_up" || action == "temp_down") controlACTemp(action);
    else{
        return false;
    }
    return true;
}
