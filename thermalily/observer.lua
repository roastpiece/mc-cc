-- Watches when thermalilies cooldown goes to zero
-- then sends signal to worker turtle to replace them

-- when new thermalily is detected sends signal to worker turtle to place lava
require("com")
require("message")

FLOWER_STATE = {
    NO_FLOWER = 0,
    IDLE = 1,
    BURNING = 2,
    COOLDOWN = 3
}

-- @returns all blockreaders found
local function init_peripherals()
    local blockreadersFound = { peripheral.find("blockReader") }
    return blockreadersFound
end

local function get_flower_state(blockreaders)
    local states = {}
    for i, reader in pairs(blockreaders) do
        states[i] = {
            checkIn = 0
        }
        local data = reader.getBlockData()
        if data == nil then
            states[i].state = FLOWER_STATE.NO_FLOWER
        elseif data.burnTime > 0 then
            states[i].state = FLOWER_STATE.BURNING
            states[i].checkIn = data.burnTime / 20
        elseif data.cooldown > 0 then
            states[i].state = FLOWER_STATE.COOLDOWN
        else
            states[i].state = FLOWER_STATE.IDLE
        end
    end

    return states
end

local function wait_for_cooldown(states)
    local waitTime = 0

    for _, state in pairs(states) do
        if state.state == FLOWER_STATE.BURNING then
            if waitTime < state.checkIn then
                waitTime = state.checkIn
            end
        end
    end

    if (waitTime > 0) then
        os.sleep(waitTime + 1)
    end
end

local function flowerReady(states)
    for _, state in pairs(states) do
        if state.state ~= FLOWER_STATE.IDLE then
            return false
        end
    end
    return true
end

local function main()
    local blockreaders = init_peripherals()
    local modem = InitObserver(10)
    while true do
        local states = get_flower_state(blockreaders)
        if states then
            if flowerReady(states) then
                modem.transmit({
                    action = ACTION.PLACE_LAVA
                })
            else
                wait_for_cooldown(states)
                modem.transmit({
                    action = ACTION.REPLACE_FLOWERS
                })
            end
        else
            blockreaders = init_peripherals()
        end
        os.sleep(1)
    end
end

main()
