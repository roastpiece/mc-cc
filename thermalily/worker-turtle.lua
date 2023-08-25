-- listens for signals from observer
-- cooldown: replace with new lily
-- lava: place lava for specified flower, test if lava gets picked up, when not, pick it up again (safety) --> error handling

-- while idle, refuel, get new flowers, dump old flowers

local move = require("move-turtle")
require("config")

local NBT_0_COOLDOWN_HASH = "43372382d5ee1774a14712b3c5e67db8"


local function findNewFlowersInInventory()
    for i = 1, 16 do
        local it = turtle.getItemDetail(i, true)
        if it ~= nil and it.name == "botania:floating_thermalily" then
            if it.nbt == nil or it.nbt == NBT_0_COOLDOWN_HASH then
                return i
            end
        end
    end
    error("No Thermalilies in Inventory") -- Maybe handle this and go get new lilies instead
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

local function findInInventory(name)
    for i = 1, 16 do
        local it = turtle.getItemDetail(i)
        if it ~= nil and it.name == name then
            return i
        end
    end
    return -1
end

local function MoveTo(pos)
    move.Absolute(pos.x, pos.z)
end


local function FillBuckets()
    MoveTo(BUCKETS_POS)
    while true do
        local slot_id = findInInventory("minecraft:bucket")
        if slot_id == -1 then return end
        turtle.select(slot_id)
        turtle.dropDown()
        turtle.suckDown()
    end
end

local function DumpFlowers()
    MoveTo(DUMP_POS)
    while true do
        local slot_id = findFlowersOnCooldownInInventory()
        if slot_id == -1 then return end
        turtle.select(slot_id)
        turtle.dropDown()
    end
end

local function getNewBuckets()
    MoveTo(BUCKETS_POS)
    for i = 1, 3 do
        turtle.suckDown()
    end
end

local function getNewFlowers()
    local flowersInInventory = 0
    for i = 1, 16 do
        local item = turtle.getItemDetail(i, true)
        if item ~= nil and item.name == "botania:floating_thermalily" and item.nbt == NBT_0_COOLDOWN_HASH then
            flowersInInventory = flowersInInventory + item.count
        end
    end

    if flowersInInventory < 6 then
        MoveTo(FLOWERS_POS)
        turtle.suckDown(6 - flowersInInventory)
    end
end

local function refuel()
    if turtle.getFuelLevel() < 100 then
        local slot_id = findInInventory("minecraft:lava_bucket")
        turtle.select(slot_id)
        turtle.refuel()
        FillBuckets()
    end
end

-- called after work is done (eg. placed flowers/lava)
local function doChores()
    DumpFlowers()
    FillBuckets()
    refuel()
    getNewFlowers()
    MoveTo(HOME_POS)
end

function ReplaceFlower()
    turtle.digDown()
    local slot_id = findNewFlowersInInventory()
    turtle.select(slot_id)
    turtle.placeDown()
end

function PlaceLava(n)
    n = n or 1
    for _ = 1, n do
        local slot_id = findInInventory("minecraft:lava_bucket")
        turtle.select(slot_id)
        turtle.placeDown()
    end
end

function ReplaceAllFlowers()
    for _ = 1, 3 do
        move.Forward()
        ReplaceFlower()
    end
    move.Back()
    move.Left()
    PlaceLava(3)

    move.Right()
    move.Forward()
    for _ = 1, 2 do
        move.Forward()
        ReplaceFlower()
    end
    move.Back()
    move.Left()
    PlaceLava(2)
end

function main()
    move.SetTransform(HOME_POS.x, HOME_POS.y, HOME_POS.z, HOME_POS.o)

    while true do
        ReplaceAllFlowers()
        doChores()
        os.sleep(35) --fixme
    end
end

main()
