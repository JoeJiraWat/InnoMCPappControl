  // #include <DHT.h>
  #include <WiFi.h>
  #include <WiFiClient.h>
  #include <WebServer.h>
  #include <ESPmDNS.h>

  #define DHTPIN 23
  #define DHTTYPE DHT22

  #define ULTRASONIC_PWR 16 // จ่ายไฟให้ Ultrasonic
  #define RELAY1 17
  #define RELAY2 18
  #define LIGHT_PIN 19 // Renamed from SERVO_PIN for clarity

  // Keep track of relay states
  bool isRelay1On = false;
  bool isRelay2On = false;

  // Add light control state
  bool isLightOn = false;

  // ================= CONSTANTS =================
  const unsigned long TWO_HOURS = 2 * 60 * 60 * 1000UL; // 2 ชม.
  const unsigned long DHT_INTERVAL = 2000;

  unsigned long startTime = 0;
  unsigned long lastDHTRead = 0;

  // DHT dht(DHTPIN, DHTTYPE);

  const char* ssid = "ESP32_AP";
  const char* password = "12345678";

  WebServer server(80);

  // Caching for DHT sensor is commented out as the sensor is not connected.
  // float last_known_temperature = NAN;
  // float last_known_humidity = NAN;
  
  // Function to send a standard JSON response
  void sendJSONResponse(String json) {
    server.send(200, "application/json", json);
  }
  
  void handleRoot() {
    server.send(200, "text/plain", "ESP32 Server is running.");
  }
  
  void handleConnect() {
    sendJSONResponse("{\"status\":\"ok\"}");
  }
  
  // Add MAC address to the status response
  void handleStatus() {
    // DHT sensor is not connected, returning default values.
    float t = 25.0;
    float h = 23.0;
  
    String macAddress = WiFi.softAPmacAddress(); // Get MAC address
  
    String json = "{";
    json += "\"temperature\":" + String(t, 2) + ",";
    json += "\"humidity\":" + String(h, 2) + ",";
    json += "\"relay1\":" + String(isRelay1On ? "true" : "false") + ",";
    json += "\"relay2\":" + String(isRelay2On ? "true" : "false") + ",";
    json += "\"light\":" + String(isLightOn ? "true" : "false") + ",";
    json += "\"macAddress\":\"" + macAddress + "\"";
    json += "}";
    sendJSONResponse(json);
  }
  // --- New Relay Handlers ---
  void handleRelay1On() {
    isRelay1On = true;
    digitalWrite(RELAY1, HIGH);
    sendJSONResponse("{\"relay\":1, \"status\":\"on\"}");
  }

  void handleRelay1Off() {
    isRelay1On = false;
    digitalWrite(RELAY1, LOW);
    sendJSONResponse("{\"relay\":1, \"status\":\"off\"}");
  }

  void handleRelay2On() {
    isRelay2On = true;
    digitalWrite(RELAY2, HIGH);
    sendJSONResponse("{\"relay\":2, \"status\":\"on\"}");
  }

  void handleRelay2Off() {
    isRelay2On = false;
    digitalWrite(RELAY2, LOW);
    sendJSONResponse("{\"relay\":2, \"status\":\"off\"}");
  }

  // Add light control handlers
  void handleLightOn() {
    isLightOn = true;
    digitalWrite(LIGHT_PIN, HIGH);
    sendJSONResponse("{\"light\":\"on\"}");
  }

  void handleLightOff() {
    isLightOn = false;
    digitalWrite(LIGHT_PIN, LOW);
    sendJSONResponse("{\"light\":\"off\"}");
  }

  void setupWiFi() {
    WiFi.softAP(ssid, password);
    IPAddress IP = WiFi.softAPIP();
    Serial.print("AP IP address: ");
    Serial.println(IP);
  }

  void setup() {
    Serial.begin(115200);
    setupWiFi();

    String macAddress = WiFi.softAPmacAddress();
    Serial.print("ESP32 MAC Address: ");
    Serial.println(macAddress);

    server.on("/", handleRoot);
    server.on("/connect", handleConnect);
    server.on("/status", handleStatus);
    
    // Register relay control handlers
    server.on("/relay/1/on", handleRelay1On);
    server.on("/relay/1/off", handleRelay1Off);
    server.on("/relay/2/on", handleRelay2On);
    server.on("/relay/2/off", handleRelay2Off);

    // Register light control handlers
    server.on("/light/on", handleLightOn);
    server.on("/light/off", handleLightOff);

    server.begin();
    Serial.println("HTTP server started");

    pinMode(ULTRASONIC_PWR, OUTPUT);
    pinMode(RELAY1, OUTPUT);
    pinMode(RELAY2, OUTPUT);
    pinMode(LIGHT_PIN, OUTPUT); // Initialize light pin

    // Set initial state
    digitalWrite(RELAY1, LOW);
    digitalWrite(RELAY2, LOW);
    digitalWrite(LIGHT_PIN, LOW); // Set light off initially

    // dht.begin();
    
    // The conflicting servo logic has been removed.

    startTime = millis();
    Serial.println("System Started...");
  }

  void loop() {
    server.handleClient();

    unsigned long now = millis();
    unsigned long elapsed = now - startTime;

    // Ultrasonic (GPIO 16) - This automatic logic is still active
    if (elapsed < TWO_HOURS) {
      digitalWrite(ULTRASONIC_PWR, HIGH);
    } else {
      digitalWrite(ULTRASONIC_PWR, LOW);
    }

    // NOTE: The automatic 6-hour relay and servo logic has been removed.
  }