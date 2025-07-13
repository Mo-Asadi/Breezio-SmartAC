# Breezio - Smart AC Project

Welcome to the **Smart AC Project**, a comprehensive smart air conditioning control system built with an ESP32 microcontroller and a Flutter-based mobile application. The project enables remote AC control through Firebase, IR signals, sensors, schedules, and more.

---

## 📁 Repository Structure
```
├── ESP32/                  # ESP32 firmware for device-side control
│   ├── ESP32.ino
│   ├── firestoreServices.*
│   ├── command.*
│   ├── initSetup.*
│   ├── sensors.*
│   ├── modeHandler.*
│   ├── ntpTime.*
│   ├── secrets.*
│   ├── parameters.h
│   └── log.h
├── Breezio-Flutter App/   # Flutter mobile app for controlling and configuring the AC
│   ├── android/ ...
│   ├── functions/ ...
│   ├── lib/
│   │    ├── providers/
│   │    │      ├── ac_maintenance_provider.dart
│   │    │      ├── ac_status_provider.dart
│   │    │      ├── command_provider.dart
│   │    │      └── sensor_data_provider.dart
│   │    ├── screens/
│   │    │      ├── authentication&onboarding/
│   │    │      │          ├── ac_setup_screen.dart
│   │    │      │          ├── login_screen.dart
│   │    │      │          ├── signup_screen.dart
│   │    │      │          └── splash_screen.dart
│   │    │      └──  homescreen/
│   │    │                 ├── dashboard_screen.dart
│   │    │                 ├── maintenance_screen.dart
│   │    │                 └── remote_controller_screen.dart
│   │    ├── widgets/
│   │    │      ├── navigation/
│   │    │      │       └── home_screen_nav.dart
│   │    │      ├── sensors/
│   │    │      │       ├── air_quality_card.dart
│   │    │      │       └── dht11_sensor_card.dart
│   │    │      ├── advice_widget.dart
│   │    │      ├── barcode_scanner_screen.dart
│   │    │      └── weather_widget.dart
│   │    └── main.dart
│   ├── test/ ...
│   ├── pubspec.yaml
│   :
│   └──README.md 
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
  - Reports result to `/devices/{deviceMac}/result`
- **Modes & Scheduling**:
  - Regular, eco, motion-based, and timer modes
  - Per-user weekly schedule with start/end times (stored as integers, e.g. 1537)
- **User Management**:
  - Admin can add/remove users and assign roles
- **Hardware Integrations**:
  - PIR motion sensor for occupancy detection
  - NeoPixel LED for theme lighting
  - Relay control for devices like scent diffusers
  - DHT11 sensor for temperature/humidity
  - Passive buzzer for alerts
- **Favorites Feature**:
  - Save and instantly apply preferred settings (mode, temp, relay, lights)
- **Online Status & Time Sync**:
  - Heartbeat system updates last seen timestamp
  - NTP sync for accurate daily scheduling
- **Memory Optimization**:
  - No large JSONs; saves only necessary data to prevent stack overflow

---

### 📱 Flutter App (`Breezio-Flutter App/`)
- **Modern Flutter Architecture**:
  - Fully refactored to use Provider pattern
  - State managers: `ACStatusProvider`, `CommandProvider`, `ACMaintenanceProvider`, `SensorDataProvider`
- **Onboarding & Setup**:
  - IR learning for custom ACs
  - Wi-Fi config via ESP32 AP-mode
- **Authentication**:
  - Firebase email/password login
  - Role-based access (admin/user)
- **Device Control**:
  - Power, temperature, mode, LED, scent relay
  - Real-time status updates and feedback
- **User-Specific Scheduling**:
  - Configure per-day start/end times
  - Apply individual schedules to device
- **Maintenance & Alerts**:
  - Displays total vs capacity hours
  - Local notifications for:
    - Idleness (no motion)
    - Maintenance required
- **Favorites Support**:
  - Apply saved preferences in a single tap

---

## 🔧 Hardware Requirements

- ESP32-microcontroller
- IR LED + Receiver
- PIR motion sensor
- Relay module
- NeoPixel RGB LED
- DHT11 temp/humidity sensor
- Passive buzzer
- Push button
- 5V power supply

---

## 🛠️ Getting Started

### ESP32 Firmware

1. **🧰 Arduino Dependencies**:
    Install the following libraries in Arduino IDE:

    | Library Name | Author | Version |
    |--------------|--------|---------|
    | [Adafruit NeoPixel](https://github.com/adafruit/Adafruit_NeoPixel) | Adafruit | 1.15.1 |
    | [Adafruit Unified Sensor](https://github.com/adafruit/Adafruit_Sensor) | Adafruit | 1.1.15 |
    | [ArduinoJson](https://arduinojson.org/) | Benoît Blanchon | 7.4.2 |
    | [DHT sensor library](https://github.com/adafruit/DHT-sensor-library) | Adafruit | 1.4.6 |
    | [Firebase ESP Client](https://github.com/mobizt/Firebase-ESP-Client) | Mobizt | 4.4.17 |
    | [IRremoteESP8266](https://github.com/crankyoldgit/IRremoteESP8266) | David Conran et al. | 2.8.6 |

2. **Setup `secrets.cpp`** (not in repo):

    ```cpp
    const char* debugssid = "YourSSID";
    const char* debugpass = "YourPassword";
    const String ApiKey = "YourFirebaseAPIKey";
    const String DbUrl = "https://your-project.firebaseio.com/";
    const String AuthEmail = "your@firebase.user";
    const String AuthPass = "YourFirebasePassword";
    ```
