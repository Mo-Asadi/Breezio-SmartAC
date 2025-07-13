# Breezio - Flutter App

The **Breezio Flutter App** is the companion mobile interface for the Smart AC Project. It enables seamless remote control, configuration, and monitoring of your ESP32-based smart air conditioning system via Firebase Realtime Database.

---

## 📲 App Features

### 🔐 Authentication
- Email/password sign-in
- Role-based access: admin or user
- Device selection screen with real-time online status indicator

### 📡 Device Setup & Onboarding
- Wi-Fi credential input
- AC model selection (Electra, LG, Samsung, or manual IR capture)
- Temperature range definition
- Manual IR learning with on/off/temp up/temp down capture

### 🎛️ Remote Control
- Power toggle
- Temperature up/down
- Mode selection: Regular, Eco, Motion, Timer
- Relay (scent diffuser) toggle
- LED strip toggle
- Favorite settings save/apply
- Real-time command result feedback

### 🗓️ Scheduling
- Weekly schedule configuration (per user)
- Intuitive time picker UI
- Time saved as compact integers (e.g. 1537 = 15:37)
- Apply schedule to global device path via command

### 🔔 Notifications
- **Idle Notification**: Alerts if no motion is detected
- **Maintenance Notification**: Notifies when capacity is reached

### 🛠️ Maintenance & Admin
- Track hours of operation
- Reset maintenance counter
- Factory reset device command
- View/delete authorized users (admin only)

---

## 📦 Folder Structure
```

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
    └──README.md 
```

---

## 🧪 Requirements

- Flutter 3.13+
- Firebase CLI set up (auth + realtime DB)
- Android emulator or real device
- `.env` file containing: DATABASE_URL=https://your-project.firebaseio.com/

---

## 🔧 Setup Instructions

1. Clone the repository:
 ```bash
 git clone https://github.com/yourusername/breezio-smart-ac.git
 cd Breezio-Flutter\ App/
```
2.	Install dependencies:
```bash
flutter pub get
```
3.	Set up Firebase for Android:
```
•	Add google-services.json (Android)
•	Ensure Firebase project has:
	•	Realtime Database enabled
	•	Email/Password Auth enabled
```
4.	Run the app:
 ```bash
flutter run
```

🧠 Architecture Notes
```
	•	Provider is used for state management
	•	Command system uses a queue to ensure commands are sent sequentially
	•	Firebase Realtime Database paths follow:
  	-	Commands: /devices/{deviceMAC}/command
  	-	Status & result: /devices/{deviceMAC}/status, /result
  	-	Users & roles: /devices/{deviceMAC}/users/{uid}
```

## 🛡️ License

MIT License. See [LICENSE](../LICENSE) for details.













