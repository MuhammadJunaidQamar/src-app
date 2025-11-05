# CanSat-Challenges-Matlab
Matlab Code to process Sensor Data from CanSat -- (tested on v2024a)

1. Run the program from main.m.

2. Place your sensor data processing code inside esp32_packet_callback.m.

3. To properly terminate the program and release the COM, use stopSerialPort.m (otherwise the COM port may remain locked).

4. Optionally, run delete(s) to ensure the COM port is fully released.

5. Use the **hardware timestamps** provided in sensor_data within your project

6. Edit line 12 of main.py to set the correct COM port (the one that receives the Sensor_data packets) before running MATLAB.
 
