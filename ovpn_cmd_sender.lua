local M = {}


---@param socket_adaptor CWebSocketAdapter
local function receive_ovpn_hearder_message(socket_adaptor)
    -- Считываем заголовок о подключении к VPN
    -- INFO:OpenVPN Management Interface Version 3 -- type 'help' for more info
    __log.debugf("receive_ovpn_hearder_message.")
    socket_adaptor:receive()
end


---@param socket_adaptor CWebSocketAdapter
local function receive_ovpn_password_message(socket_adaptor)
    -- Считываем строку об успешном вводе пароля
    -- SUCCESS: password is correct
    __log.debugf("receive_ovpn_password_message.")
    socket_adaptor:receive()
end


---@param socket_adaptor CWebSocketAdapter
local function receive_ovpn_main_message(socket_adaptor)
    return socket_adaptor:receive()
end


---@param socket_adaptor CWebSocketAdapter
local function process_password(socket_adaptor, password)
    --Отправка пароля
    __log.debugf("send password")
    local is_pcall_send_message_status, send_error = pcall(function() socket_adaptor:send(password .. '\n') end)
    if not is_pcall_send_message_status then
        socket_adaptor:close()
        return send_error.message, false
    end

    --Если пароль был неверный, то мы выйдем по тайм-ауту, и получим доступ к сообещни от ВПН "ENTER PASSWORD:"
    local response = socket_adaptor:receive()
    __log.debugf("response = '%s'", response)
    if response == "ENTER PASSWORD:" then
        __log.info("Incorrect password by configuration.")
        socket_adaptor:close()
        return "Incorrect password by configuration.", false
    end

    --Если пароль был верным, то мы прочтем ответное сообщение "SUCCESS: password is correct"
    local is_pcall_password_status, password_error_output = pcall(receive_ovpn_password_message, socket_adaptor)
    __log.debugf("is_pcall_password_status '%s', password_error_output '%s'", is_pcall_password_status, password_error_output)
    if not is_pcall_password_status then
        socket_adaptor:close()
        return password_error_output.message, false
    end
    return "Password is correct.", true
end


--[[
    При подключении к ВПН без получения ответа - сразу затребывается пароль, ожидается его получение. Поэтому получить подпись "ENTER PASSWORD:" от менеджера ВПН
    невозможно. Для невелирования такой ситуации используется механизм Тайм-Аута.
    1) Коннектимся к ВПН. Если не требуется пароль, то сразу получим вступительное сообщение "INFO:OpenVPN Management...". Всё.
    Если требуется пароль, то при подключении сработает тайм-аут получения ответа от сервера. Получим содержимое ответа в виде: ожидаем выхода по тайм-ауту
    "ENTER PASSWORD:", генерируем ошибку "For connection need password.".
    2) Передаем пароль.
    3) Если пароль подошел, то получим сообщение "INFO:OpenVPN Management...". Всё.
    4) Если пароль не подошел, то снова выйдем по тайм-ауту. Идентифицируем эту ошибку как "Incorrect password by configuration" и закроем соединение
--]]
---@param password string
---@param message string
---@param socket_adaptor CWebSocketAdapter
---@return boolean, string|table
function M.send(password, message, socket_adaptor)
    --Соединение с ВПН с дополнительной проверкой (следующие строки) на необходимость пароля
    local is_pcall_connect_status, connect_error = pcall(function() socket_adaptor:connect(nil, 0.5) end)
    __log.debugf("pcall_connect_status = '%s', connect_error = '%s'.", is_pcall_connect_status, connect_error)

    --Если ошибка соединения была по тайм-ауту, и от нас ожидали пароль, то
    if not is_pcall_connect_status then
        --Если от нас ожидают пароль и он у нас есть, то вводим
        if password and string.find(connect_error, "For connection need password.", 1, true) then
            local error_message, is_success = process_password(socket_adaptor, password)
            --если пароль не подошел
            if not is_success then
                __log.debugf("status process_password = '%s', error_message = '%s'.", is_success, error_message)
                socket_adaptor:close()
                return error_message, is_success
            end
        else
            --если ошибка соединения была по любой другой причине (не выход по тайм-ауту из-за пароля)
            __log.debugf("pcall_connect_status = '%s'.", is_pcall_connect_status)
            socket_adaptor:close()
            return connect_error.message, false
        end
    end

    --Прочитывание вступительного заголовка
    local is_pcall_header_status, header_error_output = pcall(receive_ovpn_hearder_message, socket_adaptor)
    __log.debugf("pcall_header_status = '%s', header_error_output = '%s'.", is_pcall_header_status, header_error_output)
    if not is_pcall_header_status then
        socket_adaptor:close()
        return header_error_output.message, false
    end

    --Блокировка пользователя
    local is_pcall_send_status, send_error = pcall(function() socket_adaptor:send(message .. '\n') end)
    __log.debugf("pcall_send_status = '%s', send_error = '%s'.", is_pcall_send_status, send_error)
    if not is_pcall_send_status then
        socket_adaptor:close()
        return send_error.message, false
    end

    --Результат блокировки пользователя
    local is_pcall_main_status, main_output = pcall(receive_ovpn_main_message, socket_adaptor)
    __log.debugf("pcall_main_status = '%s', main_output = '%s'.", is_pcall_main_status, main_output)
    if not is_pcall_main_status then
        socket_adaptor:close()
        return main_output.message, false
    end
    __log.debugf("socket_adaptor:close()")
    socket_adaptor:close()
    return main_output, true
end


return M