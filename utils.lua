local M = {}

string.startswith = function(self, str)
    return self:find('^' .. str:upper()) ~= nil
end

local function check_line_is_error(output)
    if (output:startswith("ERROR:")) then
        return true
    else
        return false
    end
end

local function split_output_message (inputstr, sep)
    if sep == nil then
        sep = "%s"
    end
    local t={}
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
        table.insert(t, str)
    end
    return t
end

function M.check_output_message_is_error(output)
    local output_lines = split_output_message(output, "\n")
    for _, message_line in ipairs(output_lines) do
        if (check_line_is_error(message_line)) then
            return true, message_line
        end
    end

    return false
end

return M