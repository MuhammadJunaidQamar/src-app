#include <NMEAGPS.h>
#include <HardwareSerial.h>
#include "FS.h"
#include "SD.h"
#include "SPI.h"
#include <Adafruit_BMP085_U.h>
#include <Adafruit_MPU6050.h>
#include <Adafruit_Sensor.h>
#include <Wire.h>
#include <esp_now.h>
#include <esp_wifi.h>
#include <WiFi.h>
#include <MechaQMC5883.h>



#define BAUDRATE 115200
#define SET   1
#define RESET 0
#define DELAY_AFTER_WIRED_TX   3
#define DELAY_AFTER_WIFI_TX    3


// Configure Communication Channel (wired vs wireless), Sensors to poll, and their poll periods

  uint8_t flag_Wifi_Comm = SET;              // SET --> Wifi Transmission, RESET -->Serial Transmission on selected COM port
  
  uint8_t flag_send_full_sensor_data = SET;
  uint8_t flag_read_MPU      = SET;
  uint8_t flag_read_Mag      = SET;
  uint8_t flag_read_GPS      = SET;
  uint8_t flag_read_Temp     =  SET;
  uint8_t flag_read_Alt      =  SET;
  uint8_t flag_read_Pressure = SET;

  unsigned long sent_pkt_count, dropped_pkt_count, tic_status_msg, toc_status_msg, toc;
  unsigned long tic_env, tic_Alt, tic_GPS, tic_send;
  unsigned long T_env = 2000, T_Alt = 1000, T_GPS = 1000, T_status_msg;
  // ESP-NOW TX period (ms). 50 ms = 20 Hz — matches the app's display rate and
  // leaves the 2.4 GHz channel free for the ESP32-CAM's packet bursts.
  // The old code sent every ~3 ms (~300 Hz) which starved the camera.
  unsigned long T_send = 50;
  uint8_t ref_alt = 217;                   // Lahore's Altitude with reference to Sea Level




// Sensor objects
Adafruit_MPU6050 mpu;
Adafruit_BMP085_Unified bmp(10085);
MechaQMC5883 qmc;

float seaLevelPressure, baseLinePressure;

// GPS objects
NMEAGPS gps;
gps_fix fix;
HardwareSerial gpsSerial(2); // UART2: RX=16, TX=17

// SD card chip select (use correct pin for your module)
#define SD_CS 5
File kmlFile;
unsigned long lastSaveTime = 0;
int fileIndex = 0; // counter for filenames
bool sdCardAvailable = false; // Flag to track SD card status

/*----------------------------------WIFI Starts-------------------------------------------*/
// !! MUST match the MAC your ground station prints at boot:
//   Router GS: "GS MAC      : XX:XX:..."  (STA MAC)
//   Wi-Fi GS : "GS MAC (AP) : XX:XX:..."  (AP MAC — different from STA!)
//   BLE GS   : "[BOOT] MAC ..."
uint8_t broadcastAddress[] = {0x28, 0x56, 0x2f, 0x49, 0xc0, 0xc8}; //28:56:2f:49:c0:c8
// uint8_t broadcastAddress[] = {0x6c, 0xc8, 0x40, 0x44, 0x94, 0xb8};  //gs1
//uint8_t broadcastAddress[] = {0x44, 0x1D, 0x64, 0xFB, 0xD0, 0x0C};  //gs1
//44:1d:64:f2:d2:e0

// Fallback only. At boot we probe channels 1–13 and lock onto the one where
// the ground station ACKs (needed for Router GS — its channel is decided by
// the router, often not channel 1).
#define CANSAT_FALLBACK_CHANNEL 1

//struct for RF Data
typedef struct struct_message {
  unsigned long Header;               
  float Temperature;
  float Altitude;
  float Pressure;
  float Heading;
  float Xacc;
  float Yacc;
  float Zacc;
  float Angaccx;
  float Angaccy;
  float Angaccz;
  float Magx;
  float Magy;
  float Magz;
  float Sat;
  float Lat;
  float Long;
  float GPSAlt;
  unsigned long TimeStamp;
} struct_message;

typedef struct imu_message {
  float Xacc;
  float Yacc;
  float Zacc;
  float Angaccx;
  float Angaccy;
  float Angaccz;
  float Magx;
  float Magy;
  float Magz;
 } IMU_reading_m;




struct_message myData;
IMU_reading_m imu_reading;
esp_now_peer_info_t peerInfo;

// MAC-layer ACK from the peer — used for channel probing + link watchdog.
volatile bool sendStatusKnown = false;
volatile bool sendOk = false;
uint8_t lockedChannel = CANSAT_FALLBACK_CHANNEL;
bool gsLinked = false;
unsigned long lastAckOkMs = 0;
unsigned long lastChannelProbeMs = 0;

// ESP-NOW fail ACKs can take >30 ms; wait long enough that timeouts count.
#define SEND_ACK_WAIT_MS 200
// Don't channel-hop too often — a full 1–13 scan blocks TX for seconds and
// starves SoftAP / BLE GS on channel 1 when ACKs are flaky.
#define LINK_REPROBE_MS  10000

void OnDataSent(const wifi_tx_info_t *tx_info, esp_now_send_status_t status) {
  (void)tx_info;
  sendOk = (status == ESP_NOW_SEND_SUCCESS);
  sendStatusKnown = true;
}

// Returns true if the send callback fired within timeoutMs.
bool waitForSendStatus(uint32_t timeoutMs) {
  uint32_t t0 = millis();
  while (!sendStatusKnown && (millis() - t0) < timeoutMs) {
    delay(1);
  }
  return sendStatusKnown;
}

// A unicast frame is ACKed by the radio that owns broadcastAddress —
// success means "GS is on this channel".
bool probeChannel(uint8_t ch) {
  esp_wifi_set_channel(ch, WIFI_SECOND_CHAN_NONE);
  delay(5);

  for (int attempt = 0; attempt < 3; attempt++) {
    sendStatusKnown = false;
    uint8_t probe = 0xC5; // 1-byte; ground stations ignore unknown lengths
    if (esp_now_send(broadcastAddress, &probe, 1) != ESP_OK) {
      delay(10);
      continue;
    }
    waitForSendStatus(SEND_ACK_WAIT_MS);
    if (sendStatusKnown && sendOk) return true;
  }
  return false;
}

// Scan channels. Prefer last lock + ch 1 (Wi‑Fi SoftAP / BLE default) first
// so SoftAP recovery is fast and we spend less time off-channel.
bool findGroundStationChannel() {
  lastChannelProbeMs = millis();
  Serial.println("[CANSAT] searching for ground station channel...");

  uint8_t order[13];
  uint8_t n = 0;

  // Build unique channel order: locked → 1 → 2..13
  if (lockedChannel >= 1 && lockedChannel <= 13) {
    order[n++] = lockedChannel;
  }
  if (lockedChannel != 1) {
    order[n++] = 1;
  }
  for (uint8_t ch = 2; ch <= 13; ch++) {
    if (ch == lockedChannel) continue;
    order[n++] = ch;
  }

  for (uint8_t i = 0; i < n; i++) {
    const uint8_t ch = order[i];
    if (probeChannel(ch)) {
      lockedChannel = ch;
      gsLinked = true;
      lastAckOkMs = millis();
      Serial.printf("[CANSAT] ground station found on channel %u\n", ch);
      return true;
    }
  }

  // Stay on last known / ch 1 so SoftAP/BLE still hear packets between probes
  // even when MAC ACKs are unreliable.
  if (lockedChannel < 1 || lockedChannel > 13) lockedChannel = CANSAT_FALLBACK_CHANNEL;
  gsLinked = false;
  Serial.printf("[CANSAT] GS not found — TX stays on ch %u (will retry).\n",
                (unsigned)lockedChannel);
  Serial.println("[CANSAT] Check broadcastAddress matches the GS boot print!");
  Serial.println("[CANSAT] Wi-Fi SoftAP GS → use GS MAC (AP), not STA.");
  esp_wifi_set_channel(lockedChannel, WIFI_SECOND_CHAN_NONE);
  return false;
}

// Boot / recovery: retry full scans until GS is up (or attempts exhausted).
bool findGroundStationChannelWithRetries(int maxRounds, uint32_t gapMs) {
  for (int round = 1; round <= maxRounds; round++) {
    if (findGroundStationChannel()) return true;
    if (round < maxRounds) {
      Serial.printf("[CANSAT] GS not ready (try %d/%d) — waiting %lu ms\n",
                    round, maxRounds, (unsigned long)gapMs);
      delay(gapMs);
    }
  }
  return false;
}
/*----------------------------------WIFI Ends-------------------------------------------*/

/*--------------------------------SD CARD Functions-----------------------------------------*/
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
    // Serial.println("Message appended");
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


/*--------------------------------KML File Functions-----------------------------------------*/
// Function to start a new KML file
void startNewKML() {
  if (!sdCardAvailable) return;
  
  if (kmlFile) {
    // close previous file with footer
    kmlFile.println("</coordinates>");
    kmlFile.println("</LineString>");
    kmlFile.println("</Placemark>");
    kmlFile.println("</Document>");
    kmlFile.println("</kml>");
    kmlFile.flush();
    kmlFile.close();
  }

  // create a new file with unique name
  String filename = "/gps_" + String(fileIndex++) + ".kml";
  kmlFile = SD.open(filename.c_str(), FILE_WRITE);
  
  if (kmlFile) {
    Serial.print("New file created: ");
    Serial.println(filename);
    
    // Write KML header
    kmlFile.println("<?xml version=\"1.0\" encoding=\"UTF-8\"?>");
    kmlFile.println("<kml xmlns=\"http://www.opengis.net/kml/2.2\">");
    kmlFile.println("<Document>");
    kmlFile.println("<name>GPS Path</name>");
    kmlFile.println("<Placemark>");
    kmlFile.println("<LineString>");
    kmlFile.println("<tessellate>1</tessellate>");
    kmlFile.println("<coordinates>");
    kmlFile.flush();
  } else {
    Serial.println("Failed to create new KML file!");
  }
}

void setup() {
  Serial.begin(BAUDRATE);
  gpsSerial.begin(9600, SERIAL_8N1, 16, 17); // Initialize GPS serial

  // BMP180 configuration
  if (!bmp.begin()) {
    Serial.println("Could not find a valid BMP085 sensor, check wiring!");
    while (1) {}
  }

  Wire.begin();
  //compass.init();
  qmc.init();
  Serial.println("QMC5883L Compass with Calibration (µT output)");


  //seaLevelPressure = bmp.readPressure();
  {
    float p_sea;
    bmp.getPressure(&p_sea);
    seaLevelPressure = bmp.seaLevelForAltitude((float)ref_alt, p_sea);  // Lahore altitude (m): extrapolated sea-level pressure
  }
  Serial.println("Sea level pressure: ");
  Serial.println(seaLevelPressure);

  baseLinePressure = 0;                            // Calculations of baseline pressure for relative altitude calculation 
  for (int i = 0; i < 5; i++) {
    float p;
    bmp.getPressure(&p);
    baseLinePressure += p;
    delay(50);
  }
  baseLinePressure = baseLinePressure / 5;


  // SD card configuration - Modified to handle mount failures
  Serial.println("Initializing SD card...");
  if (!SD.begin(SD_CS)) {
    Serial.println("Card Mount Failed - Continuing without SD card");
    sdCardAvailable = false;
  } else {
    uint8_t cardType = SD.cardType();
    if (cardType == CARD_NONE) {
      Serial.println("No SD card attached - Continuing without SD card");
      sdCardAvailable = false;
    } else {
      sdCardAvailable = true;
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
      
      // Only try to write file if SD card is available
      if (sdCardAvailable) {
        writeFile(SD, "/sensor_data.txt", "Xacc,Yacc,Zacc,Angaccx,Angaccy,Angaccz,Magx,Magy,Magz,Temperature,Altitude,Heading,Sat,Lat,Long,GPSAlt\n");
        
        Serial.printf("Total space: %lluMB\n", SD.totalBytes() / (1024 * 1024));
        Serial.printf("Used space: %lluMB\n", SD.usedBytes() / (1024 * 1024));
      }
    }
  }

  // MPU6050 configuration
  Serial.println("Adafruit MPU6050 test!");
  
  // Try to initialize!
  if (!mpu.begin()) {
    Serial.println("Failed to find MPU6050 chip");
    while (1) {
      delay(10);
    }
  }
  
  Serial.println("MPU6050 Found!");
  mpu.setAccelerometerRange(MPU6050_RANGE_2_G);
  
  Serial.print("Accelerometer range set to: ");
  switch (mpu.getAccelerometerRange()) {
    case MPU6050_RANGE_2_G:
      Serial.println("+-2G");
      break;
    case MPU6050_RANGE_4_G:
      Serial.println("+-4G");
      break;
    case MPU6050_RANGE_8_G:
      Serial.println("+-8G");
      break;
    case MPU6050_RANGE_16_G:
      Serial.println("+-16G");
      break;
  }
  
  mpu.setGyroRange(MPU6050_RANGE_500_DEG);
  Serial.print("Gyro range set to: ");
  switch (mpu.getGyroRange()) {
    case MPU6050_RANGE_250_DEG:
      Serial.println("+- 250 deg/s");
      break;
    case MPU6050_RANGE_500_DEG:
      Serial.println("+- 500 deg/s");
      break;
    case MPU6050_RANGE_1000_DEG:
      Serial.println("+- 1000 deg/s");
      break;
    case MPU6050_RANGE_2000_DEG:
      Serial.println("+- 2000 deg/s");
      break;
  }
  mpu.setFilterBandwidth(MPU6050_BAND_184_HZ);
  
  Serial.print("Filter bandwidth set to: ");
  switch (mpu.getFilterBandwidth()) {
    case MPU6050_BAND_260_HZ:
      Serial.println("260 Hz");
      break;
    case MPU6050_BAND_184_HZ:
      Serial.println("184 Hz");
      break;
    case MPU6050_BAND_94_HZ:
      Serial.println("94 Hz");
      break;
    case MPU6050_BAND_44_HZ:
      Serial.println("44 Hz");
      break;
    case MPU6050_BAND_21_HZ:
      Serial.println("21 Hz");
      break;
    case MPU6050_BAND_10_HZ:
      Serial.println("10 Hz");
      break;
    case MPU6050_BAND_5_HZ:
      Serial.println("5 Hz");
      break;
  }

  

  // Wifi / ESP-NOW configuration
  // Use standard 11b/g/n (NOT LR-only). Router / Wi‑Fi / BLE ground stations
  // speak normal Wi‑Fi — LR-only TX never reaches them.
  WiFi.mode(WIFI_STA);
  WiFi.setSleep(false);
  esp_wifi_set_protocol(WIFI_IF_STA,
                        WIFI_PROTOCOL_11B | WIFI_PROTOCOL_11G | WIFI_PROTOCOL_11N);
  WiFi.setTxPower(WIFI_POWER_19_5dBm);

  if (esp_now_init() != ESP_OK) {
    Serial.println("Error initializing ESP-NOW");
    return;
  }

  esp_now_register_send_cb(OnDataSent);

  // Register peer (channel 0 = follow the radio's current channel)
  memcpy(peerInfo.peer_addr, broadcastAddress, 6);
  peerInfo.channel = 0;
  peerInfo.encrypt = false;

  if (esp_now_add_peer(&peerInfo) != ESP_OK) {
    Serial.println("Failed to add peer — check broadcastAddress MAC");
    return;
  }

  // Probe channels 1–13 (retry — GS may still be joining the router).
  findGroundStationChannelWithRetries(5, 2000);
  Serial.printf("[CANSAT] peer MAC %02X:%02X:%02X:%02X:%02X:%02X | ch=%u | link=%s\n",
                broadcastAddress[0], broadcastAddress[1], broadcastAddress[2],
                broadcastAddress[3], broadcastAddress[4], broadcastAddress[5],
                (unsigned)lockedChannel, gsLinked ? "OK" : "WAITING");

  // Buzzer configuration
  pinMode(4, OUTPUT);
  digitalWrite(4, HIGH);
  delay(100);

  // Start first KML file for GPS data (only if SD card is available)
  if (sdCardAvailable) {
    startNewKML();
  }
  lastSaveTime = millis();
  delay(4000);


  sent_pkt_count = 0;
  dropped_pkt_count = 1;
  tic_status_msg = millis();
  tic_env = millis();
  tic_Alt = millis();
  tic_GPS = millis();
  tic_send = millis();
  
}

void loop() {

  // 1- mpu6050 gets data
  sensors_event_t a, g, temp;
  myData.TimeStamp = millis();
  if(flag_read_MPU){
    mpu.getEvent(&a, &g, &temp);

    imu_reading.Xacc = a.acceleration.x;
    imu_reading.Yacc = a.acceleration.y;
    imu_reading.Zacc = a.acceleration.z;
    imu_reading.Angaccx =  g.gyro.x;
    imu_reading.Angaccy =  g.gyro.y;
    imu_reading.Angaccz =  g.gyro.z;

    myData.Xacc = a.acceleration.x;
    myData.Yacc = a.acceleration.y;
    myData.Zacc = a.acceleration.z;
    myData.Angaccx =  g.gyro.x;
    myData.Angaccy =  g.gyro.y;
    myData.Angaccz =  g.gyro.z;
    //delay(1);
  }


  // 2---- Magnetometer
  if(flag_read_Mag){

    int x, y, z;
    int16_t x_, y_, z_;
    int a;
    float mx, my, mz, m;
    float heading;
    
    qmc.read(&x, &y, &z, &a);
    
    x_ = (int16_t) x;
    y_ = (int16_t) y;
    z_ = (int16_t) z;

    mx = x_ * 0.008333;
    my = y_ * 0.008333;
    mz = z_ * 0.008333;
    m = sqrt (mx*mx + my* my + mz* mz);
    heading = atan2((float)my, (float)mx) * 180.0 / PI;

    //  Serial.print("X: "); Serial.print( mx);
    //  Serial.print("  Y: "); Serial.print(my);
    //  Serial.print("  Z: "); Serial.print(mz);
    //  Serial.print("  Mag: "); Serial.print(m);
    // Serial.print("  Heading: "); Serial.print(a);
    // Serial.print("  Heading_local: "); Serial.print(heading);
    // Serial.println("°");



    myData.Magx = mx;
    myData.Magy = my;
    myData.Magz = mz;


    myData.Heading = heading;

      // Convert heading to cardinal direction
    String direction;
    if (heading >= 337.5 || heading < 22.5)  direction = "N";
    else if (heading >= 22.5 && heading < 67.5)  direction = "NE";
    else if (heading >= 67.5 && heading < 112.5) direction = "E";
    else if (heading >= 112.5 && heading < 157.5) direction = "SE";
    else if (heading >= 157.5 && heading < 202.5) direction = "S";
    else if (heading >= 202.5 && heading < 247.5) direction = "SW";
    else if (heading >= 247.5 && heading < 292.5) direction = "W";
    else if (heading >= 292.5 && heading < 337.5) direction = "NW";
  }


  // 3 --- bmp Reading
  toc = millis();
  if( (toc - tic_env) > T_env){
    if(flag_read_Temp ) {
      float t;
      bmp.getTemperature(&t);
      myData.Temperature = t;
    }
    if(flag_read_Pressure ) {
      float pr;
      bmp.getPressure(&pr);
      myData.Pressure = pr;
    }
    tic_env = toc;
  }
  

  //  4 ---- Alt Reading
  toc = millis();
  if( (toc - tic_Alt) > T_Alt){
      if(flag_read_Alt ) {
        float pr;
        bmp.getPressure(&pr);
        myData.Altitude = bmp.pressureToAltitude(seaLevelPressure, pr);
      }
      tic_Alt = toc;
  }
  

  //  5 ----  GPS get data
  toc = millis();
  if( (toc - tic_GPS) > T_GPS){
  if(flag_read_GPS){
    bool newGPSData = false;
    while (gps.available(gpsSerial)) {
        fix = gps.read();
        newGPSData = true;
        if (fix.valid.location) {
          myData.Lat = fix.latitude();
          myData.Long = fix.longitude();
        }
        if (fix.valid.altitude) {
          myData.GPSAlt = fix.altitude();
        }
        if (fix.valid.satellites) {
          myData.Sat = fix.satellites;
        }
        else{
          myData.Sat = 0;
        }
      }
      Serial.println("Tried to Read GPS data "); ;
    }
    tic_GPS = toc;
  }

  // 6-----  Send Packet (throttled to T_send so the camera gets airtime)
  myData.Header = 2864434397;
  toc = millis();
  if( (toc - tic_send) >= T_send ){
    tic_send = toc;
    if(flag_Wifi_Comm == SET){                  // Send data over Wifi via ESP-NOW
        // Re-probe every LINK_REPROBE_MS while the GS is missing or silent.
        // Time-based (not fail-streak) so late/missing ACK callbacks still recover.
        const bool linkStale = !gsLinked || lastAckOkMs == 0 ||
                               (toc - lastAckOkMs) >= LINK_REPROBE_MS;
        if (linkStale && (toc - lastChannelProbeMs) >= LINK_REPROBE_MS) {
          Serial.println("[CANSAT] link down — re-probing channels...");
          findGroundStationChannel();
        }

        sendStatusKnown = false;
        esp_err_t result = esp_now_send(broadcastAddress, (uint8_t *) &myData, sizeof(myData));
        toc_status_msg = millis();
        if (result == ESP_OK) {
          waitForSendStatus(SEND_ACK_WAIT_MS);
          // Unknown/timeout counts as fail so the watchdog always advances.
          const bool delivered = sendStatusKnown && sendOk;
          if (delivered) {
            sent_pkt_count++;
            gsLinked = true;
            lastAckOkMs = millis();
          } else {
            dropped_pkt_count++;
            // If callback never fired, treat as fail for status print.
            if (!sendStatusKnown) sendOk = false;
          }
          if((toc_status_msg - tic_status_msg) > 1000){    // print every one second
            Serial.print("ESP-NOW: Sent="); Serial.print(sent_pkt_count);
            Serial.print(" Dropped="); Serial.print(dropped_pkt_count);
            Serial.print(" ch="); Serial.print(lockedChannel);
            Serial.print(" GS ack="); Serial.println(delivered ? "yes" : "NO");
            tic_status_msg = toc_status_msg;
          } 
        }else {
          dropped_pkt_count++;
          if (!sendStatusKnown) sendOk = false;
          if((toc_status_msg - tic_status_msg) > 1000){
            Serial.print("Error queuing ESP-NOW: Sent="); Serial.print(sent_pkt_count);
            Serial.print(" Dropped="); Serial.println(dropped_pkt_count); 
             tic_status_msg = toc_status_msg;
          }
        }

        delay(DELAY_AFTER_WIFI_TX) ;
    }       
    else{                                   // Send Data Over UART
     if(flag_send_full_sensor_data == SET)
        Serial.write((uint8_t*)&myData, sizeof(myData));
      else
        Serial.write((uint8_t*)&imu_reading, sizeof(imu_reading));
      
      delay(DELAY_AFTER_WIRED_TX);            // Wait time for Transferring 36 bytes at 115200 is 2.6ms

    }
  }
 


  // 7------- Buzzer decision
    if (myData.Altitude <= 1) // THIS SHOULD BE CHANGED BASED ON THE LOCATION
    {
      digitalWrite(4, LOW);
      //Serial.print("Buzzer On");
    } else {
      digitalWrite(4, LOW);
      //Serial.print("Buzzer Off");
    }
}
