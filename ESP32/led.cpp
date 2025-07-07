#include <Adafruit_NeoPixel.h>
#include "led.h"
#include "parameters.h"
#include "FirestoreServices.h"

#define DELAYVAL 100

Adafruit_NeoPixel strip(LED_PIXELS_NUM, LED_PIN, NEO_GRB + NEO_KHZ800);

void InitLed() {
    strip.begin();
    strip.clear();
    strip.show();
}

uint32_t chooseColor(){
  float currentTemp = deviceData["status"]["currentTemperature"];
  if (currentTemp <= 22) {
    return strip.Color(0, 0, 255); //Blue
  } else if (currentTemp >= 27) {
    return strip.Color(255, 0, 0); //Red
  } else {
    return strip.Color(0, 255, 0); //Green
  }
}

bool switchLed(bool switchOn) {
  uint32_t color = chooseColor();
  for(int i=0; i<LED_PIXELS_NUM; i++){
    strip.setPixelColor(i, switchOn ? color : 0);
    strip.show();
    delay(DELAYVAL);
  }
  return true;
}