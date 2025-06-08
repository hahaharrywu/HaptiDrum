#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <SparkFun_BNO080_Arduino_Library.h>
#include <Adafruit_DRV2605.h>
#include <Wire.h>


// Device Name
// #define DEVICE_NAME "HaptiDrum_Foot_L"
// #define DEVICE_NAME "HaptiDrum_Foot_R"
// #define DEVICE_NAME "HaptiDrum_Hand_L"
#define DEVICE_NAME "HaptiDrum_Hand_R"


// ==========================
// ==== BLE Configuration ====
// ==========================

// BLE server and characteristic pointers
BLEServer* pServer = nullptr;
BLECharacteristic* pCharacteristic = nullptr;

// Track current BLE connection status
bool deviceConnected = false;

// BLE UUIDs (must match the iOS)
// For generating UUIDs: https://www.uuidgenerator.net/
#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"

// GPIO pin used to control the indicator LED
#define LED_PIN 4  // D3 / GPIO4


// Motor Driver Configuration
Adafruit_DRV2605 drv;

// ============================
// ==== IMU Configuration  ====
// ============================

// BNO080 IMU object
BNO080 myIMU;

// Timestamp of last valid IMU data
unsigned long lastUpdate = 0;

// Whether the IMU has started producing valid data
bool imuInitialized = false;

// ====================================================================
// Function: getIMUData()
// Purpose:  Read yaw, pitch, and roll values from BNO080 IMU,
//           return them as a JSON-formatted string.
//           Also handles timeout case when no data is available.
// Returns:  JSON string with yaw/pitch/roll or empty string if nothing new.
// ====================================================================
String getIMUData() {
  if (myIMU.dataAvailable()) {
    // IMU has new data available
    lastUpdate = millis();
    imuInitialized = true;  // Ensure Rotation Vector is working

    // Convert quaternion to Euler angles and convert radians to degrees
    float yaw = myIMU.getYaw() * 180.0 / PI;
    float pitch = myIMU.getPitch() * 180.0 / PI;
    float roll = myIMU.getRoll() * 180.0 / PI;

    // Angular velocity in deg/s
    float gx = myIMU.getGyroX() * 180.0 / PI;
    float gy = myIMU.getGyroY() * 180.0 / PI;
    float gz = myIMU.getGyroZ() * 180.0 / PI;


    // Format the data as a JSON string
    String jsonData = "{\"yaw\": " + String(yaw, 2) +
                  ", \"pitch\": " + String(pitch, 2) +
                  ", \"roll\": " + String(roll, 2) +
                  ", \"gx\": " + String(gx, 2) +
                  ", \"gy\": " + String(gy, 2) +
                  ", \"gz\": " + String(gz, 2) + "}";

    return jsonData;
  }


  if (millis() - lastUpdate > 1000 && imuInitialized) {
    Serial.println("IMU stalled, attempting reinit...");
    // myIMU.softReset();
    // delay(500);
    myIMU.enableRotationVector(20);
    myIMU.enableGyro(20);
    lastUpdate = millis();
  }

  // if (millis() - lastUpdate > 1000 && imuInitialized) {
  //   Serial.println("IMU stalled, attempting reinit...");
  //   Wire.end(); delay(10);
  //   Wire.begin(); delay(10);
  //   if (!myIMU.begin(BNO080_DEFAULT_ADDRESS, Wire, 500)) {
  //     Serial.println("Reinit failed: IMU not found");
  //     return "";
  //   }

  //   Serial.println("Reinit successful. Re-enabling sensors...");
  //   myIMU.enableRotationVector(20);
  //   myIMU.enableGyro(20);
  //   lastUpdate = millis();
  //   return "";
  // }

  // Serial.println("No new data yet...");
  // return "";



  // No new data available
  return "";
}

// ====================================================================
// Function: sendNotify()
// Purpose:  Send a given string (e.g. JSON or plain text) to the BLE client
//           using notify characteristic, only if the device is connected.
// ====================================================================
void sendNotify(const String& msg) {
  if (deviceConnected && msg.length() > 0) {
    // Send the string value over BLE
    pCharacteristic->setValue(msg.c_str());
    pCharacteristic->notify();

    // Print to serial for debugging
    Serial.println("Sent: " + msg);
  }
}

// ====================================================================
// Class: MyCharacteristicCallbacks
// Purpose:  Handles BLE write events (from mobile to ESP32).
//           Used here to blink LED when receiving the keyword "FIND".
// ====================================================================
class MyCharacteristicCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* pCharacteristic) override {
    String rxValue = pCharacteristic->getValue().c_str();

    // If received value is "FIND", blink LED for 1 second
    if (rxValue == "FIND") {
      drv.setMode(5);
      
      drv.setRealtimeValue(127);
      delay(3000);
      drv.setRealtimeValue(0);

      drv.setMode(0);
    }

    // If received value is "CONNECT", blink LED for 3*0.5, to confirm the connection
    if (rxValue == "CONNECT") {
      drv.setMode(5);

      drv.setRealtimeValue(127);
      delay(500);
      drv.setRealtimeValue(0);
      delay(500);
      drv.setRealtimeValue(127);
      delay(500);
      drv.setRealtimeValue(0);
      delay(500);
      drv.setRealtimeValue(127);
      delay(500);
      drv.setRealtimeValue(0);

      drv.setMode(0);
    }

    // ✅ Add RESET command handling here
    else if (rxValue == "RESET" || rxValue.indexOf("\"type\":\"RESET\"") >= 0) {
      Serial.println("Received RESET command. Restarting...");
      delay(200);  // 给 BLE 时间处理完通知
      myIMU.enableRotationVector(20);  // Enable 3D orientation (~500Hz, theoretically)
      myIMU.enableGyro(20);            // Angular Velocity 
      Serial.println("BNO085 ready.");
    }
  }
};

// ====================================================================
// Class: MyServerCallbacks
// Purpose:  Handles BLE connection and disconnection events.
//           Automatically restarts advertising when disconnected.
// ====================================================================
class MyServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) override {
    deviceConnected = true;
  }

  void onDisconnect(BLEServer* pServer) override {
    deviceConnected = false;
    BLEDevice::startAdvertising();  // Resume advertising for next device
    Serial.println("Disconnected. Restart advertising...");
  }
};

// ====================================================================
// Function: setup()
// Purpose:  One-time initialization of IMU, BLE, LED, and serial monitor.
// ====================================================================
void setup() {
  Serial.begin(115200);     // Start serial communication for debug
  Wire.begin();             // Initialize I2C (used by BNO085)


  // Initialize Motor Driver
  if (!drv.begin()) {
    Serial.println("Failed to initialize DRV2605");
    while (1);
  }

  // === 设置为 Real-Time Playback Mode ===
  drv.setMode(5);  // 0x05 = Real-Time Playback

  // === 设置为 LRA 模式（VL120628H 是 LRA）===
  drv.useLRA();    // 会设置寄存器 0x1A 第7位为1


  // ==== Initialize LED ====
  pinMode(LED_PIN, OUTPUT);
  pinMode(LED_BUILTIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);  // Ensure LED is off initially

  digitalWrite(LED_BUILTIN, HIGH);  // turn the LED on (HIGH is the voltage level)
  delay(1000);                      // wait for a second
  digitalWrite(LED_BUILTIN, LOW);   // turn the LED off by making the voltage LOW

  // ==== Initialize IMU ====
  Serial.println("Initializing BNO085...");
  if (!myIMU.begin(BNO080_DEFAULT_ADDRESS, Wire, 500)) {
    Serial.println("BNO085 not detected! Check wiring.");
    // while (1);  // Halt execution if IMU not found
    delay(2);
  }
  myIMU.softReset();              // Full reset
  delay(500);                     // Wait after reset
  myIMU.enableRotationVector(20);  // Enable 3D orientation (~500Hz, theoretically)
  myIMU.enableGyro(20);            // Angular Velocity 
  Serial.println("BNO085 ready.");

  // ==== Initialize BLE ====
  BLEDevice::init(DEVICE_NAME);  // Set BLE device name

  // Create BLE server and set connection callbacks
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  // Create BLE service and characteristic for communication
  BLEService* pService = pServer->createService(SERVICE_UUID);
  pCharacteristic = pService->createCharacteristic(
    CHARACTERISTIC_UUID,
    BLECharacteristic::PROPERTY_READ |
    BLECharacteristic::PROPERTY_WRITE |
    BLECharacteristic::PROPERTY_NOTIFY
  );
  pCharacteristic->setCallbacks(new MyCharacteristicCallbacks());
  pCharacteristic->addDescriptor(new BLE2902());  // Enable notifications on iOS
  pService->start();

  // Start advertising the BLE service so phones can find it
  BLEAdvertising* pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  BLEDevice::startAdvertising();

  Serial.println("BLE Server is ready and advertising.");
}

// ====================================================================
// Function: loop()
// Purpose:  Called repeatedly. Here it:
//           - Gets current IMU data (if available)
//           - Sends data via BLE notification
// ====================================================================
unsigned long lastSend = 0;
void loop() {
  // Step 1: Poll IMU and get formatted yaw/pitch/roll as a JSON string
  String imuData = getIMUData();

  // Step 2: Send that string over BLE to connected phone (if any)
  // sendNotify(imuData);
  if (deviceConnected && imuData.length() > 0 && millis() - lastSend > 50) {
    sendNotify(imuData);
    lastSend = millis();
  }

  if (millis() - lastSend > 3000) {
  Serial.println("looping...");
  lastSend = millis();
  }

}
