#include <Wire.h>

#define SDA_PIN 21
#define SCL_PIN 22

void setup() {
  Serial.begin(115200);
  while (!Serial) delay(10); // 等待串口准备
  delay(1000);
  Serial.println("I2C Scanner Starting...");

  Wire.begin();
  delay(100);

  byte count = 0;

  for (byte address = 1; address < 127; address++) {
    Wire.beginTransmission(address);
    if (Wire.endTransmission() == 0) {
      Serial.print("Found I2C device at 0x");
      Serial.println(address, HEX);
      count++;
    }
    delay(10);
  }

  if (count == 0) {
    Serial.println("No I2C devices found 😢");
  } else {
    Serial.print("Scan complete. Found ");
    Serial.print(count);
    Serial.println(" device(s). 🎉");
  }
}

void loop() {
  // 不需要重复扫描
}
