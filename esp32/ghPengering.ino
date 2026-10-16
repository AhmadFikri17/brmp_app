#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <PubSubClient.h>
#include <DHT.h>
#include <Wire.h>
#include <BH1750.h>
#include <LiquidCrystal_I2C.h>
#include <TinyGPS++.h>

// ==================== KONFIGURASI WiFi ====================
const char* ssid = "Publik";
const char* password = "";

// ==================== KONFIGURASI HIVEMQ ====================
const char* mqtt_server = "82a3d01bd802462e9a414c755c593ea7.s1.eu.hivemq.cloud";
const int mqtt_port = 8883;
const char* mqtt_username = "esp32_gh";
const char* mqtt_password = "!greenhouse123";

// ==================== TOPIC MQTT ====================
const char* topicRelay1Set = "relay/1/set";
const char* topicRelay1Status = "relay/1/status";
const char* topicRelay2Set = "relay/2/set";
const char* topicRelay2Status = "relay/2/status";
const char* topicRelay1Mode = "relay/1/mode";
const char* topicRelay2Mode = "relay/2/mode";
// ✅ BARU: topic status mode (retained) — app subscribe untuk sync
const char* topicRelay1ModeStatus = "relay/1/mode/status";
const char* topicRelay2ModeStatus = "relay/2/mode/status";
const char* topicSensorData = "sensor/data";
const char* topicThreshold = "sensor/threshold";
const char* topicGPS = "gps/data";

// ==================== PIN RELAY ====================
#define RELAY1_PIN 26
#define RELAY2_PIN 27
#define RELAY_ON LOW
#define RELAY_OFF HIGH

// ==================== PIN SENSOR ====================
#define DHTPIN 4
#define DHTTYPE DHT11

// ==================== PIN LCD (I2C) ====================
#define LCD_SDA 21
#define LCD_SCL 22

// ==================== PIN BH1750 (I2C) ====================
#define BH_SDA 32
#define BH_SCL 33

// ==================== PIN GPS NEO-6M ====================
#define GPS_RX 16
#define GPS_TX 17

// ==================== KONFIGURASI LCD ====================
#define LCD_ADDRESS 0x27
#define LCD_COLUMNS 16
#define LCD_ROWS 2

// ==================== THRESHOLD DEFAULT ====================
float suhuThreshold = 40.0;
float kelembapanThreshold = 65.0;
float cahayaThreshold = 300.0;

// ==================== MODE RELAY ====================
// ✅ Default: OTOMATIS (sesuai permintaan)
bool relay1AutoMode = true;
bool relay2AutoMode = true;

// ==================== INISIALISASI ====================
WiFiClientSecure espClient;
PubSubClient client(espClient);
DHT dht(DHTPIN, DHTTYPE);
BH1750 lightMeter;
LiquidCrystal_I2C lcd(LCD_ADDRESS, LCD_COLUMNS, LCD_ROWS);
TinyGPSPlus gps;

bool relay1State = false;
bool relay2State = false;
bool initialStatusSent = false;

float suhu = 0;
float kelembapan = 0;
float intensitasCahaya = 0;

// GPS Variables
double latitude = 0.0;
double longitude = 0.0;
bool gpsValid = false;
unsigned long lastGPSUpdate = 0;

unsigned long lastSensorRead = 0;
unsigned long lastStatusSend = 0;
unsigned long lastLCDUpdate = 0;
int lcdDisplayState = 0;

// ==================== FORWARD DECLARATIONS ====================
void setupWiFi();
void reconnectMQTT();
void callback(char* topic, byte* payload, unsigned int length);
void parseThreshold(String data);
void readSensors();
void checkAutoMode();
void updateLCD();
void publishRelayStatus(int relayNumber, bool state);
void publishRelayMode(int relayNumber, bool autoMode);
void sendSensorData();
void sendGPSData();
void sendRelayStatus();
void sendRelayMode();

// ==================== SETUP ====================
void setup() {
  Serial.begin(115200);
  Serial.println("\n==========================================");
  Serial.println("🌬️  ESP32 Dryer Controller Starting...");
  Serial.println("==========================================");

  // ===== RELAY =====
  pinMode(RELAY1_PIN, OUTPUT);
  pinMode(RELAY2_PIN, OUTPUT);
  digitalWrite(RELAY1_PIN, RELAY_OFF);
  digitalWrite(RELAY2_PIN, RELAY_OFF);
  Serial.println("✅ Relays initialized: OFF");

  // ===== LCD =====
  Wire.begin(LCD_SDA, LCD_SCL);
  lcd.begin();
  lcd.backlight();
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("ESP32 System");
  lcd.setCursor(0, 1);
  lcd.print("Starting...");
  Serial.println("✅ LCD 16x2 initialized (SDA=21, SCL=22)");

  // ===== BH1750 =====
  Wire1.begin(BH_SDA, BH_SCL);
  Wire1.setClock(100000);

  if (lightMeter.begin(BH1750::CONTINUOUS_HIGH_RES_MODE, 0x23, &Wire1)) {
    Serial.println("✅ BH1750 Light Sensor initialized (SDA=32, SCL=33)");
  } else {
    Serial.println("❌ BH1750 not found!");
    lcd.setCursor(0, 1);
    lcd.print("BH1750 ERROR");
    delay(2000);
  }

  // ===== DHT11 =====
  dht.begin();
  Serial.println("✅ DHT11 Sensor initialized (Pin 4)");

  // ===== GPS =====
  Serial2.begin(9600, SERIAL_8N1, GPS_RX, GPS_TX);
  Serial.println("✅ GPS NEO-6M initialized (RX=16, TX=17)");
  Serial.println("⏳ Waiting for GPS fix...");

  lcd.setCursor(0, 1);
  lcd.print("GPS Fixing... ");

  // ===== WiFi =====
  setupWiFi();

  // ===== MQTT =====
  espClient.setInsecure();
  client.setServer(mqtt_server, mqtt_port);
  client.setCallback(callback);

  reconnectMQTT();

  Serial.println("==========================================\n");

  delay(2000);
  lcd.clear();
}

// ==================== LOOP ====================
void loop() {
  if (!client.connected()) {
    reconnectMQTT();
  }
  client.loop();

  // ===== SENSOR READING (Every 2 seconds) =====
  if (millis() - lastSensorRead > 2000) {
    readSensors();
    lastSensorRead = millis();
  }

  // ===== GPS READING =====
  while (Serial2.available() > 0) {
    char c = Serial2.read();
    if (gps.encode(c)) {
      if (gps.location.isValid()) {
        latitude = gps.location.lat();
        longitude = gps.location.lng();
        gpsValid = true;
        lastGPSUpdate = millis();
      }
    }
  }

  // ===== LCD UPDATE =====
  if (millis() - lastLCDUpdate > 3000) {
    updateLCD();
    lastLCDUpdate = millis();
  }

  // ===== INITIAL STATUS (setelah connect) =====
  if (client.connected() && !initialStatusSent) {
    delay(1000);
    sendRelayStatus();
    sendRelayMode();   // ✅ KIRIM MODE JUGA
    sendSensorData();
    sendGPSData();
    initialStatusSent = true;
    Serial.println("📤 Initial status sent!");
  }

  // ===== PERIODIC STATUS (Every 30 seconds) =====
  if (client.connected() && millis() - lastStatusSend > 30000) {
    sendRelayStatus();
    sendRelayMode();   // ✅ KIRIM MODE JUGA
    sendSensorData();
    sendGPSData();
    lastStatusSend = millis();
  }
}

// ==================== SETUP WiFi ====================
void setupWiFi() {
  Serial.print("📶 Connecting to WiFi");
  WiFi.begin(ssid, password);

  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 30) {
    delay(500);
    Serial.print(".");
    attempts++;
  }

  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\n✅ WiFi Connected!");
    Serial.print("📡 IP: ");
    Serial.println(WiFi.localIP());
  } else {
    Serial.println("\n❌ WiFi Failed! Restarting...");
    delay(3000);
    ESP.restart();
  }
}

// ==================== MQTT RECONNECT ====================
void reconnectMQTT() {
  if (WiFi.status() != WL_CONNECTED) {
    setupWiFi();
  }

  Serial.print("🔌 Connecting to MQTT...");

  String clientId = "ESP32-";
  clientId += String(random(0xffff), HEX);

  if (client.connect(clientId.c_str(), mqtt_username, mqtt_password)) {
    Serial.println(" ✅ Connected!");

    client.subscribe(topicRelay1Set);
    client.subscribe(topicRelay2Set);
    client.subscribe(topicRelay1Mode);
    client.subscribe(topicRelay2Mode);
    client.subscribe(topicThreshold);

    Serial.println("✅ Subscribed to all topics");

    // ✅ Kirim status & mode ke retained topic
    initialStatusSent = false;
    sendRelayStatus();
    sendRelayMode();    // ✅ KIRIM MODE
    sendSensorData();
    sendGPSData();

  } else {
    Serial.print(" ❌ Failed, rc=");
    Serial.println(client.state());
    delay(5000);
  }
}

// ==================== MQTT CALLBACK ====================
void callback(char* topic, byte* payload, unsigned int length) {
  String message = "";
  for (int i = 0; i < length; i++) {
    message += (char)payload[i];
  }

  Serial.println("\n==========================================");
  Serial.print("📩 [RECEIVED] Topic: ");
  Serial.println(topic);
  Serial.print("📩 [RECEIVED] Payload: ");
  Serial.println(message);
  Serial.println("==========================================");

  String topicStr = String(topic);

  // ========== RELAY 1 SET ==========
  if (topicStr == topicRelay1Set) {
    String cmd = message;
    cmd.toUpperCase();

    if (relay1AutoMode) {
      Serial.println("⚠️ Relay 1 in AUTO mode, ignoring manual command!");
      publishRelayStatus(1, relay1State);
      publishRelayMode(1, relay1AutoMode);  // ✅ Info ke app
      return;
    }

    Serial.println("🔹 Processing Relay 1 command (MANUAL mode)...");

    if (cmd == "ON") {
      relay1State = true;
      digitalWrite(RELAY1_PIN, RELAY_ON);
      Serial.println("✅ Relay 1: ON");
    }
    else if (cmd == "OFF") {
      relay1State = false;
      digitalWrite(RELAY1_PIN, RELAY_OFF);
      Serial.println("✅ Relay 1: OFF");
    }
    else if (cmd == "STATUS") {
      publishRelayStatus(1, relay1State);
      publishRelayMode(1, relay1AutoMode);
      return;
    }
    else {
      Serial.println("⚠️ Unknown command: " + cmd);
      return;
    }

    publishRelayStatus(1, relay1State);
  }

  // ========== RELAY 2 SET ==========
  else if (topicStr == topicRelay2Set) {
    String cmd = message;
    cmd.toUpperCase();

    if (relay2AutoMode) {
      Serial.println("⚠️ Relay 2 in AUTO mode, ignoring manual command!");
      publishRelayStatus(2, relay2State);
      publishRelayMode(2, relay2AutoMode);
      return;
    }

    Serial.println("🔹 Processing Relay 2 command (MANUAL mode)...");

    if (cmd == "ON") {
      relay2State = true;
      digitalWrite(RELAY2_PIN, RELAY_ON);
      Serial.println("✅ Relay 2: ON");
    }
    else if (cmd == "OFF") {
      relay2State = false;
      digitalWrite(RELAY2_PIN, RELAY_OFF);
      Serial.println("✅ Relay 2: OFF");
    }
    else if (cmd == "STATUS") {
      publishRelayStatus(2, relay2State);
      publishRelayMode(2, relay2AutoMode);
      return;
    }
    else {
      Serial.println("⚠️ Unknown command: " + cmd);
      return;
    }

    publishRelayStatus(2, relay2State);
  }

  // ========== RELAY 1 MODE ==========
  else if (topicStr == topicRelay1Mode) {
    String mode = message;
    mode.toLowerCase();

    if (mode == "otomatis" || mode == "automatic") {
      relay1AutoMode = true;
      Serial.println("✅ Relay 1 set to AUTO mode");
      checkAutoMode();
    } else if (mode == "manual") {
      relay1AutoMode = false;
      Serial.println("✅ Relay 1 set to MANUAL mode");
    }

    sendRelayStatus();
    sendRelayMode();    // ✅ Kirim mode balik ke app (retained)
  }

  // ========== RELAY 2 MODE ==========
  else if (topicStr == topicRelay2Mode) {
    String mode = message;
    mode.toLowerCase();

    if (mode == "otomatis" || mode == "automatic") {
      relay2AutoMode = true;
      Serial.println("✅ Relay 2 set to AUTO mode");
      checkAutoMode();
    } else if (mode == "manual") {
      relay2AutoMode = false;
      Serial.println("✅ Relay 2 set to MANUAL mode");
    }

    sendRelayStatus();
    sendRelayMode();    // ✅ Kirim mode balik ke app
  }

  // ========== THRESHOLD ==========
  else if (topicStr == topicThreshold) {
    parseThreshold(message);
  }
}

// ==================== PARSE THRESHOLD ====================
void parseThreshold(String data) {
  Serial.print("📊 Updating thresholds from: ");
  Serial.println(data);

  int comma1 = data.indexOf(',');
  int comma2 = data.indexOf(',', comma1 + 1);

  if (comma1 > 0 && comma2 > 0) {
    suhuThreshold = data.substring(0, comma1).toFloat();
    kelembapanThreshold = data.substring(comma1 + 1, comma2).toFloat();
    cahayaThreshold = data.substring(comma2 + 1).toFloat();

    Serial.println("✅ Threshold updated:");
    Serial.print("   🔥 Suhu Maks: "); Serial.print(suhuThreshold); Serial.println(" °C");
    Serial.print("   💧 Kelembapan Maks: "); Serial.print(kelembapanThreshold); Serial.println(" %");
    Serial.print("   ☀️  Cahaya Min: "); Serial.print(cahayaThreshold); Serial.println(" Lux");
  }
}

// ==================== READ SENSORS ====================
void readSensors() {
  float h = dht.readHumidity();
  float t = dht.readTemperature();
  float lux = lightMeter.readLightLevel();

  if (isnan(h) || isnan(t)) {
    Serial.println("⚠️ Failed to read from DHT sensor!");
    return;
  }

  if (lux < 0) lux = 0;

  suhu = t;
  kelembapan = h;
  intensitasCahaya = lux;

  checkAutoMode();
  sendSensorData();

  Serial.println("\n📊 Sensor Data:");
  Serial.print("   🌡️  Suhu: "); Serial.print(suhu); Serial.println(" °C");
  Serial.print("   💧 Kelembapan: "); Serial.print(kelembapan); Serial.println(" %");
  Serial.print("   ☀️  Cahaya: "); Serial.print(intensitasCahaya); Serial.println(" Lux");
  Serial.print("   🔹 Relay 1: "); Serial.println(relay1State ? "ON" : "OFF");
  Serial.print("   🔹 Relay 2: "); Serial.println(relay2State ? "ON" : "OFF");
  Serial.print("   🔹 Relay 1 Mode: "); Serial.println(relay1AutoMode ? "AUTO" : "MANUAL");
  Serial.print("   🔹 Relay 2 Mode: "); Serial.println(relay2AutoMode ? "AUTO" : "MANUAL");

  if (gpsValid) {
    Serial.print("   🛰️  GPS: "); Serial.print(latitude, 6); Serial.print(", "); Serial.println(longitude, 6);
  } else {
    Serial.println("   🛰️  GPS: No Fix");
  }
  Serial.println();
}

// ==================== AUTO MODE ====================
void checkAutoMode() {
  bool shouldRelayOn = (kelembapan > kelembapanThreshold) ||
                       (suhu > suhuThreshold) ||
                       (intensitasCahaya < cahayaThreshold);

  // ========== RELAY 1 ==========
  if (relay1AutoMode) {
    if (shouldRelayOn != relay1State) {
      relay1State = shouldRelayOn;
      digitalWrite(RELAY1_PIN, relay1State ? RELAY_ON : RELAY_OFF);
      publishRelayStatus(1, relay1State);
      Serial.print("🔄 Auto Mode: Relay 1 changed to ");
      Serial.println(relay1State ? "ON" : "OFF");
    }
  }

  // ========== RELAY 2 ==========
  if (relay2AutoMode) {
    if (shouldRelayOn != relay2State) {
      relay2State = shouldRelayOn;
      digitalWrite(RELAY2_PIN, relay2State ? RELAY_ON : RELAY_OFF);
      publishRelayStatus(2, relay2State);
      Serial.print("🔄 Auto Mode: Relay 2 changed to ");
      Serial.println(relay2State ? "ON" : "OFF");
    }
  }
}

// ==================== UPDATE LCD ====================
void updateLCD() {
  lcd.clear();

  if (lcdDisplayState == 0) {
    lcd.setCursor(0, 0);
    lcd.print("T:");
    lcd.print(suhu, 1);
    lcd.print("C H:");
    lcd.print(kelembapan, 1);
    lcd.print("%");

    lcd.setCursor(0, 1);
    lcd.print("L:");
    lcd.print(intensitasCahaya, 0);
    lcd.print("Lx");

    lcd.setCursor(10, 1);
    lcd.print("R");
    lcd.print(relay1State ? "1" : "0");
    lcd.print(relay2State ? "1" : "0");

  } else {
    lcd.setCursor(0, 0);
    if (gpsValid) {
      char latStr[16];
      dtostrf(latitude, 8, 5, latStr);
      lcd.print("Lat:");
      lcd.print(latStr);
    } else {
      lcd.print("GPS: No Fix");
    }

    lcd.setCursor(0, 1);
    if (gpsValid) {
      char lngStr[16];
      dtostrf(longitude, 8, 5, lngStr);
      lcd.print("Lng:");
      lcd.print(lngStr);
    } else {
      if (gps.satellites.value() > 0) {
        lcd.print("SAT:");
        lcd.print(gps.satellites.value());
        lcd.print("  ");
      } else {
        lcd.print("Searching...");
      }
    }
  }

  lcdDisplayState = (lcdDisplayState + 1) % 2;
}

// ==================== PUBLISH FUNCTIONS ====================
void publishRelayStatus(int relayNumber, bool state) {
  String status = state ? "ON" : "OFF";
  String topic = (relayNumber == 1) ? topicRelay1Status : topicRelay2Status;

  Serial.print("📤 Publishing to ");
  Serial.print(topic);
  Serial.print(": ");
  Serial.println(status);

  // ✅ retained = true → app baru buka langsung dapat
  if (client.publish(topic.c_str(), status.c_str(), true)) {
    Serial.println("✅ Status published successfully!");
  } else {
    Serial.println("❌ Failed to publish status!");
  }
}

// ✅ BARU: publish mode sebagai retained
void publishRelayMode(int relayNumber, bool autoMode) {
  String mode = autoMode ? "otomatis" : "manual";
  String topic = (relayNumber == 1) ? topicRelay1ModeStatus : topicRelay2ModeStatus;

  Serial.print("📤 Publishing to ");
  Serial.print(topic);
  Serial.print(": ");
  Serial.println(mode);

  if (client.publish(topic.c_str(), mode.c_str(), true)) {
    Serial.println("✅ Mode published successfully!");
  } else {
    Serial.println("❌ Failed to publish mode!");
  }
}

void sendSensorData() {
  String sensorData = String(suhu, 1) + "," +
                      String(kelembapan, 1) + "," +
                      String(intensitasCahaya, 1);

  Serial.print("📤 Publishing sensor data: ");
  Serial.println(sensorData);

  if (client.publish(topicSensorData, sensorData.c_str())) {
    Serial.println("✅ Sensor data published!");
  } else {
    Serial.println("❌ Failed to publish sensor data!");
  }
}

void sendGPSData() {
  if (gpsValid) {
    String gpsData = String(latitude, 6) + "," + String(longitude, 6);
    Serial.print("📤 Publishing GPS data: ");
    Serial.println(gpsData);

    if (client.publish(topicGPS, gpsData.c_str())) {
      Serial.println("✅ GPS data published!");
    } else {
      Serial.println("❌ Failed to publish GPS data!");
    }
  } else {
    Serial.println("📤 GPS data not available (no fix)");
    client.publish(topicGPS, "NO_FIX,NO_FIX");
  }
}

void sendRelayStatus() {
  publishRelayStatus(1, relay1State);
  delay(50);
  publishRelayStatus(2, relay2State);
}

// ✅ BARU: kirim mode relay ke app
void sendRelayMode() {
  publishRelayMode(1, relay1AutoMode);
  delay(50);
  publishRelayMode(2, relay2AutoMode);
}