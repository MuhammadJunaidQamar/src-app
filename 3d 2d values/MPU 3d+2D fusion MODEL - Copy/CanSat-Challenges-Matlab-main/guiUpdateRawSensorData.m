function guiUpdateRawSensorData(s, sensor_data)
    %% Code to compute the frequency of data arrival (average time between last 10 calls)
    persistent startTime lastCallTimes hwTimeStampOffset;
    % Initialize on first call
    if s.UserData.tStart == 0
        startTime = tic;        % start a global stopwatch
        lastCallTimes = [];
        hwTimeStampOffset = sensor_data.TimeStamp;
        s.UserData.tStart = tic;
    end
    ud = s.UserData;

    % Record current time since first call
    currentTime = sensor_data.TimeStamp;        % Calculate Update Rate based on HW time Stamp only
    lastCallTimes(end+1) = currentTime;  %#ok<AGROW>
    %fprintf('%d \n', currentTime);

    % Keep only last 11 entries (10 intervals require 11 timestamps)
    if numel(lastCallTimes) > 11
        lastCallTimes(1) = []; 
    end
    
    % Default output
    avgInterval = NaN;
    
    % Compute intervals if enough calls
    if numel(lastCallTimes) >= 2
        intervals = diff(lastCallTimes);
        if numel(intervals) >= 10
            avgInterval = mean(intervals(end-9:end));
        else
            avgInterval = mean(intervals);
        end
    end
   %% Code to display raw sensor values

    if isfield(s.UserData, 'GUI_RAW')
        h = s.UserData.GUI_RAW;

        % -----------------------------
        % Accelerometer
        % -----------------------------
        h.accX.Value = sprintf('%.3f', sensor_data.Xacc + 0*s.UserData.ax_offset);             % Printing Values after Removing Correction through Empirical Offset -- See read_agm_data_from_esp32 or read_complete_sensor_data_from_esp32
        h.accY.Value = sprintf('%.3f', sensor_data.Yacc + 0*s.UserData.ay_offset);
        h.accZ.Value = sprintf('%.3f', sensor_data.Zacc + 0*s.UserData.az_offset);

        % -----------------------------
        % Gyroscope
        % -----------------------------
        h.gyroX.Value = sprintf('%.3f', sensor_data.Angaccx);
        h.gyroY.Value = sprintf('%.3f', sensor_data.Angaccy);
        h.gyroZ.Value = sprintf('%.3f', sensor_data.Angaccz);

        % -----------------------------
        % Magnetometer
        % -----------------------------
        h.magX.Value = sprintf('%.3f', sensor_data.Magx);
        h.magY.Value = sprintf('%.3f', sensor_data.Magy);
        h.magZ.Value = sprintf('%.3f', sensor_data.Magz);
        h.magMag.Value = sprintf('%.3f', sqrt(sensor_data.Magx * sensor_data.Magx + sensor_data.Magy * sensor_data.Magy + sensor_data.Magz * sensor_data.Magz));

        % -----------------------------
        % Environment
        % -----------------------------
        h.temp.Value = sprintf('%.3f', sensor_data.Temperature);
        h.press.Value = sprintf('%.3f', sensor_data.Pressure);
        h.alt.Value   = sprintf('%.3f', sensor_data.Altitude);
        heading = atan2(sensor_data.Magy , sensor_data.Magx ) * (180/pi);
        %heading(heading < 0) = heading(heading < 0) + 360;
        h.head.Value  = sprintf('%.3f', heading);

        % -----------------------------
        % GPS
        % -----------------------------
        h.sat.Value    = sprintf('%.0f', sensor_data.Sat);
        h.lat.Value    = sprintf('%.6f', sensor_data.Lat);
        h.lon.Value    = sprintf('%.6f', sensor_data.Long);
        h.gpsAlt.Value = sprintf('%.3f', sensor_data.GPSAlt);

        h.updateRate.Value = sprintf('%.3f', 1000/avgInterval);

        % -----------------------------
        % Timestamp
        % -----------------------------
        h.tsHW.Value = sprintf('%.0f', sensor_data.TimeStamp);
        h.tsSW.Value = sprintf('%.0f', hwTimeStampOffset + toc(startTime) * 1000);

    end
end