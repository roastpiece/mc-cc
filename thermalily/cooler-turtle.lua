local move = require("move-turtle")
require("com")
local inspect             = require("inspect")
local LuaSerializer       = LuaSerializer or require("LuaSerializer")

--- get coords of done flowers, collect them

local NBT_0_COOLDOWN_HASH = "43372382d5ee1774a14712b3c5e67db8"

local HOME_POS            = { x = -150, y = 5, z = 96, o = ORIENTATION.SOUTH }
local DUMP_POS            = { x = -149, z = 96 }
local FLOWERS_POS         = { x = -150, z = 96 }

local workQueue           = {}
local currentWork

local calibrationQueue    = {}
local currentCalibration

local plantablePositions  = {}
local POSITION_STATE      = {
    FREE          = 1,
    PENDING_PLANT = 2,
    PLANTED       = 3
}

local function comparePositions(a, b)
    if a == nil or b == nil then
        return false
    end
    return a.x == b.x and a.z == b.z
end

local function compareWorkHarvest(a, b)
    if a == nil or b == nil then
        return false
    end
    return a.action == b.action and comparePositions(a.position, b.position)
end

local function tableFind(t, p)
    for _, val in pairs(t) do
        if p(val) then
            return val
        end
    end
    return nil
end

local function findFlowersOnCooldownInInventory()
    for i = 1, 16 do
        local it = turtle.getItemDetail(i, true)
        if it ~= nil and it.name == "botania:floating_thermalily" then
            if it.nbt ~= nil and it.nbt ~= NBT_0_COOLDOWN_HASH then
                return i
            end
        end
    end
    return -1
end

local function findNewFlowersInInventory()
    for i = 1, 16 do
        local it = turtle.getItemDetail(i, true)
        if it ~= nil and it.name == "botania:floating_thermalily" then
            if it.nbt == nil or it.nbt == NBT_0_COOLDOWN_HASH then
                return i
            end
        end
    end
    return -1
end

local function MoveTo(pos)
    move.Absolute(pos.x, pos.z)
end

local function DumpFlowers()
    while true do
        local slot_id = findNewFlowersInInventory()
        if slot_id == -1 then return end
        turtle.select(slot_id)
        turtle.dropDown()
    end
end

local function workCooled(work)
    MoveTo(work.position)
    if turtle.digDown() then
        work.position.state = POSITION_STATE.FREE
    end
end

local function workDump(work)
    local flowersInInventory = 0
    for i = 1, 16 do
        local item = turtle.getItemDetail(i)
        if item ~= nil and item.name == "botania:floating_thermalily" and item.count > 1 then
            flowersInInventory = flowersInInventory + 1
        end
    end

    if flowersInInventory >= 1 then
        MoveTo(DUMP_POS)
        DumpFlowers()
    end
end

local function workGetFlowers(work)
    local flowersInInventory = 0
    for i = 1, 16 do
        local item = turtle.getItemDetail(i)
        if item ~= nil and item.name == "botania:floating_thermalily" and item.count == 1 then
            flowersInInventory = flowersInInventory + 1
        end
    end

    if flowersInInventory < 10 then
        MoveTo(FLOWERS_POS)
        for i = 1, 10 - flowersInInventory do
            turtle.suckDown()
        end
    end
end

local function workCalibrate(work)
    if tableFind(plantablePositions, function(val)
            return comparePositions(val, work.position)
        end) == nil then
        work.position.state = POSITION_STATE.FREE
        table.insert(plantablePositions, work.position)

        local file = fs.open("calibration-cache", "w")
        local dataSerialized = LuaSerializer.serialize_nocompress(plantablePositions)
        file.write(dataSerialized)
        file.close()
    end
    MoveTo(work.position)
    turtle.digDown()
end

local function workPlant(work)
    local slot = findFlowersOnCooldownInInventory()
    if slot ~= -1 then
        MoveTo(work.position)
        turtle.select(slot)
        if turtle.placeDown() then
            work.position.state = POSITION_STATE.PLANTED
        end
    else
        work.position.state = POSITION_STATE.FREE
    end
end

local WORK_ACTIONS = {
    HARVEST = workCooled,
    DUMP = workDump,
    GET_FLOWERS = workGetFlowers,
    CALIBRATE = workCalibrate,
    PLANT = workPlant
}

local function listenForMessage()
    while true do
        local channel, message
        repeat
            _, _, channel, _, message, _ = os.pullEvent("modem_message")
        until channel == 20

        --print("Message received: ", inspect(message))
        if message.message == "cooled" then
            local newWork = {
                action = WORK_ACTIONS.HARVEST,
                position = tableFind(plantablePositions, function(val)
                    return comparePositions(val, message.position)
                end)
            }
            if tableFind(workQueue, function(val)
                    return compareWorkHarvest(val, newWork)
                end) == nil and (not compareWorkHarvest(currentWork, newWork)) then
                table.insert(workQueue, newWork)
                print("cooled: ", newWork.position.x, ",", newWork.position.z)
            end
        elseif message.message == "calibration" then
            if tableFind(calibrationQueue, function(val)
                    return comparePositions(val.position, message.position)
                end) == nil and (not comparePositions(currentCalibration, message.position)) then
                table.insert(calibrationQueue, {
                    action = WORK_ACTIONS.CALIBRATE,
                    position = message.position
                })

                print("calibration: ", message.position.x, ",", message.position.z)
            end
        end
    end
end

local function scheduleChores()
    while true do
        table.insert(workQueue, {
            action = WORK_ACTIONS.GET_FLOWERS
        })
        table.insert(workQueue, {
            action = WORK_ACTIONS.DUMP
        })
        os.sleep(10)
    end
end

local function schedulePlanting()
    while true do
        for i = 1, 6 do
            local position = tableFind(plantablePositions, function(val)
                return val.state == POSITION_STATE.FREE
            end)
            if position ~= nil then
                position.state = POSITION_STATE.PENDING_PLANT
                table.insert(workQueue, {
                    action = WORK_ACTIONS.PLANT,
                    position = position
                })
            end
        end

        local freePlots = 0
        for _, pos in pairs(plantablePositions) do
            if pos.state == POSITION_STATE.FREE then
                freePlots = freePlots + 1
            end
        end
        print("free plots: ", freePlots)
        os.sleep(10)
    end
end

local function doWork()
    while true do
        currentCalibration = table.remove(calibrationQueue)
        if currentCalibration ~= nil then
            currentCalibration.action(currentCalibration)
            currentCalibration = nil
        else
            currentWork = table.remove(workQueue)
            if currentWork ~= nil then
                currentWork.action(currentWork)
                currentWork = nil
            end
        end
        os.sleep(0)
    end
end

local function exitHandler()
    os.pullEventRaw("terminate")
    MoveTo(HOME_POS)
    return
end

local function loadCache()
    local file = fs.open("calibration-cache", "r")
    if file ~= nil then
        local data = file.readAll()
        plantablePositions = LuaSerializer.unserialize_nocompress(data)[1]

        for _, pos in pairs(plantablePositions) do
            pos.state = POSITION_STATE.FREE
        end
    end
end

local function main()
    move.SetTransform(HOME_POS.x, HOME_POS.y, HOME_POS.z, HOME_POS.o)
    loadCache()

    local modem = InitWorker(20)
    parallel.waitForAll(listenForMessage, doWork, schedulePlanting, scheduleChores, exitHandler)
end

main()
