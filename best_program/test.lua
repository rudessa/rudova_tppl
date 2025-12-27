local orig_socket = socket
local pass, fail = 0, 0

local function t(n,f)
    io.write(n.." ... ")
    local ok, err = pcall(f)
    if ok then
        print("OK")
        pass=pass+1
    else
        print("FAIL")
        fail=fail+1
    end
end

t("bytes_to_uint64_be",function() assert(bytes_to_uint64_be(string.char(0,0,0,0,0,0,0,1))==1) end)
t("bytes_to_uint64_be offset",function() assert(bytes_to_uint64_be(string.char(0,0,0,0,0,0,0,0,0,0,0,1),5)==1) end)
t("bytes_to_uint64_be max",function() assert(bytes_to_uint64_be(string.char(0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF))>0) end)
t("bytes_to_float_be zero",function() assert(bytes_to_float_be(string.char(0,0,0,0))==0.0) end)
t("bytes_to_float_be one",function() assert(math.abs(bytes_to_float_be(string.char(0x3F,0x80,0,0))-1.0)<0.001) end)
t("bytes_to_float_be neg",function() assert(math.abs(bytes_to_float_be(string.char(0xBF,0x80,0,0))+1.0)<0.001) end)
t("bytes_to_float_be inf",function() assert(bytes_to_float_be(string.char(0x7F,0x80,0,0))==math.huge) end)
t("bytes_to_float_be -inf",function() assert(bytes_to_float_be(string.char(0xFF,0x80,0,0))==-math.huge) end)
t("bytes_to_float_be NaN",function() local r=bytes_to_float_be(string.char(0x7F,0x80,0,1)) assert(r~=r) end)
t("bytes_to_float_be ofs",function() assert(math.abs(bytes_to_float_be(string.char(0,0,0,0,0x3F,0x80,0,0),5)-1.0)<0.001) end)
t("bytes_to_int16_be pos",function() assert(bytes_to_int16_be(string.char(0,1))==1) end)
t("bytes_to_int16_be neg",function() assert(bytes_to_int16_be(string.char(0xFF,0xFF))==-1) end)
t("bytes_to_int16_be min",function() assert(bytes_to_int16_be(string.char(0x80,0))==-32768) end)
t("bytes_to_int16_be max",function() assert(bytes_to_int16_be(string.char(0x7F,0xFF))==32767) end)
t("bytes_to_int16_be ofs",function() assert(bytes_to_int16_be(string.char(0,0,0,1),3)==1) end)
t("bytes_to_int32_be pos",function() assert(bytes_to_int32_be(string.char(0,0,0,1))==1) end)
t("bytes_to_int32_be neg",function() assert(bytes_to_int32_be(string.char(0xFF,0xFF,0xFF,0xFF))==-1) end)
t("bytes_to_int32_be min",function() assert(bytes_to_int32_be(string.char(0x80,0,0,0))==-2147483648) end)
t("bytes_to_int32_be max",function() assert(bytes_to_int32_be(string.char(0x7F,0xFF,0xFF,0xFF))==2147483647) end)
t("bytes_to_int32_be ofs",function() assert(bytes_to_int32_be(string.char(0,0,0,0,1),2)==1) end)
t("calculate_checksum",function() assert(calculate_checksum(string.char(1,2,3))==6) end)
t("calculate_checksum ovf",function() assert(calculate_checksum(string.char(0xFF,0xFF))==254) end)
t("calculate_checksum empty",function() assert(calculate_checksum("")==0) end)
t("timestamp valid",function() assert(type(timestamp_to_datetime(1609459200000000))=="string") end)
t("timestamp invalid",function() assert(string.find(timestamp_to_datetime(-1),"RAW_TIME")) end)
t("timestamp zero",function() assert(type(timestamp_to_datetime(0))=="string") end)
t("debug off",function() CONFIG.debug_mode=false debug_print_bytes("t","n") end)
t("debug on",function() CONFIG.debug_mode=true debug_print_bytes("test","n") CONFIG.debug_mode=false end)
t("debug long",function() CONFIG.debug_mode=true debug_print_bytes(string.rep("x",50),"n") CONFIG.debug_mode=false end)
t("debug empty",function() CONFIG.debug_mode=true debug_print_bytes("","n") CONFIG.debug_mode=false end)

t("Connection new",function()
    local c=Connection:new(5,15,"T")
    assert(c.port==5 and c.data_size==15)
end)

t("Connection mark_success",function()
    local c=Connection:new(5,15,"T")
    c.consecutive_errors=5
    c:mark_success()
    assert(c.consecutive_errors==0)
end)

t("Connection mark_error",function()
    local c=Connection:new(5,15,"T")
    c:mark_error()
    assert(c.consecutive_errors==1)
end)

t("Connection mark_error multi",function()
    local c=Connection:new(5,15,"T")
    c:mark_error()
    c:mark_error()
    assert(c.consecutive_errors==2)
end)

t("Connection should_reconnect",function()
    local c=Connection:new(5,15,"T")
    assert(not c:should_reconnect())
    c.consecutive_errors=1
    assert(c:should_reconnect())
end)

t("Connection connect ok",function()
    local old_tcp = socket.tcp
    local old_sleep = socket.sleep
    local old_gettime = socket.gettime
    
    socket.tcp = function()
        return {
            settimeout = function() end,
            connect = function() return true end,
            send = function() return 6 end,
            receive = function() return nil,"timeout" end,
            close = function() end
        }
    end
    socket.sleep = function() end
    socket.gettime = function() return 1 end
    
    local c = Connection:new(5,15,"T")
    local result = c:connect()
    
    socket.tcp = old_tcp
    socket.sleep = old_sleep
    socket.gettime = old_gettime
    
    assert(result and c.connected)
end)

t("Connection connect fail tcp",function()
    local old_tcp = socket.tcp
    socket.tcp = function() return nil end
    
    local c = Connection:new(5,15,"T")
    local result = c:connect()
    
    socket.tcp = old_tcp
    assert(not result)
end)

t("Connection connect fail conn",function()
    local old_tcp = socket.tcp
    local old_sleep = socket.sleep
    
    socket.tcp = function()
        return {
            settimeout = function() end,
            connect = function() return nil,"refused" end,
            close = function() end
        }
    end
    socket.sleep = function() end
    
    local c = Connection:new(5,15,"T")
    local result = c:connect()
    
    socket.tcp = old_tcp
    socket.sleep = old_sleep
    assert(not result)
end)

t("Connection connect fail send",function()
    local old_tcp = socket.tcp
    local old_sleep = socket.sleep
    
    socket.tcp = function()
        return {
            settimeout = function() end,
            connect = function() return true end,
            send = function() return nil,"err" end,
            close = function() end
        }
    end
    socket.sleep = function() end
    
    local c = Connection:new(5,15,"T")
    local result = c:connect()
    
    socket.tcp = old_tcp
    socket.sleep = old_sleep
    assert(not result)
end)

t("Connection connect debug",function()
    CONFIG.debug_mode = true
    local old_tcp = socket.tcp
    local old_sleep = socket.sleep
    local old_gettime = socket.gettime
    
    socket.tcp = function()
        return {
            settimeout = function() end,
            connect = function() return true end,
            send = function() return 6 end,
            receive = function() return nil,"timeout" end,
            close = function() end
        }
    end
    socket.sleep = function() end
    socket.gettime = function() return 1 end
    
    local c = Connection:new(5,15,"T")
    c:connect()
    
    CONFIG.debug_mode = false
    socket.tcp = old_tcp
    socket.sleep = old_sleep
    socket.gettime = old_gettime
end)

t("Connection receive_exact ok",function()
    local c = Connection:new(5,15,"T")
    c.connected = true
    c.sock = {
        receive = function(self, n)
            return string.rep("x", n)
        end
    }
    local d = c:receive_exact()
    assert(d and #d == 15)
end)

t("Connection receive_exact fail",function()
    local c = Connection:new(5,15,"T")
    c.connected = true
    c.sock = {
        receive = function(self, n)
            return nil, "error"
        end
    }
    local d = c:receive_exact()
    assert(d == nil and not c.connected)
end)

t("Connection req_recv not conn",function()
    local c = Connection:new(5,15,"T")
    local d,e = c:request_and_receive()
    assert(d==nil and e=="not connected")
end)

t("Connection req_recv send fail",function()
    local old_gettime = socket.gettime
    socket.gettime = function() return 1 end
    
    local c = Connection:new(5,15,"T")
    c.connected = true
    c.sock = {
        send = function() return nil, "error" end
    }
    local d = c:request_and_receive()
    assert(d==nil and c.consecutive_errors==1)
    
    socket.gettime = old_gettime
end)

t("Connection req_recv recv fail",function()
    local old_gettime = socket.gettime
    socket.gettime = function() return 1 end
    
    local c = Connection:new(5,15,"T")
    c.connected = true
    c.sock = {
        send = function() return 3 end,
        receive = function() return nil, "error" end
    }
    local d = c:request_and_receive()
    assert(d==nil and c.consecutive_errors==1)
    
    socket.gettime = old_gettime
end)

t("Connection req_recv ok",function()
    local old_gettime = socket.gettime
    socket.gettime = function() return 1 end
    
    local c = Connection:new(5,15,"T")
    c.connected = true
    c.sock = {
        send = function() return 3 end,
        receive = function(self, n) return string.rep("x", n) end
    }
    local d = c:request_and_receive()
    assert(d and #d == 15)
    
    socket.gettime = old_gettime
end)

t("Connection force_reconnect",function()
    local c = Connection:new(5,15,"T")
    c.connected = true
    c.sock = {close = function() end}
    c.consecutive_errors = 5
    c:force_reconnect("test")
    assert(not c.connected and c.consecutive_errors == 0)
end)

t("Connection force_reconnect debug",function()
    CONFIG.debug_mode = true
    local c = Connection:new(5,15,"T")
    c.connected = true
    c.sock = {close = function() end}
    c:force_reconnect("test")
    CONFIG.debug_mode = false
    assert(not c.connected)
end)

t("Connection close",function()
    local c = Connection:new(5,15,"T")
    c.connected = true
    c.sock = {close = function() end}
    c:close()
    assert(not c.connected and c.sock == nil)
end)

t("Connection close no sock",function()
    local c = Connection:new(5,15,"T")
    c.connected = true
    c.sock = nil
    c:close()
    assert(not c.connected)
end)

t("parse_server1 invalid len",function()
    local r,e=parse_server1_data("s")
    assert(r==nil and string.find(e,"invalid"))
end)

t("parse_server1 bad chk",function()
    local d=string.char(0,0,0,0,0,0,0,0,0,0,0,0,0,0,99)
    local r,e=parse_server1_data(d)
    assert(r==nil and string.find(e,"checksum"))
end)

t("parse_server1 chk debug",function()
    CONFIG.debug_mode=true
    local d=string.char(0,0,0,0,0,0,0,0,0,0,0,0,0,0,99)
    parse_server1_data(d)
    CONFIG.debug_mode=false
end)

t("parse_server1 ok",function()
    local ts=string.char(0,0,1,0x77,0x35,0x94,0xD8,0)
    local tp=string.char(0x42,0x28,0,0)
    local p=string.char(3,0xE8)
    local pl=ts..tp..p
    local d=pl..string.char(calculate_checksum(pl))
    local r=parse_server1_data(d)
    assert(r and r.source=="Server1" and r.pressure==1000)
end)

t("parse_server2 invalid len",function()
    local r,e=parse_server2_data("s")
    assert(r==nil and string.find(e,"invalid"))
end)

t("parse_server2 bad chk",function()
    local d=string.char(0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,99)
    local r,e=parse_server2_data(d)
    assert(r==nil and string.find(e,"checksum"))
end)

t("parse_server2 chk debug",function()
    CONFIG.debug_mode=true
    local d=string.char(0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,99)
    parse_server2_data(d)
    CONFIG.debug_mode=false
end)

t("parse_server2 ok",function()
    local ts=string.char(0,0,1,0x77,0x35,0x94,0xD8,0)
    local x=string.char(0,0,0,10)
    local y=string.char(0,0,0,20)
    local z=string.char(0,0,0,30)
    local pl=ts..x..y..z
    local d=pl..string.char(calculate_checksum(pl))
    local r=parse_server2_data(d)
    assert(r and r.source=="Server2" and r.x==10)
end)

t("write server1",function()
    local f=io.open("t.txt","w")
    write_to_file(f,{datetime="2021-01-01 00:00:00",source="Server1",temperature=25.5,pressure=1013})
    f:close()
    local r=io.open("t.txt","r")
    local c=r:read("*all")
    r:close()
    os.remove("t.txt")
    assert(string.find(c,"Server1"))
end)

t("write server2",function()
    local f=io.open("t.txt","w")
    write_to_file(f,{datetime="2021-01-01 00:00:00",source="Server2",x=100,y=200,z=300})
    f:close()
    local r=io.open("t.txt","r")
    local c=r:read("*all")
    r:close()
    os.remove("t.txt")
    assert(string.find(c,"Server2"))
end)


print(string.rep("=",50))
print(string.format("PASS: %d  FAIL: %d",pass,fail))
print(string.rep("=",50))
os.exit(fail==0 and 0 or 1)