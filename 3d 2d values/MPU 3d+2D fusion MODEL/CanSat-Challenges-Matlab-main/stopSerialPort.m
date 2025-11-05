%configureCallback(s, "off");

close(s.UserData.GUI_RAW.fig);    % RAW sensor data GUI
close(s.UserData.GyroGUI);    % GYRO GUI 
close all;
flush(s);
delete(s);
