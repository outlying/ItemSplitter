local addonName, ns = ...

-- Define log levels
local LOG_LEVELS = {
    ERROR = 1,
    WARN = 2,
    INFO = 3,
    DEBUG = 4
}

-- Set the current log level (only logs at or above this level will be printed)
local CURRENT_LOG_LEVEL = LOG_LEVELS.WARN -- Adjust this to control log verbosity

-- Create the Log table in the ns (namespace) table
ns.Log = {}

-- Internal function to handle logging
local function logMessage(message, level)
    if not message then
        return
    end

    local logLevelValue = LOG_LEVELS[level] or LOG_LEVELS.INFO

    -- Only log if the message level is equal or higher than the current log level
    if logLevelValue <= CURRENT_LOG_LEVEL then
        local color = "|cffffd700" -- Default color is yellow

        -- Set color based on level
        if level == "ERROR" then
            color = "|cffff0000" -- Red for errors
        elseif level == "WARN" then
            color = "|cffffff00" -- Yellow for warnings
        elseif level == "DEBUG" then
            color = "|cff00ff00" -- Green for debug messages
        elseif level == "INFO" then
            color = "|cffffffd7" -- Light yellow for info
        end

        DEFAULT_CHAT_FRAME:AddMessage(color .. "[" .. level .. "]:|r " .. tostring(message))
    end
end

-- Define methods for each log level in ns.Log
function ns.Log.error(message)
    logMessage(message, "ERROR")
end

function ns.Log.warn(message)
    logMessage(message, "WARN")
end

function ns.Log.info(message)
    logMessage(message, "INFO")
end

function ns.Log.debug(message)
    logMessage(message, "DEBUG")
end
