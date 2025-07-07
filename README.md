# Smart AC Project

Welcome to the **Smart AC Project**, a comprehensive smart air conditioning control system built with an ESP32 microcontroller and a Flutter-based mobile application. The project enables remote AC control through Firebase, IR signals, sensors, schedules, and more.

---

## 📁 Repository Structure
```
├── ESP32/                  # ESP32 firmware for device-side control
├      ├── ESP32.ino
├      ├── FirestoreServices.*
├      ├── IRCommand.*
├      ├── InitSetup.*
├      ├── buzzer.*
├      ├── dhtSensor.*
├      ├── led.*
├      ├── modeHandler.*
├      ├── ntpTime.*
├      ├── pirSensor.*
├      ├── relay.*
├      ├── secrets.*
├      ├── parameters.h
├      └── log.h
├── Breezio-Flutter App/   # Flutter mobile app for controlling and configuring the AC  
├── README.md              # Project documentation
└── LICENSE                # Project License

```

---

## 🚀 Features

### ✅ ESP32 Firmware (`ESP32/`)
- **IR-based AC control**:
  - Supports Electra, Samsung, LG
  - Manual IR mode for any other brand (user-provided IR codes)
- **Realtime Commands via Firebase**:
  - Listens to `/devices/{deviceMac}/command`
  - Reports status to `/devices/{deviceMac}/result`
- **Modes & Scheduling**:
  - Regular, eco, motion-based, and timer modes
  - Per-user weekly schedule with start/end times
- **User Management**:
  - Admin can add other users and manage privileges
- **Hardware Integrations**:
  - PIR motion sensor for occupancy detection
  - NeoPixel LED for status and mood lighting
  - Relay to control external devices (e.g., scent diffuser)
  - Buzzer for audio notifications
  - DHT11 sensor for temperature/humidity
- **Favorites Feature**:
  - Save and instantly apply personalized settings
- **Online Status & Time Sync**:
  - Heartbeat system to indicate device availability
  - NTP synchronization for daily schedule execution

---

### 📱 Flutter App (`Breezio-Flutter App/`)
- **Onboarding & Setup**:
  - Device discovery
  - Wi-Fi credentials input
  - IR signal learning (manual mode)
- **Authentication**:
  - Email/password login system
  - Role-based access control (admin/user)
- **Control Interface**:
  - Power toggle, temperature up/down
  - Mode switch (eco, motion, etc.)
  - Relay and LED toggles
  - Apply and saved favorite settings
- **User-Specific Scheduling**:
  - Day-based time intervals for automatic AC control
- **Live Feedback**:
  - Shows current temperature
  - Displays last known command and result

---

## 🔧 Hardware Requirements

- ESP32-microcontroller
- IR LED and Receiver
- PIR motion sensor
- Relay module
- NeoPixel RGB LED strip
- DHT11 temperature & humidity sensor
- Passive buzzer
- Tactile button
- Power supply (USB or 5V regulator)

---

## 🛠️ Getting Started

### ESP32 Firmware

1. **🧰 Arduino Dependencies**:
    Make sure to install the following libraries in the Arduino IDE:
    | Library Name | Author | Version |
    |--------------|--------|---------|
    | [Adafruit NeoPixel](https://github.com/adafruit/Adafruit_NeoPixel) | Adafruit | 1.15.1 |
    | [Adafruit Unified Sensor](https://github.com/adafruit/Adafruit_Sensor) | Adafruit | 1.1.15 |
    | [ArduinoJson](https://arduinojson.org/) | Benoît Blanchon | 7.4.2 |
    | [DHT sensor library](https://github.com/adafruit/DHT-sensor-library) | Adafruit | 1.4.6 |
    | [Firebase Arduino Client](https://github.com/mobizt/Firebase-ESP-Client) | Mobizt | 4.4.17 |
    | [IRremoteESP8266](https://github.com/crankyoldgit/IRremoteESP8266) | David Conran et al. | 2.8.6 |


2. **Setup `secrets.cpp`** (not included in repo):
   ```cpp
    const char* debugssid = "YourSSID";
    const char* debugpass = "YourPassword";
    const String ApiKey = "YourFirebaseAPIKey";
    const String DbUrl = "https://your-project.firebaseio.com/";
    const String AuthEmail = "your@firebase.user";
    const String AuthPass = "YourFirebasePassword";

