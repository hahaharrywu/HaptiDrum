#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

// Global BLE server and characteristic pointers
BLEServer* pServer = nullptr;
BLECharacteristic* pCharacteristic = nullptr;

bool deviceConnected = false;  // Track BLE connection status
uint32_t value = 0;             // Value to send via notifications

// UUIDs for the BLE service and characteristic (must match the ones used in the iOS app)
#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"

#define LED_PIN 4  // GPIO4 (can also be referred to as D3 or A3 on some boards)

// Callback class that handles data written by the client (iOS)
class MyCharacteristicCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* pCharacteristic) override {
    // Convert received data to String
    String rxValue = pCharacteristic->getValue().c_str();
    if (rxValue.length() > 0) {
      Serial.println("Received from iOS: " + rxValue);

      // If the received value is "FIND", blink the LED for 1 second
      if (rxValue == "FIND") {
        digitalWrite(LED_PIN, HIGH);   // Turn LED on
        delay(1000);                   // Keep it on for 1 second
        digitalWrite(LED_PIN, LOW);    // Turn LED off
      }

      if (rxValue == "CONNECT") {
        digitalWrite(LED_PIN, HIGH);
        delay(250);
        digitalWrite(LED_PIN, LOW);
        delay(250);
        digitalWrite(LED_PIN, HIGH);
        delay(250);
        digitalWrite(LED_PIN, LOW);
        delay(250);
        digitalWrite(LED_PIN, HIGH);
        delay(250);
        digitalWrite(LED_PIN, LOW);
      }
    }
  }
};

// Callback class to handle BLE connection/disconnection events
class MyServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) override {
    deviceConnected = true;  // Set flag to true when a device connects
  }

  void onDisconnect(BLEServer* pServer) override {
    deviceConnected = false;  // Set flag to false when device disconnects
    BLEDevice::startAdvertising();  // Restart advertising so another device can connect
    Serial.println("Disconnected. Restart advertising...");
  }
};

void setup() {
  Serial.begin(115200);  // Start serial output for debugging

  // Configure the LED pin as output
  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);  // Ensure LED is off initially

  // Initialize BLE device with a name
  BLEDevice::init("HaptiDrum_Foot_R");

  // Create BLE server and set its connection callbacks
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  // Create a BLE service with the defined UUID
  BLEService* pService = pServer->createService(SERVICE_UUID);

  // Create a characteristic within the service, supporting read/write/notify
  pCharacteristic = pService->createCharacteristic(
    CHARACTERISTIC_UUID,
    BLECharacteristic::PROPERTY_READ |
    BLECharacteristic::PROPERTY_WRITE |    // Enables receiving messages from iOS
    BLECharacteristic::PROPERTY_NOTIFY     // Enables sending notifications to iOS
  );

  // Assign our write callback to the characteristic
  pCharacteristic->setCallbacks(new MyCharacteristicCallbacks());

  // Add Client Characteristic Configuration Descriptor (CCCD) for notification
  pCharacteristic->addDescriptor(new BLE2902());

  // Start the service so it becomes visible to clients
  pService->start();

  // Start advertising to make the device discoverable
  BLEAdvertising* pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  BLEDevice::startAdvertising();

  Serial.println("BLE Server is up and running...");
}

void loop() {
  if (deviceConnected) {
    // If a device is connected, send a notification every second
    pCharacteristic->setValue((uint8_t*)&value, 4);  // Send current value as binary
    pCharacteristic->notify();  // Notify connected client
    value++;                    // Increment value
    delay(1000);                // Wait 1 second
  } else {
    delay(100);  // If not connected, just idle
  }
}
