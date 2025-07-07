#include "FirestoreServices.h"
#include "modeHandler.h"
#include "parameters.h"
#include "log.h"
#include "IRCommand.h"
#include "pirSensor.h"
#include "buzzer.h"
#include "ntpTime.h"

//Maintenance Flags
unsigned long acOnStartMillis = 0;
bool wasACOn = false;

//Motion Mode Flags
unsigned long lastMotionMillis = 0;
unsigned long idleStartMillis = 0;

//Eco Mode Flags
unsigned long ecoCycleStartMillis = 0;

//Timer Mode Flags
unsigned long timerStartMillis = 0;
unsigned long timerDurationMillis = 0;

//Scheduler Flags
String currentDay;
int currentTime;

void handleMaintenance(){
  // Track total working hours
  bool acIsOn = deviceData["status"]["powered"];
  float totalHours = deviceData["maintenance"]["totalHours"];
  float capacityHours = deviceData["maintenance"]["capacityHours"];
  bool shouldBuzz = deviceData["maintenance"]["buzz"];
  if (shouldBuzz && totalHours >= capacityHours) buzz();
  if (acIsOn) {
    if (!wasACOn) {
      acOnStartMillis = millis();  // AC just turned on
    } else {
      unsigned long elapsed = millis() - acOnStartMillis;
      if (elapsed >= 15 * 60 * 1000) {  // 15 minutes
        acOnStartMillis = millis();  // reset timer
        totalHours = deviceData["maintenance"]["totalHours"];
        totalHours += 0.25;
        deviceData["maintenance"]["totalHours"] = totalHours;
        saveDeviceData();
        delay(1000);
      }
    }
  } else {
    acOnStartMillis = millis();  // Reset if turned off
  }

}

void handleSchedule(){
  bool suActive = deviceData["schedule"]["sunday"]["active"];
  bool moActive = deviceData["schedule"]["monday"]["active"];
  bool tuActive = deviceData["schedule"]["tuesday"]["active"];
  bool weActive = deviceData["schedule"]["wednesday"]["active"];
  bool thActive = deviceData["schedule"]["thursday"]["active"];
  bool frActive = deviceData["schedule"]["friday"]["active"];
  bool saActive = deviceData["schedule"]["saturday"]["active"];
  static bool alreadyTurnedOn = false;
  static bool alreadyTurnedOff = false;
  if(!suActive && !moActive && !tuActive && !weActive && !thActive && !frActive && !saActive) return;
  if(isNewDay(currentDay)){
    alreadyTurnedOn = false;
    alreadyTurnedOff = false;
  }
  currentDay.toLowerCase();
  if (!deviceData["schedule"][currentDay]["active"].as<bool>()) return;
  int startTime = deviceData["schedule"][currentDay]["start"];
  int endTime = deviceData["schedule"][currentDay]["end"];
  currentTime = getCurrentHourMinute();
  bool acIsOn = deviceData["status"]["powered"];
  if (currentTime >= startTime && currentTime < endTime && !alreadyTurnedOn){
    alreadyTurnedOn = true;
    if(acIsOn) return;
    JsonDocument command;
    command["action"] = "switch_power";
    command["uid"] = "scheduler";
    PerformAction(command);
  }
  else if(currentTime >= endTime && !alreadyTurnedOff){
    alreadyTurnedOff = true;
    deviceData["status"]["manualTurnOff"] = true;
    if(!acIsOn) return;
    JsonDocument command;
    command["action"] = "switch_power";
    command["uid"] = "scheduler";
    PerformAction(command);
  }
}

void handleMotionMode(){
  unsigned long now = millis();
  bool acIsOn = deviceData["status"]["powered"];
  String idleFlag = deviceData["status"]["idleFlag"];
  if(!acIsOn) return;
  if (isMotionDetected()) {
    lastMotionMillis = now;
    if (idleFlag == "user_prompt") {
      LOG_INFO("🚶 Motion resumed — resetting idle status");
      deviceData["status"]["idleFlag"] = "active";
      saveDeviceData();
      delay(1000);
    }
    return;
  }
  if (idleFlag == "continue") return;
  // 30 minutes idle passed
  if (idleFlag == "active" && (now - lastMotionMillis > IDLE_THRESHOLD_MS)) {
    LOG_WARN("🕒 30 mins idle — prompting user via RTDB");
    deviceData["status"]["idleFlag"] = "user_prompt";
    saveDeviceData();
    delay(1000);
    idleStartMillis = now;
    return;
  }
  // 45 minutes total idle & user didn't respond
  if (idleFlag == "user_prompt" && (now - idleStartMillis > SHUTDOWN_WAIT_MS)) {
    LOG_WARN("⚠️ No user response — auto turning off AC");
    JsonDocument command;
    command["action"] = "switch_power";
    command["uid"] = "system";
    deviceData["status"]["idleFlag"] = "auto_off";
    PerformAction(command);
  }
}

void resetOtherFlags(String& mode){
  bool acIsOn = deviceData["status"]["powered"];
  if (mode != "motion" || !acIsOn) {
    // Reset motion mode timers and flags
    lastMotionMillis = 0;
    idleStartMillis = 0;
    if(mode != "motion" || (!acIsOn && deviceData["status"]["idleFlag"] == "continue")) deviceData["status"]["idleFlag"] = "active";
  }
  if (mode != "eco") {
    // Reset eco mode timers and flags
    ecoCycleStartMillis = 0;
  }
  if(mode != "timer" || !acIsOn){
    // Reset timer mode timers and flags
    timerStartMillis = 0;
  }
}

void handleEcoMode(){
  unsigned long now = millis();
  bool acIsOn = deviceData["status"]["powered"];
  bool manualTurnedOff = deviceData["status"]["manualTurnOff"];
  if (!acIsOn && manualTurnedOff) return;
  if (ecoCycleStartMillis == 0 && acIsOn) {
    ecoCycleStartMillis = now;
    LOG_INFO("🌿 ECO mode is On");
  }
  if (acIsOn && (now - ecoCycleStartMillis > ECO_ON_DURATION)) {
    JsonDocument command;
    command["action"] = "switch_power";
    command["uid"] = "system";
    LOG_INFO("🌿 ECO mode — 1 hour passed, turning AC OFF");
    PerformAction(command);
    ecoCycleStartMillis = now;
  }
  else if (!acIsOn && (now - ecoCycleStartMillis > ECO_OFF_DURATION)) {
    JsonDocument command;
    command["action"] = "switch_power";
    command["uid"] = "system";
    LOG_INFO("🌿 ECO mode — 10 mins OFF passed, turning AC ON");
    PerformAction(command);
    ecoCycleStartMillis = 0;
  }
}

void handleRegularMode(){
  return;
}

void handleTimerMode(){
  unsigned long now = millis();
  bool acIsOn = deviceData["status"]["powered"];
  if (!acIsOn) return;
  int duration = deviceData["status"]["currentTimer"];
  timerDurationMillis = duration * 60000UL;
  if (timerStartMillis == 0){
    timerStartMillis = now;
    LOGF("⏱️ Timer Mode started for %d minutes", duration);
  }
  if (now - timerStartMillis >= timerDurationMillis) {
      LOG_WARN("⏰ Timer expired — turning off AC");
      JsonDocument command;
      command["action"] = "switch_power";
      command["uid"] = "system";
      PerformAction(command);
  }
}

void handleMode(){
  String mode = deviceData["status"]["mode"];
  bool acIsOn = deviceData["status"]["powered"];
  resetOtherFlags(mode);
  handleMaintenance();
  handleSchedule();
  if(mode == "regular") handleRegularMode();
  else if(mode == "timer") handleTimerMode();
  else if(mode == "eco") handleEcoMode();
  else if(mode == "motion") handleMotionMode();
  else{
    LOG_ERROR("Can't Handle Unknown AC Mode");
  }
}
