#include <DHT.h>
#include <Adafruit_NeoPixel.h>
#include "firestoreServices.h"
#include "parameters.h"
#include "log.h"
#include "sensors.h"

DHT dht(DHTPIN, DHTTYPE);

Adafruit_NeoPixel strip(LED_PIXELS_NUM, LED_PIN, NEO_GRB + NEO_KHZ800);

void initSensors(){
  pinMode(PIRPIN, INPUT);
  pinMode(BUZZER, OUTPUT);
  pinMode(RELAY_PIN, OUTPUT);
  pinMode(RESET_BUTTON_PIN, INPUT_PULLUP);
  digitalWrite(RELAY_PIN, HIGH); // Start OFF (OPEN)
  dht.begin();
  strip.begin();
  strip.clear();
  strip.show();
}

bool readMotionSensor(){
  return digitalRead(PIRPIN);
}

void buzz(){
  tone(BUZZER, 784);
  delay(5000);
  noTone(BUZZER);
}

float readTemperature (){
  static bool firstRead = true;
  float currRoomTemp = dht.readTemperature();
  if (isnan(currRoomTemp)){
    if (firstRead) LOG_ERROR("❌ Failed to read room temperature");
    firstRead = false;
    return 0.0;
  }
  firstRead = true;
  return currRoomTemp;
}

float readHumidity(){
  static bool firstRead = true;
  float currRoomHumidity = dht.readHumidity();
  if (isnan(currRoomHumidity)){
    if(firstRead) LOG_ERROR("❌ Failed to read room humidity");
    firstRead = false;
    return 0.0;
  }
  firstRead = true;
  return currRoomHumidity;
}

uint32_t chooseColor(){
  if (currTemp <= 22) {
    return strip.Color(0, 0, 255); //Blue
  } else if (currTemp >= 27) {
    return strip.Color(255, 0, 0); //Red
  } else {
    return strip.Color(0, 255, 0); //Green
  }
}

void switchLed() {
  uint32_t color = chooseColor();
  for(int i=0; i<LED_PIXELS_NUM; i++){
    strip.setPixelColor(i, lights_on ? 0 : color);
    strip.show();
    delay(DELAYVAL);
  }
}

void validateLedColor(){
  uint32_t color = chooseColor();
  for(int i=0; i<LED_PIXELS_NUM; i++){
    strip.setPixelColor(i, lights_on ? color : 0);
    strip.show();
    delay(DELAYVAL);
  }
}

void switchRelay() {
  if(!relay_on) {
    digitalWrite(RELAY_PIN, LOW);
  }
  else{
    digitalWrite(RELAY_PIN, HIGH);
  }
}

bool isButtonPressed(){
  if(digitalRead(RESET_BUTTON_PIN) == LOW){
    return true;
  }
  return false;
}