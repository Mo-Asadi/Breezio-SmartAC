#include "pirSensor.h"
#include "parameters.h"
#include "log.h"
#include "FirestoreServices.h"



void InitPir(){
  pinMode(PIRPIN, INPUT);
}

bool isMotionDetected(){
  return digitalRead(PIRPIN);
}

bool readMotionSensor(){
  static unsigned long lastUpload = 0;
  const unsigned long uploadInterval = 10000; // 10 seconds
  unsigned long now = millis();
  if ((now - lastUpload < uploadInterval) && lastUpload != 0) return false;
  lastUpload = now;
  if(isMotionDetected() != deviceData["sensors"]["motion"]){
    deviceData["sensors"]["motion"] = isMotionDetected();
    return true;
  }
  return false;
}
