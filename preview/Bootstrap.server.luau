--//Parabolic movement
--!nolint
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")

local server_connections = require(ReplicatedStorage.Connections.server_connections)
local basketBall_class = require("./defs/basketBall.class")

local ignoreAssets = Instance.new("Folder", workspace)
ignoreAssets.Name = "IgnoreCasting"

local rendering = {} :: { [any]: RBXScriptConnection }
local basketBallMovementChanged

--//globals
const GRAVITY_VECTOR = Vector3.new(0, -workspace.Gravity, 0)

--//helpers

@native
function isVectorPositive(vector: Vector3)
	return (vector.X + vector.Y + vector.Z) < 0
end

@native
local function calculateEntirePosition(basketBall: basketBall_class.basketballClass, delta)
	local speed, position = basketBall:calculateByAxis({
		currentVelocity = basketBall.data.velocity,
		gravityVector = GRAVITY_VECTOR,
		dt = delta,
	})

	return speed, position
end

@native
local function extractPosition(init: { CFrame: CFrame, owner: BasePart?, getFromPivot: boolean? })
	if type(init) == "table" and init.getFromPivot then
		return init.owner:GetPivot()
	end
	return init.CFrame
end

local function throwBall(renderBasketballSchema: renderBasketballSchema)
	local initCordinated = extractPosition(renderBasketballSchema.init)
	local validSpawnPosition = initCordinated.Position + (initCordinated.LookVector * 2)

	local basketball = basketBall_class.new({
		initialLocation = CFrame.new(validSpawnPosition),
	})

	local parabolicSettings = basketball:getParabolicSettings(renderBasketballSchema.holdPower)
	local parabolicReatives = basketball:getParabolicValues(initCordinated, parabolicSettings)
	parabolicReatives.name = "first-calc"

	basketball:moveTo(initCordinated)
	basketball:setParent(ignoreAssets)
	basketball:set("velocity", parabolicReatives.axisVelocity)

	local lastClock = os.clock()
	local artefact = basketball.guid
	local elapsedTime = 0

	if rendering[artefact] then
		rendering[artefact]:Disconnect()
		rendering[artefact] = nil
	end

	basketball:listenCallback(
		"DirectionChanged",
		function(direction: Vector3, hitted: boolean, lastValidPosition: Vector3)
			basketball:stepTo(direction)
		end
	)
	
	local spawnTime = os.clock()

	rendering[artefact] = basketball.cache:Add(RunService.Heartbeat:Connect(function(delta: number)
		-- elapsedTime = math.clamp(elapsedTime + delta, 0, 1)

		if renderBasketballSchema.player:DistanceFromCharacter(basketball:getActualPosition()) > 100 then
			basketball.cache:Cleanup()
			return
		end

		local speed, validPosition = calculateEntirePosition(basketball, delta)

		if not isVectorPositive(speed) and (os.clock() - spawnTime) > 4 then
			server_connections.ActiveBasketBallNativePhysics.FireAll({
				guid = basketball.guid,
			})

			return rendering[artefact]:Disconnect()
		end
		
		basketball:set("velocity", speed)
		-- print(`is z axis positive: {zAxisCalc > 0} \n; z axis {zAxisCalc}`)

		-- task.delay(.005, function()
		-- 	rendering[artefact]:Disconnect()
		-- end)

		local actualPosition = validPosition
		local _, nextPosition = calculateEntirePosition(basketball, delta * 2)

		local basketballMovementSchema = {
			basketBallOwner = renderBasketballSchema.player,
			direction = nextPosition - actualPosition,
			throwSpeed = parabolicSettings.throwSpeed,
			delta = os.clock() - lastClock,
			basketballObject = basketball,
		} :: basketballMovementSchema
		
		basketball:set("direction", basketballMovementSchema.direction)

		local newDirection: Vector3?, hitPosition: Vector3?, hitNormal: Vector3?, raycastResult =
			basketBallMovementChanged(basketballMovementSchema)
		basketball:set("delta", delta)

		if basketBall_class.debugMode then
			server_connections.RenderCurvePoint.FireAll({
				position = basketball:getActualCFrame(),
				state = "Line",
				guid = basketball.guid,
			})
		end

		if newDirection then
			if basketBall_class.debugMode then
				server_connections.RenderCurvePoint.FireAll({
					position = basketball:getActualCFrame(),
					state = "Reflection",
					guid = basketball.guid,
				})
			end

			local safePositionToSummon = CFrame.new(hitPosition + hitNormal * 2)
			parabolicSettings = basketball:getParabolicSettings(0.85, true)
			parabolicReatives = basketball:getParabolicValues(safePositionToSummon, parabolicSettings)
			parabolicReatives.name = "another-calc"
			-- elapsedTime = 0

			basketball:set("direction", newDirection)
			basketball:set("velocity", parabolicReatives.axisVelocity)
			basketball:directionChanged(basketball.data.direction)
		else
			basketball:set("direction", basketballMovementSchema.direction)
			basketball:directionChanged(basketball.data.direction)
		end

		-- basketball:moveTo(CFrame.new(nextPosition))
	end))
end

basketBallMovementChanged = function(schema: basketballMovementSchema)
	local paramters = RaycastParams.new()
	paramters.BruteForceAllSlow = true
	paramters.FilterDescendantsInstances = { schema.basketBallOwner.Character, ignoreAssets }
	paramters.IgnoreWater = true

	-- local result = workspace:Spherecast(schema.basketballObject:getActualPosition(), ReplicatedStorage.Basketball.Size.Y/2, schema.direction, paramters)
	local result = schema.basketballObject:castAllDirections(paramters)

	if result then
		local newDirection = schema.direction - 2 * (schema.direction:Dot(result.Normal)) * result.Normal

		schema.basketballObject:increase("ricochets", 1)
		schema.basketballObject:set("lastHit", result):set("lastHitStamp", os.clock())

		return newDirection, result.Position, result.Normal, result
	end

	return nil
end

server_connections.ThrowBall.On(function(player: Player, schema)
	if player:DistanceFromCharacter(schema.from.Position) < 6 then
		throwBall({
			init = { CFrame = schema.from },
			player = player,
			holdPower = 1 --math.clamp(schema.power, 1, 5),
		})
	end
end)

StarterPlayer.EnableMouseLockOption = false

type basketballMovementSchema = {
	model: BasePart,
	direction: Vector3,
	throwSpeed: number,
	basketBallOwner: Player,
	delta: number,
	basketballObject: typeof(basketBall_class.new()),
}

type renderBasketballSchema = {
	init: BasePart,
	target: Vector3,
	player: Player,
	holdPower: number,
	basketball: BasePart?,
}
