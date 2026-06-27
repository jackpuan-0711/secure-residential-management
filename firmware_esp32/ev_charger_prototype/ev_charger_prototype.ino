/*
  ESP32 EV Charger Prototype

  Purpose:
  - Demonstrates the EV charging flow with real ESP32 hardware.
  - Uses one LED board as the visible "charger on" indicator.
  - Uses a rechargeable battery voltage reading to simulate EV battery level.
  - Keeps Firebase/cloud work as TODO hooks for the next step.

  Safety:
  - Do not connect a rechargeable lithium battery directly to ESP32 GPIO.
  - Use a proper battery charger/protection module for actual charging.
  - The ESP32 ADC pin must read the battery through a voltage divider.
*/

// ----------------------- Hardware pins -----------------------
// Buttons are wired between the GPIO pin and GND. Internal pullups are enabled.
constexpr uint8_t START_BUTTON_PIN = 18;
constexpr uint8_t STOP_BUTTON_PIN = 19;
constexpr uint8_t FAULT_BUTTON_PIN = 23;

// Built-in LED on many ESP32 dev boards. Change if your board uses another pin.
constexpr uint8_t STATUS_LED_PIN = 2;

// Drives the LED board or the input of a MOSFET/relay module for the demo load.
constexpr uint8_t CHARGER_OUTPUT_PIN = 26;

// ADC input only pin. Connect battery divider midpoint here.
constexpr uint8_t BATTERY_ADC_PIN = 34;

// ----------------------- Battery settings -----------------------
// Set false if you do not have the battery voltage divider connected yet.
constexpr bool USE_REAL_BATTERY_ADC = true;

// For a single-cell Li-ion/LiPo demo battery. Adjust if your battery differs.
constexpr float BATTERY_EMPTY_VOLTAGE = 3.20f;
constexpr float BATTERY_FULL_VOLTAGE = 4.20f;
constexpr float BATTERY_UNSAFE_LOW_VOLTAGE = 2.90f;
constexpr float BATTERY_UNSAFE_HIGH_VOLTAGE = 4.25f;
constexpr float FULL_PERCENT_THRESHOLD = 98.0f;

// Example voltage divider: 100k from battery+ to ADC, 100k from ADC to GND.
// ADC sees half the battery voltage, so the divider ratio is 2.0.
constexpr float VOLTAGE_DIVIDER_RATIO = 2.0f;
constexpr float ADC_REFERENCE_VOLTAGE = 3.30f;
constexpr float ADC_MAX_READING = 4095.0f;

// Used only when USE_REAL_BATTERY_ADC is false.
constexpr float DEMO_START_PERCENT = 25.0f;
constexpr float DEMO_CHARGE_PERCENT_PER_MINUTE = 8.0f;

// ----------------------- Timing -----------------------
constexpr uint32_t DEBOUNCE_MS = 35;
constexpr uint32_t BATTERY_READ_INTERVAL_MS = 1000;
constexpr uint32_t TELEMETRY_INTERVAL_MS = 2000;
constexpr uint32_t MAX_SESSION_MS = 30UL * 60UL * 1000UL;

enum class ChargerState : uint8_t {
  boot,
  available,
  charging,
  full,
  fault,
};

struct DebouncedButton {
  uint8_t pin;
  bool rawPressed = false;
  bool stablePressed = false;
  bool pressedEdge = false;
  uint32_t lastChangeAt = 0;

  void begin() {
    pinMode(pin, INPUT_PULLUP);
    rawPressed = digitalRead(pin) == LOW;
    stablePressed = rawPressed;
    lastChangeAt = millis();
  }

  void update(uint32_t now) {
    pressedEdge = false;
    const bool currentRawPressed = digitalRead(pin) == LOW;

    if (currentRawPressed != rawPressed) {
      rawPressed = currentRawPressed;
      lastChangeAt = now;
    }

    if ((now - lastChangeAt) >= DEBOUNCE_MS &&
        currentRawPressed != stablePressed) {
      stablePressed = currentRawPressed;
      if (stablePressed) {
        pressedEdge = true;
      }
    }
  }

  bool wasPressed() const {
    return pressedEdge;
  }

  bool isHeld() const {
    return stablePressed;
  }
};

DebouncedButton startButton{START_BUTTON_PIN};
DebouncedButton stopButton{STOP_BUTTON_PIN};
DebouncedButton faultButton{FAULT_BUTTON_PIN};

ChargerState state = ChargerState::boot;
uint32_t stateStartedAt = 0;
uint32_t lastBatteryReadAt = 0;
uint32_t lastTelemetryAt = 0;

float batteryVoltage = 0.0f;
float batteryPercent = DEMO_START_PERCENT;
float demoBatteryPercent = DEMO_START_PERCENT;
bool sessionActive = false;

const char* stateName(ChargerState value) {
  switch (value) {
    case ChargerState::boot:
      return "boot";
    case ChargerState::available:
      return "available";
    case ChargerState::charging:
      return "charging";
    case ChargerState::full:
      return "full";
    case ChargerState::fault:
      return "fault";
  }
  return "unknown";
}

float clampFloat(float value, float minValue, float maxValue) {
  if (value < minValue) return minValue;
  if (value > maxValue) return maxValue;
  return value;
}

float percentFromVoltage(float voltage) {
  const float range = BATTERY_FULL_VOLTAGE - BATTERY_EMPTY_VOLTAGE;
  const float percent = ((voltage - BATTERY_EMPTY_VOLTAGE) / range) * 100.0f;
  return clampFloat(percent, 0.0f, 100.0f);
}

float voltageFromPercent(float percent) {
  const float safePercent = clampFloat(percent, 0.0f, 100.0f);
  const float range = BATTERY_FULL_VOLTAGE - BATTERY_EMPTY_VOLTAGE;
  return BATTERY_EMPTY_VOLTAGE + ((safePercent / 100.0f) * range);
}

float readBatteryVoltage() {
  constexpr uint8_t samples = 16;
  uint32_t rawTotal = 0;

  for (uint8_t i = 0; i < samples; i++) {
    rawTotal += analogRead(BATTERY_ADC_PIN);
    delayMicroseconds(300);
  }

  const float rawAverage = static_cast<float>(rawTotal) / samples;
  const float adcVoltage =
      (rawAverage / ADC_MAX_READING) * ADC_REFERENCE_VOLTAGE;
  return adcVoltage * VOLTAGE_DIVIDER_RATIO;
}

void transitionTo(ChargerState nextState, const char* reason) {
  if (state == nextState) return;

  state = nextState;
  stateStartedAt = millis();

  Serial.print("{\"event\":\"state_change\",\"state\":\"");
  Serial.print(stateName(state));
  Serial.print("\",\"reason\":\"");
  Serial.print(reason);
  Serial.println("\"}");
}

void onSessionStarted() {
  // Firebase TODO:
  // Later, call your backend/Firebase here to mark ev_stations/{id}.status
  // as "inUse" and create an ev_sessions document.
}

void onSessionEnded(const char* reason) {
  // Firebase TODO:
  // Later, call your backend/Firebase here to complete the active ev_sessions
  // document and return ev_stations/{id}.status to "available" or "offline".
  (void)reason;
}

void startChargingSession() {
  Serial.println("{\"event\":\"session_started\",\"source\":\"local_button\"}");
  sessionActive = true;
  onSessionStarted();
  transitionTo(ChargerState::charging, "start_button");
}

void finishChargingSession(ChargerState finalState, const char* reason) {
  Serial.print("{\"event\":\"session_ended\",\"reason\":\"");
  Serial.print(reason);
  Serial.println("\"}");
  if (sessionActive) {
    onSessionEnded(reason);
    sessionActive = false;
  }
  transitionTo(finalState, reason);
}

void tripFault(const char* reason) {
  Serial.print("{\"event\":\"fault\",\"reason\":\"");
  Serial.print(reason);
  Serial.println("\"}");
  if (sessionActive) {
    onSessionEnded(reason);
    sessionActive = false;
  }
  transitionTo(ChargerState::fault, reason);
}

void updateBattery(uint32_t now, bool force = false) {
  if (!force && (now - lastBatteryReadAt) < BATTERY_READ_INTERVAL_MS) {
    return;
  }

  const uint32_t elapsedMs = lastBatteryReadAt == 0 ? 0 : now - lastBatteryReadAt;
  lastBatteryReadAt = now;

  if (USE_REAL_BATTERY_ADC) {
    batteryVoltage = readBatteryVoltage();
    batteryPercent = percentFromVoltage(batteryVoltage);
    return;
  }

  if (state == ChargerState::charging) {
    const float minutes = static_cast<float>(elapsedMs) / 60000.0f;
    demoBatteryPercent += DEMO_CHARGE_PERCENT_PER_MINUTE * minutes;
  }

  demoBatteryPercent = clampFloat(demoBatteryPercent, 0.0f, 100.0f);
  batteryPercent = demoBatteryPercent;
  batteryVoltage = voltageFromPercent(demoBatteryPercent);
}

void updateButtons(uint32_t now) {
  startButton.update(now);
  stopButton.update(now);
  faultButton.update(now);
}

void runStateMachine(uint32_t now) {
  if (faultButton.wasPressed()) {
    tripFault("manual_fault_button");
    return;
  }

  switch (state) {
    case ChargerState::boot:
      transitionTo(ChargerState::available, "boot_complete");
      break;

    case ChargerState::available:
      if (startButton.wasPressed()) {
        if (USE_REAL_BATTERY_ADC &&
            batteryVoltage < BATTERY_UNSAFE_LOW_VOLTAGE) {
          tripFault("battery_voltage_too_low");
          return;
        }
        startChargingSession();
      }
      break;

    case ChargerState::charging: {
      const uint32_t elapsed = now - stateStartedAt;

      if (USE_REAL_BATTERY_ADC &&
          batteryVoltage > BATTERY_UNSAFE_HIGH_VOLTAGE) {
        tripFault("battery_voltage_too_high");
        return;
      }

      if (stopButton.wasPressed()) {
        finishChargingSession(ChargerState::available, "stop_button");
        return;
      }

      if (batteryPercent >= FULL_PERCENT_THRESHOLD) {
        finishChargingSession(ChargerState::full, "battery_full");
        return;
      }

      if (elapsed >= MAX_SESSION_MS) {
        finishChargingSession(ChargerState::available, "session_timeout");
      }
      break;
    }

    case ChargerState::full:
      if (stopButton.wasPressed() || startButton.wasPressed()) {
        transitionTo(ChargerState::available, "reset_after_full");
      }
      break;

    case ChargerState::fault:
      if (stopButton.wasPressed() && !faultButton.isHeld()) {
        transitionTo(ChargerState::available, "fault_reset");
      }
      break;
  }
}

bool ledPattern(uint32_t now) {
  switch (state) {
    case ChargerState::boot:
      return (now % 300) < 100;
    case ChargerState::available:
      return (now % 2000) < 120;
    case ChargerState::charging:
      return (now % 1000) < 700;
    case ChargerState::full: {
      const uint32_t phase = now % 2000;
      return phase < 120 || (phase >= 240 && phase < 360);
    }
    case ChargerState::fault:
      return (now % 300) < 150;
  }
  return false;
}

void updateOutputs(uint32_t now) {
  const bool chargerOn = state == ChargerState::charging;
  digitalWrite(CHARGER_OUTPUT_PIN, chargerOn ? HIGH : LOW);
  digitalWrite(STATUS_LED_PIN, ledPattern(now) ? HIGH : LOW);
}

void printTelemetry(uint32_t now) {
  if ((now - lastTelemetryAt) < TELEMETRY_INTERVAL_MS) {
    return;
  }
  lastTelemetryAt = now;

  Serial.print("{\"event\":\"telemetry\",\"state\":\"");
  Serial.print(stateName(state));
  Serial.print("\",\"charger_on\":");
  Serial.print(state == ChargerState::charging ? "true" : "false");
  Serial.print(",\"session_active\":");
  Serial.print(sessionActive ? "true" : "false");
  Serial.print(",\"battery_voltage\":");
  Serial.print(batteryVoltage, 2);
  Serial.print(",\"battery_percent\":");
  Serial.print(batteryPercent, 1);
  Serial.print(",\"elapsed_ms\":");
  Serial.print(now - stateStartedAt);
  Serial.println("}");
}

void setup() {
  Serial.begin(115200);
  delay(500);

  pinMode(STATUS_LED_PIN, OUTPUT);
  pinMode(CHARGER_OUTPUT_PIN, OUTPUT);
  digitalWrite(STATUS_LED_PIN, LOW);
  digitalWrite(CHARGER_OUTPUT_PIN, LOW);

  startButton.begin();
  stopButton.begin();
  faultButton.begin();

  analogReadResolution(12);
  analogSetPinAttenuation(BATTERY_ADC_PIN, ADC_11db);

  stateStartedAt = millis();
  updateBattery(millis(), true);

  Serial.println("{\"event\":\"boot\",\"device\":\"esp32_ev_charger_demo\"}");
  transitionTo(ChargerState::available, "boot_complete");
}

void loop() {
  const uint32_t now = millis();

  updateButtons(now);
  updateBattery(now);
  runStateMachine(now);
  updateOutputs(now);
  printTelemetry(now);
}
