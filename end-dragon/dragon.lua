local move = require("move-turtle")
require("config-worker")

local RESERVED_SLOTS = {15, 16} -- For peripherals

local automata = peripheral.wrap("left")
if not automata or automata.savePoint == nil then
    error("No automata peripheral found on left side!")
end

local function panic(msg)
    print("PANIC: " .. msg)
    exit()
end

local function ensurePeripheral(name)
    local ty = turtle.getEquippedRight()
    if ty.name == name then
        return peripheral.wrap("right")
    end

    for _, slot in pairs(RESERVED_SLOTS) do
        local it = turtle.getItemDetail(slot)
        if it ~= nil and it.name == name then
            turtle.select(slot)
            turtle.equipRight()
            return peripheral.wrap("right")
        end
    end
    
    return nil
end

local function message(msg)
    local chatBox = ensurePeripheral("advancedperipherals:chat_box")
    if not chatBox then
        panic("No chat box found in reserved slots!")
    end

    print("Sending message: " .. msg)
    chatBox.sendMessage(msg, "Dragon Turtle")
end

local function waitForBlockId(blockId)
    print("Waiting for block: " .. (blockId or "nil"))
    while true do
        local ok, it = turtle.inspect()
        if blockId == nil and not ok then
            return
        end

        if ok and it.name == blockId then
            return
        end
        sleep(1)
    end
end

local function waitAndBreakEgg()
    print("Waiting for dragon egg...")
    ensurePeripheral("minecraft:diamond_pickaxe")
    waitForBlockId("minecraft:dragon_egg")
    turtle.dig()
end

local function ensureEndCrystals()
    print("Checking for end crystals...")
    for i = 1, 16 do
        for _, reserved in pairs(RESERVED_SLOTS) do
            if i == reserved then
                goto continue
            end
        end
        
        local it = turtle.getItemDetail(i)
        if it ~= nil and it.name == "minecraft:end_crystal" and it.count >= 4 then
            turtle.select(i)
            return true
        end
        ::continue::
    end

    return false
end

local function tryRefuel()
    for _, slot in pairs(RESERVED_SLOTS) do
        local it = turtle.getItemDetail(slot)
        if it ~= nil and it.name == "draconicevolution:wyvern_capacitor" then
            turtle.select(slot)
            automata.chargeTurtle()
        end
    end
    return true
end

local function ensureFuel()
    tryRefuel()

    if turtle.getFuelLevel() < 1000 then
        message("Low on fuel! Please recharge capacitor.")
    end
        
    while tryRefuel() and turtle.getFuelLevel() < 1000 do
        sleep(5)
    end
end

local function tryPlaceEndCrystal()
    local ok, it = turtle.inspect()
    if ok and it.name == "minecraft:end_crystal" then
        return true
    end
    
    turtle.place() -- ignore failure
    return true
end

local function placeEndCrystals()
    print("Placing end crystals...")
    automata.warpToPoint("east_crystal")
    move.TurnToOrientation(ORIENTATION.EAST)
    if not tryPlaceEndCrystal() then
        return false
    end

    automata.warpToPoint("west_crystal")
    move.TurnToOrientation(ORIENTATION.WEST)
    if not tryPlaceEndCrystal() then
        return false
    end

    automata.warpToPoint("south_crystal")
    move.TurnToOrientation(ORIENTATION.SOUTH)
    if not tryPlaceEndCrystal() then
        return false
    end

    automata.warpToPoint("north_crystal")
    move.TurnToOrientation(ORIENTATION.NORTH)
    if not tryPlaceEndCrystal() then
        return false
    end
    
    return true
end

local function verifyWarpPoints()
    local points = automata.points()
    if points == nil then
        return false
    end
    
    local requiredPoints = {
        "home",
        "east_crystal",
        "west_crystal",
        "south_crystal",
        "north_crystal",
        "save_postdeath",
        "save_prespawn",
    }
    
    for _, p in pairs(requiredPoints) do
        for _, existing in pairs(points) do
            if existing == p then
                goto continue
            end
        end
        print("Missing automata warp point: " .. p)
        do return false end
        ::continue::
    end
    
    return true
end

local function setup()
    local success = true
    local msg = nil

    move.SetTransform(HOME_POS.x, HOME_POS.y, HOME_POS.z, HOME_POS.o)
    
    if verifyWarpPoints() then
        print("All automata warp points already set up.")
        return true
    end

    success, msg = success and automata.savePoint("home")
    if msg then
        print(msg)
    end
    
    move.Absolute(7, 0)
    success, msg = success and automata.savePoint("east_crystal")
    if msg then
        print(msg)
    end

    move.Absolute(-7, 0)
    success, msg = success and automata.savePoint("west_crystal")
    if msg then
        print(msg)
    end

    move.Absolute(0, 7)
    success, msg = success and automata.savePoint("south_crystal")
    if msg then
        print(msg)
    end

    move.Absolute(0, -4)
    success, msg = success and automata.savePoint("save_postdeath")
    if msg then
        print(msg)
    end

    move.Absolute(0, -7)
    success, msg = success and automata.savePoint("north_crystal")
    if msg then
        print(msg)
    end
    
    move.Absolute(-4, -7)
    move.Absolute(-4, -8)
    success, msg = success and automata.savePoint("save_prespawn")
    if msg then
        print(msg)
    end
    
    return success
end

local function selectItemSlot(itemName)
    for i = 1, 16 do
        local it = turtle.getItemDetail(i)
        if it ~= nil and it.name == itemName then
            turtle.select(i)
            return true
        end
    end
    return false
end

local function main()
    if not setup() then
        panic("Failed to setup automata save points!")
    end
    
    automata.warpToPoint("home")
    move.TurnToOrientation(HOME_POS.o)
    while true do
        ensureFuel()
        
        automata.warpToPoint("save_prespawn")
        move.TurnToOrientation(ORIENTATION.EAST)
        waitForBlockId("minecraft:end_stone_bricks")
        ensurePeripheral("minecraft:diamond_pickaxe")
        turtle.dig()
        
        automata.warpToPoint("save_postdeath")
        move.TurnToOrientation(ORIENTATION.SOUTH)
        selectItemSlot("minecraft:end_stone_bricks")
        turtle.place()
        waitForBlockId(nil)
        
        --[[
        automata.warpToPoint("home")
        move.TurnToOrientation(HOME_POS.o)
        ]]

        if not ensureEndCrystals() then
            message("Out of end crystals! Please restock.")
            while not ensureEndCrystals() do
                sleep(1)
            end
        end
        if not placeEndCrystals() then
            message("Failed to place end crystals!")
            return
        end
    end
end

main()
automata.warpToPoint("save_prespawn")
move.TurnToOrientation(HOME_POS.o)