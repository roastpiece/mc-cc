ORIENTATION = {
    NORTH = {
        x = 0,
        z = -1
    },
    EAST = {
        x = 1,
        z = 0
    },
    SOUTH = {
        x = 0,
        z = 1
    },
    WEST = {
        x = -1,
        z = 0
    }
}

local function compareOrientation(a, b)
    return a.x == b.x and a.z == b.z
end

local Move = {}
Move.transform = {
    x = 0, y = 0, z = 0, o = ORIENTATION.NORTH
}

local transform = Move.transform

math.randomseed(os.time())

function Move.SetTransform(x, y, z, o)
    o = o or ORIENTATION.NORTH
    transform.x = x
    transform.y = y
    transform.z = z
    transform.o = o
end

function Move.Forward()
    if turtle.forward() then
        transform.x = transform.x + transform.o.x
        transform.z = transform.z + transform.o.z
    end
end

function Move.Back()
    if turtle.back() then
        transform.x = transform.x - transform.o.x
        transform.z = transform.z - transform.o.z
    end
end

function Move.Up()
    if turtle.up() then
        transform.y = transform.y + 1
    end
end

function Move.Down()
    if turtle.down() then
        transform.y = transform.y - 1
    end
end

function Move.TurnRight()
    local newO = {
        x = 0,
        z = 0
    }
    if turtle.turnRight() then
        newO.x = transform.o.z * -1
        newO.z = transform.o.x
    end
    transform.o = newO
end

function Move.TurnLeft()
    local newO = {
        x = 0,
        z = 0
    }
    if turtle.turnLeft() then
        newO.x = transform.o.z
        newO.z = transform.o.x * -1
    end
    transform.o = newO
end

function Move.Left()
    if math.random() > 0.5 then
        Move.TurnLeft()
        Move.Forward()
        Move.TurnRight()
    else
        Move.TurnRight()
        Move.Back()
        Move.TurnLeft()
    end
end

function Move.Right()
    if math.random() > 0.5 then
        Move.TurnLeft()
        Move.Back()
        Move.TurnRight()
    else
        Move.TurnRight()
        Move.Forward()
        Move.TurnLeft()
    end
end

function Move.RelativeToOrientation(fw, lr)
    if fw ~= 0 then
        local move
        if fw > 0 then move = Move.Forward else move = Move.Back end
        for _ = 1, math.abs(fw) do
            move()
        end
    end
    if lr ~= 0 then
        if lr > 0 then Move.TurnRight() else Move.TurnLeft() end
        for _ = 1, math.abs(lr) do
            Move.Forward()
        end
        if lr > 0 then Move.TurnLeft() else Move.TurnRight() end
    end
end

function Move.RelativeToWorldspace(dx, dz)
    if compareOrientation(transform.o, ORIENTATION.NORTH) then
        Move.RelativeToOrientation(-dz, dx)
    elseif compareOrientation(transform.o, ORIENTATION.SOUTH) then
        Move.RelativeToOrientation(dz, -dx)
    elseif compareOrientation(transform.o, ORIENTATION.EAST) then
        Move.RelativeToOrientation(dx, dz)
    elseif compareOrientation(transform.o, ORIENTATION.WEST) then
        Move.RelativeToOrientation(-dx, -dz)
    end
end

function Move.Absolute(x, z)
    Move.RelativeToWorldspace(x - transform.x, z - transform.z) -- THIS DOESNT WORK
end

return Move
