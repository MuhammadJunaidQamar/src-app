function hGUI = initRawSensorGUI(s)
    % -----------------------------
    % Styled GUI for RAW Sensor Data
    % -----------------------------
    figHeight = 510;   % increased to fit UpdateRate row
    figWidth  = 950;
    fig = uifigure('Name','How Our CanSat Sees and Feels','Position',[900 100 figWidth figHeight]);
    fig.Color = [0 0 0];  % black background

    % -----------------------------
    % Add Main Title
    % -----------------------------
    uilabel(fig, 'Position',[0 figHeight-40 figWidth 40], ...
        'Text','Raw Data from CanSat Sensors', ...
        'FontSize',22,'FontWeight','bold', ...
        'FontColor',[1 0.84 0], ...
        'BackgroundColor',[0 0 0], ...
        'HorizontalAlignment','center');

    % -----------------------------
    % Helper anonymous functions
    % -----------------------------
    styledRowLabel = @(x,y,text) uilabel(fig,'Position',[x y 200 30], ...
        'Text',text,'FontSize',18,'FontWeight','bold', ...
        'FontColor',[1 0.84 0],'BackgroundColor',[0 0 0]);

    smallLabel = @(x,y,text,fs) uilabel(fig,'Position',[x y 35 30], ...
        'Text',text,'FontSize',fs,'FontWeight','bold', ...
        'FontColor',[1 0.84 0],'BackgroundColor',[0 0 0], ...
        'HorizontalAlignment','right');

    styledField = @(x,y,w,fs) uieditfield(fig,'text','Position',[x y w 30], ...
        'FontSize',fs,'FontWeight','bold','BackgroundColor',[0 0 0], ...
        'FontColor',[1 0.84 0],'HorizontalAlignment','right');

    % -----------------------------
    % Layout parameters
    % -----------------------------
    startY = figHeight - 100;   % shifted down to make room for title
    rowSpacing = 60;
    baseX = 200;    
    boxW = 100;     
    step = 180;     
    labelGap = 45;  
    fsBig = 16; 
    fsSmall = 14;

    % -----------------------------
    % Row 1: Accelerometer
    % -----------------------------
    styledRowLabel(20, startY, 'Accelerometer (m/s2)');
    smallLabel(baseX, startY, 'ax', fsBig); hGUI.accX = styledField(baseX+labelGap, startY, boxW, fsBig);
    smallLabel(baseX+step, startY, 'ay', fsBig); hGUI.accY = styledField(baseX+step+labelGap, startY, boxW, fsBig);
    smallLabel(baseX+2*step, startY, 'az', fsBig); hGUI.accZ = styledField(baseX+2*step+labelGap, startY, boxW, fsBig);

    % -----------------------------
    % Row 2: Gyroscope
    % -----------------------------
    gyY = startY - rowSpacing;
    styledRowLabel(20, gyY, 'Gyroscope (rad/s)');
    smallLabel(baseX, gyY, 'gx', fsBig); hGUI.gyroX = styledField(baseX+labelGap, gyY, boxW, fsBig);
    smallLabel(baseX+step, gyY, 'gy', fsBig); hGUI.gyroY = styledField(baseX+step+labelGap, gyY, boxW, fsBig);
    smallLabel(baseX+2*step, gyY, 'gz', fsBig); hGUI.gyroZ = styledField(baseX+2*step+labelGap, gyY, boxW, fsBig);

    % -----------------------------
    % Row 3: Magnetometer
    % -----------------------------
    magY = gyY - rowSpacing;
    styledRowLabel(20, magY, 'Magnetometer (uT)');
    smallLabel(baseX, magY, 'mx', fsBig); hGUI.magX = styledField(baseX+labelGap, magY, boxW, fsBig);
    smallLabel(baseX+step, magY, 'my', fsBig); hGUI.magY = styledField(baseX+step+labelGap, magY, boxW, fsBig);
    smallLabel(baseX+2*step, magY, 'mz', fsBig); hGUI.magZ = styledField(baseX+2*step+labelGap, magY, boxW, fsBig);
    smallLabel(baseX+3*step, magY, 'Mag', fsBig); hGUI.magMag = styledField(baseX+3*step+labelGap, magY, boxW, fsBig);

     % -----------------------------
    % Row 4: Environment (T, P, Alt, Head)
    % -----------------------------
    envY = magY - rowSpacing;
    styledRowLabel(20, envY, 'Environment');

    % Move labels 30 px more to the left, make them wider
    labelShift = 30;
    labelW = 70;

    uilabel(fig,'Position',[baseX-labelShift, envY, labelW, 30], ...
        'Text','T (°C)','FontSize',fsSmall,'FontWeight','bold', ...
        'FontColor',[1 0.84 0],'BackgroundColor',[0 0 0], ...
        'HorizontalAlignment','right');
    hGUI.temp = styledField(baseX+labelGap, envY, boxW, fsSmall);

    uilabel(fig,'Position',[baseX+step-labelShift, envY, labelW, 30], ...
        'Text','P (Pa)','FontSize',fsSmall,'FontWeight','bold', ...
        'FontColor',[1 0.84 0],'BackgroundColor',[0 0 0], ...
        'HorizontalAlignment','right');
    hGUI.press = styledField(baseX+step+labelGap, envY, boxW, fsSmall);

    uilabel(fig,'Position',[baseX+2*step-labelShift, envY, labelW, 30], ...
        'Text','Alt (m)','FontSize',fsSmall,'FontWeight','bold', ...
        'FontColor',[1 0.84 0],'BackgroundColor',[0 0 0], ...
        'HorizontalAlignment','right');
    hGUI.alt = styledField(baseX+2*step+labelGap, envY, boxW, fsSmall);

    uilabel(fig,'Position',[baseX+3*step-labelShift, envY, labelW, 30], ...
        'Text','Heading','FontSize',fsSmall,'FontWeight','bold', ...
        'FontColor',[1 0.84 0],'BackgroundColor',[0 0 0], ...
        'HorizontalAlignment','right');
    hGUI.head = styledField(baseX+3*step+labelGap, envY, boxW, fsSmall);

    % -----------------------------
    % Row 5: GPS (Sat, Lat, Lon, Alt)
    % -----------------------------
    gpsY = envY - rowSpacing;
    styledRowLabel(20, gpsY, 'GPS');

    uilabel(fig,'Position',[baseX-labelShift, gpsY, labelW, 30], ...
        'Text','Sat','FontSize',fsSmall,'FontWeight','bold', ...
        'FontColor',[1 0.84 0],'BackgroundColor',[0 0 0], ...
        'HorizontalAlignment','right');
    hGUI.sat = styledField(baseX+labelGap, gpsY, boxW, fsSmall);

    uilabel(fig,'Position',[baseX+step-labelShift, gpsY, labelW, 30], ...
        'Text','Lat','FontSize',fsSmall,'FontWeight','bold', ...
        'FontColor',[1 0.84 0],'BackgroundColor',[0 0 0], ...
        'HorizontalAlignment','right');
    hGUI.lat = styledField(baseX+step+labelGap, gpsY, boxW, fsSmall);

    uilabel(fig,'Position',[baseX+2*step-labelShift, gpsY, labelW, 30], ...
        'Text','Long','FontSize',fsSmall,'FontWeight','bold', ...
        'FontColor',[1 0.84 0],'BackgroundColor',[0 0 0], ...
        'HorizontalAlignment','right');
    hGUI.lon = styledField(baseX+2*step+labelGap, gpsY, boxW, fsSmall);

    uilabel(fig,'Position',[baseX+3*step-labelShift, gpsY, labelW, 30], ...
        'Text','GPSAlt','FontSize',fsSmall,'FontWeight','bold', ...
        'FontColor',[1 0.84 0],'BackgroundColor',[0 0 0], ...
        'HorizontalAlignment','right');
    hGUI.gpsAlt = styledField(baseX+3*step+labelGap, gpsY, boxW, fsSmall);

    % -----------------------------
    % Row 6: Update Rate
    % -----------------------------
    updY = gpsY - rowSpacing;
    styledRowLabel(20, updY, 'Update Rate (Hz)');
    hGUI.updateRate = styledField(baseX+0*step+labelGap, updY, boxW, fsSmall);


    % -----------------------------
    % Row 7: Timestamp (HW, SW)
    % -----------------------------
    tsY = updY - rowSpacing;
    styledRowLabel(20, tsY, 'Timestamp');

    uilabel(fig,'Position',[baseX-labelShift, tsY, labelW, 30], ...
        'Text','HW','FontSize',fsSmall,'FontWeight','bold', ...
        'FontColor',[1 0.84 0],'BackgroundColor',[0 0 0], ...
        'HorizontalAlignment','right');
    hGUI.tsHW = styledField(baseX+labelGap, tsY, boxW*1.0, fsSmall);

    uilabel(fig,'Position',[baseX+step-labelShift, tsY, labelW, 30], ...
        'Text','SW','FontSize',fsSmall,'FontWeight','bold', ...
        'FontColor',[1 0.84 0],'BackgroundColor',[0 0 0], ...
        'HorizontalAlignment','right');
    hGUI.tsSW = styledField(baseX+step+labelGap, tsY, boxW*1.0, fsSmall);

    % Store figure handle
    hGUI.fig = fig;

    % Attach to serial object
    if nargin > 0
        s.UserData.GUI_RAW = hGUI;
    end
end
