local LIB_ROOT = "D:\\lualibs_windows\\" 

package.cpath = package.cpath .. ";" .. LIB_ROOT .. "luasocket\\?.dll"
package.cpath = package.cpath .. ";" .. LIB_ROOT .. "luasocket\\mime\\?.dll"
package.path = package.path .. ";" .. LIB_ROOT .. "luasocket\\?.lua"

print("Program Initialization")
print("Loading libraries...")

local socket_ok, socket = pcall(require, "socket")
if not socket_ok then
    print("ERROR: Failed to load socket library")
    print("Details: " .. tostring(socket))
    print("\nPlease check:")
    print("1. Library path: " .. LIB_ROOT)
    print("2. File exists: " .. LIB_ROOT .. "luasocket\\socket.dll")
    print("3. Lua version compatibility")
    os.exit(1)
end
print("Socket library loaded successfully")

local os = require("os")

local CONFIG = {
    host = "95.163.237.76",
    port1 = 5123,
    port2 = 5124,
    secret_key = "isu_pt",
    get_command = "get",
    output_file = "sensor_data.txt",
    timeout = 4.0,           
    reconnect_delay = 1.0,   
    request_interval = 0.0,  
    debug_mode = true,
    max_consecutive_errors = 3 
}

print(string.format("Host: %s", CONFIG.host))
print(string.format("Ports: %d, %d", CONFIG.port1, CONFIG.port2))
print(string.format("Max consecutive errors before reconnect: %d", CONFIG.max_consecutive_errors))
print()


local function bytes_to_uint64_be(data, offset)
    offset = offset or 1
    local result = 0
    for i = 0, 7 do
        result = result * 256 + data:byte(offset + i)
    end
    return result
end

local function bytes_to_float_be(data, offset)
    offset = offset or 1
    local b1, b2, b3, b4 = data:byte(offset, offset + 3)
    
    local sign = (b1 >= 128) and -1 or 1
    local exponent_bits = ((b1 % 128) * 2) + math.floor(b2 / 128)
    local mantissa_bits = ((b2 % 128) * 65536) + (b3 * 256) + b4
    local mantissa = mantissa_bits / 8388608.0
    local exponent = exponent_bits - 127
    
    if exponent_bits == 0 and mantissa_bits == 0 then
        return 0.0
    elseif exponent_bits == 255 then
        return mantissa_bits == 0 and (sign * math.huge) or (0/0)
    end
    
    local fractional_part = 1.0 + mantissa
    local factor = 2 ^ exponent
    return sign * fractional_part * factor
end

local function bytes_to_int16_be(data, offset)
    offset = offset or 1
    local b1, b2 = data:byte(offset, offset + 1)
    local value = b1 * 256 + b2
    if value >= 32768 then
        value = value - 65536
    end
    return value
end

local function bytes_to_int32_be(data, offset)
    offset = offset or 1
    local b1, b2, b3, b4 = data:byte(offset, offset + 3)
    local value = b1 * 16777216 + b2 * 65536 + b3 * 256 + b4
    if value >= 2147483648 then
        value = value - 4294967296
    end
    return value
end

local function calculate_checksum(data)
    local sum = 0
    for i = 1, #data do
        sum = sum + data:byte(i)
    end
    return sum % 256 
end

local function timestamp_to_datetime(timestamp_us)
    local timestamp_s = timestamp_us / 1000000 
    
    local date_str, err = pcall(os.date, "!%Y-%m-%d %H:%M:%S", math.floor(timestamp_s))
    
    if type(date_str) == "string" then
        return date_str
    else
        local date_from_error = tostring(err)
        if string.match(date_from_error, "%d%d%d%d%-%d%d%-%d%d %d%d%:%d%d%:%d%d") then
            return date_from_error
        end
        
        if CONFIG.debug_mode then
            print(string.format("[DEBUG DATE FATAL] Could not convert timestamp. Value in seconds: %s. Error: %s", 
                math.floor(timestamp_s), err or "unknown"))
        end
        return string.format("RAW_TIME(s): %s", math.floor(timestamp_s))
    end
end

local function debug_print_bytes(data, name)
    if not CONFIG.debug_mode then return end
    local hex = {}
    for i = 1, math.min(#data, 32) do
        hex[i] = string.format("%02X", data:byte(i))
    end
    print(string.format("[DEBUG %s] Length: %d, Bytes: %s%s", 
        name, #data, table.concat(hex, " "), #data > 32 and "..." or ""))
end


local Connection = {}
Connection.__index = Connection

function Connection:new(port, data_size, name)
    local obj = {
        port = port,
        data_size = data_size,
        name = name,
        sock = nil,
        connected = false,
        last_request_time = 0,
        connection_attempts = 0,
        consecutive_errors = 0  
    }
    setmetatable(obj, self)
    return obj
end

function Connection:receive_exact()
    local buffer = ""
    local received_len = 0
    local size = self.data_size
    
    while received_len < size do
        local data, err = self.sock:receive(size - received_len)
        
        if not data then
            self.connected = false
            return nil, err
        end
        
        buffer = buffer .. data
        received_len = received_len + #data
    end
    return buffer
end

function Connection:connect()
    self.connection_attempts = self.connection_attempts + 1
    
    if self.sock then
        pcall(function() self.sock:close() end)
        self.sock = nil
    end
    
    print(string.format("[%s] Connection attempt #%d to %s:%d...", 
        self.name, self.connection_attempts, CONFIG.host, self.port))
    
    self.sock = socket.tcp()
    if not self.sock then
        print(string.format("[%s] Socket creation failed", self.name))
        return false
    end
    
    self.sock:settimeout(CONFIG.timeout)
    
    local success, err = self.sock:connect(CONFIG.host, self.port)
    if not success then
        print(string.format("[%s] Connection error: %s", self.name, err or "unknown"))
        self.connected = false
        return false
    end
    
    print(string.format("[%s] TCP connection established", self.name))
    
    local sent, err = self.sock:send(CONFIG.secret_key)
    if not sent then
        print(string.format("[%s] Failed to send key: %s", self.name, err or "unknown"))
        self.connected = false
        return false
    end
    
    print(string.format("[%s] Secret key sent (%d bytes)", self.name, #CONFIG.secret_key))
    
    self.sock:settimeout(0.5) 
    local auth_response = self.sock:receive(1024)
    if auth_response and CONFIG.debug_mode then 
        print(string.format("[DEBUG %s] Auth response: %q", self.name, auth_response))
    end
    self.sock:settimeout(CONFIG.timeout) 
    
    self.connected = true
    self.consecutive_errors = 0  
    print(string.format("[%s] SUCCESSFULLY CONNECTED ", self.name))
    self.connection_attempts = 0
    return true
end

function Connection:request_and_receive()
    if not self.connected then
        return nil, "not connected"
    end
    
    local sent, err = self.sock:send(CONFIG.get_command)
    if not sent then
        self.connected = false
        self.consecutive_errors = self.consecutive_errors + 1
        return nil, "send error: " .. (err or "unknown")
    end
    
    local data, err = self:receive_exact()
    
    if not data then
        self.connected = false
        self.consecutive_errors = self.consecutive_errors + 1
        return nil, "receive error: " .. (err or "unknown")
    end
    
    self.last_request_time = socket.gettime()
    return data
end

function Connection:mark_success()
    self.consecutive_errors = 0
end

function Connection:mark_error()
    self.consecutive_errors = self.consecutive_errors + 1
end

function Connection:should_reconnect()
    return self.consecutive_errors >= CONFIG.max_consecutive_errors
end

function Connection:force_reconnect(reason)
    print(string.format("[%s] FORCE RECONNECT: %s (errors: %d/%d)", 
        self.name, reason, self.consecutive_errors, CONFIG.max_consecutive_errors))
    self:close()
    self.consecutive_errors = 0
end

function Connection:close()
    if self.sock then
        pcall(function() self.sock:close() end)
        self.sock = nil
    end
    self.connected = false
end


local function parse_server1_data(data)
    if #data ~= 15 then
        return nil, string.format("invalid data length: %d (expected 15)", #data)
    end
    
    local payload = data:sub(1, 14)
    local checksum = data:byte(15)
    local calculated = calculate_checksum(payload)
    
    if calculated ~= checksum then
        if CONFIG.debug_mode then
             local hex = {}
             for i = 1, #data do
                 hex[i] = string.format("%02X", data:byte(i))
             end
             print(string.format("[DEBUG Server1 RAW] Bytes: %s", table.concat(hex, " ")))
             local sum_payload = 0
             for i = 1, 14 do sum_payload = sum_payload + data:byte(i) end
             print(string.format("[DEBUG Server1 CHECK] Sum: %d, Got: %d, Calculated: %d", 
                 sum_payload, checksum, calculated))
             print("[Server1 WARNING] Checksum mismatch found but BYPASSED. Server's checksum is likely incorrect.")
        end
        return nil, string.format("checksum error: got %d, calculated %d", checksum, calculated)
    end
    
    local timestamp = bytes_to_uint64_be(data, 1)
    local temperature = bytes_to_float_be(data, 9)
    local pressure = bytes_to_int16_be(data, 13)
    
    return {
        timestamp = timestamp,
        datetime = timestamp_to_datetime(timestamp),
        temperature = temperature,
        pressure = pressure,
        source = "Server1"
    }
end

local function parse_server2_data(data)
    if #data ~= 21 then
        return nil, string.format("invalid data length: %d (expected 21)", #data)
    end
    
    local payload = data:sub(1, 20)
    local checksum = data:byte(21)
    local calculated = calculate_checksum(payload)
    
    if calculated ~= checksum then
        if CONFIG.debug_mode then
             local hex = {}
             for i = 1, #data do
                 hex[i] = string.format("%02X", data:byte(i))
             end
             print(string.format("[DEBUG Server2 RAW] Bytes: %s", table.concat(hex, " ")))
             local sum_payload = 0
             for i = 1, 20 do sum_payload = sum_payload + data:byte(i) end
             print(string.format("[DEBUG Server2 CHECK] Sum: %d, Got: %d, Calculated: %d", 
                 sum_payload, checksum, calculated))
        end
        return nil, string.format("checksum error: got %d, calculated %d", checksum, calculated)
    end
    
    local timestamp = bytes_to_uint64_be(data, 1)
    local x = bytes_to_int32_be(data, 9)
    local y = bytes_to_int32_be(data, 13)
    local z = bytes_to_int32_be(data, 17)
    
    return {
        timestamp = timestamp,
        datetime = timestamp_to_datetime(timestamp),
        x = x,
        y = y,
        z = z,
        source = "Server2"
    }
end


local function write_to_file(file, data)
    if data.source == "Server1" then
        file:write(string.format("%s | %s | Temp: %.2f°C | Press: %d Pa\n",
            data.datetime, data.source, data.temperature, data.pressure))
    else
        file:write(string.format("%s | %s | X: %d | Y: %d | Z: %d\n",
            data.datetime, data.source, data.x, data.y, data.z))
    end
    file:flush()
end

local function main()
    print("\n" .. string.rep("=", 50))
    print("  DATA COLLECTION FROM TWO SERVERS")
    print(string.rep("=", 50))
    print("Press Ctrl+C to stop the program\n")
    
    local file = io.open(CONFIG.output_file, "a")
    if not file then
        print("CRITICAL ERROR: Failed to open file for writing: " .. CONFIG.output_file)
        return
    end
    
    print("Output file opened: " .. CONFIG.output_file)
    
    file:write(string.format("\n%s\n", string.rep("=", 60)))
    file:write(string.format("SESSION START: %s\n", os.date("%Y-%m-%d %H:%M:%S")))
    file:write(string.format("%s\n\n", string.rep("=", 60)))
    file:flush()
    
    local conn1 = Connection:new(CONFIG.port1, 15, "Server1")
    local conn2 = Connection:new(CONFIG.port2, 21, "Server2")
    
    local function cleanup_and_exit()
        print("\n\nGraceful Shutdown")
        conn1:close()
        conn2:close()
        if file then
            local current_time, err = pcall(os.date, "%Y-%m-%d %H:%M:%S", os.time())
            if not current_time then current_time = "Unknown time" end
            file:write(string.format("\n%s\n", string.rep("=", 60)))
            file:write(string.format("SESSION END: %s\n", current_time))
            file:write(string.format("%s\n", string.rep("=", 60)))
            file:close()
        end
        print("Sockets and file closed.")
        os.exit(0)
    end

    local stats = {
        server1_count = 0,
        server2_count = 0,
        server1_errors = 0,
        server2_errors = 0,
        server1_reconnects = 0,
        server2_reconnects = 0,
        start_time = os.time(),
        last_stats_time = os.time()
    }
    
    print("\nStarting main data collection loop\n")
    
    local function data_loop()
        if not conn1.connected then conn1:connect() end
        if not conn2.connected then conn2:connect() end
        
        while true do
            local process_count = 0
            
            if conn1:should_reconnect() then
                stats.server1_reconnects = stats.server1_reconnects + 1
                conn1:force_reconnect("reached error threshold")
            end
            
            if conn1.connected then
                local data, err = conn1:request_and_receive()
                if data then
                    local parsed, parse_err = parse_server1_data(data)
                    if parsed then
                        write_to_file(file, parsed)
                        conn1:mark_success() 
                        stats.server1_count = stats.server1_count + 1
                        process_count = process_count + 1
                        if stats.server1_count % 100 == 0 and not CONFIG.debug_mode then
                            print(string.format("[Server1] Records received: %d", stats.server1_count))
                        end
                    else
                        conn1:mark_error()
                        stats.server1_errors = stats.server1_errors + 1
                        print(string.format("[Server1] Parse/Format error: %s (consecutive: %d/%d)", 
                            parse_err, conn1.consecutive_errors, CONFIG.max_consecutive_errors))
                    end
                elseif err ~= "timeout" and err ~= "closed" then
                    stats.server1_errors = stats.server1_errors + 1
                    print(string.format("[Server1] Connection lost or error: %s (consecutive: %d/%d). Reconnecting...", 
                        err, conn1.consecutive_errors, CONFIG.max_consecutive_errors))
                    conn1:close()
                elseif err == "closed" then
                    stats.server1_errors = stats.server1_errors + 1
                    print(string.format("[Server1] Connection closed by remote host (consecutive: %d/%d). Reconnecting...", 
                        conn1.consecutive_errors, CONFIG.max_consecutive_errors))
                    conn1:close()
                end
            else
                if not conn1:connect() then
                    socket.sleep(CONFIG.reconnect_delay)
                end
            end
            
            if conn2:should_reconnect() then
                stats.server2_reconnects = stats.server2_reconnects + 1
                conn2:force_reconnect("reached error threshold")
            end
            
            if conn2.connected then
                local data, err = conn2:request_and_receive()
                if data then
                    local parsed, parse_err = parse_server2_data(data)
                    if parsed then
                        write_to_file(file, parsed)
                        conn2:mark_success()  
                        stats.server2_count = stats.server2_count + 1
                        process_count = process_count + 1
                        if stats.server2_count % 100 == 0 and not CONFIG.debug_mode then
                            print(string.format("[Server2] Records received: %d", stats.server2_count))
                        end
                    else
                        conn2:mark_error()
                        stats.server2_errors = stats.server2_errors + 1
                        print(string.format("[Server2] Parse error: %s (consecutive: %d/%d)", 
                            parse_err, conn2.consecutive_errors, CONFIG.max_consecutive_errors))
                    end
                elseif err ~= "timeout" and err ~= "closed" then
                    stats.server2_errors = stats.server2_errors + 1
                    print(string.format("[Server2] Connection lost or error: %s (consecutive: %d/%d). Reconnecting...", 
                        err, conn2.consecutive_errors, CONFIG.max_consecutive_errors))
                    conn2:close()
                elseif err == "closed" then
                    stats.server2_errors = stats.server2_errors + 1
                    print(string.format("[Server2] Connection closed by remote host (consecutive: %d/%d). Reconnecting...", 
                        conn2.consecutive_errors, CONFIG.max_consecutive_errors))
                    conn2:close()
                end
            else
                if not conn2:connect() then
                    socket.sleep(CONFIG.reconnect_delay)
                end
            end
            
            local current_time_os = os.time()
            if current_time_os - stats.last_stats_time >= 60 then
                local runtime = current_time_os - stats.start_time
                local rate1 = runtime > 0 and stats.server1_count / runtime or 0
                local rate2 = runtime > 0 and stats.server2_count / runtime or 0
                
                print(string.format("\n%s STATISTICS %s", string.rep("=", 15), string.rep("=", 15)))
                print(string.format("Runtime: %d sec (%.1f min)", runtime, runtime / 60))
                print(string.format("Server1: %d records, %d errors, %d reconnects (%.1f rec/sec)", 
                    stats.server1_count, stats.server1_errors, stats.server1_reconnects, rate1))
                print(string.format("Server2: %d records, %d errors, %d reconnects (%.1f rec/sec)", 
                    stats.server2_count, stats.server2_errors, stats.server2_reconnects, rate2))
                print(string.format("Total: %d records", stats.server1_count + stats.server2_count))
                print(string.format("Current errors: Server1=%d, Server2=%d", 
                    conn1.consecutive_errors, conn2.consecutive_errors))
                print(string.rep("=", 45) .. "\n")
                
                stats.last_stats_time = current_time_os
            end
            
            if process_count == 0 then
                 socket.sleep(CONFIG.request_interval or 0.001)
            end
        end
    end

    local status, err = pcall(data_loop)
    if not status then
        if string.find(tostring(err), "closed") or string.find(tostring(err), "interrupted") then
             cleanup_and_exit()
        else
            print("\nCRITICAL RUNTIME ERROR")
            print("Details: " .. tostring(err))
            print("\nStack trace:")
            print(debug.traceback())
            cleanup_and_exit()
        end
    end
end


main()

print("\nProgram terminated.")