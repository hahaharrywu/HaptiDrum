#include <Wire.h>
#include "SparkFun_BNO080_Arduino_Library.h"

BNO080 myIMU;

#define SDA_PIN 21
#define SCL_PIN 22

void setup() {
  Serial.begin(115200);
  while (!Serial) delay(10);
  delay(1000);
  Serial.println("BNO080 I2C Test - SparkFun");
  Wire.begin();  // 使用你实际的 I2C 引脚

  if (!myIMU.begin(0x5A, Wire)) {  // 也可以尝试 0x4B
    Serial.println("Failed to connect to BNO080 over I2C");
    while (1) delay(10);
  }

  Serial.println("BNO080 connected!");

  myIMU.enableRotationVector(50);  // 20Hz 输出
}

void loop() {
  if (myIMU.dataAvailable()) {
    float roll  = myIMU.getRoll()  * RAD_TO_DEG;
    float pitch = myIMU.getPitch() * RAD_TO_DEG;
    float yaw   = myIMU.getYaw()   * RAD_TO_DEG;

    Serial.print("Roll: ");
    Serial.print(roll, 2);
    Serial.print("°, Pitch: ");
    Serial.print(pitch, 2);
    Serial.print("°, Yaw: ");
    Serial.print(yaw, 2);
    Serial.println("°");
  }
  delay(10);
}


