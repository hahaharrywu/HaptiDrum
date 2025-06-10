#include <Wire.h>
#include <Adafruit_DRV2605.h>

Adafruit_DRV2605 drv;

void setup() {
  Serial.begin(9600);
  delay(1000);
  Serial.println("DRV2605L + VL120628H Serial Control");

  if (!drv.begin()) {
    Serial.println("Failed to initialize DRV2605");
    while (1);
  }

  drv.useLRA();  // Set device to use LRA mode
  Serial.println("Type 'p' to play, 's' to stop.");
}

void loop() {
  if (Serial.available()) {
    char cmd = Serial.read();
    if (cmd == 'p') {
      drv.setMode(5);               // Set to Real-Time Playback mode
      drv.setRealtimeValue(100);   // Set vibration strength (recommended: 60~100)
      Serial.println("Vibrating...");
    } else if (cmd == 's') {
      drv.setRealtimeValue(0);     // Set vibration strength to 0
      drv.setMode(0);              // Set to Standby mode (fully stop output)
      Serial.println("Stopped.");
    } else {
      Serial.println("Type 'p' to play, 's' to stop.");
    }
  }
}
