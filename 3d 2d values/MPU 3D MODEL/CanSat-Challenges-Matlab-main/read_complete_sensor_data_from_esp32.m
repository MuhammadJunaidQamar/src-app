% function [sensor_data] = read_complete_sensor_data_from_esp32(src, sensor_data )
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% % Gets bytes from serial buffer, deserializes them and stores them in sensor_data structure. 
% % Inputs and Outputs
% % src: serial port object
% % sensor_data: sensor_data structure with a header
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function sensor_datas = read_complete_sensor_data_from_esp32(src)
    % Returns a cell array of decoded packets (0, 1, or many)

    HEADER = uint32(0xAABBCCDD);
    ud = src.UserData;
    buffer = ud.buffer;
    sensor_datas = {};   % <-- will hold all decoded packets

    % Read all available bytes
    if src.NumBytesAvailable > 0
        newData = read(src, src.NumBytesAvailable, "uint8")';
        buffer = [buffer; newData];
    end

    % Try to extract as many packets as possible
    while length(buffer) >= ud.packet_size
        headerCandidate = typecast(buffer(1:4), 'uint32');
        if headerCandidate == HEADER
            % Extract one packet
            packet = buffer(1:ud.packet_size);
            buffer(1:ud.packet_size) = [];

            % Deserialize into struct
            sensor_data = parse_packet(packet, ud);
            ud.pkt_cntr = ud.pkt_cntr + 1;

            % Append to list
            sensor_datas{end+1} = sensor_data;
        else
            % Misaligned, discard one byte and keep searching
            buffer(1) = [];
        end
    end

    % Save leftover buffer back
    ud.buffer = buffer;
    src.UserData = ud;
end




function sensor_data = parse_packet(packet, ud)
    offset = 1;
    sensor_data.Header = typecast(uint8(packet(offset:offset+3)), 'uint32'); 
    offset = offset+4;
    sensor_data.Temperature = typecast(uint8(packet(offset:offset+3)), 'single'); 
    offset = offset+4;
    sensor_data.Altitude = typecast(uint8(packet(offset:offset+3)), 'single'); 
    offset = offset+4;
    sensor_data.Pressure = typecast(uint8(packet(offset:offset+3)), 'single'); 
    offset = offset+4;
    sensor_data.Heading  = typecast(uint8(packet(offset:offset+3)), 'single'); 
    offset = offset+4;
    sensor_data.Xacc     = typecast(uint8(packet(offset:offset+3)), 'single') - 0*ud.ax_offset; 
    offset = offset+4;
    sensor_data.Yacc     = typecast(uint8(packet(offset:offset+3)), 'single') - 0*ud.ay_offset; 
    offset = offset+4;
    sensor_data.Zacc     = typecast(uint8(packet(offset:offset+3)) , 'single') -0*ud.az_offset; 
    offset = offset+4;
    sensor_data.Angaccx  = typecast(uint8(packet(offset:offset+3)), 'single'); 
    offset = offset+4;
    sensor_data.Angaccy  = typecast(uint8(packet(offset:offset+3)), 'single');
    offset = offset+4;
    sensor_data.Angaccz  = typecast(uint8(packet(offset:offset+3)), 'single');
    offset = offset+4;
    sensor_data.Magx     = typecast(uint8(packet(offset:offset+3)), 'single'); 
    offset = offset+4;
    sensor_data.Magy     = typecast(uint8(packet(offset:offset+3)), 'single');
    offset = offset+4;
    sensor_data.Magz     = typecast(uint8(packet(offset:offset+3)), 'single');
    offset = offset+4;
    sensor_data.Sat      = typecast(uint8(packet(offset:offset+3)), 'single');
    offset = offset+4;
    sensor_data.Lat      = typecast(uint8(packet(offset:offset+3)), 'single'); 
    offset = offset+4;
    sensor_data.Long     = typecast(uint8(packet(offset:offset+3)), 'single');
    offset = offset+4;
    sensor_data.GPSAlt   = typecast(uint8(packet(offset:offset+3)), 'single');
    offset = offset+4;
    sensor_data.TimeStamp= typecast(uint8(packet(offset:offset+3)), 'uint32');
    sensor_data.Pkt_num  = ud.pkt_cntr;
    sensor_data.Recv_time= datetime('now');

end