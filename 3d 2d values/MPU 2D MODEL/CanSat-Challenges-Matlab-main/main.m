clc; clear; close all;

% === Serial Port Setup ===
port = "COM4";
baud = 115200;

oldPorts = serialportfind;
if ~isempty(oldPorts)
    delete(oldPorts);
end

s = serialport(port, baud);
configureTerminator(s, "LF");
flush(s);
disp("✅ Serial connected. Waiting for MPU data...");

% === Create Figure ===
f = figure('Name','MPU Path Visualizer','NumberTitle','off', ...
    'Position',[100 100 900 700]);

ax = axes('Parent',f);
hold(ax, 'on'); grid(ax, 'on'); axis(ax, 'equal');
xlabel(ax, 'X Position');
ylabel(ax, 'Y Position');
title(ax, '2D Path from MPU Orientation (Roll/Pitch/Yaw)');
xlim(ax, [-200 200]);
ylim(ax, [-200 200]);

% Variables
x = 0; y = 0;
pathX = x;
pathY = y;
speed = 1.0;
dataReceived = false;

hPath = plot(ax, pathX, pathY, '-b', 'LineWidth', 2);
hPoint = plot(ax, x, y, 'ro', 'MarkerFaceColor', 'r');

% === UI Controls ===
uicontrol('Style', 'text', 'String', 'Zoom', ...
    'Units', 'normalized', 'Position', [0.77 0.9 0.15 0.04], ...
    'FontSize', 10, 'FontWeight', 'bold');
zoomSlider = uicontrol('Style', 'slider', ...
    'Min', 0.5, 'Max', 5, 'Value', 1, ...
    'Units', 'normalized', 'Position', [0.77 0.85 0.15 0.04]);

uicontrol('Style', 'text', 'String', 'Speed Sensitivity', ...
    'Units', 'normalized', 'Position', [0.77 0.77 0.15 0.04], ...
    'FontSize', 10, 'FontWeight', 'bold');
speedSlider = uicontrol('Style', 'slider', ...
    'Min', 0.1, 'Max', 5, 'Value', 1.0, ...
    'Units', 'normalized', 'Position', [0.77 0.72 0.15 0.04]);

resetBtn = uicontrol('Style', 'pushbutton', 'String', 'Reset View', ...
    'Units', 'normalized', 'Position', [0.77 0.63 0.15 0.05], ...
    'FontSize', 10, 'BackgroundColor', [0.8 0.9 1]);

clearBtn = uicontrol('Style', 'pushbutton', 'String', 'Clear Path', ...
    'Units', 'normalized', 'Position', [0.77 0.55 0.15 0.05], ...
    'FontSize', 10, 'BackgroundColor', [1 0.8 0.8]);

resetBtn.Callback = @(~,~) resetView();
clearBtn.Callback = @(~,~) clearPath();

    function resetView()
        xlim(ax, [-200 200]);
        ylim(ax, [-200 200]);
    end

    function clearPath()
        pathX = 0; pathY = 0;
        x = 0; y = 0;
        set(hPath,'XData',pathX,'YData',pathY);
        set(hPoint,'XData',x,'YData',y);
        disp("🧹 Path cleared.");
    end

% === Live Loop ===
while isvalid(s) && isvalid(f)
    try
        line = readline(s);
        line = strtrim(line);

        tokens = regexp(line, ...
            'Roll:\s*([-+]?\d*\.?\d+)[\t ]+Pitch:\s*([-+]?\d*\.?\d+)[\t ]+Yaw:\s*([-+]?\d*\.?\d+)', ...
            'tokens');

        if ~isempty(tokens)
            vals = str2double(tokens{1});
            roll = vals(1);
            pitch = vals(2);
            yaw = vals(3);

            if ~dataReceived
                disp("📡 Receiving MPU data...");
                dataReceived = true;
            end

            r = deg2rad(roll);
            p = deg2rad(pitch);
            yAng = deg2rad(yaw);

            % --- Movement Model ---
            sensitivity = 0.1; % Reduce tilt effect drastically
            speed = speedSlider.Value;
            dx = speed * sensitivity * sin(p);
            dy = speed * sensitivity * sin(r);

            newX =  cos(yAng)*dx - sin(yAng)*dy;
            newY =  sin(yAng)*dx + cos(yAng)*dy;

            x = x + newX;
            y = y + newY;

            pathX(end+1) = x;
            pathY(end+1) = y;

            zoomVal = zoomSlider.Value;
            xlim(ax, [-200 200]*(1/zoomVal));
            ylim(ax, [-200 200]*(1/zoomVal));

            set(hPath,'XData',pathX,'YData',pathY);
            set(hPoint,'XData',x,'YData',y);
            drawnow limitrate;
        end
    catch ME
        warning(ME.message);
        break;
    end
end
