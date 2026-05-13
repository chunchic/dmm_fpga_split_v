clear

portName = "/dev/ttyUSB1";
baudRate = 115200;
cnfFile  = "shuffled_0004.cnf";

MAGIC_WORD = uint32(hex2dec('11111111'));

% parse CNF
[n, n_clause, packed] = parse_cnf(cnfFile);

% open UART
s = serialport(portName, baudRate);
flush(s);
pause(0.2);

% send header
write_u32(s, MAGIC_WORD);
write_u32(s, uint32(n));
write_u32(s, uint32(n_clause));

% send clauses
for i = 1:double(n_clause)
    write_u32(s, packed(i,1));
    write_u32(s, packed(i,2));
    write_u32(s, packed(i,3));
end

% receive output
pause(0.5);

while true
    if s.NumBytesAvailable > 0
        data = read(s, s.NumBytesAvailable, "uint8");
        txt = char(data);
        fprintf("%s", txt);

        if contains(txt, "donezo")
            break;
        end
    end
end

clear s;


%% 
function [n, n_clause, packedClauses] = parse_cnf(filename)

fid = fopen(filename, 'r');

n = [];
n_clause = [];
list = {};

while ~feof(fid)
    line = strtrim(fgetl(fid));
    if isempty(line) || startsWith(line,'c')
        continue;
    end

    if startsWith(line,'p')
        parts = split(line);
        n = uint32(str2double(parts{3}));
        n_clause = uint32(str2double(parts{4}));
        continue;
    end

    vals = sscanf(line,'%d').';
    lits = vals(1:end-1);

    packed = zeros(1,3,'uint32');

    for k = 1:3
        lit = lits(k);

        var = uint32(abs(lit) - 1);

        if lit < 0
            pol = uint32(1);
        else
            pol = uint32(0);
        end

        packed(k) = bitor(bitshift(var,1), pol);
    end

    list{end+1} = packed;
end

fclose(fid);

packedClauses = zeros(double(n_clause),3,'uint32');
for i = 1:double(n_clause)
    packedClauses(i,:) = list{i};
end

end


function write_u32(s, val)

val = uint32(val);

b = uint8([
    bitand(val,255), ...
    bitand(bitshift(val,-8),255), ...
    bitand(bitshift(val,-16),255), ...
    bitand(bitshift(val,-24),255)
]);

write(s, b, "uint8");

end