#include "firestoreServices.h"
#include "modeHandler.h"
#include "parameters.h"
#include "log.h"
#include "command.h"
#include "ntpTime.h"
#include "sensors.h"


//Motion Mode Flags
unsigned long lastMotionMillis = 0;
unsigned long idleStartMillis = 0;
unsigned long motionModeActivated = 0;

//Eco Mode Flags
unsigned long ecoCycleStartMillis = 0;

//Timer Mode Flags
unsigned long timerStartMillis = 0;
unsigned long timerDurationMillis = 0;

//Scheduler Flags
String currentDay;
int currentTime;
bool alreadyTurnedOn = false;
bool alreadyTurnedOff = false;

void handleSchedule(){
  if(isNewDay(currentDay)){
    alreadyTurnedOn = false;
    alreadyTurnedOff = false;
  }
  int dayIndex = dayNameToIndex(currentDay);
  DaySchedule* dayPtrs[] = {
    &schedule.sun, &schedule.mon, &schedule.tue, &schedule.wed,
    &schedule.thu, &schedule.fri, &schedule.sat
  };
  if (!dayPtrs[dayIndex]->active) return;
  int startTime = dayPtrs[dayIndex]->startHour;
  int endTime = dayPtrs[dayIndex]->endHour;
  currentTime = getCurrentHourMinute();
  if (currentTime >= startTime && currentTime < endTime && !alreadyTurnedOn){
    LOG_INFO("Schedule Started");
    alreadyTurnedOn = true;
    if(acPowered) return;
    if(mode == "timer"){
      mode = "regular";
      notifyUser("reset_mode");
    }
    execute("switch_power");
    notifyUser("system_switch_power");
  }
  else if(currentTime >= endTime && !alreadyTurnedOff){
    LOG_INFO("Schedule Ended");
    alreadyTurnedOff = true;
    ecoCanTurnOn = false;
    if(!acPowered) return;
    execute("switch_power");
    notifyUser("system_switch_power");
  }
}

void handleMotionMode(){
  unsigned long now = millis();
  if(!acPowered) return;
  if (readMotionSensor()) {
    lastMotionMillis = now;
    if (idleFlag == "user_prompt") {
      LOG_INFO("🚶 Motion resumed — resetting idle status");
      idleFlag = "active";
    }
    return;
  }
  if (idleFlag == "continue") return;
  // 30 minutes idle passed
  int motionPromptMillis = testMode ? 1 : IDLE_THRESHOLD_MS;
  if (idleFlag == "active" && (now - lastMotionMillis > motionPromptMillis * MINUTES_CONVERT)) {
    LOGF("🕒 %d mins idle — prompting user via RTDB", motionPromptMillis);
    idleFlag = "user_prompt";
    notifyUser("motion");
    idleStartMillis = now;
    return;
  }
  // 45 minutes total idle & user didn't respond
  int autoOffMillis = testMode ? 1 : SHUTDOWN_WAIT_MS;
  if (idleFlag == "user_prompt" && (now - idleStartMillis > autoOffMillis * MINUTES_CONVERT)) {
    execute("switch_power");
    notifyUser("system_switch_power_due_to_motion");
  }
}

void resetOtherFlags(const String& mode){
  if (mode != "motion" || !acPowered) {
    // Reset motion mode timers and flags
    lastMotionMillis = 0;
    idleStartMillis = 0;
    idleFlag = "active";
  }
  if (mode != "eco") {
    // Reset eco mode timers and flags
    ecoCycleStartMillis = 0;
  }
  if(mode != "timer" || !acPowered){
    // Reset timer mode timers and flags
    timerStartMillis = 0;
  }
}

void handleEcoMode(){
  unsigned long now = millis();
  if (!acPowered && !ecoCanTurnOn){
    ecoCycleStartMillis = now;
    return;
  }
  if (ecoCycleStartMillis == 0 && acPowered) {
    ecoCycleStartMillis = now;
    LOG_INFO("🌿 ECO mode is On");
  }
  int ecoOnDuration = testMode ? 1 : ECO_ON_DURATION;
  int ecoOffDuration = testMode ? 1 : ECO_OFF_DURATION;
  if (acPowered && (now - ecoCycleStartMillis > ecoOnDuration * MINUTES_CONVERT)) {
    LOGF("🌿 ECO mode — %d minutes passed, turning AC OFF", ecoOnDuration);
    execute("eco_switch_power");
    notifyUser("system_switch_power");
    ecoCycleStartMillis = now;
  }
  else if (!acPowered && (now - ecoCycleStartMillis > ecoOffDuration * MINUTES_CONVERT)) {
    LOGF("🌿 ECO mode — %d mins OFF passed, turning AC ON", ecoOffDuration);
    execute("eco_switch_power");
    notifyUser("system_switch_power");
    ecoCycleStartMillis = 0;
  }
}

void handleTimerMode(){
  unsigned long now = millis();
  if (!acPowered) return;
  timerDurationMillis = duration * MINUTES_CONVERT;
  if (timerStartMillis == 0){
    timerStartMillis = now;
    LOGF("⏱️ Timer Mode started for %d minutes", duration);
  }
  if (acPowered && (now - timerStartMillis >= timerDurationMillis)) {
      LOG_WARN("⏰ Timer expired — turning off AC");
      execute("switch_power");
      notifyUser("system_switch_power");
  }
}

void handleMode(){
  resetOtherFlags(mode);
  handleSchedule();
  if(mode == "timer") handleTimerMode();
  else if(mode == "eco") handleEcoMode();
  else if(mode == "motion") handleMotionMode();
  else{ //mode = "regular"
    return;
  }
}
