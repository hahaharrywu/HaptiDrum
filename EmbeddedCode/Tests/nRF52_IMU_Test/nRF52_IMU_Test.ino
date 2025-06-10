#include "LSM6DS3.h"
#include "Wire.h"

// Create an instance of the LSM6DS3 class
LSM6DS3 myIMU(I2C_MODE, 0x6A);  // Device address 0x6A

void setup() {
    Serial.begin(9600);
    while (!Serial);

    if (myIMU.begin() != 0) {
        Serial.println("Device error");
    } else {
        Serial.println("Device OK!");
    }
}

void loop() {
    // === Read accelerometer data ===
    float ax = myIMU.readFloatAccelX();
    float ay = myIMU.readFloatAccelY();
    float az = myIMU.readFloatAccelZ();

    // === Compute pitch and roll from acceleration ===
    float pitch = atan2(-ax, sqrt(ay * ay + az * az)) * 180.0 / PI;
    float roll  = atan2(ay, az) * 180.0 / PI;

    // === Print pitch and roll ===
    Serial.println("\n=== Orientation ===");
    Serial.print("Pitch: ");
    Serial.print(pitch, 2);
    Serial.print("°,  Roll: ");
    Serial.print(roll, 2);
    Serial.println("°");

    // === Print raw accelerometer ===
    Serial.println("\nAccelerometer:");
    Serial.print(" X = ");
    Serial.println(ax, 4);
    Serial.print(" Y = ");
    Serial.println(ay, 4);
    Serial.print(" Z = ");
    Serial.println(az, 4);

    // === Print raw gyroscope ===
    Serial.println("\nGyroscope:");
    Serial.print(" X = ");
    Serial.println(myIMU.readFloatGyroX(), 4);
    Serial.print(" Y = ");
    Serial.println(myIMU.readFloatGyroY(), 4);
    Serial.print(" Z = ");
    Serial.println(myIMU.readFloatGyroZ(), 4);

    // === Print temperature ===
    Serial.println("\nTemperature:");
    Serial.print(" Celsius = ");
    Serial.println(myIMU.readTempC(), 2);
    Serial.print(" Fahrenheit = ");
    Serial.println(myIMU.readTempF(), 2);

    delay(500);  // Update rate
}
