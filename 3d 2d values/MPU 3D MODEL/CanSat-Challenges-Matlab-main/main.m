clc; clear; close all;

% === Serial Port Setup ===
port = "COM4";      % <-- change if needed
baud = 115200;

% Close any old connections
oldPorts = serialportfind;
if ~isempty(oldPorts)
    delete(oldPorts);
end

% Open serial
s = serialport(port, baud);
configureTerminator(s, "LF");
flush(s);
disp("✅ Serial connected. Waiting for MPU data...");

% === Create 3D Figure ===
figure('Name','MPU Orientation Visualization','NumberTitle','off');
axis equal;
grid on;
xlabel('X'); ylabel('Y'); zlabel('Z');
title('3D Cylinder - Roll, Pitch, Yaw from ESP32');
view(45, 30);
hold on;

% === Create Cylinder ===
[cx, cy, cz] = cylinder(0.5, 40);   % radius=0.5, 40 segments for smoothness
cz = cz * 2 - 1;                    % height from -1 to 1
hCyl = surf(cx, cy, cz, ...
    'FaceColor', [0.2 0.7 1], ...
    'EdgeColor', 'none', ...
    'FaceAlpha', 0.8);
light; lighting gouraud;

% Add reference axes for clarity
quiver3(0,0,0,1,0,0,'r','LineWidth',2); % X-axis
quiver3(0,0,0,0,1,0,'g','LineWidth',2); % Y-axis
quiver3(0,0,0,0,0,1,'b','LineWidth',2); % Z-axis

% --- Loop Variables ---
roll = 0; pitch = 0; yaw = 0;
dataReceived = false; % flag to confirm data reception

% === Live Update Loop ===
while isvalid(s)
    try
        % Read line from serial
        line = readline(s);
        line = strtrim(line);

        % Match roll/pitch/yaw pattern
        tokens = regexp(line, 'Roll:\s*([-+]?\d*\.?\d+)\s*Pitch:\s*([-+]?\d*\.?\d+)\s*Yaw:\s*([-+]?\d*\.?\d+)', 'tokens');

        if ~isempty(tokens)
            vals = str2double(tokens{1});
            roll = vals(1);
            pitch = vals(2);
            yaw = vals(3);

            % Mark that data is being received
            if ~dataReceived
                disp("📡 Receiving MPU data...");
                dataReceived = true;
            end

            % Convert degrees to radians
            r = deg2rad(roll);
            p = deg2rad(pitch);
            y = deg2rad(yaw);

            % Rotation matrices
            Rx = [1 0 0; 0 cos(r) -sin(r); 0 sin(r) cos(r)];
            Ry = [cos(p) 0 sin(p); 0 1 0; -sin(p) 0 cos(p)];
            Rz = [cos(y) -sin(y) 0; sin(y) cos(y) 0; 0 0 1];

            % Combined rotation (ZYX order)
            R = Rz * Ry * Rx;

            % Apply rotation to cylinder vertices
            v = [cx(:), cy(:), cz(:)] * R';
            newX = reshape(v(:,1), size(cx));
            newY = reshape(v(:,2), size(cy));
            newZ = reshape(v(:,3), size(cz));

            % Update cylinder orientation
            set(hCyl, 'XData', newX, 'YData', newY, 'ZData', newZ);
            drawnow limitrate;
        end
    catch ME
        warning(ME.message);
        break;
    end
end
