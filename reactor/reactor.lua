local tempMax = 5000
local satMinP = 0.2
local shieldMinP = 0.25
local fuelConversionMaxP = 0.9

local r = peripheral.wrap("back")


local function initiateShutdown(r)
    r.stopReactor()
    print("Reactor shutdown initiated!")
    while true do sleep(1) end
end

term.setCursorPos(1,1)
term.clear()
print("Reactor monitor started.")
while true do
    local ri = r.getReactorInfo()
    local temp = ri.temperature
    local satP = ri.energySaturation / ri.maxEnergySaturation
    local shieldP = ri.fieldStrength / ri.maxFieldStrength
    local fuelConversionP = ri.fuelConversion / ri.maxFuelConversion
    
    if
        satP < satMinP or
        shieldP < shieldMinP or
        fuelConversionP > fuelConversionMaxP or
        temp > tempMax
    then
        initiateShutdown(r)
    end
    
    local remainingFuel = ri.maxFuelConversion - ri.fuelConversion
    local remainingFuelTicks = remainingFuel / (ri.fuelConversionRate/1000/1000/(1-fuelConversionP))
    local remainingFuelSeconds = remainingFuelTicks / 20
    local remainingFuelMinutes = remainingFuelSeconds / 60
    local remainingFuelHours = remainingFuelMinutes / 60

    term.setCursorPos(1,2)
    print(string.format(
        "Temp: %d / %d | Sat: %.2f%% | Shield: %.2f%% | Fuel Conv: %.2f%% | Suggested Field input: %d | Estimated refuel in: %02d:%02d:%02d",
        temp, tempMax,
        satP * 100,
        shieldP * 100,
        fuelConversionP * 100,
        ri.fieldDrainRate * 1.34,
        remainingFuelHours, remainingFuelMinutes % 60, remainingFuelSeconds % 60
    ))
end