#include <DHT.h>
#include "dhtSensor.h"
#include "parameters.h"
#include "log.h"
#include "FirestoreServices.h"


DHT dht(DHTPIN, DHTTYPE);

void InitDHT(){
  dht.begin();
}

bool readTemperature (){
  static unsigned long lastUpload = 0;
  static bool firstRead = true;
  const unsigned long uploadInterval = 10000; // 10 seconds
  unsigned long now = millis();
  if ((now - lastUpload < uploadInterval) && lastUpload != 0) return false;
  lastUpload = now;
  float currRoomTemp = dht.readTemperature();
  float roomTemp = deviceData["sensors"]["roomTemperature"];
  if (isnan(currRoomTemp)){
    if (firstRead) LOG_ERROR("❌ Failed to read room temperature");
    firstRead = false;
    return false;
  }
  if(abs(currRoomTemp - roomTemp) >= TEMP_CHANGE_THRESHOLD){
    deviceData["sensors"]["roomTemperature"] = currRoomTemp;
    return true;
  }
  return false;
}

bool readHumidity(){
  static unsigned long lastUpload = 0;
  const unsigned long uploadInterval = 10000; // 10 seconds
  static bool firstRead = true;
  unsigned long now = millis();
  if ((now - lastUpload < uploadInterval) && lastUpload != 0) return false;
  lastUpload = now;
  float currRoomHumidity = dht.readHumidity();
  float roomHumidity = deviceData["sensors"]["roomHumidity"];
  if (isnan(currRoomHumidity)){
    if(firstRead) LOG_ERROR("❌ Failed to read room humidity");
    firstRead = false;
    return false;
  }
  if(abs(currRoomHumidity - roomHumidity) >= HUM_CHANGE_THRESHOLD){
    deviceData["sensors"]["roomHumidity"] = currRoomHumidity;
    return true;
  }
  return false;
}