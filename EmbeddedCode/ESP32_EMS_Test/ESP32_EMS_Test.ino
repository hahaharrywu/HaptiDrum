#include <Wire.h>

#define MCP4725_ADDR 0x60  // 默认地址：A0 接 GND 时为 0x60
#define VREF 3.3           // MCP4725 供电电压 = 最大输出电压

const int pinD0 = 1; //(D0=GPIO1=AGD1636 IN1)
const int pinD1 = 2; //(D0=GPIO1=AGD1636 IN2)
const int pinD7 = 7;

float frequency = 1.0;
float dutyCycle = 50.0;
float amplitude = 1.0;  // 0~3.3V
unsigned long ton_us = 500000;
unsigned long period_us = 1000000;
bool active = true;

void readParameters() {
  String input;

  Serial.println("Enter frequency in Hz (e.g., 10): ");
  while (true) {
    if (Serial.available()) {
      input = Serial.readStringUntil('\n');
      input.trim();
      if (input.equalsIgnoreCase("s")) continue;
      frequency = input.toFloat();
      break;
    }
  }

  Serial.println("Enter duty cycle in % (e.g., 20): ");
  while (true) {
    if (Serial.available()) {
      input = Serial.readStringUntil('\n');
      input.trim();
      if (input.equalsIgnoreCase("s")) continue;
      dutyCycle = input.toFloat();
      break;
    }
  }

  Serial.println("Enter pulse amplitude in V (0.0 - 3.3): ");
  while (true) {
    if (Serial.available()) {
      input = Serial.readStringUntil('\n');
      input.trim();
      if (input.equalsIgnoreCase("s")) continue;
      amplitude = input.toFloat();
      break;
    }
  }

  amplitude = constrain(amplitude, 0.0, VREF);
  period_us = (unsigned long)(1e6 / frequency);
  ton_us = (unsigned long)(period_us * (dutyCycle / 100.0));

  Serial.print("Calculated period: "); Serial.print(period_us); Serial.println(" us");
  Serial.print("TON: "); Serial.print(ton_us); Serial.println(" us");
  Serial.print("Amplitude: "); Serial.print(amplitude); Serial.println(" V");

  active = true;
}

void setup() {
  Serial.begin(115200);
  while (!Serial) {}

  Wire.begin(5, 6);  // SDA = GPIO5 (D4), SCL = GPIO6 (D5)

  pinMode(pinD0, OUTPUT);
  pinMode(pinD1, OUTPUT);
  pinMode(pinD7, OUTPUT);
  digitalWrite(pinD7, HIGH);  // 始终保持 GPIO7 为高电平
 // pinMode(7, OUTPUT);
  
  // 拉高 GPIO7（即输出高电平）
  //digitalWrite(7, HIGH);
  readParameters();
}

void loop() {
  if (Serial.available()) {
    String input = Serial.readStringUntil('\n');
    input.trim();
    if (input.equalsIgnoreCase("s")) {
      active = false;
      setVoltage(0);  // 停止 DAC 输出
      digitalWrite(pinD0, LOW);
      digitalWrite(pinD1, LOW);
      Serial.println("Pulse output stopped. Restarting input sequence...");
      readParameters();
      return;
    }
  }

  if (active) {
    uint16_t dacValue = (uint16_t)((amplitude / VREF) * 4095);

    // 高电平 - 前一半
    setVoltage(dacValue);
    digitalWrite(pinD0, HIGH);
    digitalWrite(pinD1, LOW);
    delayMicroseconds(ton_us / 2);

    // 高电平 - 后一半
    digitalWrite(pinD0, LOW);
    digitalWrite(pinD1, HIGH);
    delayMicroseconds(ton_us / 2);

    // 低电平
    setVoltage(0);
    digitalWrite(pinD0, LOW);
    digitalWrite(pinD1, LOW);
    delayMicroseconds(period_us - ton_us);
  }
}

void setVoltage(uint16_t val) {
  Wire.beginTransmission(MCP4725_ADDR);
  Wire.write(0x40);               // 快速写入模式
  Wire.write(val >> 4);           // 高8位
  Wire.write((val & 0xF) << 4);   // 低4位左移
  Wire.endTransmission();
}
