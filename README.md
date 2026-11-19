# 🛡️ IoT-Based Coal Mine Safety Monitoring & Real-Time Alerting System

**Oral Defense & Live Engineering Prototype**  
**Microcontroller:** ESP32 DevKit v1 (30-pin, 240 MHz Dual-Core)  
**Sensors:** MQ-135 (Methane/CO), DHT11 (Temp/Hum), SW-520D (Tilt/Cave-In), LCD 1602 I2C, Active Buzzer 85 dB  
**Enclosure:** Industrial 3D Shockproof Casing IP65 / ATEX (AutoCAD / Tinkercad 3D)  

---

## 🌐 Live Web Application & Interactive 3D Model
- **Live URL:** [https://glazbery11.github.io/mine-safety-system/](https://glazbery11.github.io/mine-safety-system/)

---

## 📁 Repository Contents
- `index.html` - Full-Stack Web Application (SCADA Telemetry Dashboard, Next-Gen 3D CAD Viewer, Oral Defense Guide)
- `mine_safety_enclosure.stl` - Ready-to-3D-print ASCII STL enclosure model for AutoCAD / Tinkercad
- `mine_safety_enclosure.scad` - Parametric OpenSCAD enclosure CAD source

---

## ⚡ ESP32 Wi-Fi Architecture
The hardware runs autonomously without any computer. When powered via USB powerbank, the ESP32 initiates:
1. **Built-in SoftAP:** SSID `ESP32_MINE_SAFETY` (IP: `192.168.4.1`)
2. **High-Speed REST API:** `/data` (JSON telemetry broadcast every 500 ms)
3. **Autonomous Buzzer Siren & LCD 1602:** Instant hardware alert upon threshold breach (>700 ppm Gas or >15° Tilt).
