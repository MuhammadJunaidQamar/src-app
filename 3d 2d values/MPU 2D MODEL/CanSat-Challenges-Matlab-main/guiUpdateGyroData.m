ud = src.UserData;

dt = (single(sensor_data.TimeStamp) - ud.lastTimeStamp)/1000;   % dt in  seconds
ud.lastTimeStamp = single(sensor_data.TimeStamp);

% Reset if requested
if ud.resetFlag
    ud.theta = [0 0 0];
    ud.resetFlag = false;
end

%mean_adjusted_gyro_rates = [gx gy gz]  ;
gyro_rates = [sensor_data.Angaccx sensor_data.Angaccy sensor_data.Angaccz];
% Integrate gyro to angles
ud.theta = ud.theta + gyro_rates * dt;

% Update UI labels
if isfield(ud, "gyroUI")
    ud.gyroUI.gx.Text = sprintf("%.3f", gyro_rates(1));
    ud.gyroUI.gy.Text = sprintf("%.3f", gyro_rates(2));
    ud.gyroUI.gz.Text = sprintf("%.3f", gyro_rates(3));

    ud.gyroUI.ax.Text = sprintf("%.2f", rad2deg(ud.theta(1)));
    ud.gyroUI.ay.Text = sprintf("%.2f", rad2deg(ud.theta(2)));
    ud.gyroUI.az.Text = sprintf("%.2f", rad2deg(ud.theta(3)));

        % Update UI labels
    ud.gyroUI.ax.Text = sprintf("%.1f", mod(rad2deg(ud.theta(1)), 360) );
    ud.gyroUI.ay.Text = sprintf("%.1f", mod(rad2deg(ud.theta(2)), 360));
    ud.gyroUI.az.Text = sprintf("%.1f", mod(rad2deg(ud.theta(3)), 360));

    % Update Gauges
  
thetaWrapped = mod(rad2deg(ud.theta), 360);

 thetaRad = deg2rad(thetaWrapped);  % convert to radians

% X = cos(theta), Y = sin(theta) maps 0° at 0 rad → right
set(ud.gyroNeedles(1), 'XData', [0 cos(thetaRad(1))], ...
                        'YData', [0 sin(thetaRad(1))]);
set(ud.gyroNeedles(2), 'XData', [0 cos(thetaRad(2))], ...
                        'YData', [0 sin(thetaRad(2))]);
set(ud.gyroNeedles(3), 'XData', [0 cos(thetaRad(3))], ...
                        'YData', [0 sin(thetaRad(3))]);


end

src.UserData = ud;

