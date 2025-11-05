function initGyroGUI(s)
    % --- Main uifigure ---
    f = uifigure("Name","Gyro Monitor","Position",[100 100 900 400],...
                 "Color",[0.15 0.15 0.15]);  % dark background

    % --- Main Title ---
    uilabel(f,"Text","Bias Adjusted Gyro Rates",...
            "FontSize",20,"FontWeight","bold",...
            "FontColor",[1 0.84 0],...      % golden color
            "HorizontalAlignment","center",...
            "Position",[0 360 900 30],...   % spans top
            "BackgroundColor",f.Color);

    % --- Style settings ---
    boxColor = [0.2 0.2 0.2];       % dark gray for value boxes
    textColor = [1.0 0.84 0];       % golden text
    fontSize = 18;                  

    %% --- Text labels and value boxes (left side) ---
    labels = {"Gyro X (rad/s):","Gyro Y (rad/s):","Gyro Z (rad/s):", ...
              "Angle X (deg):","Angle Y (deg):","Angle Z (deg):"};
    yPos = [280 240 200 150 110 70];
    for k = 1:6
        uilabel(f,"Position",[30 yPos(k) 150 25], ...
            "Text",labels{k},"FontColor",textColor,"BackgroundColor",f.Color,"FontSize",14,"FontWeight","bold");
    end

    % Value boxes
    ui.gx = uilabel(f,"Position",[190 280 200 30],"Text","0","BackgroundColor",boxColor,"FontColor",textColor,"FontWeight","bold","HorizontalAlignment","center","FontSize",fontSize);
    ui.gy = uilabel(f,"Position",[190 240 200 30],"Text","0","BackgroundColor",boxColor,"FontColor",textColor,"FontWeight","bold","HorizontalAlignment","center","FontSize",fontSize);
    ui.gz = uilabel(f,"Position",[190 200 200 30],"Text","0","BackgroundColor",boxColor,"FontColor",textColor,"FontWeight","bold","HorizontalAlignment","center","FontSize",fontSize);

    ui.ax = uilabel(f,"Position",[190 150 200 30],"Text","0","BackgroundColor",boxColor,"FontColor",textColor,"FontWeight","bold","HorizontalAlignment","center","FontSize",fontSize);
    ui.ay = uilabel(f,"Position",[190 110 200 30],"Text","0","BackgroundColor",boxColor,"FontColor",textColor,"FontWeight","bold","HorizontalAlignment","center","FontSize",fontSize);
    ui.az = uilabel(f,"Position",[190 70 200 30],"Text","0","BackgroundColor",boxColor,"FontColor",textColor,"FontWeight","bold","HorizontalAlignment","center","FontSize",fontSize);

    %% --- Circular dials (right side) ---
    [axX, needleX] = createCircularDial(f,[0.55 0.45 0.25 0.45],'Angle X',textColor);
    [axY, needleY] = createCircularDial(f,[0.78 0.45 0.25 0.45],'Angle Y',textColor);
    [axZ, needleZ] = createCircularDial(f,[0.665 0.05 0.25 0.45],'Angle Z',textColor);

    %% --- Reset button ---
    uibutton(f,"push",...
        "Text","Reset Angles",...
        "BackgroundColor",[0.25 0.25 0.25],...
        "FontColor",[1 1 1],...
        "FontWeight","bold","FontSize",14,...
        "Position",[190 20 150 35],...
        "ButtonPushedFcn",@(~,~) resetAngles(s));

    %% --- Store UI state ---
    ud = s.UserData;
    ud.gyroUI = ui;
    ud.gyroNeedles = [needleX needleY needleZ];
    ud.theta = [0 0 0];
    ud.lastTime = tic;
    ud.resetFlag = false;
    s.UserData = ud;
    s.UserData.GyroGUI = f;
end

%% --- Circular dial creation function ---
function [ax, needle] = createCircularDial(parentFig,parentPos,labelStr,textColor)
    ax = uiaxes(parentFig,'Units','normalized','Position',parentPos, ...
                'Color',parentFig.Color);
    ax.XColor = 'none';
    ax.YColor = 'none';
    ax.XLim = [-1.5 1.5];
    ax.YLim = [-1.5 1.5];
    axis(ax,'equal');
    hold(ax,'on');

    % Outer circle
    rCircle = 0.95;  
    theta = linspace(0,2*pi,360);
    x = rCircle*cos(theta);
    y = rCircle*sin(theta);
    plot(ax,x,y,'Color',textColor,'LineWidth',2);

    % Major ticks every 30°
    for ang = 0:30:330
        rOuter = 0.90;
        rInner = 0.75;
        x1 = rInner*cosd(ang); 
        y1 = rInner*sind(ang);
        x2 = rOuter*cosd(ang); 
        y2 = rOuter*sind(ang);
        plot(ax,[x1 x2],[y1 y2],'Color',textColor,'LineWidth',1.5);
    end

    % Labels at 0,90,180,270 (move outward)
    for ang = 0:90:270
        rLabel = 1.2;
        text(ax, rLabel*cosd(ang), rLabel*sind(ang), num2str(ang), ...
            'HorizontalAlignment','center','VerticalAlignment','middle', ...
            'FontWeight','bold','Color',textColor,'FontSize',12);
    end

    % Title below dial
    text(ax,0,-1.6,labelStr,'Color',textColor,'FontWeight','bold', ...
         'FontSize',14,'HorizontalAlignment','center');

    % Initial needle
    needle = plot(ax,[0 0],[0 1],'r','LineWidth',2);

    axis(ax,[-1.5 1.5 -1.5 1.5])
end

%% --- Reset angles function ---
function resetAngles(s)
    ud = s.UserData;
    ud.resetFlag = true;
    s.UserData = ud;
end
