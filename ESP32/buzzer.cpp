#include "buzzer.h"
#include "parameters.h"
#include "log.h"
#include "FirestoreServices.h"



void InitBuzzer(){
  pinMode(BUZZER, OUTPUT);
}

void buzz(){
  tone(BUZZER, 784);
  delay(5000);
  noTone(BUZZER);
  deviceData["maintenance"]["buzz"] = false;
}
