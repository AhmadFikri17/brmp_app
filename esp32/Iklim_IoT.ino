/***************************************
* WEATHER STATION - ESP32 FINAL
* 
* Sistem: 
* - Kirim data hourly DI JAM PENUH (09:00, 10:00, 11:00, dst)
* - HANYA kirim pada jam 06:00 - 18:00 WIB (13 data/hari)
* - Jika ESP32 nyala jam 08:30 → kirim pertama jam 09:00
* - Di luar jam operasional, buffer di-reset otomatis
* 
* Sensor:
* 1. Anemometer PRO
* 2. Wind Direction 16 Arah
* 3. Rain Gauge Tipping Bucket
* 4. RTC DS3231
* 5. DHT11
* 6. Intensitas Cahaya (LDR)
* 
* Output: LCD 20x4 I2C + Serial Monitor + MQTT + Google Sheets
****************************************/

#include <Wire.h>
#include <LiquidCrystal_I2C.h>
#include <AS5600.h>
#include <RTClib.h>
#include <string.h>
#include <DHT.h>
#include <WiFi.h>
#include <WiFiClient.h>
#include <WiFiManager.h> 
#include <WiFiClientSecure.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>
#include <Preferences.h>
#include <HTTPClient.h>
#include <esp_task_wdt.h>  

// ===== PIN DEFINISI =====
#define ANEMOMETER_PIN 27
#define RAIN_PIN 13
#define DHT_PIN 4
#define DHT_TYPE DHT11
#define LDR_PIN 34
#define LED_BUILTIN 2

// ===== WATCHDOG TIMER CONFIG =====
#define WDT_TIMEOUT 20

// ===== PREFERENCES CONFIG =====
#define PREF_NAMESPACE "weather"
#define PREF_RAIN_KEY "dailyRain"
#define PREF_DATE_KEY "rainDate"

// ===== RAIN GAUGE INTERRUPT CONFIG =====
#define RAIN_DEBOUNCE_MS 50

// ===== JAM OPERASIONAL =====
#define JAM_MULAI  6   // 06:00 WIB
#define JAM_AKHIR  18  // 18:00 WIB

// ===== KONFIGURASI KIRIM DI JAM PENUH =====
// Kirim saat menit 0, detik 0-5
#define MENIT_KIRIM   0    // menit 0
#define DETIK_MAX_KIRIM 5  // detik 0-5

// ================= KONFIGURASI HIVEMQ =================
const char* mqtt_server = "335c4f56e51e42f4a5a82c5a477c3e96.s1.eu.hivemq.cloud";
const int mqtt_port = 8883;
const char* mqtt_user = "esp32sensoriklim";
const char* mqtt_pass = "12345678aBz";

// ================= MQTT TOPICS =================
const char* topic_weather = "weatherstation/sensors";
const char* topic_status = "weatherstation/status";

// ================= GOOGLE SHEETS CONFIG =================
const char* googleScriptURL = "https://script.google.com/macros/s/AKfycbzbkE_FgihGklCqDai5vBJo7FT2KORegpPxd_0zjb-664WJUpE1pAeQN2KqdAtw17v9/exec";

// ===== LCD 20x4 I2C ===== 
LiquidCrystal_I2C lcd(0x27, 20, 4);

// ===== AS5600 Wind Direction =====
AMS_5600 ams5600;

// ===== RTC DS3231 =====
RTC_DS3231 rtc;

// ===== DHT11 =====
DHT dht(DHT_PIN, DHT_TYPE);

// ===== MQTT =====
WiFiClientSecure espClient;
PubSubClient client(espClient);

// ==============================================
//         BAGIAN ANEMOMETER 
// ==============================================

const float radius = 0.09;
const float diameter = radius * 2.0;
const float circumference = 2.0 * 3.1416 * radius;
float K = 1.6;

volatile unsigned long pulseCount = 0;
unsigned long lastTime = 0;

#define FILTER_SIZE_ANEMO 10
float velocityBuffer[FILTER_SIZE_ANEMO];
uint8_t anemometerBufferIndex = 0;
bool anemometerBufferFull = false;

void IRAM_ATTR sensorISR() {
  pulseCount++;
}

float movingAverageAnemo(float newValue) {
  velocityBuffer[anemometerBufferIndex] = newValue;
  anemometerBufferIndex++;

  if (anemometerBufferIndex >= FILTER_SIZE_ANEMO) {
    anemometerBufferIndex = 0;
    anemometerBufferFull = true;
  }

  float sum = 0;
  uint8_t count = anemometerBufferFull ? FILTER_SIZE_ANEMO : anemometerBufferIndex;
  for (uint8_t i = 0; i < count; i++) sum += velocityBuffer[i];

  return sum / count;
}

void resetMovingAverageAnemo() {
  for (uint8_t i = 0; i < FILTER_SIZE_ANEMO; i++) velocityBuffer[i] = 0;
  anemometerBufferIndex = 0;
  anemometerBufferFull = false;
}

// ==============================================
//       BAGIAN WIND DIRECTION 
// ==============================================

#define FILTER_SIZE_DIR 10
float angleBuffer[FILTER_SIZE_DIR];
uint8_t dirBufferIndex = 0;
bool dirBufferFull = false;

float angle_in = -1;
float offsetUtara = 0.0;

float movingAverageDir(float value) {
  angleBuffer[dirBufferIndex] = value;
  dirBufferIndex++;

  if (dirBufferIndex >= FILTER_SIZE_DIR) {
    dirBufferIndex = 0;
    dirBufferFull = true;
  }

  float sum = 0;
  uint8_t count = dirBufferFull ? FILTER_SIZE_DIR : dirBufferIndex;
  for (uint8_t i = 0; i < count; i++) {
    sum += angleBuffer[i];
  }

  return sum / count;
}

void arahMataAngin16(float deg, char *arah) {
  deg += 11.25;
  if (deg >= 360) deg -= 360;

  if (deg < 22.5)        strcpy(arah, "U/N");
  else if (deg < 45)     strcpy(arah, "UTL/NNE");
  else if (deg < 67.5)   strcpy(arah, "TL/NE");
  else if (deg < 90)     strcpy(arah, "TTL/ENE");
  else if (deg < 112.5)  strcpy(arah, "T/E");
  else if (deg < 135)    strcpy(arah, "TTG/ESE");
  else if (deg < 157.5)  strcpy(arah, "TG/SE");
  else if (deg < 180)    strcpy(arah, "STG/SSE");
  else if (deg < 202.5)  strcpy(arah, "S/S");
  else if (deg < 225)    strcpy(arah, "SBD/SSW");
  else if (deg < 247.5)  strcpy(arah, "BD/SW");
  else if (deg < 270)    strcpy(arah, "BBD/WSW");
  else if (deg < 292.5)  strcpy(arah, "B/W");
  else if (deg < 315)    strcpy(arah, "BBL/WNW");
  else if (deg < 337.5)  strcpy(arah, "BL/NW");
  else                   strcpy(arah, "UBL/NNW");
}

float readAngle() {
  uint16_t raw = ams5600.getRawAngle();
  float angle = (raw * 360.0) / 4096.0;

  angle += offsetUtara;
  if (angle >= 360) angle -= 360;
  if (angle < 0) angle += 360;

  return angle;
}

float normalizeAngle(float angle) {
  while (angle >= 360.0) angle -= 360.0;
  while (angle < 0.0)    angle += 360.0;
  return angle;
}

// ==============================================
//        BAGIAN RAIN GAUGE 
// ==============================================

const double bucketAmount = 0.7;
double dailyRain = 0.0;

volatile unsigned long rainBucketCounter = 0;
volatile unsigned long lastRainInterruptTime = 0;

Preferences preferences;
String currentDate = "";

void IRAM_ATTR rainISR() {
  unsigned long currentTime = millis();
  if (currentTime - lastRainInterruptTime > RAIN_DEBOUNCE_MS) {
    rainBucketCounter++;
    lastRainInterruptTime = currentTime;
  }
}

// ==============================================
//        PREFERENCES RAIN DAILY
// ==============================================

void saveRainDaily(float rainValue) {
  static float lastSavedRain = -1.0;
  static unsigned long lastSaveTime = 0;
  
  if (rainValue != lastSavedRain) {
    if (millis() - lastSaveTime > 5000) {
      preferences.putFloat(PREF_RAIN_KEY, rainValue);
      lastSavedRain = rainValue;
      lastSaveTime = millis();
    }
  }
}

void checkDayChange() {
  DateTime now = rtc.now();
  String todayDate = String(now.year()) + "-" + 
                     String(now.month()) + "-" + 
                     String(now.day());
  
  if (currentDate == "") {
    currentDate = todayDate;
    return;
  }
  
  if (currentDate != todayDate) {
    dailyRain = 0.0;
    preferences.putString(PREF_DATE_KEY, todayDate);
    preferences.putFloat(PREF_RAIN_KEY, 0.0);
    Serial.println("🌅 New day detected! Rain daily reset to 0");
    currentDate = todayDate;
  }
}

// ==============================================
//        BAGIAN SENSOR INTENSITAS CAHAYA
// ==============================================

const float LDR_REFERENCE_RESISTOR = 10000.0;
const float LDR_SUPPLY_VOLTAGE = 3.3;

#define FILTER_SIZE_LDR 10
float luxBuffer[FILTER_SIZE_LDR];
uint8_t ldrBufferIndex = 0;
bool ldrBufferFull = false;

float movingAverageLDR(float newValue) {
  luxBuffer[ldrBufferIndex] = newValue;
  ldrBufferIndex++;

  if (ldrBufferIndex >= FILTER_SIZE_LDR) {
    ldrBufferIndex = 0;
    ldrBufferFull = true;
  }

  float sum = 0;
  uint8_t count = ldrBufferFull ? FILTER_SIZE_LDR : ldrBufferIndex;
  for (uint8_t i = 0; i < count; i++) {
    sum += luxBuffer[i];
  }

  return sum / count;
}

float readLux() {
  int adcValue = analogRead(LDR_PIN);
  float voltage = adcValue * (LDR_SUPPLY_VOLTAGE / 4095.0);
  float resistance = LDR_REFERENCE_RESISTOR * ((LDR_SUPPLY_VOLTAGE / voltage) - 1);
  
  if (resistance < 100) resistance = 100;
  if (resistance > 1000000) resistance = 1000000;
  
  float _rawLux = 500.0 / (resistance / 1000.0);
  float rawLux = (float)map((int)_rawLux, 0, 5000, 0, 10000);
  
  if (rawLux < 0) rawLux = 0;
  if (rawLux > 10000) rawLux = 10000;
  
  return movingAverageLDR(rawLux);
}

// ==============================================
//        FUNGSI ROUND TO DECIMALS
// ==============================================

float roundTo(float value, int decimals) {
  float multiplier = pow(10.0, decimals);
  long rounded = (long)(value * multiplier + 0.5);
  return (float)rounded / multiplier;
}

// ==============================================
//        FUNGSI CEK JAM OPERASIONAL
// ==============================================

bool isOperatingHour() {
  DateTime now = rtc.now();
  int hour = now.hour();
  
  // Jam operasional: 06:00 - 18:00 WIB
  return (hour >= JAM_MULAI && hour <= JAM_AKHIR);
}

// ==============================================
//        FUNGSI CEK JAM PENUH
// ==============================================

// Cek apakah sekarang tepat jam penuh (menit 0, detik 0-5)
bool isTopOfHour() {
  DateTime now = rtc.now();
  return (now.minute() == MENIT_KIRIM && now.second() <= DETIK_MAX_KIRIM);
}

// ==============================================
//        BAGIAN HOURLY BUFFER
// ==============================================

struct HourlyBuffer {
  double tempSum = 0;
  double humSum = 0;
  double windSum = 0;
  double windKnotSum = 0;
  double angleSum = 0;
  double rainLatest = 0;
  double luxSum = 0;
  int count = 0;
};

HourlyBuffer hourlyBuffer;

// Track jam terakhir yang sudah dikirim (untuk hindari duplikat)
int lastSentHour = -1;

bool hourlySendPending = false;

// ==============================================
//        FUNGSI HOURLY
// ==============================================

void addToHourlyBuffer(float temp, float hum, float wind, float windKnot,
                       float angle, float rain, float lux) {
  hourlyBuffer.tempSum += temp;
  hourlyBuffer.humSum += hum;
  hourlyBuffer.windSum += wind;
  hourlyBuffer.windKnotSum += windKnot;
  hourlyBuffer.angleSum += angle;
  hourlyBuffer.rainLatest = rain;
  hourlyBuffer.luxSum += lux;
  hourlyBuffer.count++;
}

void resetHourlyBuffer() {
  hourlyBuffer.tempSum = 0;
  hourlyBuffer.humSum = 0;
  hourlyBuffer.windSum = 0;
  hourlyBuffer.windKnotSum = 0;
  hourlyBuffer.angleSum = 0;
  hourlyBuffer.rainLatest = 0;
  hourlyBuffer.luxSum = 0;
  hourlyBuffer.count = 0;
}

String filterResponse(String response) {
  if (response.indexOf("Moved Temporarily") > 0 || 
      response.indexOf("<HTML>") > 0 ||
      response.indexOf("<html>") > 0) {
    return "[Redirect response hidden]";
  }
  if (response.length() > 500 && response.indexOf("<") >= 0) {
    return "[Response too long, hidden]";
  }
  return response;
}

// ==============================================
//        FUNGSI KIRIM HOURLY REPORT
// ==============================================

void sendHourlyReport() {
  // ===== CEK JAM OPERASIONAL =====
  if (!isOperatingHour()) {
    DateTime now = rtc.now();
    Serial.print("🌙 Di luar jam operasional (");
    if (now.hour() < 10) Serial.print("0");
    Serial.print(now.hour());
    Serial.println(":xx). Skip kirim.");
    
    resetHourlyBuffer();
    hourlySendPending = false;
    return;
  }
  
  if (hourlyBuffer.count == 0) {
    Serial.println("⚠️ Hourly buffer kosong, skip");
    return;
  }

  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("⚠️ WiFi tidak terhubung, skip hourly report");
    hourlySendPending = true;
    return;
  }

  // Hitung rata-rata
  float avgTemp      = hourlyBuffer.tempSum / hourlyBuffer.count;
  float avgHum       = hourlyBuffer.humSum / hourlyBuffer.count;
  float avgWind      = hourlyBuffer.windSum / hourlyBuffer.count;
  float avgWindKnot  = hourlyBuffer.windKnotSum / hourlyBuffer.count;
  float avgAngle     = hourlyBuffer.angleSum / hourlyBuffer.count;
  float avgLux       = hourlyBuffer.luxSum / hourlyBuffer.count;
  float rainDaily    = hourlyBuffer.rainLatest;

  // Timestamp jam penuh (WIB)
  DateTime now = rtc.now();
  char timestampStr[20];
  sprintf(timestampStr, "%04d-%02d-%02d %02d:00:00",
          now.year(), now.month(), now.day(), now.hour());

  Serial.println("========================================");
  Serial.println("📊 HOURLY REPORT");
  Serial.println("----------------------------------------");
  Serial.print("⏰ Timestamp: ");
  Serial.println(timestampStr);
  Serial.print("📊 Samples: ");
  Serial.println(hourlyBuffer.count);
  Serial.print("📊 Avg Temp: ");
  Serial.println(avgTemp, 2);
  Serial.print("📊 Avg Hum: ");
  Serial.println(avgHum, 2);
  Serial.print("📊 Avg Wind: ");
  Serial.println(avgWind, 2);
  Serial.print("📊 Avg Lux: ");
  Serial.println(avgLux, 2);
  Serial.print("📊 Rain Daily: ");
  Serial.println(rainDaily, 2);
  Serial.println("========================================");

  // Build JSON
  DynamicJsonDocument doc(1024);
  doc["type"] = "hourly";
  doc["count"] = 1;

  JsonArray dataArray = doc.createNestedArray("data");
  JsonObject obj = dataArray.createNestedObject();
  
  obj["timestamp"]       = timestampStr;
  obj["temperature"]     = roundTo(avgTemp, 2);
  obj["humidity"]        = roundTo(avgHum, 2);
  obj["wind_speed_ms"]   = roundTo(avgWind, 2);
  obj["wind_speed_knot"] = roundTo(avgWindKnot, 2);
  obj["wind_angle"]      = roundTo(avgAngle, 1);
  obj["wind_direction"]  = "--";
  obj["rain_daily_mm"]   = roundTo(rainDaily, 2);
  obj["lux"]             = roundTo(avgLux, 2);

  String jsonString;
  serializeJson(doc, jsonString);

  Serial.print("📏 JSON Size: ");
  Serial.print(jsonString.length());
  Serial.println(" bytes");

  // HTTP POST
  HTTPClient http;
  http.begin(googleScriptURL);
  http.addHeader("Content-Type", "application/json");
  http.setTimeout(10000);

  esp_task_wdt_reset();
  int httpResponseCode = http.POST(jsonString);
  esp_task_wdt_reset();

  if (httpResponseCode > 0) {
    String response = http.getString();
    Serial.print("✅ Hourly Report Success: ");
    Serial.println(filterResponse(response));

    resetHourlyBuffer();
    hourlySendPending = false;
  } else {
    Serial.print("❌ Hourly Report Failed: ");
    Serial.println(httpResponseCode);
    hourlySendPending = true;
  }

  http.end();
  Serial.println("========================================\n");
}

// ==============================================
//        RTC SETTING VIA SERIAL
// ==============================================

void handleSerialCommands() {
  if (Serial.available()) {
    String command = Serial.readStringUntil('\n');
    command.trim();
    
    if (command.startsWith("settime ")) {
      String datetimeStr = command.substring(8);
      datetimeStr.trim();
      
      int spaceIdx = datetimeStr.indexOf(' ');
      
      if (spaceIdx > 0) {
        String datePart = datetimeStr.substring(0, spaceIdx);
        String timePart = datetimeStr.substring(spaceIdx + 1);
        
        int dash1 = datePart.indexOf('-');
        int dash2 = datePart.indexOf('-', dash1 + 1);
        
        int colon1 = timePart.indexOf(':');
        int colon2 = timePart.indexOf(':', colon1 + 1);
        
        if (dash1 > 0 && dash2 > 0 && colon1 > 0 && colon2 > 0) {
          int year = datePart.substring(0, dash1).toInt();
          int month = datePart.substring(dash1 + 1, dash2).toInt();
          int day = datePart.substring(dash2 + 1).toInt();
          int hour = timePart.substring(0, colon1).toInt();
          int minute = timePart.substring(colon1 + 1, colon2).toInt();
          int second = timePart.substring(colon2 + 1).toInt();
          
          if (year >= 2000 && year <= 2100 &&
              month >= 1 && month <= 12 &&
              day >= 1 && day <= 31 &&
              hour >= 0 && hour <= 23 &&
              minute >= 0 && minute <= 59 &&
              second >= 0 && second <= 59) {
            
            rtc.adjust(DateTime(year, month, day, hour, minute, second));
            Serial.println("=== RTC Time Updated! ===");
            currentDate = String(rtc.now().year()) + "-" + 
                          String(rtc.now().month()) + "-" + 
                          String(rtc.now().day());
          } else {
            Serial.println("ERROR: Nilai tidak valid!");
          }
        } else {
          Serial.println("ERROR: Format salah!");
        }
      } else {
        Serial.println("ERROR: Gunakan spasi antara tanggal dan waktu.");
      }
    }
    else if (command == "rtc") {
      DateTime now = rtc.now();
      Serial.print("RTC Time: ");
      Serial.print(now.year()); Serial.print("-");
      Serial.print(now.month()); Serial.print("-");
      Serial.print(now.day()); Serial.print(" ");
      Serial.print(now.hour()); Serial.print(":");
      Serial.print(now.minute()); Serial.print(":");
      Serial.println(now.second());
      
      Serial.print("Jam operasional: ");
      Serial.print(isOperatingHour() ? "✅ AKTIF" : "🌙 TIDAK AKTIF");
      Serial.println(" (06:00 - 18:00 WIB)");
      
      Serial.print("Jam penuh: ");
      Serial.println(isTopOfHour() ? "✅ YA" : "❌ TIDAK");
      
      Serial.print("Last sent hour: ");
      Serial.println(lastSentHour);
    }
    else if (command == "hourly") {
      Serial.println("📊 Force hourly report...");
      if (isOperatingHour()) {
        sendHourlyReport();
      } else {
        Serial.print("⚠️ Di luar jam operasional (");
        Serial.print(rtc.now().hour());
        Serial.println(":xx). Skip.");
      }
    }
    else if (command == "buffer") {
      Serial.print("Hourly Count: ");
      Serial.print(hourlyBuffer.count);
      Serial.print(" | Pending: ");
      Serial.print(hourlySendPending ? "YES" : "NO");
      Serial.print(" | Jam OK: ");
      Serial.print(isOperatingHour() ? "YES" : "NO");
      Serial.print(" | Last Sent Hour: ");
      Serial.println(lastSentHour);
    }
    else if (command == "reset") {
      resetHourlyBuffer();
      hourlySendPending = false;
      lastSentHour = -1;
      Serial.println("Hourly buffer reset!");
    }
    else if (command == "HELP" || command == "help") {
      Serial.println("===== SERIAL COMMANDS =====");
      Serial.println("settime YYYY-MM-DD HH:MM:SS - Set RTC");
      Serial.println("rtc - Read RTC time + status");
      Serial.println("hourly - Force send hourly report");
      Serial.println("buffer - Check hourly buffer");
      Serial.println("reset - Reset hourly buffer");
      Serial.println("help - Show this help");
      Serial.println("===========================");
    }
  }
}

// ==============================================
//        BAGIAN MQTT
// ==============================================

void publishWeatherData(float temp, float hum, float wind, float windKnot, 
                        float angle, char* direction, float rain, float lux) {
  
  StaticJsonDocument<192> doc;
  
  DateTime now = rtc.now();
  char timestampStr[20];
  sprintf(timestampStr, "%04d-%02d-%02d %02d:%02d:%02d",
          now.year(), now.month(), now.day(),
          now.hour(), now.minute(), now.second());
  doc["ts"] = timestampStr;
  
  doc["tmp"] = roundTo(temp, 1);
  doc["hum"] = roundTo(hum, 0);
  doc["wnd"] = roundTo(wind, 1);
  doc["knt"] = roundTo(windKnot, 1);
  doc["ang"] = angle >= 0 ? roundTo(angle, 0) : 0;
  doc["dir"] = direction;
  doc["rn"] = roundTo(rain, 1);
  doc["lx"] = (int)round(lux);
  
  char buffer[192];
  serializeJson(doc, buffer);
  
  if (!client.connected()) {
    connectMQTT();
    delay(100);
    if (!client.connected()) return;
  }
  
  bool success = client.publish(topic_weather, buffer);
  
  if (!success) {
    client.disconnect();
    delay(100);
    connectMQTT();
  }
}

void publishStatus() {
  StaticJsonDocument<128> doc;
  doc["status"] = "online";
  doc["uptime"] = millis() / 1000;
  doc["rssi"] = WiFi.RSSI();
  doc["hourly_count"] = hourlyBuffer.count;
  
  char buffer[128];
  serializeJson(doc, buffer);
  client.publish(topic_status, buffer);
}

void connectMQTT() {
  while (!client.connected()) {
    Serial.print("Connecting to HiveMQ...");
    
    String clientId = "esp32_weather" + String(WiFi.macAddress());
    
    if (client.connect(clientId.c_str(), mqtt_user, mqtt_pass)) {
      Serial.println("Connected!");
    } else {
      Serial.print("Failed, rc=");
      Serial.print(client.state());
      Serial.println(" retrying...");
      delay(5000);
    }
  }
}

// ==============================================
//        LED BLINK
// ==============================================

unsigned long previousLedMillis = 0;
const long ledInterval = 1000;
bool ledState = LOW;

void updateLED() {
  unsigned long currentMillis = millis();
  
  if (currentMillis - previousLedMillis >= ledInterval) {
    previousLedMillis = currentMillis;
    ledState = !ledState;
    digitalWrite(LED_BUILTIN, ledState);
  }
}

// ==========================================
//                SETUP
// ==========================================

void setup() {
  Serial.begin(115200);

  preferences.begin(PREF_NAMESPACE, false);

  pinMode(LED_BUILTIN, OUTPUT);
  digitalWrite(LED_BUILTIN, LOW);

  pinMode(ANEMOMETER_PIN, INPUT_PULLUP);
  attachInterrupt(digitalPinToInterrupt(ANEMOMETER_PIN), sensorISR, FALLING);

  Wire.begin(21, 22);
  Wire.setClock(50000);

  pinMode(RAIN_PIN, INPUT_PULLUP);
  attachInterrupt(digitalPinToInterrupt(RAIN_PIN), rainISR, FALLING);

  bool rtcOK = rtc.begin();
  if (!rtcOK) {
    Serial.println("⚠ RTC DS3231 tidak ditemukan!");
  }
  
  if (rtcOK && rtc.lostPower()) {
    Serial.println("RTC lost power, set time!");
    rtc.adjust(DateTime(F(__DATE__), F(__TIME__)));
  }

  String savedDate = preferences.getString(PREF_DATE_KEY, "");
  float savedRain = preferences.getFloat(PREF_RAIN_KEY, 0.0);
  
  DateTime now = rtc.now();
  String todayDate = String(now.year()) + "-" + 
                     String(now.month()) + "-" + 
                     String(now.day());
  
  currentDate = todayDate;
  
  if (savedDate == todayDate && savedRain > 0) {
    dailyRain = savedRain;
    Serial.print("✅ Restored dailyRain: ");
    Serial.println(dailyRain, 2);
  } else {
    dailyRain = 0.0;
    preferences.putString(PREF_DATE_KEY, todayDate);
    preferences.putFloat(PREF_RAIN_KEY, 0.0);
    Serial.println("🔄 New day, dailyRain reset to 0");
  }

  dht.begin();

  pinMode(LDR_PIN, INPUT);
  
  for (uint8_t i = 0; i < FILTER_SIZE_LDR; i++) {
    luxBuffer[i] = 0;
  }
  ldrBufferIndex = 0;
  ldrBufferFull = false;

  lcd.begin();
  lcd.backlight();
  
  lcd.setCursor(0, 0);
  lcd.print("    SENSOR IKLIM    ");
  lcd.setCursor(0, 1);
  lcd.print("  IoT + MQTT READY  ");
  lcd.setCursor(0, 2);
  lcd.print("   INITIALIZING...  ");
  lcd.setCursor(0, 3);
  lcd.print("   PLEASE WAIT...   ");

  Serial.println("==============================================");
  Serial.println("             SENSOR IKLIM                     ");
  Serial.println("  Hourly Report @ Jam Penuh (06:00-18:00)     ");
  Serial.println("==============================================");
  
  delay(2000);
  
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("  CONNECTING WIFI   ");
  lcd.setCursor(0, 1);
  lcd.print("  SSID: Iklim-IoT   ");
  
  delay(1000);
  
  WiFi.mode(WIFI_STA);
  
  WiFiManager wm;
  
  bool res;
  res = wm.autoConnect("Iklim-IoT", "12345678");
  
  if (!res) {
    Serial.println("Gagal Koneksi WiFi");
    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print("  WIFI FAILED!      ");
    delay(3000);
    ESP.restart();
  } else {
    Serial.println("WiFi Connected!");
    Serial.print("IP: ");
    Serial.println(WiFi.localIP());
    
    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print("  WIFI CONNECTED    ");
    lcd.setCursor(0, 1);
    lcd.print("  IP: ");
    lcd.print(WiFi.localIP());
    delay(2000);
  }
  
  espClient.setInsecure();
  client.setServer(mqtt_server, mqtt_port);
  
  if (!ams5600.detectMagnet()) {
    Serial.println("Magnet not detected!");
    lcd.setCursor(0, 3);
    lcd.print(" MAGNET NOT DETECT  ");
  } else {
    Serial.println("Magnet detected.");
    lcd.setCursor(0, 3);
    lcd.print("   ALL SENSORS OK   ");
  }
  
  delay(1000);
  lcd.clear();

  // ===== WATCHDOG SETELAH WIFI & MQTT =====
  esp_task_wdt_config_t wdt_config = {
      .timeout_ms = WDT_TIMEOUT * 1000,
      .idle_core_mask = (1 << 0) | (1 << 1),
      .trigger_panic = true,
  };
  
  esp_err_t err = esp_task_wdt_init(&wdt_config);
  if (err == ESP_OK) {
      esp_task_wdt_add(NULL);
      Serial.printf("✅ Watchdog init: %d seconds\n", WDT_TIMEOUT);
  }
  
  Serial.println("System Ready!");
  Serial.print("⏰ Jam operasional: ");
  Serial.print(JAM_MULAI);
  Serial.print(":00 - ");
  Serial.print(JAM_AKHIR);
  Serial.println(":00 WIB");
  Serial.println("⏰ Kirim: DI JAM PENUH (menit 0)");
  
  // ===== INISIALISASI TIMING =====
  resetHourlyBuffer();
  lastSentHour = -1;
  
  previousLedMillis = millis();
  ledState = LOW;
  digitalWrite(LED_BUILTIN, ledState);
}

// ==============================================
//                LOOP UTAMA
// ==============================================

void loop() {
  unsigned long currentTime = millis();
  DateTime now = rtc.now();
  
  esp_task_wdt_reset();
  updateLED();
  handleSerialCommands();
  
  // ===== CEK WIFI =====
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("WiFi putus, reconnect...");
    WiFi.reconnect();
    delay(100);
  }
  
  // ===== CEK MQTT =====
  if (!client.connected()) {
    connectMQTT();
  }
  client.loop();
  
  // ============================================
  //  1. PROSES RAIN GAUGE
  // ============================================
  if (rainBucketCounter > 0) {
    noInterrupts();
    unsigned long count = rainBucketCounter;
    rainBucketCounter = 0;
    interrupts();
    
    dailyRain += bucketAmount * count;
    
    if (count > 1) {
      Serial.print("🌧️ Rain: ");
      Serial.print(count);
      Serial.println(" bucket(s)");
    }
    
    static unsigned long lastRainSaveTime = 0;
    if (millis() - lastRainSaveTime > 5000) {
      saveRainDaily(dailyRain);
      lastRainSaveTime = millis();
    }
  }
  
  checkDayChange();
  
  // ============================================
  //  2. BACA SENSOR SETIAP 1 DETIK
  // ============================================
  if (currentTime - lastTime >= 1000) {

    noInterrupts();
    unsigned long pulses = pulseCount;
    pulseCount = 0;
    interrupts();

    float rpm = pulses * 60.0;
    float velocityFiltered = 0.0;
    float velocityKnot = 0.0;
           
    if (rpm == 0) {
      resetMovingAverageAnemo();
      velocityFiltered = 0.0;
      velocityKnot = 0.0;
    } else {
      float velocity_ms = (rpm * circumference) / 60.0;
      velocity_ms *= K;
      velocityFiltered = movingAverageAnemo(velocity_ms);
      velocityKnot = velocityFiltered * 1.94384;
    }

    // Wind Direction
    float currentAngle = -1;
    char arah[48];
    strcpy(arah, "--");
    
    if (ams5600.detectMagnet()) {
      currentAngle = readAngle();
      currentAngle = movingAverageDir(currentAngle);
      currentAngle = normalizeAngle(currentAngle);
      angle_in = currentAngle;
      arahMataAngin16(angle_in, arah);
    }

    // DHT11
    float temperature = dht.readTemperature();
    float humidity = dht.readHumidity();
    
    if (isnan(temperature) || isnan(humidity)) {
      temperature = -999.0;
      humidity = -999.0;
    }

    // LDR
    float lux = readLux();

    // ===== TAMBAHKAN KE HOURLY BUFFER (HANYA JAM OPERASIONAL) =====
    if (isOperatingHour()) {
      if (temperature != -999.0 && humidity != -999.0) {
        addToHourlyBuffer(temperature, humidity, velocityFiltered, velocityKnot,
                          currentAngle >= 0 ? currentAngle : 0, dailyRain, lux);
      }
    }

    // ============================================
    //  KIRIM HOURLY DI JAM PENUH (06:00-18:00)
    // ============================================
    if (isTopOfHour() && now.hour() != lastSentHour) {
      if (isOperatingHour()) {
        Serial.print("🕐 Jam penuh: ");
        Serial.print(now.hour());
        Serial.println(":00 - Kirim hourly report");
        
        sendHourlyReport();
        lastSentHour = now.hour();
      } else {
        Serial.print("🌙 Jam ");
        Serial.print(now.hour());
        Serial.println(":00 - Di luar jam operasional, skip");
        
        resetHourlyBuffer();
        hourlySendPending = false;
        lastSentHour = now.hour();
      }
    }
    
    // Retry hourly jika pending (HANYA JAM OPERASIONAL)
    if (hourlySendPending && WiFi.status() == WL_CONNECTED) {
      if (isOperatingHour()) {
        Serial.println("🔄 Retry hourly report...");
        sendHourlyReport();
      } else {
        hourlySendPending = false;
        resetHourlyBuffer();
      }
    }

    // ============================================
    //  KIRIM MQTT SETIAP 2 DETIK
    // ============================================
    static unsigned long lastMQTT = 0;
    if (currentTime - lastMQTT >= 2000) {
      if (client.connected()) {
        publishWeatherData(temperature, humidity, velocityFiltered, velocityKnot,
                          currentAngle, arah, dailyRain, lux);
        publishStatus();
        lastMQTT = currentTime;
      } else {
        connectMQTT();
      }
    }

    // ============================================
    //  OUTPUT SERIAL
    // ============================================
    Serial.print("Timestamp: ");
    if (now.hour() < 10) Serial.print("0");
    Serial.print(now.hour()); Serial.print(":");
    if (now.minute() < 10) Serial.print("0");
    Serial.print(now.minute()); Serial.print(":");
    if (now.second() < 10) Serial.print("0");
    Serial.print(now.second());
    
    Serial.print(" | Temp: ");
    if (temperature != -999.0) {
      Serial.print(temperature, 1);
      Serial.print("°C");
    } else {
      Serial.print("ERR");
    }
    
    Serial.print(" | H: ");
    if (humidity != -999.0) {
      Serial.print(humidity, 0);
      Serial.print("%");
    } else {
      Serial.print("ERR");
    }
    
    Serial.print(" | W: ");
    Serial.print(velocityFiltered, 1);
    Serial.print("m/s ");
                    
    if (currentAngle >= 0) {                    
      Serial.print(arah);
    }
    
    Serial.print(" | R: ");
    Serial.print(dailyRain, 1);
    Serial.print("mm");
    
    Serial.print(" | L: ");
    Serial.print(lux, 0);         
    
    Serial.print(" | Hourly: ");
    Serial.print(hourlyBuffer.count);
    
    if (isOperatingHour()) Serial.print(" | JAM:OK");
    else Serial.print(" | JAM:NO");
    
    Serial.print(" | LastH: ");
    Serial.print(lastSentHour);
    
    if (client.connected()) Serial.print(" | MQTT:ON");
    else Serial.print(" | MQTT:OFF");
    Serial.println("");

    // ============================================
    //  OUTPUT LCD
    // ============================================
    lcd.setCursor(0, 0);
    if (temperature != -999.0 && humidity != -999.0) {
      lcd.print("T:");
      lcd.print(temperature, 1);
      lcd.write(223);
      lcd.print("C H:");
      lcd.print(humidity, 0);
      lcd.print("% ");
    } else {
      lcd.print("T:--  H:-- ");
    }
    
    lcd.setCursor(0, 1);
    lcd.print("W:");
    lcd.print(velocityFiltered, 1);
    lcd.print("m/s ");
    if (currentAngle >= 0) {
      lcd.print(arah);
      for (int i = strlen(arah) + 7; i < 20; i++) lcd.print(" ");
    } else {
      lcd.print("--  ");
    }

    lcd.setCursor(0, 2);
    lcd.print("R:");
    lcd.print(dailyRain, 1);
    lcd.print("mm L:");
    lcd.print(lux, 0);  
    lcd.print("   ");
    
    lcd.setCursor(13, 3);
    lcd.print("[");
    if (now.hour() < 10) lcd.print("0");    
    lcd.print(now.hour());
    lcd.print(":");
    if (now.minute() < 10) lcd.print("0");
    lcd.print(now.minute());
    lcd.print("]");
           
    lastTime = currentTime;
  }

  delay(1);
}