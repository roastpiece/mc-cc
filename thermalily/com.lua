function InitObserver(tx)
    local modem = peripheral.find("modem", function(name, modem)
        return modem.isWireless()
    end) or error("NO MODEM FOUND")
    modem.open(tx + 1)

    local wrapped_modem = {
        __index = modem,
        transmit = function(message)
            modem.transmit(tx, tx + 1, message)
        end
    }
    setmetatable(wrapped_modem, modem)

    return wrapped_modem
end

function InitWorker(tx)
    local modem = peripheral.find("modem") or error("NO MODEM FOUND")
    modem.open(tx)

    local wrapped_modem = {
        __index = modem,
        transmit = function(message)
            modem.transmit(tx + 1, tx, message)
        end
    }
    setmetatable(wrapped_modem, modem)

    return wrapped_modem
end
