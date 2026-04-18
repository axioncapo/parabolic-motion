--!native
--!optimize 2
local tools = {
    frames = {}
}

function tools.frames
    :stepVelocity(currentVelocity: Vector3, gravityVector: Vector3, dt: number)
    return currentVelocity + gravityVector * dt
end

function tools.frames
    :stepPosition(currentPosition: Vector3, nextVelocity: Vector3, dt: number)
    return currentPosition + nextVelocity * dt
end

function tools.frames:calculateByAxis(schema: {
    currentVelocity: Vector3, 
    gravityVector: Vector3, 
    dt: number
}): (Vector3, Vector3)
    local currentPosition: Vector3 = self:stepPosition(self.data.actualPosition, schema.currentVelocity, schema.dt)
    local currentSpeed: Vector3 = self:stepVelocity(schema.currentVelocity, schema.gravityVector, schema.dt)

    return currentSpeed, currentPosition
end

return setmetatable(tools, {__index = tools.frames})