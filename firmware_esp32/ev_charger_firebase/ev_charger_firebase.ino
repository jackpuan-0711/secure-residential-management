#include <ArduinoJson.h>
#include <HTTPClient.h>
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <Wire.h>
#include <hd44780.h>
#include <hd44780ioClass/hd44780_I2Cexp.h>

#include "secrets.h"

hd44780_I2Cexp lcd;
WiFiClientSecure secureClient;

constexpr int ADC_PIN = 34;
constexpr float ADC_REFERENCE = 3.3f;
constexpr int ADC_MAX = 4095;
constexpr float CHARGING_THRESHOLD = 2.0f;

constexpr unsigned long SENSOR_INTERVAL_MS = 500;
constexpr unsigned long HEARTBEAT_INTERVAL_MS = 5000;
constexpr unsigned long WIFI_RETRY_INTERVAL_MS = 10000;
constexpr unsigned long AUTH_REFRESH_INTERVAL_MS = 50UL * 60UL * 1000UL;

String firebaseIdToken;
unsigned long authenticatedAt = 0;
unsigned long lastSensorReadAt = 0;
unsigned long lastHeartbeatAt = 0;
unsigned long lastWifiRetryAt = 0;

int adcValue = 0;
float adcVoltage = 0.0f;
bool charging = false;
bool previousCharging = false;

void showLcd(const char* state) {
  lcd.setCursor(0, 0);
  lcd.print("Vadc: ");
  lcd.print(adcVoltage, 2);
  lcd.print(" V   ");

  lcd.setCursor(0, 1);
  lcd.print(state);
  for (int i = strlen(state); i < 16; i++) lcd.print(' ');
}

void startWifi() {
  Serial.print("Connecting to Wi-Fi: ");
  Serial.println(WIFI_SSID);
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  lastWifiRetryAt = millis();
}

void maintainWifi() {
  if (WiFi.status() == WL_CONNECTED) return;
  if (millis() - lastWifiRetryAt < WIFI_RETRY_INTERVAL_MS) return;

  firebaseIdToken = "";
  WiFi.disconnect();
  startWifi();
}

bool authenticateFirebase() {
  if (WiFi.status() != WL_CONNECTED) return false;

  const String url =
      "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=" +
      String(FIREBASE_API_KEY);

  DynamicJsonDocument request(512);
  request["email"] = DEVICE_EMAIL;
  request["password"] = DEVICE_PASSWORD;
  request["returnSecureToken"] = true;

  String body;
  serializeJson(request, body);

  HTTPClient http;
  http.begin(secureClient, url);
  http.addHeader("Content-Type", "application/json");
  const int code = http.POST(body);
  const String response = http.getString();
  http.end();

  Serial.print("Firebase login HTTP code: ");
  Serial.println(code);
  if (code != 200) {
    Serial.println(response);
    return false;
  }

  DynamicJsonDocument result(2048);
  if (deserializeJson(result, response) != DeserializationError::Ok) {
    Serial.println("Could not parse Firebase login response.");
    return false;
  }

  firebaseIdToken = result["idToken"].as<String>();
  if (firebaseIdToken.isEmpty()) return false;

  authenticatedAt = millis();
  Serial.println("Firebase authentication successful.");
  return true;
}

bool ensureFirebaseAuth() {
  const bool expired =
      firebaseIdToken.isEmpty() ||
      millis() - authenticatedAt >= AUTH_REFRESH_INTERVAL_MS;
  return !expired || authenticateFirebase();
}

bool publishHeartbeat() {
  if (!ensureFirebaseAuth()) return false;

  const String documentName =
      "projects/" + String(FIREBASE_PROJECT_ID) +
      "/databases/(default)/documents/ev_device_status/" + String(STATION_ID);
  const String url =
      "https://firestore.googleapis.com/v1/projects/" +
      String(FIREBASE_PROJECT_ID) + "/databases/(default)/documents:commit";

  DynamicJsonDocument request(2048);
  JsonObject write = request.createNestedArray("writes").createNestedObject();
  JsonObject update = write.createNestedObject("update");
  update["name"] = documentName;

  JsonObject fields = update.createNestedObject("fields");
  fields.createNestedObject("state")["stringValue"] =
      charging ? "charging" : "idle";
  fields.createNestedObject("adc")["integerValue"] = String(adcValue);
  fields.createNestedObject("online")["booleanValue"] = true;

  JsonObject transform =
      write.createNestedArray("updateTransforms").createNestedObject();
  transform["fieldPath"] = "lastSeenAt";
  transform["setToServerValue"] = "REQUEST_TIME";

  String body;
  serializeJson(request, body);

  HTTPClient http;
  http.begin(secureClient, url);
  http.addHeader("Authorization", "Bearer " + firebaseIdToken);
  http.addHeader("Content-Type", "application/json");
  const int code = http.POST(body);
  const String response = http.getString();
  http.end();

  Serial.print("Firestore heartbeat HTTP code: ");
  Serial.println(code);
  if (code == 401) firebaseIdToken = "";
  if (code != 200) Serial.println(response);
  return code == 200;
}

void readChargingState() {
  adcValue = analogRead(ADC_PIN);
  adcVoltage = (adcValue * ADC_REFERENCE) / ADC_MAX;
  charging = adcVoltage > CHARGING_THRESHOLD;

  Serial.print("ADC = ");
  Serial.print(adcValue);
  Serial.print(" | Vadc = ");
  Serial.print(adcVoltage, 2);
  Serial.print(" V | State = ");
  Serial.print(charging ? "CHARGING" : "IDLE");
  Serial.print(" | WiFi = ");
  Serial.println(WiFi.status() == WL_CONNECTED ? "CONNECTED" : "DISCONNECTED");

  showLcd(charging ? "Charging" : "Idle");
}

void setup() {
  Serial.begin(115200);
  Wire.begin(21, 22);
  analogReadResolution(12);

  const int lcdStatus = lcd.begin(16, 2);
  if (lcdStatus) hd44780::fatalError(lcdStatus);
  lcd.backlight();
  lcd.clear();
  lcd.print("Starting...");

  secureClient.setInsecure();
  startWifi();
}

void loop() {
  maintainWifi();

  const unsigned long now = millis();
  if (now - lastSensorReadAt >= SENSOR_INTERVAL_MS) {
    lastSensorReadAt = now;
    previousCharging = charging;
    readChargingState();
  }

  const bool stateChanged = charging != previousCharging;
  if (stateChanged || now - lastHeartbeatAt >= HEARTBEAT_INTERVAL_MS) {
    if (publishHeartbeat()) lastHeartbeatAt = now;
  }

  delay(20);
}
