# UPI Payment Alert

**UPI Payment Alert** is a Flutter + Kotlin Android application that listens for UPI and bank payment notifications and announces transactions using Text-to-Speech (TTS), allowing users to know instantly when money is received or sent without checking their phone.

## Features

### Real-Time Payment Voice Alerts
- Detects payment notifications in real time.
- Announces incoming and outgoing transactions.
- Example:
  - "Received 500 rupees"
  - "Sent 100 rupees"

### Multi-Language Support
Supports:
- English (India)
- Hindi
- Tamil
- Telugu
- Kannada
- Malayalam
- Bengali

### Smart Duplicate Protection
- Prevents the same transaction from being announced multiple times.
- Handles duplicate notifications from multiple banking apps.

### Payment Dashboard
- Receive and Send tabs
- Payment history
- Daily statistics
- Transaction tracking

### Customization
- Voice speed control
- Language selection
- Night mode (Quiet Hours)
- Dark fintech UI

### Diagnostics & Permissions
- Notification Listener setup
- Battery optimization setup
- Permission status indicators
- One-tap access to system settings

## Tech Stack

- Flutter (Dart)
- Kotlin
- Provider
- Hive
- SharedPreferences
- flutter_tts
- MethodChannel
- NotificationListenerService

## Architecture

1. User grants Notification Listener access.
2. Native Android service listens for payment notifications.
3. Notification text is parsed to extract:
   - Amount
   - Transaction type
4. Duplicate protection is applied.
5. Transaction is stored locally using Hive.
6. A voice alert is generated instantly.

## Privacy

- All processing happens entirely on-device.
- All transaction data is stored locally in an AES-encrypted Hive database.
- Encryption keys are securely stored using the device's secure keystore.
- No data is uploaded to any external server.
- No login or account is required.
- No third-party sharing.
- Users can clear transaction history at any time.

## Permissions Used

- Notification Listener Service
- Foreground Service
- Ignore Battery Optimizations
- Boot Completed (optional)

## Developer

**Anjanakrishnan A**

Email: **anjanakrishnananil@gmail.com**

---

**UPI Payment Alert – v1.0.0**

Real-time voice alerts for UPI and bank transactions.