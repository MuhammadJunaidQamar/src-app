clc; clear; close all;

%% === Serial Port Setup ===
port = "COM4";       % <-- change COM port if needed
baud = 115200;

% Close any previous serial connections
oldPorts = serialportfind;
if ~isempty(oldPorts)
    delete(oldPorts);
end

% Open new serial connection
s = serialport(port, baud);
configureTerminator(s, "LF");
flush(s);
disp("✅ Serial connected. Waiting for CanSat data...");

%% === Create Main Figure with Two Axes ===
fig = figure('Name','CanSat 3D + 2D Visualizer','NumberTitle','off', ...
    'Position',[100 100 1200 600], 'Color',[0.98 0.95 0.9]);

%% === 3D Orientation Setup (Left Side) ===
ax3D = subplot(1,2,1);
axis(ax3D,'equal'); grid(ax3D,'on');
xlabel(ax3D,'X'); ylabel(ax3D,'Y'); zlabel(ax3D,'Z');
title(ax3D,'3D Orientation (Roll, Pitch, Yaw)');
view(ax3D, [45 30]); hold(ax3D,'on');

[X,Y,Z] = meshgrid([0 1]);
verts = [X(:) Y(:) Z(:)] - 0.5;
faces = [1 2 4 3; 1 2 6 5; 2 4 8 6; 4 3 7 8; 3 1 5 7; 5 6 8 7];
cube = patch('Vertices',verts,'Faces',faces,'FaceColor',[0.3 0.7 1],'FaceAlpha',0.7,'Parent',ax3D);
light(ax3D); lighting(ax3D,'gouraud');

%% === 2D Path Plot (Right Side) ===
ax2D = subplot(1,2,2);
hold(ax2D, 'on'); grid(ax2D, 'on'); axis(ax2D, 'equal');
xlabel(ax2D, 'X Position');
ylabel(ax2D, 'Y Position');
title(ax2D, '2D Path from MPU Orientation');
xlim(ax2D, [-200 200]);
ylim(ax2D, [-200 200]);

x = 0; y = 0;
pathX = x; pathY = y;
hPath = plot(ax2D, pathX, pathY, '-b', 'LineWidth', 2);
hPoint = plot(ax2D, x, y, 'ro', 'MarkerFaceColor', 'r');

%% === UI Controls ===
uicontrol('Style','text','String','3D Rotation Scale','Position',[1050 520 120 20],'BackgroundColor',[0.95 0.9 0.85]);
rotSlider = uicontrol('Style','slider','Min',0.5,'Max',2,'Value',1,'Position',[1050 500 120 20]);

uicontrol('Style', 'text', 'String', '2D Zoom', ...
    'Position', [1050 460 120 20],'BackgroundColor',[0.95 0.9 0.85]);
zoomSlider = uicontrol('Style', 'slider', 'Min',0.5,'Max',5,'Value',1,'Position',[1050 440 120 20]);

uicontrol('Style', 'text', 'String', 'Speed Sensitivity', ...
    'Position', [1050 400 120 20],'BackgroundColor',[0.95 0.9 0.85]);
speedSlider = uicontrol('Style', 'slider', 'Min',0.1,'Max',5,'Value',1.0,'Position',[1050 380 120 20]);

resetBtn = uicontrol('Style', 'pushbutton', 'String', 'Reset 2D View', ...
    'Position', [1050 340 120 30], 'BackgroundColor', [0.8 0.9 1], ...
    'Callback', @(~,~) resetView());

clearBtn = uicontrol('Style', 'pushbutton', 'String', 'Clear 2D Path', ...
    'Position', [1050 300 120 30], 'BackgroundColor', [1 0.8 0.8], ...
    'Callback', @(~,~) clearPath());

%% === Callback Functions ===
    function resetView()
        xlim(ax2D, [-200 200]);
        ylim(ax2D, [-200 200]);
    end

    function clearPath()
        pathX = 0; pathY = 0;
        x = 0; y = 0;
        set(hPath,'XData',pathX,'YData',pathY);
        set(hPoint,'XData',x,'YData',y);
        disp("🧹 Path cleared.");
    end

%% === Variables ===
dataReceived = false;

%% === Live Loop ===
while isvalid(s) && isvalid(fig)
    try
        line = readline(s);
        line = strtrim(line);

        % Match both possible formats (ROLL=... or Roll: ...)
        tokens = regexp(line, ...
            '(?:ROLL|Roll)[:=]\s*([-+]?\d*\.?\d+)\s+(?:PITCH|Pitch)[:=]\s*([-+]?\d*\.?\d+)\s+(?:YAW|Yaw)[:=]\s*([-+]?\d*\.?\d+)', ...
            'tokens');

        if ~isempty(tokens)
            vals = str2double(tokens{1});
            roll = vals(1);
            pitch = vals(2);
            yaw = vals(3);

            if ~dataReceived
                disp("📡 Receiving CanSat orientation data...");
                dataReceived = true;
            end

            %% === 3D Orientation Update ===
            r = deg2rad(roll * rotSlider.Value);
            p = deg2rad(pitch * rotSlider.Value);
            yAng = deg2rad(yaw * rotSlider.Value);

            Rx = [1 0 0; 0 cos(r) -sin(r); 0 sin(r) cos(r)];
            Ry = [cos(p) 0 sin(p); 0 1 0; -sin(p) 0 cos(p)];
            Rz = [cos(yAng) -sin(yAng) 0; sin(yAng) cos(yAng) 0; 0 0 1];
            R = Rz * Ry * Rx;

            rotatedVerts = (R * verts')';
            set(cube,'Vertices',rotatedVerts);

            %% === 2D Path Update ===
            sensitivity = 0.1;
            spd = speedSlider.Value;
            dx = spd * sensitivity * sin(p);
            dy = spd * sensitivity * sin(r);

            newX =  cos(yAng)*dx - sin(yAng)*dy;
            newY =  sin(yAng)*dx + cos(yAng)*dy;

            x = x + newX;
            y = y + newY;
            pathX(end+1) = x;
            pathY(end+1) = y;

            zoomVal = zoomSlider.Value;
            xlim(ax2D, [-200 200]*(1/zoomVal));
            ylim(ax2D, [-200 200]*(1/zoomVal));

            set(hPath,'XData',pathX,'YData',pathY);
            set(hPoint,'XData',x,'YData',y);

            drawnow limitrate;
        end
    catch ME
        warning(ME.message);
        break;
    end
end
