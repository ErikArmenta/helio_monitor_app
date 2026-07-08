// ESP32 Helium Recovery Sensor - EA Innovation
// Sends temperature and pressure via BLE to the Flutter app
// Board: ESP32 Dev Module

#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"

// Sensor pins (adjust to your wiring)
#define TEMP_SENSOR_PIN 34  // Analog input for temperature sensor
#define PRES_SENSOR_PIN 35  // Analog input for pressure transducer

BLEServer* pServer = NULL;
BLECharacteristic* pCharacteristic = NULL;
bool deviceConnected = false;

class MyServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) { deviceConnected = true; }
    void onDisconnect(BLEServer* pServer) { deviceConnected = false; }
};

void setup() {
  Serial.begin(115200);
  pinMode(TEMP_SENSOR_PIN, INPUT);
  pinMode(PRES_SENSOR_PIN, INPUT);

  BLEDevice::init("EA_Helium_Sensor");
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  BLEService *pService = pServer->createService(SERVICE_UUID);
  pCharacteristic = pService->createCharacteristic(
    CHARACTERISTIC_UUID,
    BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY
  );
  pCharacteristic->addDescriptor(new BLE2902());
  pService->start();

  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(false);
  pAdvertising->setMinPreferred(0x0);
  BLEDevice::startAdvertising();

  Serial.println("EA Helium Sensor ready - waiting for connection...");
}

void loop() {
  if (deviceConnected) {
    // Read sensors - replace with your actual sensor calibration
    float rawTemp = analogRead(TEMP_SENSOR_PIN);
    float rawPres = analogRead(PRES_SENSOR_PIN);

    // Example calibration (adjust for your sensors):
    // LM35: voltage = raw * 3.3 / 4095, temp_c = voltage * 100
    float tempC = (rawTemp * 3.3 / 4095.0) * 100.0;
    // Pressure transducer 0-500 PSI, 0.5-4.5V output
    float voltage = rawPres * 3.3 / 4095.0;
    float psi = ((voltage - 0.5) / 4.0) * 500.0;

    // Send as JSON via BLE
    char payload[64];
    snprintf(payload, sizeof(payload), "{\"temp\":%.2f,\"psi\":%.2f}", tempC, psi);

    pCharacteristic->setValue(payload);
    pCharacteristic->notify();

    Serial.println(payload);
  }

  delay(2000); // Send every 2 seconds
}
