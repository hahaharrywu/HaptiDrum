#include <Wire.h>
#include <Adafruit_DRV2605.h>

Adafruit_DRV2605 drv;

void setup() {
  Serial.begin(9600);
  delay(1000);
  Serial.println("DRV2605L + VL120628H Continuous Test");

  if (!drv.begin()) {
    Serial.println("Failed to initialize DRV2605");
    while (1);
  }

  // === 设置为 Real-Time Playback Mode ===
  drv.setMode(5);  // 0x05 = Real-Time Playback

  // === 设置为 LRA 模式（VL120628H 是 LRA）===
  drv.useLRA();    // 会设置寄存器 0x1A 第7位为1

  // === 设置震动强度（范围 0~127）===
  drv.setRealtimeValue(127);  // 实时播放强度，值越大震动越强（推荐60~100之间）

  Serial.println("Now vibrating continuously...");
}

void loop() {
  // 保持运行，实时播放持续输出震动
  delay(100);
}
