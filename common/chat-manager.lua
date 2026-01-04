--- @class ChatBox
--- @field sendMessage fun(message: string, prefix?: string, brackets?: string, bracketColor?: string, range?: number, utf8Support?: boolean): true | nil, string
--- @field sendToastToPlayer fun(message: string, title: string, username: string, prefix?: string, brackets?: string, bracketColor?: string, range?: number, utf8Support?: boolean): true | nil, string

--- @class Message
--- @field text string
--- @field title string
--- @field receipients table<number, string>

--- @class ChatManager
--- @field chatBox ChatBox
--- @field prefix string
--- @field scheduledMessages table<number, Message>
local CM = {}

function CM.new(chatBox, prefix)
    local self = setmetatable({}, { __index = CM })
    
    if not chatBox then
        error("No chat box peripheral provided!")
    end

    self.chatBox = chatBox
    self.prefix = prefix
    self.scheduledMessages = {}

    return self
end

function CM:sendMessage(msg)
    self.chatBox.sendMessage(msg, self.prefix)
end

--- @param msg string
--- @param receipients table<number, string>
function CM:scheduleToast(msg, title, receipients)
    table.insert(self.scheduledMessages, {
        text = msg,
        title = title,
        receipients = receipients
    })
end

--- @param self ChatManager
--- @param message Message
--- @return boolean success
local function trySendScheduledMessage(self, message)
    local remaining = {}
    for _, username in pairs(message.receipients) do
        local ok, err = self.chatBox.sendToastToPlayer(
            message.text,
            message.title,
            username,
            self.prefix
        )
        if not ok then
            table.insert(remaining, username)
        end
    end
    
    if #remaining > 0 then
        message.receipients = remaining
        return false
    end
    return true
end

function CM:worker()
    while true do
        for i, message in ipairs(self.scheduledMessages) do
            local success = trySendScheduledMessage(self, message)
            if success then
                table.remove(self.scheduledMessages, i)
            end
        end
        
        sleep(10)
    end
end

return CM