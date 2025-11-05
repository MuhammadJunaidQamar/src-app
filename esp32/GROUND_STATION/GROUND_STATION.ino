#include <esp_now.h>
#include <WiFi.h>

// Updated Struct for RF Data with roll, pitch, yaw and all parameters
typedef struct struct_message {
  // Header and basic info
  unsigned long Header;
  unsigned long timestamp;
  
  // IMU data
  float Xacc;
  float Yacc;
  float Zacc;
  float Angaccx;
  float Angaccy;
  float Angaccz;
  
  // Orientation (new fields)
  float roll;
  float pitch;
  float yaw;
  
  // Magnetometer data
  float Magx;
  float Magy;
  float Magz;
  
  // Environmental data
  float Temperature;
  float Altitude;
  float Pressure;
  
  // Compass data
  float CompassHeading;
  float GPSHeading;
  
  // GPS data
  float Sat;
  float Lat;
  float Long;
  float GPSAlt;
  
  // Distance tracking
  float Distance;
  float TotalDistance;
} struct_message;

// Create a struct_message called myData
struct_message myData;

// New ESP-NOW receive callback
void OnDataRecv(const esp_now_recv_info_t *recv_info, const uint8_t *incomingData, int len) {
  if (len == sizeof(myData)) {
    memcpy(&myData, incomingData, sizeof(myData));

    // Get MAC address from recv_info
    char macStr[18];
    snprintf(macStr, sizeof(macStr),
             "%02X:%02X:%02X:%02X:%02X:%02X",
             recv_info->src_addr[0], recv_info->src_addr[1], recv_info->src_addr[2],
             recv_info->src_addr[3], recv_info->src_addr[4], recv_info->src_addr[5]);

    // Send Data to Matlab/Serial
    Serial.write((uint8_t*)&myData, sizeof(myData));

    // Optional: Print debug information
    /*
    Serial.print("From MAC: ");
    Serial.println(macStr);
    
    Serial.print("Header: "); Serial.println(myData.Header);
    Serial.print("Timestamp: "); Serial.println(myData.timestamp);
    
    Serial.print("Orientation - Roll: "); Serial.print(myData.roll);
    Serial.print(", Pitch: "); Serial.print(myData.pitch);
    Serial.print(", Yaw: "); Serial.println(myData.yaw);
    
    Serial.print("Acceleration - X: "); Serial.print(myData.Xacc);
    Serial.print(", Y: "); Serial.print(myData.Yacc);
    Serial.print(", Z: "); Serial.println(myData.Zacc);
    
    Serial.print("Gyro - X: "); Serial.print(myData.Angaccx);
    Serial.print(", Y: "); Serial.print(myData.Angaccy);
    Serial.print(", Z: "); Serial.println(myData.Angaccz);
    
    Serial.print("Magnetometer - X: "); Serial.print(myData.Magx);
    Serial.print(", Y: "); Serial.print(myData.Magy);
    Serial.print(", Z: "); Serial.println(myData.Magz);
    
    Serial.print("Environment - Temp: "); Serial.print(myData.Temperature);
    Serial.print("°C, Alt: "); Serial.print(myData.Altitude);
    Serial.print("m, Pressure: "); Serial.println(myData.Pressure);
    
    Serial.print("Compass Heading: "); Serial.print(myData.CompassHeading);
    Serial.print("°, GPS Heading: "); Serial.println(myData.GPSHeading);
    
    Serial.print("GPS - Sat: "); Serial.print(myData.Sat);
    Serial.print(", Lat: "); Serial.print(myData.Lat, 6);
    Serial.print(", Lon: "); Serial.print(myData.Long, 6);
    Serial.print(", GPS Alt: "); Serial.println(myData.GPSAlt);
    
    Serial.print("Distance - Current: "); Serial.print(myData.Distance);
    Serial.print("m, Total: "); Serial.print(myData.TotalDistance);
    Serial.println("m");
    Serial.println("----------------------");
    */
  } else {
    Serial.print("Invalid data length: ");
    Serial.println(len);
  }
}

void setup() {
  Serial.begin(115200);

  // Set device as a Wi-Fi Station
  WiFi.mode(WIFI_STA);

  // Init ESP-NOW
  if (esp_now_init() != ESP_OK) {
    Serial.println("Error initializing ESP-NOW");
    return;
  }

  // Register receive callback
  esp_now_register_recv_cb(OnDataRecv);

  Serial.println("Receiver ready with updated data structure...");

  // Optional: Test data transmission (uncomment to test)
  /*
  myData.Header = 2864434397;
  myData.timestamp = millis();
  myData.Xacc = 1.0;
  myData.Yacc = 2.0;
  myData.Zacc = 3.0;
  myData.Angaccx = 4.0;
  myData.Angaccy = 5.0;
  myData.Angaccz = 6.0;
  myData.roll = 10.5;
  myData.pitch = -5.2;
  myData.yaw = 45.7;
  myData.Magx = 11.0;
  myData.Magy = 12.0;
  myData.Magz = 13.0;
  myData.Temperature = 25.5;
  myData.Altitude = 217.0;
  myData.Pressure = 101325.0;
  myData.CompassHeading = 90.0;
  myData.GPSHeading = 95.2;
  myData.Sat = 8.0;
  myData.Lat = 31.5204;
  myData.Long = 74.3587;
  myData.GPSAlt = 218.5;
  myData.Distance = 15.3;
  myData.TotalDistance = 1250.7;

  while(1) {
    Serial.write((uint8_t*)&myData, sizeof(myData));
    delay(1000);
  }
  */
}

void loop() {
  // Nothing here - ESP-NOW handles reception via callback
  
  // Optional: Periodic status message
  static unsigned long lastStatus = 0;
  if (millis() - lastStatus > 10000) { // Every 10 seconds
    Serial.println("Receiver active - waiting for ESP-NOW data...");
    lastStatus = millis();
  }
  
  delay(100);
}