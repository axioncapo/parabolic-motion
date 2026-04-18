--!nolint

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local janitor = require("@game/ReplicatedStorage/Packages/janitor")
local directions_casting = require(script.Parent.directions_casting)
local server_connections = require(ReplicatedStorage.Connections.server_connections)
local mathTools = require("./mathTools")

local freeze = table.freeze

local basketballClass = { debugMode = true }
local methods = setmetatable({}, { __index = mathTools })

local parabolicSettings = {
	liftSpeed = 50,
	throwSpeed = 40,
	renderSmoothFactor = 0.015,
}

--//Helpers
local function canUserDataBeIncreased<t>(userData: t)
	return typeof(userData) == "CFrame" or typeof(userData) == "Vector3" or typeof(userData) == "number"
end

local function removeIt(array)
	table.clear(array)
	array = nil
end

--//Class
function basketballClass.new(schema: {
	initialLocation: CFrame,
})
	local new = setmetatable({
		-- basketballModel = (ReplicatedStorage:FindFirstChild("Basketball") :: BasePart):Clone(),
	}, { __index = methods })

	new.cache = janitor.new()
	-- new.cache:Add(new.basketballModel)

	-- new.basketballModel.Anchored = true
	-- new.basketballModel.CanCollide = false
	-- new.basketballModel.CFrame = schema.initialLocation

	new.guid = HttpService:GenerateGUID(false):sub(1, 13):gsub("-", "")
	new.data = {
		ricochets = 0,
		active = true,
		actualPosition = schema.initialLocation.Position,
	} :: basketballReactivesStates

	--//private :sob:
	new.__callbacks = freeze({
		ValueChanged = {},
		DirectionChanged = {},
	})

	new.cache:Add(function()
		server_connections.CleanBasketBall.FireAll({
			guid = new.guid,
		})
		for _, callbackList in new.__callbacks do
			table.clear(callbackList)
		end

		table.clear(new)
		setmetatable(new, nil)
	end)

	new:listenCallback("ValueChanged", function(selector: basketballReactivesStatesSelector, newValue: CFrame | Vector3)
		if selector == "actualCordinated" then
			server_connections.UpdateBasketBall.FireAll({
				guid = new.guid,
				newPos = newValue,
			})
		end
	end)

	server_connections.SummonBasketBall.FireAll({
		guid = new.guid,
		startPos = schema.initialLocation,
	})

	return new
end

--//changing methods
function methods.set(self: basketballClass, selector: basketballReactivesStatesSelector, newValue: any)
	self.data[selector] = newValue
	self:__callAll(self.__callbacks.ValueChanged, selector, newValue)

	return self
end

--if it is a cframe, that not increase, that mull
function methods.increase(self: basketballClass, selector: basketballReactivesStatesSelector, rate: any)
	assert(self.data[selector], `{selector}, dont exist or not setted inside data, set it first`)

	if not canUserDataBeIncreased(self.data[selector]) then
		error(`expected some user data that u can increase`)
	end

	if typeof(self.data[selector]) == "CFrame" then
		self.data[selector] *= rate
	else
		self.data[selector] += rate
	end

	self:__callAll(self.__callbacks.ValueChanged, selector, self.data[selector])
	return self
end

--//callbacks
function methods.listenCallback<t>(
	self: basketballClass,
	selector: basketballEventsSelector,
	callback: rawget<basketballEvents, t>
)
	assert(self.__callbacks[selector], `expected a callback event inside basketball events`)
	table.insert(self.__callbacks[selector], callback)
end

--//misc
function methods.setParent(self: basketballClass, parent: Instance)
	-- self.basketballModel.Parent = parent
end

function methods.moveTo(self: basketballClass, target: CFrame)
	self:set("actualPosition", target.Position)
	self:set("actualCordinated", target)

	-- self.basketballModel.CFrame = target
end

function methods.stepTo(self: basketballClass, target: Vector3)
	self:set("actualPosition", self.data.actualPosition + target)
	self:set("actualCordinated", CFrame.new(self.data.actualPosition + target) * self:getActualCFrame().Rotation)

	-- self.basketballModel.Position += target
end

function methods.getActualPosition(self: basketballClass): Vector3
	return self.data.actualPosition
end

function methods.getActualCFrame(self: basketballClass)
	return self.data.actualCordinated
end

--//physics

function methods.getParabolicSettings(self: basketballClass, speedFactor: number?, mul: boolean?): parabolicSettings
	speedFactor = speedFactor or 1

	self.parabolicSettings = self.parabolicSettings or table.clone(parabolicSettings)

	if mul and speedFactor then
		self.parabolicSettings.liftSpeed *= speedFactor
		self.parabolicSettings.throwSpeed *= speedFactor
	elseif not mul and speedFactor then
		self.parabolicSettings.liftSpeed += speedFactor
		self.parabolicSettings.throwSpeed += speedFactor
	end

	return self.parabolicSettings
end

function methods.castAllDirections(self: basketballClass, parameters: RaycastParams)
	local rayHits = {}
	local moveDirection = self.data.direction

	if moveDirection.Magnitude <= 0 then
		return nil
	end

	moveDirection = moveDirection.Unit

	local ballRadius = ReplicatedStorage.Basketball.Size.Y / 2
	local bestHit = nil
	local bestBlockScore = -math.huge
	local bestFrontScore = -math.huge
	local bestDistance = math.huge

	for _, castDirection in directions_casting do
		local unitDirection = castDirection.Unit
		local castResult = workspace:Raycast(
			self:getActualPosition(),
			unitDirection * ballRadius,
			parameters
		)

		if castResult then
			table.insert(rayHits, {
				castResult = castResult,
				castDirection = unitDirection,
			})
		end
	end

	for _, hitData: { castResult: RaycastResult, castDirection: Vector3 } in pairs(rayHits) do
		local frontScore = hitData.castDirection:Dot(moveDirection)
		local blockScore = -hitData.castResult.Normal:Dot(moveDirection)
		local hitDistance = hitData.castResult.Distance

		if frontScore <= 0 or blockScore <= 0 then
			continue
		end
		
		local isBetter =
			blockScore > bestBlockScore
			or (
				blockScore == bestBlockScore
				and frontScore > bestFrontScore
			)
			or (
				blockScore == bestBlockScore
				and frontScore == bestFrontScore
				and hitDistance < bestDistance
			)

		if isBetter then
			bestHit = hitData.castResult
			bestBlockScore = blockScore
			bestFrontScore = frontScore
			bestDistance = hitDistance
		end
	end

	task.delay(3, removeIt, rayHits)

	return bestHit
end

function methods.getParabolicValues(self: basketballClass, initCordinated: CFrame, parabolicSettings: parabolicSettings)
	local ballCframe = initCordinated
	local rawFoward = ballCframe.LookVector
	local normalizedForward = Vector3.new(rawFoward.X, 0, rawFoward.Z).Unit
	local axisVelocity = normalizedForward * parabolicSettings.throwSpeed
		+ Vector3.new(0, parabolicSettings.liftSpeed, 0)

	-- print("debugging", parabolicSettings, normalizedForward, axisVelocity)

	return {
		ballCframe = ballCframe,
		rawFoward = rawFoward,
		normalizedForward = normalizedForward,
		axisVelocity = axisVelocity,
	}
end

--//handlers

function methods.directionChanged(self: basketballClass, ...)
	self:__callAll(self.__callbacks.DirectionChanged, ...)
end

function methods:__callAll(callbackList: { (...any) -> any }, ...)
	for _, callback in callbackList do
		task.spawn(callback, ...)
	end
end

--//types
type basketballEvents = {
	ValueChanged: (selector: basketballReactivesStatesSelector, newValue: any) -> (),
	DirectionChanged: (direction: Vector3, hitted: boolean, lastValidPosition: Vector3) -> (),
}

export type basketballEventsSelector = keyof<basketballEvents>
export type basketballReactivesStates = {
	ricochets: number,
	active: boolean,

	direction: Vector3?, --// next pos - act pos
	delta: number?,
	actualPosition: Vector3?,
	actualCordinated: CFrame?,
	velocity: Vector3?,

	lastHit: RaycastResult?,
	state: "Reflection" | "Line"?,
	lastHitStamp: number?, --//time stamp
}

export type basketballReactivesStatesSelector = keyof<basketballReactivesStates>

type parabolicSettings = typeof(parabolicSettings)
export type basketballClass = typeof(basketballClass) & typeof(basketballClass.new()) & {
	data: basketballReactivesStates,
	parabolicSettings: parabolicSettings?,
} & typeof(mathTools)

return basketballClass
