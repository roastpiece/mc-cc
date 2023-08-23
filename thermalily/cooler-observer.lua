-- Watches when thermalilies cooldown goes to zero
-- then sends signal to worker turtle to replace them

-- when new thermalily is detected sends signal to worker turtle to place lava
require("com")

FLOWER_STATE = {
    NO_FLOWER = 0,
    IDLE = 1,
    COOLDOWN = 2
}

-- @returns all blockreaders found
local function init_peripherals()
    local blockreadersFound = { peripheral.find("blockReader") }
    return blockreadersFound
end

local function get_flower_state(blockreaders)
    local states = {}
    for i, reader in pairs(blockreaders) do
        local data = reader.getBlockData()
        states[i] = {
            checkIn = 0,
        }
        if data == nil then
            states[i].state = FLOWER_STATE.NO_FLOWER
        elseif data.cooldown > 0 then
            states[i].state = FLOWER_STATE.COOLDOWN
            states[i].x = data.x
            states[i].z = data.z
            states[i].checkIn = data.cooldown
        else
            states[i].state = FLOWER_STATE.IDLE
            states[i].x = data.x
            states[i].z = data.z
        end
    end

    return states
end

local function findCooledDownFlowers(states)
    local found = {}
    for i, state in pairs(states) do
        if state.state == FLOWER_STATE.COOLDOWN and state.checkIn < 20 then
            table.insert(found, state)
        elseif state.state == FLOWER_STATE.IDLE then
            table.insert(found, state)
        end
    end
    return found
end

local function getCalibrationPositions(blockreaders)
    local positions = {}
    for i, reader in pairs(blockreaders) do
        local data = reader.getBlockData()
        if data ~= nil and data.id == "minecraft:chest" then
            table.insert(positions, {
                x = data.x, z = data.z
            })
        end
    end
    return positions
end

local function main()
    local blockreaders = init_peripherals()
    local modem = InitObserver(20)

    local calibrating = true
    while calibrating do
        local positions = getCalibrationPositions(blockreaders)

        calibrating = false
        for _, pos in pairs(positions) do
            calibrating = true
            modem.transmit({
                message = "calibration",
                position = pos
            })
        end

        os.sleep(10)
    end

    while true do
        local states = get_flower_state(blockreaders)
        if states then
            local allCooled = findCooledDownFlowers(states)

            for _, cooled in pairs(allCooled) do
                modem.transmit({
                    message = "cooled",
                    position = {
                        x = cooled.x, z = cooled.z
                    }
                })
            end
        else
            blockreaders = init_peripherals()
        end
        os.sleep(1)
    end
end

main()
