local socket = require("socket")


---@class CWebSocketAdapter
---@field host string
---@field port string
local CWebSocketAdapter = {}


---@param host string
---@param port string
function CWebSocketAdapter:new(host, port)
    local new_obj = {}
    new_obj.host = host
    new_obj.port = port

    self.__index = self

    return setmetatable(new_obj, self)
end


---@param block_timeout number
---@param total_timeout number
function CWebSocketAdapter:connect(block_timeout, total_timeout)
    local tcp = assert(socket.tcp())
    if block_timeout then
        tcp:settimeout(block_timeout, 'b')
        __log.infof("set block timeout %s", block_timeout)
    end
    if total_timeout then
        tcp:settimeout(total_timeout, 't')
        __log.infof("set total timeout %s", total_timeout)
    end

    tcp:connect(self.host, self.port);
    self.tcp = tcp
    local s, status, partial = self.tcp:receive()
    __log.debugf("connect s = %s, status = %s, partial = %s", s, status, partial)

    --Если при соединении требует ввести пароль, то генерируем ошибку, чтобы выше ее обработать
    if partial == "ENTER PASSWORD:" then
        __log.infof("For connection need password.")
        error("For connection need password.")
    end
end


---@param message string
function CWebSocketAdapter:send(message)
    self.tcp:send(message)
end


function CWebSocketAdapter:receive()
    local s, status, partial = self.tcp:receive()
    if (status == "Socket is not connected") then
        error({message = status})
    end

    local message = s or partial
    return message
end


function CWebSocketAdapter:close()
    self.tcp:close()
end

return CWebSocketAdapter