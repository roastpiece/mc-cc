--- @source CC-Tweaked/doc/stub/os.lua
--- @source CC-Tweaked/projects/core/src/main/resources/data/computercraft/lua/rom/apis/term.lua

--- Hard limits
local tempMax = 8000
local satMinP = 0.15
local shieldMinP = 0.20
local fuelConversionMaxP = 0.9

--- Target parameters
local shieldTargetP = 0.25
local maxTrend = 0.1
local targetOutputFlow = 20 * 1000 * 1000
local targetTemp = 7500
local targetSatP = 0.5

local dryRun = true

local reactorSide        = "back"
local inputFlowGateSide  = "flow_gate_2"
local outputFlowGateSide = "flow_gate_3"


--[[ Configuration End ]]

local lastTempC = 20
local lastTemps = {}

local function resetLastTemps()
    lastTemps = {}
    
    for i = 1, lastTempC do
        table.insert(lastTemps, 0)
    end
end

local targetStepP = 0.02

--- @class Reactor
--- @field getReactorInfo fun(): ReactorInfo
--- @field stopReactor fun()
--- @field startReactor fun()
local R = peripheral.wrap(reactorSide)
if not R then
    error("No reactor connected found!")
end

--- @class ReactorInfo
--- @field temperature number
--- @field maxTemperature number
--- @field energySaturation number
--- @field maxEnergySaturation number
--- @field fieldStrength number
--- @field maxFieldStrength number
--- @field fuelConversion number
--- @field maxFuelConversion number
--- @field fuelConversionRate number
--- @field fieldDrainRate number
--- @field generationRate number

--- @class FlowGate
--- @field setOverrideEnabled fun(enabled: boolean)
--- @field setFlowOverride fun(rate: number)
--- @field getFlowOverride fun(): number
--- @field getOverrideEnabled fun(): boolean
--- @field setSignalHighFlow fun(rate: number)
--- @field setSignalLowFlow fun(rate: number)
--- @field getSignalHighFlow fun(): number
--- @field getSignalLowFlow fun(): number
--- @field getFlow fun(): number
local InputFg = peripheral.wrap(inputFlowGateSide)
if not InputFg then
    error("No flow gate connected found!")
end

--- @class FlowGate
local OutputFg = peripheral.wrap(outputFlowGateSide)
if not OutputFg then
    error("No output flow gate connected found!")
end

--- @class ReactorStatus
local reactorStatus = {
    status = "unknown",
}

local function setOverride(enabled)
    OutputFg.setOverrideEnabled(enabled)
    InputFg.setOverrideEnabled(enabled)
end

--- Initiate reactor shutdown
---@param r Reactor
local function initiateShutdown(r)
    r.stopReactor()
    print("Reactor shutdown initiated!")
    while true do sleep(1) end
end

--- Check if the reactor is in a stable state
--- @param ri ReactorInfo
--- @return boolean
local function isReactorStable(ri)
    local temp = ri.temperature
    local satP = ri.energySaturation / ri.maxEnergySaturation
    local shieldP = ri.fieldStrength / ri.maxFieldStrength
    local fuelConversionP = ri.fuelConversion / ri.maxFuelConversion
    
    return not (
        satP < satMinP or
        shieldP < shieldMinP or
        fuelConversionP > fuelConversionMaxP or
        temp > tempMax
    )
end

--- Check if the reactor is warmed up
--- @param ri ReactorInfo
--- @return boolean
local function isReactorWarmedUp(ri)
    local temp = ri.temperature
    return temp > 2000
end

--- Update the reactor status
---@param ri ReactorInfo
local function updateStatus(ri)
    local fuelConversionP = ri.fuelConversion / ri.maxFuelConversion
    local remainingFuel = ri.maxFuelConversion - ri.fuelConversion
    --local conversionLevel = fuelConversionP * 1.3 - 0.3
    local remainingFuelTicks = remainingFuel / (ri.fuelConversionRate/1000/1000/(1-fuelConversionP))

    reactorStatus.remainingFuelTicks = remainingFuelTicks
    reactorStatus.netFlow = ri.generationRate - InputFg.getFlow()
end

local function updateLastTemps(ri)
    table.remove(lastTemps, 1)
    table.insert(lastTemps, ri.temperature)
end

local function getTempTrend()
    local trend = 0
    for i = 2, #lastTemps do
        trend = trend + (lastTemps[i] - lastTemps[i-1])
    end
    return trend / (#lastTemps - 1)
end

local function getNextOutputFlowStep(currentFlow, targetFlow)
    local step = targetStepP * targetOutputFlow
    if math.abs(targetFlow - currentFlow) <= step then
        return targetFlow
    elseif targetFlow > currentFlow then
        return currentFlow + step
    else
        return currentFlow - step
    end
end

--- Handle output flow adjustment step
---@param ri ReactorInfo
local function handleOutputStep(ri)
    if dryRun then
        return
    end
    
    updateLastTemps(ri)
    if lastTemps[1] == 0 then
        return
    end
    
    if ri.temperature > targetTemp then
        reactorStatus.status = "SCALING: waiting for temperature to decrease"
        return
    end

    if (ri.energySaturation / ri.maxEnergySaturation) < targetSatP then
        reactorStatus.status = "SCALING: saturation target reached"
        return
    end

    local tempTrend = getTempTrend()
    if tempTrend > maxTrend then
        reactorStatus.status = "SCALING: waiting for temperature to stabilize"
        return
    end

    local currentFlow = ri.generationRate
    if currentFlow >= (targetOutputFlow - 10000) then
        reactorStatus.status = "RUNNING: target output flow reached"
        return
    end

    local nextFlow = getNextOutputFlowStep(currentFlow, targetOutputFlow)
    local nextFlowStep = math.min(nextFlow, targetOutputFlow)
    OutputFg.setFlowOverride(nextFlowStep)
    reactorStatus.targetOutputFlow = nextFlowStep
    if nextFlowStep < currentFlow then
        reactorStatus.status = "SCALING DOWN: adjusting output flow to need"
    else
        reactorStatus.status = "SCALING UP"
        resetLastTemps()
    end
end

--- Update the field gate based on reactor info
---@param fg FlowGate
---@param ri ReactorInfo
local function updateFieldGate(fg, ri)
    local targetFactor = 1/((((1/shieldTargetP) * ri.fieldDrainRate - ri.fieldDrainRate) / ri.fieldDrainRate)
                            / ((1/shieldTargetP) * ri.fieldDrainRate / ri.fieldDrainRate))
    local targetInputFlow = ri.fieldDrainRate * targetFactor
    reactorStatus.targetInputFlow = targetInputFlow
    
    if dryRun then
        return
    else
        fg.setFlowOverride(targetInputFlow)
    end
end

--- Print the reactor status
--- @param status ReactorStatus
--- @param ri ReactorInfo
local function printStatus(status, ri)
    term.clear()
    term.setCursorPos(1,1)
    print("Reactor Status Monitor")
    print("----------------------")
    print("Status: " .. status.status)
    print(string.format("Remaining Fuel Time: > %.2f hours", status.remainingFuelTicks/20/60/60))
    print(string.format("Field Strength: %.2f%%", (ri.fieldStrength / ri.maxFieldStrength) * 100))
    print(string.format("Temperature: %.2f C", ri.temperature))
    print(string.format("Target Input Flow: %.2f MRF/t", status.targetInputFlow / 1000/1000))
    print(string.format("Target Output Flow: %.2f MRF/t", (status.targetOutputFlow / 1000/1000) or 0))
    print(string.format("Net Generation: %f MRF/t", (status.netFlow)/1000/1000))
end

OutputFg.setFlowOverride(0)
InputFg.setFlowOverride(InputFg.getSignalLowFlow())
setOverride(true)

if true then
    local ri = R.getReactorInfo()
    if not isReactorWarmedUp(ri) then
        reactorStatus.status = "warming up"
        while not isReactorWarmedUp(ri) do
            sleep(5)
        end
        reactorStatus.status = "running"
        OutputFg.setFlowOverride(OutputFg.getSignalHighFlow())
    end
end

while true do
    local ri = R.getReactorInfo()
    if not isReactorStable(ri) then
        initiateShutdown(R)
    end
    
    handleOutputStep(ri)
    updateFieldGate(InputFg, ri)

    updateStatus(ri)
    printStatus(reactorStatus, ri)
    sleep(0.1)
end