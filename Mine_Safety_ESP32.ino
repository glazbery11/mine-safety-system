#include <WiFi.h>
#include <WebServer.h>
#include <DHT.h>
#include <Wire.h>
#include <LiquidCrystal_I2C.h>
#include <BLEDevice.h>
#include <BLEScan.h>
#include <BLEAdvertisedDevice.h>

// 1. НАСТРОЙКИ ТОЧКИ ДОСТУПА ESP32 И ID УСТРОЙСТВА
const char* AP_SSID  = "MineSafety_01"; // Имя Wi-Fi сети, которую создаст ESP32
const char* AP_PASS  = "12345678";      // Пароль (минимум 8 символов)
const char* MINER_ID = "Miner_01";

// 2. ПИНЫ ПОДКЛЮЧЕНИЯ (баззер пока отключён)
#define MQ135_PIN   34   // D34 -> AO датчика газа MQ-135
#define DHT_PIN     4    // D4  -> средний контакт DHT11
#define LED_PIN     2    // Встроенный синий светодиод на ESP32

#define DHTTYPE DHT11
DHT dht(DHT_PIN, DHTTYPE);
LiquidCrystal_I2C lcd(0x27, 16, 2);
WebServer server(80);
BLEScan* pBLEScan;

// 3. КРИТИЧЕСКИЕ ПОРОГИ ШАХТЫ И НАСТРОЙКИ ЗОН
const float TEMP_MAX          = 28.0;  // Предельная температура (°C)
const float HEAT_STRESS_TEMP  = 24.0;  // Порог T для теплового стресса (°C)
const float HEAT_STRESS_HUM   = 75.0;  // Порог H при повышенной температуре (%)
const float HUM_MAX           = 85.0;  // Критическая сырость (%)
const float HUM_MIN           = 15.0;  // Порог сухости (адаптирован под DHT11)

const unsigned long WARMUP_MS       = 40000; // 40 сек прогрев MQ-135
const int GAS_DELTA                 = 600;   // Скачок выше базы для тревоги
const int RSSI_THRESHOLD            = -80;   // Порог сигнала маяка (~1-1.5 м)
const unsigned long ZONE_TIMEOUT_MS = 6000;  // Сброс в Z:0 через 6 сек после ухода от маяка

int gasThreshold   = 2200;
bool gasCalibrated = false;

int currentGas     = 0;
float currentTemp  = 23.0;
float currentHum   = 45.0;
int currentZone    = 0;
bool dhtError      = false;
bool currentDanger = false;

// Переменные для Safe_Zone (таймер отдыха и статус эвакуации)
bool isEvacuated             = false;
unsigned long safeZoneEnterTime = 0;
unsigned long restSeconds       = 0;

unsigned long lastDhtTime      = 0;
unsigned long lastBleTime      = 0;
unsigned long lastLcdTime      = 0;
unsigned long lastZoneSeenTime = 0;

void setup() {
  Serial.begin(115200);

  pinMode(MQ135_PIN, INPUT);
  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);

  dht.begin();
  Wire.begin(21, 22);
  lcd.init();
  lcd.backlight();

  // Запуск собственной точки доступа Wi-Fi
  WiFi.mode(WIFI_AP);
  WiFi.softAP(AP_SSID, AP_PASS);
  WiFi.setTxPower(WIFI_POWER_19_5dBm);

  String ipStr = WiFi.softAPIP().toString(); // Всегда 192.168.4.1

  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("AP:");
  lcd.print(AP_SSID);
  lcd.setCursor(0, 1);
  lcd.print("IP:");
  lcd.print(ipStr);

  Serial.println("\n=== Miner_01 SoftAP + BLE Online ===");
  Serial.println("JSON URL: http://" + ipStr + "/data");

  // Инициализация BLE-сканера для поиска маяков зон
  BLEDevice::init(MINER_ID);
  pBLEScan = BLEDevice::getScan();
  pBLEScan->setActiveScan(true);
  pBLEScan->setInterval(100);
  pBLEScan->setWindow(99);

  // Запуск локального HTTP-сервера
  server.on("/", HTTP_GET, handleRoot);
  server.on("/data", HTTP_GET, handleData);
  server.on("/data", HTTP_OPTIONS, handleCorsPreflight);
  server.begin();

  delay(4000);
  lcd.clear();
}

void loop() {
  server.handleClient();
  unsigned long now = millis();

  // 1. Газ и автокалибровка после 40 сек прогрева
  currentGas = analogRead(MQ135_PIN);
  bool isWarmingUp = (now < WARMUP_MS);

  if (!isWarmingUp && !gasCalibrated) {
    gasThreshold = currentGas + GAS_DELTA;
    if (gasThreshold > 3700) gasThreshold = 3700;
    gasCalibrated = true;
    Serial.println("MQ-135 calibrated. Base: " + String(currentGas) + " | Limit: " + String(gasThreshold));
  }

  // 2. Температура и влажность раз в 1.5 сек
  if (now - lastDhtTime >= 1500) {
    lastDhtTime = now;
    float t = dht.readTemperature();
    float h = dht.readHumidity();
    if (isnan(t) || isnan(h)) {
      dhtError = true;
    } else {
      dhtError    = false;
      currentTemp = t;
      currentHum  = h;
    }
  }

  // 3. Поиск BLE-маяков зон раз в 3 сек
  if (now - lastBleTime >= 3000) {
    lastBleTime = now;
    scanBeacons();
  }

  // Логика Safe_Zone: перекличка (эвакуация) и таймер отдыха
  if (currentZone == 3) {
    if (!isEvacuated) {
      isEvacuated = true;
      safeZoneEnterTime = now;
      Serial.println("Roll Call: Miner_01 entered SAFE ZONE (Evacuated).");
    }
    restSeconds = (now - safeZoneEnterTime) / 1000;
  } else {
    if (isEvacuated) {
      Serial.println("Miner_01 left SAFE ZONE. Rest duration: " + String(restSeconds) + "s");
    }
    isEvacuated = false;
    restSeconds = 0;
  }

  // 4. Проверка угроз и световая индикация на плате
  bool dangerGas       = (!isWarmingUp) && (currentGas >= gasThreshold);
  bool dangerTemp      = !dhtError && (currentTemp >= TEMP_MAX);
  bool dangerHeatCombo = !dhtError && (currentTemp >= HEAT_STRESS_TEMP) && (currentHum >= HEAT_STRESS_HUM);
  bool dangerHumHigh   = !dhtError && (currentHum >= HUM_MAX);
  bool dangerHumLow    = !dhtError && (currentHum <= HUM_MIN);

  // В Safe_Zone (зона 3) все тревоги отключены
  if (currentZone == 3) {
    currentDanger = false;
  } else {
    currentDanger = dangerGas || dangerTemp || dangerHeatCombo || dangerHumHigh || dangerHumLow;
  }

  if (currentDanger) {
    bool pulse = ((now / 250) % 2 == 0);
    digitalWrite(LED_PIN, pulse ? HIGH : LOW);
  } else {
    digitalWrite(LED_PIN, LOW);
  }

  // 5. Обновление LCD каждые 250 мс
  if (now - lastLcdTime >= 250) {
    lastLcdTime = now;

    // Особый экран для Safe_Zone (убираем показатели шахты, показываем таймер отдыха)
    if (currentZone == 3) {
      lcd.setCursor(0, 0);
      lcd.print("   SAFE ZONE    "); // Ровно 16 символов

      unsigned long mins = restSeconds / 60;
      unsigned long secs = restSeconds % 60;
      char line2[17];
      snprintf(line2, sizeof(line2), "  REST: %02lu:%02lu   ", mins, secs);
      lcd.setCursor(0, 1);
      lcd.print(line2);
      return;
    }

    // Стандартный экран для зон 0, 1, 2
    char line1[17];
    snprintf(line1, sizeof(line1), "G:%-4d T:%2dC Z:%d", currentGas, (int)currentTemp, currentZone);
    lcd.setCursor(0, 0);
    lcd.print(line1);

    const char* activeAlerts[6];
    int alertCount = 0;

    if (dangerGas)       activeAlerts[alertCount++] = "ALERT: HIGH GAS!";
    if (dangerTemp)      activeAlerts[alertCount++] = "ALERT: TEMP>=28C";
    if (dangerHeatCombo) activeAlerts[alertCount++] = "ALERT: HEAT+HUM!";
    if (dangerHumHigh)   activeAlerts[alertCount++] = "ALERT: HIGH HUM!";
    if (dangerHumLow)    activeAlerts[alertCount++] = "ALERT: DRY AIR! ";
    if (dhtError)        activeAlerts[alertCount++] = "WARN: DHT ERROR ";

    lcd.setCursor(0, 1);
    if (alertCount > 0) {
      int alertIndex = (now / 1000) % alertCount;
      lcd.print(activeAlerts[alertIndex]);
    } else if (isWarmingUp) {
      int secLeft = (WARMUP_MS - now) / 1000 + 1;
      char line2[17];
      snprintf(line2, sizeof(line2), "WARMUP:%2ds H:%2d%%", secLeft, (int)currentHum);
      lcd.print(line2);
    } else {
      char line2[17];
      snprintf(line2, sizeof(line2), "STATUS:OK  H:%2d%%", (int)currentHum);
      lcd.print(line2);
    }
  }
}

void scanBeacons() {
  BLEScanResults* foundDevices = pBLEScan->start(1, false);
  int bestRssi = -100;
  int detectedZone = 0;

  for (int i = 0; i < foundDevices->getCount(); i++) {
    BLEAdvertisedDevice device = foundDevices->getDevice(i);
    String devName = String(device.getName().c_str());
    int rssi = device.getRSSI();

    if (rssi > RSSI_THRESHOLD && rssi > bestRssi) {
      if (devName == "MINE_ZONE_1") {
        detectedZone = 1;
        bestRssi = rssi;
      } else if (devName == "MINE_ZONE_2") {
        detectedZone = 2;
        bestRssi = rssi;
      } else if (devName == "Safe_Zone") {
        detectedZone = 3;
        bestRssi = rssi;
      }
    }
  }
  pBLEScan->clearResults();

  if (detectedZone > 0) {
    currentZone = detectedZone;
    lastZoneSeenTime = millis();
  } else if (currentZone != 0 && (millis() - lastZoneSeenTime > ZONE_TIMEOUT_MS)) {
    currentZone = 0;
  }
}

void sendCorsHeaders() {
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.sendHeader("Access-Control-Allow-Methods", "GET, OPTIONS");
  server.sendHeader("Access-Control-Allow-Headers", "Content-Type");
}

void handleCorsPreflight() {
  sendCorsHeaders();
  server.send(204);
}

void handleData() {
  sendCorsHeaders();
  String json = "{";
  json += "\"id\":\"" + String(MINER_ID) + "\",";
  json += "\"zone\":" + String(currentZone) + ",";
  json += "\"evacuated\":" + String(isEvacuated ? "true" : "false") + ",";
  json += "\"rest_sec\":" + String(restSeconds) + ",";
  json += "\"gas\":" + String(currentGas) + ",";
  json += "\"temp\":" + String(currentTemp, 1) + ",";
  json += "\"hum\":" + String(currentHum, 1) + ",";
  json += "\"danger\":" + String(currentDanger ? "true" : "false");
  json += "}";
  server.send(200, "application/json", json);
}

void handleRoot() {
  sendCorsHeaders();
  server.send(200, "text/plain", "ESP32 Mine Safety Unit Online. JSON: /data");
}
