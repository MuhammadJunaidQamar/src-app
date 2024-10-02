//Source: https://www.brettb.com/coding-tutorials/esp32-mqtt-tutorial/

//Basic Arduino IDE sketch required to connect to MQTT server
//using ESP32, ESP32 CAM or ESP8266 microcontroller
#include <WiFi.h>
#include <WiFiMulti.h>
WiFiMulti WiFiMulti;

#include <PubSubClient.h>

// Update these with values suitable for your network.

const char* ssid = "HUAWEI-7sz5";
const char* password = "3gwpc2BR";
const char* mqtt_server = "192.168.18.33";

WiFiClient espClient;
PubSubClient client(espClient);
unsigned long lastMsg = 0;
#define MSG_BUFFER_SIZE	(256)//129
char msg[MSG_BUFFER_SIZE];

void setup_wifi() {

  delay(10);
  // We start by connecting to a WiFi network
  Serial.println();
  Serial.print("Connecting to ");
  Serial.println(ssid);

  WiFi.mode(WIFI_STA);
  WiFi.begin(ssid, password);

  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }

  randomSeed(micros());

  Serial.println("");
  Serial.println("WiFi connected");
  Serial.println("IP address: ");
  Serial.println(WiFi.localIP());
}

void callback(char* topic, byte* payload, unsigned int length) {
  Serial.print("Message arrived [");
  Serial.print(topic);
  Serial.print("] ");
  for (int i = 0; i < length; i++) {
    Serial.print((char)payload[i]);
  }
  Serial.println();

}

void reconnect() {
  // Loop until we're reconnected
  while (!client.connected()) {
    Serial.print("Attempting MQTT connection...");
    // Create a random client ID
    String clientId = "ESP32Client-";
    clientId += String(random(0xffff), HEX);
    // Attempt to connect
    if (client.connect(clientId.c_str())) {
      Serial.println("connected");
      // Once connected, publish an announcement...
      client.publish("outTopic", "/* 37.00, 98515, 237.30, 98506, 2.93, -0.96, -10.36, 0.08, 0.08, 0.08, 80.91, -1.73, 141.53, 11.38, 7, 31.45, 74.27, 250.50 */");
      // ... and resubscribe
      client.subscribe("inTopic");
    } else {
      Serial.print("failed, rc=");
      Serial.print(client.state());
      Serial.println(" try again in 5 seconds");
      // Wait 5 seconds before retrying
      delay(5000);
    }
  }
}

void setup() {
  Serial.begin(9600);
  setup_wifi();
  client.setServer(mqtt_server, 1883);
  client.setCallback(callback);
}

void loop() {

  if (!client.connected()) {
    reconnect();
  }
  client.loop();

  unsigned long now = millis();
  if (now - lastMsg > 2000) {
    lastMsg = now;

    snprintf (msg, MSG_BUFFER_SIZE, "/* 37.00, 98515, 237.30, 98506, 2.93, -0.96, -10.36, 0.08, 0.08, 0.08, 80.91, -1.73, 141.53, 11.38, 7, 31.45, 74.27, 250.50 */");
    Serial.print("Publish message: ");
    Serial.println(msg);
    client.publish("outTopic", msg);

    delay(500);
    snprintf (msg, MSG_BUFFER_SIZE, "/* 36.90, 98500, 237.99, 98504, 2.97, -0.91, -10.03, -0.06, -0.06, -0.06, 80.18, 0.27, 141.94, 12.80, 7, 31.45, 74.27, 250.60 */");
    Serial.print("Publish message: ");
    Serial.println(msg);
    client.publish("outTopic", msg);
    
    delay(500);
    snprintf (msg, MSG_BUFFER_SIZE, "/* 37.10, 98520, 235.26, 98531, 2.85, -0.15, -11.00, 0.22, 0.22, 0.22, 83.00, 1.91, 144.80, 13.92, 7, 31.45, 74.27, 250.60 */");
    Serial.print("Publish message: ");
    Serial.println(msg);
    client.publish("outTopic", msg);
    
    delay(500);
    snprintf (msg, MSG_BUFFER_SIZE, "/* 37.00, 98522, 235.43, 98526, 2.76, -0.97, -10.12, 0.05, 0.05, 0.05, 80.91, 0.82, 141.84, 13.18, 7, 31.45, 74.27, 250.20 */");
    Serial.print("Publish message: ");
    Serial.println(msg);
    client.publish("outTopic", msg);
    
    delay(500);
    snprintf (msg, MSG_BUFFER_SIZE, "/* 37.00, 98519, 236.20, 98526, 2.90, -0.68, -10.83, 0.01, 0.01, 0.01, 80.00, 1.82, 143.06, 13.91, 7, 31.45, 74.27, 250.20 */");
    Serial.print("Publish message: ");
    Serial.println(msg);
    client.publish("outTopic", msg);
    
    delay(500);
    snprintf (msg, MSG_BUFFER_SIZE, "/* 37.00, 98510, 236.37, 98512, 2.69, -0.87, -10.44, 0.07, 0.07, 0.07, 79.45, 1.55, 141.63, 13.72, 6, 31.45, 74.27, 250.00 */");
    Serial.print("Publish message: ");
    Serial.println(msg);
    client.publish("outTopic", msg);
    
    delay(500);
    snprintf (msg, MSG_BUFFER_SIZE, "/* 37.10, 98525, 236.03, 98528, 2.63, -0.45, -10.97, -0.10, -0.10, -0.10, 80.55, 2.36, 141.33, 14.29, 6, 31.45, 74.27, 250.00 */");
    Serial.print("Publish message: ");
    Serial.println(msg);
    client.publish("outTopic", msg);
    
    delay(500);
    snprintf (msg, MSG_BUFFER_SIZE, "/* 37.00, 98526, 236.88, 98520, 2.84, -0.96, -10.47, 0.06, 0.06, 0.06, 78.36, 0.73, 140.41, 13.14, 6, 31.45, 74.27, 249.30 */");
    Serial.print("Publish message: ");
    Serial.println(msg);
    client.publish("outTopic", msg);
    
    delay(500);
    snprintf (msg, MSG_BUFFER_SIZE, "/* 37.10, 98519, 236.37, 98518, 2.74, -0.92, -10.47, 0.02, 0.02, 0.02, 78.18, 1.18, 140.61, 13.47, 6, 31.45, 74.27, 249.30 */");
    Serial.print("Publish message: ");
    Serial.println(msg);
    client.publish("outTopic", msg);
    
    delay(500);
    snprintf (msg, MSG_BUFFER_SIZE, "/* 37.10, 98512, 237.13, 98511, 2.75, -1.06, -11.00, 0.04, 0.04, 0.04, 77.91, 0.82, 140.41, 13.21, 6, 31.45, 74.27, 249.50 */");
    Serial.print("Publish message: ");
    Serial.println(msg);
    client.publish("outTopic", msg);
    
    delay(500);
    snprintf (msg, MSG_BUFFER_SIZE, "/* 37.00, 98484, 238.92, 98494, 2.54, -0.98, -10.28, 0.04, 0.04, 0.04, 77.36, 0.00, 140.10, 12.61, 6, 31.45, 74.27, 249.50 */");
    Serial.print("Publish message: ");
    Serial.println(msg);
    client.publish("outTopic", msg);
    
    delay(500);
    snprintf (msg, MSG_BUFFER_SIZE, "/* 37.20, 98530, 235.26, 98528, 3.31, -0.90, -10.47, 0.05, 0.05, 0.05, 75.27, 1.27, 141.12, 13.57, 7, 31.45, 74.27, 249.60 */");
    Serial.print("Publish message: ");
    Serial.println(msg);
    client.publish("outTopic", msg);
    delay(500);
  }
}