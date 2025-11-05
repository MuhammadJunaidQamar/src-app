function esp32_packet_callback_with_box(src, ~)
    try
        % --- Call your original sensor processing ---
        esp32_packet_callback(src, []);  

        % Get latest user data
        ud = src.UserData;

        % Safety check
        if ~isfield(ud, 'track') || isempty(ud.track)
            return;
        end

        % Extract the last position from track
        pos = ud.track(end, :);

        % Example: get last roll, pitch, yaw (if available)
        if isfield(ud, 'lastRoll') && isfield(ud, 'lastPitch') && isfield(ud, 'lastYaw')
            roll = ud.lastRoll;
            pitch = ud.lastPitch;
            yaw = ud.lastYaw;
        else
            roll = 0; pitch = 0; yaw = 0;
        end

        % --- Update 3D cube orientation ---
        hBox = ud.hBox;
        if isempty(hBox) || ~isvalid(hBox)
            return;
        end

        % Build rotation matrix
        R = eul2rotm(deg2rad([yaw pitch roll]), 'ZYX');

        % Original cube vertices
        [X, Y, Z] = ndgrid([0 1]);
        fv = isosurface(X, Y, Z, ones(size(X)));
        newVerts = (R * fv.vertices')' + pos;

        set(hBox, 'Vertices', newVerts);
        drawnow limitrate;

    catch ME
        warning("Box callback error: %s", ME.message);
    end
end
