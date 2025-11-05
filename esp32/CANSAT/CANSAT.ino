#include <Wire.h>
#include <QMC5883LCompass.h>
#include <NMEAGPS.h>
#include <HardwareSerial.h>
#include "FS.h"
#include "SD.h"
#include "SPI.h"
#include <Adafruit_BMP085.h>
#include <Adafruit_MPU6050.h>
#include <Adafruit_Sensor.h>
#include <Adafruit_HMC5883_U.h>
#include <esp_now.h>
#include <esp_wifi.h>
#include <WiFi.h>
#include <math.h>

// Sensor objects
QMC5883LCompass compass;
Adafruit_MPU6050 mpu;
Adafruit_BMP085 bmp;
Adafruit_HMC5883_Unified mag = Adafruit_HMC5883_Unified(12345);
float sealevel;

// GPS objects
NMEAGPS gps;
gps_fix fix;
HardwareSerial gpsSerial(2); // UART2: RX=16, TX=17

// SD card chip select
#define SD_CS 5
File kmlFile;
File dataFile;
unsigned long lastSaveTime = 0;
int fileIndex = 0;

// SD card availability flags
bool sdAvailable = false;
bool kmlActive = false;

// Compass calibration values
int16_t Xmin = -505, Xmax = 1117;
int16_t Ymin = -758, Ymax = 1475;
int16_t Zmin = -3778, Zmax = 0;

// Distance tracking
double lastLat = 0.0;
double lastLon = 0.0;
double totalDistance = 0.0;
#define EARTH_RADIUS 6371000.0

// Time variables
String lastFormattedTime = "1970-01-01 00:00:00"; // Default fallback time

// ESP-NOW configuration
uint8_t broadcastAddress[] = {0x44, 0x1d, 0x64, 0xfa, 0x03, 0x34};  // 44:1d:64:fa:03:34

// Enhanced Data structure for ESP-NOW with roll, pitch, yaw
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

struct_message myData;
esp_now_peer_info_t peerInfo;
wifi_interface_t current_wifi_interface;

// Orientation calculation variables
float roll = 0.0, pitch = 0.0, yaw = 0.0;
unsigned long lastOrientationTime = 0;

// Function prototypes
double haversine(double lat1, double lon1, double lat2, double lon2);
double calculateHeading(double lat1, double lon1, double lat2, double lon2);
void startNewKML();
void readFile(fs::FS &fs, const char * path);
void writeFile(fs::FS &fs, const char * path, const char * message);
void appendFile(fs::FS &fs, const char * path, String message);
void deleteFile(fs::FS &fs, const char * path);
void displaySensorDetails(void);
void OnDataSent(const uint8_t *mac_addr, esp_now_send_status_t status);
String getLahoreTimestamp();
void updateTimeFromGPS();
void checkSDReconnect();
void safeAppendToFile(fs::FS &fs, const char *path, const String &message);
void safeAppendToKML(fs::FS &fs, const char *path, const String &message);
void calculateOrientation(float ax, float ay, float az, float gx, float gy, float gz);
void updateOrientation(float ax, float ay, float az, float gx, float gy, float gz);

// Check SD card reconnect
void checkSDReconnect() {
  if (!sdAvailable) {
    if (SD.begin(SD_CS)) {
      Serial.println("✅ SD card reconnected.");
      sdAvailable = true;

      // Ensure text file exists
      if (!SD.exists("/sensor_data.txt")) {
        writeFile(SD, "/sensor_data.txt",
          "Timestamp,Xacc,Yacc,Zacc,Angaccx,Angaccy,Angaccz,Roll,Pitch,Yaw,Magx,Magy,Magz,Temperature,Altitude,Pressure,CompassHeading,GPSHeading,Sat,Lat,Long,GPSAlt,Distance,TotalDistance\n");
      }

      // Ensure KML session is active
      if (!kmlActive) {
        startNewKML(); // fresh session
        kmlActive = true;
      }
    }
  }
}

// Safe Append for .txt
void safeAppendToFile(fs::FS &fs, const char *path, const String &message) {
  if (!sdAvailable) {
    Serial.println("⚠️ SD not available, skipping TXT log.");
    return;
  }

  File file = fs.open(path, FILE_APPEND);
  if (!file) {
    Serial.println("❌ Failed to open TXT file, disabling SD.");
    sdAvailable = false;
    return;
  }

  if (!file.print(message)) {
    Serial.println("❌ Append to TXT failed.");
  }
  file.close();
}

// Safe Append for .kml
void safeAppendToKML(fs::FS &fs, const char *path, const String &message) {
  if (!sdAvailable) {
    Serial.println("⚠️ SD not available, skipping KML log.");
    return;
  }

  File file = fs.open(path, FILE_APPEND);
  if (!file) {
    Serial.println("❌ Failed to open KML file, disabling SD.");
    sdAvailable = false;
    kmlActive = false;
    return;
  }

  if (!file.print(message)) {
    Serial.println("❌ Append to KML failed.");
  }
  file.close();
}

// Update current Lahore time directly from GPS
void updateTimeFromGPS() {
  if (fix.valid.time && fix.valid.date) {
    int gpsYear = fix.dateTime.year;
    if (gpsYear < 100) gpsYear += 2000;  // Handle YY → YYYY

    // Apply UTC+5 offset
    int hour = fix.dateTime.hours + 5;
    int day  = fix.dateTime.date;
    int month = fix.dateTime.month;
    int year  = gpsYear;
    int minute = fix.dateTime.minutes;
    int second = fix.dateTime.seconds;

    // Handle day/month rollover when hour >= 24
    if (hour >= 24) {
      hour -= 24;
      day += 1;
      
      // Handle month rollover
      if ((month == 1 || month == 3 || month == 5 || month == 7 || month == 8 || month == 10 || month == 12) && day > 31) {
        day = 1;
        month++;
      } else if ((month == 4 || month == 6 || month == 9 || month == 11) && day > 30) {
        day = 1;
        month++;
      } else if (month == 2) {
        // Simple leap year calculation (good until 2100)
        bool isLeapYear = (year % 4 == 0 && (year % 100 != 0 || year % 400 == 0));
        if (day > (isLeapYear ? 29 : 28)) {
          day = 1;
          month++;
        }
      }
      
      if (month > 12) {
        month = 1;
        year++;
      }
    }

    // Format the timestamp string
    char timestamp[25];
    sprintf(timestamp, "%04d-%02d-%02d %02d:%02d:%02d",
            year, month, day, hour, minute, second);

    // Store it in the global string
    lastFormattedTime = String(timestamp);
  }
}

// Global variable to track if GPS time is valid
bool gpsTimeAvailable = false;

// Getter for Lahore timestamp
String getLahoreTimestamp() {
  if (gpsTimeAvailable) {
    return lastFormattedTime;  // updated from GPS when satellites fix
  } else {
    // fallback: use millis() based local clock
    unsigned long ms = millis();
    int seconds = (ms / 1000) % 60;
    int minutes = (ms / 60000) % 60;
    int hours   = (ms / 3600000) % 24;

    char buffer[15];
    sprintf(buffer, "%02d:%02d:%02d", hours, minutes, seconds);
    return String(buffer);
  }
}

// ESP-NOW callback function
void OnDataSent(const uint8_t *mac_addr, esp_now_send_status_t status) {
  //Serial.print("\r\nLast Packet Send Status:\t");
  //Serial.println(status == ESP_NOW_SEND_SUCCESS ? "Delivery Success" : "Delivery Fail");
}

// Calculate roll, pitch, and yaw from accelerometer and gyroscope data
void calculateOrientation(float ax, float ay, float az, float gx, float gy, float gz) {
  // Calculate roll and pitch from accelerometer
  myData.roll = atan2(ay, az) * 180.0 / PI;
  myData.pitch = atan2(-ax, sqrt(ay * ay + az * az)) * 180.0 / PI;
  
  // Simple yaw from gyroscope (integrate Z-axis gyro)
  static unsigned long lastTime = 0;
  unsigned long currentTime = millis();
  if (lastTime > 0) {
    float dt = (currentTime - lastTime) / 1000.0; // Convert to seconds
    myData.yaw += gz * dt * 180.0 / PI; // Integrate gyro Z
  }
  lastTime = currentTime;
  
  // Keep yaw in 0-360 range
  if (myData.yaw < 0) myData.yaw += 360.0;
  if (myData.yaw >= 360.0) myData.yaw -= 360.0;
}

// Alternative orientation calculation using complementary filter
void updateOrientation(float ax, float ay, float az, float gx, float gy, float gz) {
  static unsigned long lastUpdate = 0;
  unsigned long now = millis();
  float dt = (now - lastUpdate) / 1000.0;
  
  if (lastUpdate == 0) {
    lastUpdate = now;
    return;
  }
  
  // Calculate roll and pitch from accelerometer (in radians)
  float rollAcc = atan2(ay, az);
  float pitchAcc = atan2(-ax, sqrt(ay * ay + az * az));
  
  // If this is the first reading, initialize with accelerometer values
  static bool firstReading = true;
  if (firstReading) {
    roll = rollAcc * 180.0 / PI;
    pitch = pitchAcc * 180.0 / PI;
    yaw = 0;
    firstReading = false;
    lastUpdate = now;
    return;
  }
  
  // Complementary filter coefficient
  float alpha = 0.96;
  
  // Convert current orientation to radians for gyro integration
  float rollRad = roll * PI / 180.0;
  float pitchRad = pitch * PI / 180.0;
  
  // Gyro integration (convert gyro rates to angle rates)
  float rollRate = gx + sin(rollRad) * tan(pitchRad) * gy + cos(rollRad) * tan(pitchRad) * gz;
  float pitchRate = cos(rollRad) * gy - sin(rollRad) * gz;
  float yawRate = sin(rollRad) / cos(pitchRad) * gy + cos(rollRad) / cos(pitchRad) * gz;
  
  // Integrate gyro rates
  roll += rollRate * dt * 180.0 / PI;
  pitch += pitchRate * dt * 180.0 / PI;
  yaw += yawRate * dt * 180.0 / PI;
  
  // Apply complementary filter
  roll = alpha * roll + (1.0 - alpha) * (rollAcc * 180.0 / PI);
  pitch = alpha * pitch + (1.0 - alpha) * (pitchAcc * 180.0 / PI);
  
  // Keep angles in reasonable ranges
  if (roll > 180) roll -= 360;
  if (roll < -180) roll += 360;
  if (pitch > 180) pitch -= 360;
  if (pitch < -180) pitch += 360;
  if (yaw < 0) yaw += 360;
  if (yaw >= 360) yaw -= 360;
  
  // Update the data structure
  myData.roll = roll;
  myData.pitch = pitch;
  myData.yaw = yaw;
  
  lastUpdate = now;
}

// Haversine distance calculation
double haversine(double lat1, double lon1, double lat2, double lon2) {
  double dLat = radians(lat2 - lat1);
  double dLon = radians(lon2 - lon1);
  double a = sin(dLat/2) * sin(dLat/2) +
             cos(radians(lat1)) * cos(radians(lat2)) *
             sin(dLon/2) * sin(dLon/2);
  double c = 2 * atan2(sqrt(a), sqrt(1-a));
  return EARTH_RADIUS * c;
}

// Calculate heading from GPS coordinates
double calculateHeading(double lat1, double lon1, double lat2, double lon2) {
  double dLon = radians(lon2 - lon1);
  double y = sin(dLon) * cos(radians(lat2));
  double x = cos(radians(lat1)) * sin(radians(lat2)) -
             sin(radians(lat1)) * cos(radians(lat2)) * cos(dLon);
  double heading = degrees(atan2(y, x));
  if (heading < 0) heading += 360.0;
  return heading;
}

// Start a new KML file
void startNewKML() {
  if (kmlFile) {
    kmlFile.println("</coordinates>");
    kmlFile.println("</LineString>");
    kmlFile.println("</Placemark>");
    kmlFile.println("</Document>");
    kmlFile.println("</kml>");
    kmlFile.flush();
    kmlFile.close();
  }

  String filename = "/gps_" + String(fileIndex) + ".kml";
  kmlFile = SD.open(filename.c_str(), FILE_WRITE);

  if (kmlFile) {
    Serial.print("📂 New file created: ");
    Serial.println(filename);
    kmlFile.println("<?xml version=\"1.0\" encoding=\"UTF-8\"?>");
    kmlFile.println("<kml xmlns=\"http://www.opengis.net/kml/2.2\">");
    kmlFile.println("<Document>");
    kmlFile.println("<name>GPS Path</name>");
    kmlFile.println("<Placemark>");
    kmlFile.println("<LineString>");
    kmlFile.println("<tessellate>1</tessellate>");
    kmlFile.println("<coordinates>");
    kmlFile.flush();
    kmlActive = true;
  } else {
    Serial.println("❌ Failed to create new KML file!");
    kmlActive = false;
  }
}

// SD Card Functions
void readFile(fs::FS &fs, const char * path) {
  Serial.printf("Reading file: %s\n", path);
  File file = fs.open(path);
  if (!file) {
    Serial.println("Failed to open file for reading");
    return;
  }
  while (file.available()) {
    Serial.write(file.read());
  }
  file.close();
}

void writeFile(fs::FS &fs, const char * path, const char * message) {
  Serial.printf("Writing file: %s\n", path);
  File file = fs.open(path, FILE_WRITE);
  if (!file) {
    Serial.println("Failed to open file for writing");
    return;
  }
  if (file.print(message)) {
    Serial.println("File written");
  } else {
    Serial.println("Write failed");
  }
  file.close();
}

void appendFile(fs::FS &fs, const char * path, String message) {
  File file = fs.open(path, FILE_APPEND);
  if (!file) {
    Serial.println("Failed to open file for appending");
    return;
  }
  if (file.print(message)) {
    // Success message commented out to reduce serial clutter
  } else {
    Serial.println("Append failed");
  }
  file.close();
}

void deleteFile(fs::FS &fs, const char * path) {
  Serial.printf("Deleting file: %s\n", path);
  if (fs.remove(path)) {
    Serial.println("File deleted");
  } else {
    Serial.println("Delete failed");
  }
}

// HMC5883L sensor details
void displaySensorDetails(void) {
  sensor_t sensor;
  mag.getSensor(&sensor);
  Serial.println("------------------------------------");
  Serial.print ("Sensor: "); Serial.println(sensor.name);
  Serial.print ("Driver Ver: "); Serial.println(sensor.version);
  Serial.print ("Unique ID: "); Serial.println(sensor.sensor_id);
  Serial.print ("Max Value: "); Serial.print(sensor.max_value); Serial.println(" uT");
  Serial.print ("Min Value: "); Serial.print(sensor.min_value); Serial.println(" uT");
  Serial.print ("Resolution: "); Serial.print(sensor.resolution); Serial.println(" uT");
  Serial.println("------------------------------------");
  Serial.println("");
  delay(500);
}

void setup() {
  Serial.begin(115200);
  gpsSerial.begin(9600, SERIAL_8N1, 16, 17);
  
  // Initialize compass
  Wire.begin();
  compass.init();
  
  // Initialize BMP180
  if (!bmp.begin()) {
    Serial.println("Could not find a valid BMP085 sensor, check wiring!");
    while (1) {}
  }
  sealevel = bmp.readPressure();
  Serial.print("Sea level pressure: ");
  Serial.println(sealevel);

  // Initialize SD card (with failure handling)
  if (!SD.begin(SD_CS)) {
    Serial.println("⚠️ Card Mount Failed, continuing without SD logging.");
    sdAvailable = false;
  } else {
    sdAvailable = true;
    uint8_t cardType = SD.cardType();
    if (cardType == CARD_NONE) {
      Serial.println("No SD card attached");
      sdAvailable = false;
    } else {
      Serial.print("SD Card Type: ");
      if (cardType == CARD_MMC) {
        Serial.println("MMC");
      } else if (cardType == CARD_SD) {
        Serial.println("SDSC");
      } else if (cardType == CARD_SDHC) {
        Serial.println("SDHC");
      } else {
        Serial.println("UNKNOWN");
      }
      
      uint64_t cardSize = SD.cardSize() / (1024 * 1024);
      Serial.printf("SD Card Size: %lluMB\n", cardSize);
      
      // Write header to data file with timestamp column and orientation fields
      writeFile(SD, "/sensor_data.txt", "Timestamp,Xacc,Yacc,Zacc,Angaccx,Angaccy,Angaccz,Roll,Pitch,Yaw,Magx,Magy,Magz,Temperature,Altitude,Pressure,CompassHeading,GPSHeading,Sat,Lat,Long,GPSAlt,Distance,TotalDistance\n");
      
      Serial.printf("Total space: %lluMB\n", SD.totalBytes() / (1024 * 1024));
      Serial.printf("Used space: %lluMB\n", SD.usedBytes() / (1024 * 1024));
    }
  }

  // Initialize MPU6050
  Serial.println("Adafruit MPU6050 test!");
  if (!mpu.begin()) {
    Serial.println("Failed to find MPU6050 chip");
    while (1) {
      delay(10);
    }
  }
  
  Serial.println("MPU6050 Found!");
  mpu.setAccelerometerRange(MPU6050_RANGE_8_G);
  mpu.setGyroRange(MPU6050_RANGE_500_DEG);
  mpu.setFilterBandwidth(MPU6050_BAND_21_HZ);

  // Initialize HMC5883
  if (!mag.begin()) {
    Serial.println("Ooops, no HMC5883 detected ... Check your wiring!");
    while (1);
  }
  
  displaySensorDetails();

  // Initialize ESP-NOW
  WiFi.mode(WIFI_STA);
  if (esp_wifi_set_protocol(current_wifi_interface, WIFI_PROTOCOL_LR) != ESP_OK) {
    Serial.println("Error initializing WIFI LR");
    return;
  }
  
  WiFi.setTxPower(WIFI_POWER_19_5dBm);
  
  if (esp_now_init() != ESP_OK) {
    Serial.println("Error initializing ESP-NOW");
    return;
  }
  
  esp_now_register_send_cb(OnDataSent);
  
  memcpy(peerInfo.peer_addr, broadcastAddress, 6);
  peerInfo.channel = 0;
  peerInfo.encrypt = false;
  
  if (esp_now_add_peer(&peerInfo) != ESP_OK) {
    Serial.println("Failed to add peer");
    return;
  }

  // Initialize buzzer
  pinMode(4, OUTPUT);
  digitalWrite(4, HIGH);
  delay(100);

  // Set header for data structure
  myData.Header = 2864434397;

  // Start first KML file if SD card is available
  if (sdAvailable) {
    startNewKML();
  }
  lastSaveTime = millis();

  Serial.println("All sensors initialized successfully!");
  Serial.println("📡 NEO-6M GPS with distance & heading logging");
  if (sdAvailable) {
    Serial.println("✅ SD Card initialized.");
  } else {
    Serial.println("⚠️ SD Card not available, continuing without SD logging.");
  }
}

void loop() {
  checkSDReconnect();
  
  // Get timestamp
  unsigned long currentMillis = millis();
  myData.timestamp = currentMillis;
  
  // Read compass data
  compass.read();
  int x = compass.getX();
  int y = compass.getY();
  int z = compass.getZ();

  // Apply calibration (normalize to -1 … +1)
  float x_norm = ((float)x - (Xmin + Xmax) / 2.0) / ((Xmax - Xmin) / 2.0);
  float y_norm = ((float)y - (Ymin + Ymax) / 2.0) / ((Ymax - Ymin) / 2.0);
  float z_norm = ((float)z - (Zmin + Zmax) / 2.0) / ((Zmax - Zmin) / 2.0);

  // Scale to Earth magnetic field (~48 µT in Lahore)
  float earthField = 48.0; // µT
  myData.Magx = x_norm * earthField;
  myData.Magy = y_norm * earthField;
  myData.Magz = z_norm * earthField;

  // Compute heading from compass
  float compassHeading = atan2(y_norm, x_norm) * 180.0 / PI;
  if (compassHeading < 0) compassHeading += 360.0;
  myData.CompassHeading = compassHeading;

  // Convert heading to cardinal direction
  String direction;
  if (compassHeading >= 337.5 || compassHeading < 22.5)  direction = "N";
  else if (compassHeading >= 22.5 && compassHeading < 67.5)  direction = "NE";
  else if (compassHeading >= 67.5 && compassHeading < 112.5) direction = "E";
  else if (compassHeading >= 112.5 && compassHeading < 157.5) direction = "SE";
  else if (compassHeading >= 157.5 && compassHeading < 202.5) direction = "S";
  else if (compassHeading >= 202.5 && compassHeading < 247.5) direction = "SW";
  else if (compassHeading >= 247.5 && compassHeading < 292.5) direction = "W";
  else if (compassHeading >= 292.5 && compassHeading < 337.5) direction = "NW";

  // Read MPU6050 data
  sensors_event_t a, g, temp;
  mpu.getEvent(&a, &g, &temp);
  myData.Xacc = a.acceleration.x;
  myData.Yacc = a.acceleration.y;
  myData.Zacc = a.acceleration.z;
  myData.Angaccx = g.gyro.x;
  myData.Angaccy = g.gyro.y;
  myData.Angaccz = g.gyro.z;

  // Calculate orientation (roll, pitch, yaw)
  updateOrientation(myData.Xacc, myData.Yacc, myData.Zacc, 
                   myData.Angaccx, myData.Angaccy, myData.Angaccz);

  // Read BMP180 data
  myData.Temperature = bmp.readTemperature();
  myData.Pressure = bmp.readPressure();
  myData.Altitude = bmp.readAltitude(sealevel);

  // Process GPS data
  bool newGPSData = false;
  double distance = 0.0;
  myData.GPSHeading = 0.0;
  
  while (gps.available(gpsSerial)) {
    fix = gps.read();
    newGPSData = true;
    
    // Update time from GPS if available
    updateTimeFromGPS();
    
    if (fix.valid.location) {
      myData.Lat = fix.latitude();
      myData.Long = fix.longitude();
      
      // Calculate distance and heading from GPS
      if (lastLat != 0.0 && lastLon != 0.0) {
        distance = haversine(lastLat, lastLon, myData.Lat, myData.Long);
        totalDistance += distance;
        myData.GPSHeading = calculateHeading(lastLat, lastLon, myData.Lat, myData.Long);
      }
      lastLat = myData.Lat;
      lastLon = myData.Long;
      
      myData.Distance = distance;
      myData.TotalDistance = totalDistance;
    }
    
    if (fix.valid.altitude) {
      myData.GPSAlt = fix.altitude();
    }
    
    if (fix.valid.satellites) {
      myData.Sat = fix.satellites;
    }
    
    // Save GPS data to KML file if SD card is available
    if (sdAvailable && kmlActive && fix.valid.location) {
      String kml_entry = String(fix.longitude(), 6) + "," +
                         String(fix.latitude(), 6) + ",";
      
      if (fix.valid.altitude) {
        kml_entry += String(fix.altitude());
      } else {
        kml_entry += "0";
      }
      kml_entry += "\n";
      
      safeAppendToKML(SD, ("/gps_" + String(fileIndex) + ".kml").c_str(), kml_entry);
    }
  }

  // Write sensor data to SD Card with timestamp (if available)
  String lahoreTime = getLahoreTimestamp();
  String sd_text = lahoreTime + "," + 
                  String(myData.Xacc) + "," + 
                  String(myData.Yacc) + "," + 
                  String(myData.Zacc) + "," + 
                  String(myData.Angaccx) + "," + 
                  String(myData.Angaccy) + "," + 
                  String(myData.Angaccz) + "," + 
                  String(myData.roll) + "," + 
                  String(myData.pitch) + "," + 
                  String(myData.yaw) + "," + 
                  String(myData.Magx) + "," + 
                  String(myData.Magy) + "," + 
                  String(myData.Magz) + "," + 
                  String(myData.Temperature) + "," + 
                  String(myData.Altitude) + "," + 
                  String(myData.Pressure) + "," + 
                  String(myData.CompassHeading) + "," + 
                  String(myData.GPSHeading) + "," + 
                  String(myData.Sat) + "," + 
                  String(myData.Lat, 6) + "," + 
                  String(myData.Long, 6) + "," + 
                  String(myData.GPSAlt) + "," +
                  String(myData.Distance) + "," +
                  String(myData.TotalDistance) + "\n";
                  
  safeAppendToFile(SD, "/sensor_data.txt", sd_text);

  // Send data via ESP-NOW
  esp_err_t result = esp_now_send(broadcastAddress, (uint8_t *) &myData, sizeof(myData));
  if (result == ESP_OK) {
    Serial.println("Sent with success");
  } else {
    Serial.println("Error sending the data");
  }

  // Display data on Serial Monitor
  Serial.println("====== GPS & Sensor Data ======");
  
  if (fix.valid.time && fix.valid.date) {
    Serial.print("GPS UTC Time: ");
    Serial.printf("%04d-%02d-%02d %02d:%02d:%02d\n",
                  fix.dateTime.year, fix.dateTime.month, fix.dateTime.date,
                  fix.dateTime.hours, fix.dateTime.minutes, fix.dateTime.seconds);

    Serial.print("Lahore Local Time: ");
    Serial.println(getLahoreTimestamp());
  }
  
  if (fix.valid.location) {
    Serial.print("Latitude: "); Serial.println(myData.Lat, 6);
    Serial.print("Longitude: "); Serial.println(myData.Long, 6);
    Serial.print("Distance from last point (m): "); Serial.println(myData.Distance, 2);
    Serial.print("Total distance (m): "); Serial.println(myData.TotalDistance, 2);
    Serial.print("GPS Heading (°): "); Serial.println(myData.GPSHeading, 2);
  } else {
    Serial.println("Latitude: (not fixed)");
    Serial.println("Longitude: (not fixed)");
    Serial.println("Distance from last point (m): 0.00");
    Serial.print("Total distance (m): "); Serial.println(myData.TotalDistance, 2);
    Serial.println("GPS Heading (°): 0.00");
  }

  Serial.print("Altitude: ");
  if (fix.valid.altitude) Serial.print(myData.GPSAlt);
  else Serial.print("0");
  Serial.println(" m");

  Serial.print("Satellites: ");
  if (fix.valid.satellites) Serial.println(myData.Sat);
  else Serial.println("0");

  Serial.print("Speed: ");
  if (fix.valid.speed) Serial.print(fix.speed_kph(), 2);
  else Serial.print("0.00");
  Serial.println(" km/h");

  // New orientation data display
  Serial.print("Orientation - Roll: "); Serial.print(myData.roll, 2);
  Serial.print("°, Pitch: "); Serial.print(myData.pitch, 2);
  Serial.print("°, Yaw: "); Serial.print(myData.yaw, 2); Serial.println("°");

  Serial.print("Compass X: "); Serial.print(myData.Magx, 2); Serial.print(" µT, ");
  Serial.print("Y: "); Serial.print(myData.Magy, 2); Serial.print(" µT, ");
  Serial.print("Z: "); Serial.print(myData.Magz, 2); Serial.println(" µT");
  
  Serial.print("Compass Heading: "); Serial.print(myData.CompassHeading, 1);
  Serial.print("° Direction: "); Serial.println(direction);
  
  Serial.print("Acceleration X: "); Serial.print(myData.Xacc);
  Serial.print(", Y: "); Serial.print(myData.Yacc);
  Serial.print(", Z: "); Serial.print(myData.Zacc);
  Serial.println(" m/s^2");
  
  Serial.print("Rotation X: "); Serial.print(myData.Angaccx);
  Serial.print(", Y: "); Serial.print(myData.Angaccy);
  Serial.print(", Z: "); Serial.print(myData.Angaccz);
  Serial.println(" rad/s");
  
  Serial.print("Temperature: "); Serial.print(myData.Temperature);
  Serial.println(" *C");
  
  Serial.print("Pressure: "); Serial.print(myData.Pressure);
  Serial.println(" Pa");
  
  Serial.print("Baro Altitude: "); Serial.print(myData.Altitude);
  Serial.println(" meters");
  
  Serial.print("Lahore Time: "); Serial.println(lahoreTime);
  Serial.println("=====================\n");

 if (myData.Altitude <= 1) // THIS SHOULD BE CHANGED BASED ON THE LOCATION
    {
      digitalWrite(4, LOW);
      //Serial.print("Buzzer On");
    } else {
      digitalWrite(4, LOW);
      //Serial.print("Buzzer Off");
    }

  // Create new KML file every 2 minutes (if SD card is available)
  if (sdAvailable && millis() - lastSaveTime >= 120000) {
    fileIndex++;
    startNewKML();
    lastSaveTime = millis();
  }

  delay(1000); // Delay between readings
}