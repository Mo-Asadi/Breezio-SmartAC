#include "relay.h"
#include "parameters.h"

void InitRelay() {
    pinMode(RELAY_PIN, OUTPUT);
    digitalWrite(RELAY_PIN, HIGH); // Start OFF (OPEN)
}

bool switchRelay(bool switchOn) {
  if(switchOn) digitalWrite(RELAY_PIN, LOW);
  else{
    digitalWrite(RELAY_PIN, HIGH);
  }
  return true;
}