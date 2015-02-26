--[[
	A library to help make RTS-style and Tower Defense custom games in Dota 2
	Developer: Myll
	Version: 2.0
	Credits to:
		Ash47 and BMD for timers.lua.
		BMD for helping figure out how to get mouse clicks in Flash.
		Perry for writing FlashUtil, which contains functions for cursor tracking.
]]

BUILDINGHELPER_THINK = 0.03
GRIDNAV_SQUARES = {}
BUILDING_SQUARES = {}
BH_UNITS = {}
FORCE_UNITS_AWAY = false
UsePathingMap = false
AUTO_SET_HULL = true
BHGlobalDummySet = false
PACK_ENABLED = false
Debug_BH = true

-- Circle packing math.
BH_A = math.pow(2,.5) --multi this by rad of building
BH_cos45 = math.pow(.5,.5) -- cos(45)

if not OutOfWorldVector then
	OutOfWorldVector = Vector(11000,11000,0)
end

BuildingHelper = {}
BuildingAbilities = {}
-- Abilities which don't cancel building ghost.
DontCancelBuildingGhostAbils = {}

function BuildingHelper:Init(...)
	local nMapLength = 16384*2
	if arg ~= nil then
		nMapLength = arg[1]*2
	end

	Convars:RegisterCommand( "BuildingPosChosen", function()
		--get the player that sent the command
		local cmdPlayer = Convars:GetCommandClient()
		if cmdPlayer then
			cmdPlayer.buildingPosChosen = true
		end
	end, "", 0 )

	Convars:RegisterCommand( "CancelBuilding", function()
		--get the player that sent the command
		local cmdPlayer = Convars:GetCommandClient()
		if cmdPlayer then
			cmdPlayer.cancelBuilding = true
		end
	end, "", 0 )

	AbilityKVs = LoadKeyValues("scripts/npc/npc_abilities_custom.txt")
	ItemKVs = LoadKeyValues("scripts/npc/npc_items_custom.txt")
	-- abils and items can't have the same name or the item will override the ability.
	--PrintTable(abilities)
	for i=1,2 do
		local t = AbilityKVs
		if i == 2 then
			t = ItemKVs
		end
		for abil_name,abil_info in pairs(t) do
			if type(abil_info) == "table" then
				local isBuilding = abil_info["Building"]
				local cancelsBuildingGhost = abil_info["CancelsBuildingGhost"]
				if isBuilding ~= nil and tostring(isBuilding) == "1" then
					BuildingAbilities[tostring(abil_name)] = abil_info
				end
				if cancelsBuildingGhost ~= nil and tostring(cancelsBuildingGhost) == "0" then
					DontCancelBuildingGhostAbils[tostring(abil_name)] = true
				end
			else
				--print('[BuildingHelper] Error parsing npc_abilities_custom.txt')
			end
		end
	end

	local halfLength = nMapLength/2
	local blockedCount = 0
	-- Check the center of each square on the map to see if it's blocked by the GridNav.
	for x=-halfLength+32, halfLength-32, 64 do
		for y=halfLength-32, -halfLength+32,-64 do
			if GridNav:IsBlocked(Vector(x,y,0)) or not GridNav:IsTraversable(Vector(x,y,0)) then
				GRIDNAV_SQUARES[VectorString(Vector(x,y,0))] = true
				blockedCount=blockedCount+1
			end
		end
	end
	print("Total Blocked squares added: " .. blockedCount)

	--print("BuildingAbilities: ")
	--PrintTable(BuildingAbilities)
end

--[[function BuildingHelper:BlockRectangularArea(leftBorderX, rightBorderX, topBorderY, bottomBorderY)
	if leftBorderX%64 ~= 0 or rightBorderX%64 ~= 0 or topBorderY%64 ~= 0 or bottomBorderY%64 ~= 0 then
		print("[BuildingHelper] Error in BlockRectangularArea. One of the values does not divide evenly into 64.")
		return
	end
	local blockedCount = 0
	for x=leftBorderX+32, rightBorderX-32, 64 do
		for y=topBorderY-32, bottomBorderY+32,-64 do
			GRIDNAV_SQUARES[VectorString(Vector(x,y,0))] = true
			blockedCount=blockedCount+1
		end
	end
end]]

function BuildingHelper:BlockRectangularArea(vPoint1, vPoint2)
	local leftBorderX = vPoint2.x
	local rightBorderX = vPoint1.x
	if vPoint1.x < vPoint2.x then
		leftBorderX = vPoint1.x
		rightBorderX = vPoint2.x
	end

	local bottomBorderY = vPoint2.y
	local topBorderY = vPoint1.y
	if vPoint1.y < vPoint2.y then
		bottomBorderY = vPoint1.y
		topBorderY = vPoint2.y
	end

	if leftBorderX%64 ~= 0 or rightBorderX%64 ~= 0 or topBorderY%64 ~= 0 or bottomBorderY%64 ~= 0 then
		print("[BuildingHelper] Error in BlockRectangularArea. One of the values does not divide evenly into 64.")
		return
	end
	local blockedCount = 0
	for x=leftBorderX+32, rightBorderX-32, 64 do
		for y=topBorderY-32, bottomBorderY+32,-64 do
			GRIDNAV_SQUARES[VectorString(Vector(x,y,0))] = true
			blockedCount=blockedCount+1
		end
	end
end

function BuildingHelper:SetForceUnitsAway(bForceAway)
	FORCE_UNITS_AWAY=bForceAway
end

function BuildingHelper:DisableFireEffects(bDisableFireEffects)
	if bDisableFireEffects then
		FIRE_EFFECTS_ENABLED = false
	else
		FIRE_EFFECTS_ENABLED = true
	end
end

function BuildingHelper:SetPacking(bPacking)
	if not bPacking then
		PACK_ENABLED = false
	else
		PACK_ENABLED = true
		AUTO_SET_HULL = true
	end
end

function BuildingHelper:AutoSetHull(bAutoSetHull)
	if not bAutoSetHull then
		AUTO_SET_HULL = false
	else
		AUTO_SET_HULL = true
	end
end

function BuildingHelper:AddBuilding(keys)

	-- Callbacks
	function keys:OnConstructionStarted( callback )
		keys.onConstructionStarted = callback
	end

	function keys:OnConstructionCompleted( callback )
		keys.onConstructionCompleted = callback
	end

	function keys:EnableFireEffect( sFireEffect )
		keys.fireEffect = sFireEffect
	end

	function keys:OnBelowHalfHealth( callback )
		keys.onBelowHalfHealth = callback
	end

	function keys:OnAboveHalfHealth( callback )
		keys.onAboveHalfHealth = callback
	end

	-- TODO: since the ability phase funcs are screwed up, can't get when building was canceled
	-- due to right click
	function keys:OnCanceled( callback )
		keys.onCanceledCallback = callback
	end

	local hAbility = keys.ability
	local abilName = hAbility:GetAbilityName()
	local caster = keys.caster
	local builder = caster -- alias
	-- get player handle that owns the builder.
	local player = builder:GetPlayerOwner()
	-- player's hero could be diff from the builder.
	local playersHero = player:GetAssignedHero()
	local pID = player:GetPlayerID()

	local buildingTable = BuildingAbilities[abilName]

	function buildingTable:GetVal( key, expectedType )
		local val = buildingTable[key]
		--print('val: ' .. tostring(val))
		if val == nil and expectedType == "bool" then
			return false
		end
		if val == nil and expectedType ~= "bool" then
			return nil
		end

		if tostring(val) == "" then
			return nil
		end

		local sVal = tostring(val)
		if sVal == "1" and expectedType == "bool" then
			return true
		elseif sVal == "0" and expectedType == "bool" then
			return false
		elseif sVal == "" then
			return nil
		elseif expectedType == "number" or expectedType == "float" then
			return tonumber(val)
		end
		return sVal
	end

	player.buildingPosChosen = false
	player.cancelBuilding = false
	-- store ref to the buildingTable in the builder.
	builder.buildingTable = buildingTable

	if player.ghost_particles == nil then
		player.ghost_particles = {}
	end
	-- store player handle ref in the builder
	if builder.player == nil then
		builder.player = player
	end

	if builder.orders == nil then
		builder.orders = {}
	end

	buildingTable["abil"] = hAbility
	buildingTable["player"] = player
	buildingTable["playersHero"] = playersHero

	local size = buildingTable:GetVal("BuildingSize", "number")
	--local size = buildingTable["BuildingSize"]
	if size == nil then
		print('[BuildingHelper] Error: ' .. abilName .. ' does not have a BuildingSize KeyValue')
		return
	end

	local unitName = buildingTable:GetVal("UnitName", "string")
	if unitName == nil then
		print('[BuildingHelper] Error: ' .. abilName .. ' does not have a UnitName KeyValue')
		return
	end

	local castRange = buildingTable:GetVal("AbilityCastRange", "number")
	if castRange == nil then
		castRange = 200
	end

	local goldCost = buildingTable:GetVal("AbilityGoldCost", "number")
	if goldCost == nil then
		goldCost = 0
	end
	-- store this for quick retrieval later.
	buildingTable.goldCost = goldCost

	-- dynamically handle the cooldown. if player cancels building, etc
	hAbility:EndCooldown()
	-- same thing with the gold cost.
	if playersHero ~= nil then
		playersHero:SetGold(playersHero:GetGold()+goldCost, false)
	end

	local resources = {}
	local notEnoughResources = {}
	-- Check other resource costs.
	local abilitySpecials = {}
	if buildingTable["AbilitySpecial"] ~= nil then
		abilitySpecials = buildingTable["AbilitySpecial"]
	end

	for k2,v2 in pairs(abilitySpecials) do
		if abilitySpecials[k2] ~= nil then
			local abilitySpecial = abilitySpecials[k2]
			for k3,v3 in pairs(abilitySpecial) do
				if string.starts(k3, "resource_") then
					local cost = tonumber(abilitySpecial[k3])
					local resourceName = string.sub(k3, 10):lower()
					resources[resourceName] = cost
					--print("Detected resource: " .. resourceName)
					if player[resourceName] == nil then
						player[resourceName] = 0
					end
					if player[resourceName] < cost then
						notEnoughResources[resourceName] = cost-player[resourceName]
					end
				end
			end
		end
	end

	buildingTable.resources = resources

	if TableLength(notEnoughResources) > 0 then
		return {["error"] = "not_enough_resources", ["resourceTable"] = notEnoughResources}
	end

	--setup the dummy for model ghost
	if player.modelGhostDummy ~= nil then
		player.modelGhostDummy:RemoveSelf()
	end

	local fMaxScale = buildingTable:GetVal("MaxScale", "float")
	if fMaxScale == nil then
		fMaxScale = 1
	end
	player.modelGhostDummy = CreateUnitByName(unitName, OutOfWorldVector, false, nil, nil, caster:GetTeam())
	local mgd = player.modelGhostDummy -- alias
	--mgd:SetModelScale(.2) -- this won't reduce the model particle size atm...
	mgd.isBuildingDummy = true -- store this for later use
	-- set it underground
	Timers:CreateTimer(.03, function()
		if IsValidEntity(mgd) and mgd:IsAlive() then
			local loc = mgd:GetAbsOrigin()
			mgd:SetAbsOrigin(Vector(loc.x,loc.y,loc.z-300))
		end
	end)
	player.lastCursorCenter = OutOfWorldVector

	function player:BeginGhost()
		if not player.cursorStream then
			local delta = .03
			local start = false
			player.cursorStream = FlashUtil:RequestDataStream( "cursor_position_world", delta, pID, function(playerID, cursorPos)
				local validPos = true
				-- Remember, our blocked squares are defined according to the square's center.
				if cursorPos.x > 30000 or cursorPos.y > 30000 or cursorPos.z > 30000 then
					validPos = false
				end

				-- Check if the player canceled the ghost.
				if player.cancelBuilding then
					FlashUtil:StopDataStream( player.cursorStream )
					player.cursorStream = nil
					player.cancelBuilding = false
					player.lastCursorCenter = OutOfWorldVector
					ClearParticleTable(player.ghost_particles)
					return
				end

				--if validPos then
				-- Check if the player chose the position.
				if player.buildingPosChosen then
					if validPos then
						AddToGrid(cursorPos)
					end
					FlashUtil:StopDataStream( player.cursorStream )
					player.cursorStream = nil
					player.buildingPosChosen = false
					player.lastCursorCenter = OutOfWorldVector
					ClearParticleTable(player.ghost_particles)
					return
				end

				if validPos then
					local centerX = SnapToGrid64(cursorPos.x)
					local centerY = SnapToGrid64(cursorPos.y)
					local z = cursorPos.z
					-- Buildings are centered differently when the size is odd.
					if size%2 ~= 0 then
						centerX=SnapToGrid32(cursorPos.x)
						centerY=SnapToGrid32(cursorPos.y)
					end

					local vBuildingCenter = Vector(centerX,centerY,z)
					local halfSide = (size/2)*64
					local boundingRect = {leftBorderX = centerX-halfSide, 
						rightBorderX = centerX+halfSide, 
						topBorderY = centerY+halfSide,
						bottomBorderY = centerY-halfSide}

					-- No need to redraw the particles if the cursor is at the same location. 
					-- (bug) it will stay green if cursor stays at the same location and a building is built at the location.
					local cursorSnap = nil
					if player.lastCursorCenter ~= nil then
						local cursorSnapX = SnapToGrid32(player.lastCursorCenter.x)
						local cursorSnapY = SnapToGrid32(player.lastCursorCenter.y)
						cursorSnap = Vector(cursorSnapX, cursorSnapY, vBuildingCenter.z)
					end
					if cursorSnap ~= nil and vBuildingCenter ~= cursorSnap then
						ClearParticleTable(player.ghost_particles)
						local areaBlocked = false
						local squares = {}
						for x=boundingRect.leftBorderX+32,boundingRect.rightBorderX-32,64 do
							for y=boundingRect.topBorderY-32,boundingRect.bottomBorderY+32,-64 do
								local groundZ = GetGroundPosition(Vector(x,y,z),caster).z
								--table.insert(squares, Vector(x,y,z))
								--print(VectorString(Vector(x,y,z)))
								local id = ParticleManager:CreateParticleForPlayer("particles/square_sprite.vpcf", PATTACH_ABSORIGIN, caster, player)
								ParticleManager:SetParticleControl(id, 0, Vector(x,y,groundZ))
								ParticleManager:SetParticleControl(id, 1, Vector(32,0,0))
								ParticleManager:SetParticleControl(id, 3, Vector(70,0,0))
								if IsSquareBlocked(Vector(x,y,z), true) then
									ParticleManager:SetParticleControl(id, 2, Vector(255,0,0))
									areaBlocked = true
									--DebugDrawBox(Vector(x,y,z), Vector(-32,-32,0), Vector(32,32,1), 255, 0, 0, 40, delta)
								else
									ParticleManager:SetParticleControl(id, 2, Vector(0,255,0))
								end
								table.insert(player.ghost_particles, id)
							end
						end
						--<BMD> position is 0, model attach is 1, color is CP2, and alpha is CP3.x
						--ParticleManager:SetParticleControlEnt(particle, 1, unit, 1, "follow_origin", unit:GetAbsOrigin(), true)
						local modelParticle = ParticleManager:CreateParticleForPlayer("particles/ghost_model.vpcf", PATTACH_ABSORIGIN, player.modelGhostDummy, player)
						ParticleManager:SetParticleControlEnt(modelParticle, 1, player.modelGhostDummy, 1, "follow_origin", player.modelGhostDummy:GetAbsOrigin(), true)
						ParticleManager:SetParticleControl(modelParticle, 3, Vector(100,0,0))
						if areaBlocked then
							ParticleManager:SetParticleControl(modelParticle, 2, Vector(255,0,0))
						else
							ParticleManager:SetParticleControl(modelParticle, 2, Vector(0,255,0))
						end
						ParticleManager:SetParticleControl(modelParticle, 0, vBuildingCenter)
						table.insert(player.ghost_particles, modelParticle)
					end
					player.lastCursorCenter = vBuildingCenter
				end
			end)
		end
	end

	-- Private function.
	function AddToGrid(vPoint)
		-- Remember, our blocked squares are defined according to the square's center.
		local centerX = SnapToGrid64(vPoint.x)
		local centerY = SnapToGrid64(vPoint.y)
		-- Buildings are centered differently when the size is odd.
		if size%2 ~= 0 then
			centerX=SnapToGrid32(vPoint.x)
			centerY=SnapToGrid32(vPoint.y)
		end

		local vBuildingCenter = Vector(centerX,centerY,vPoint.z)
		local halfSide = (size/2)*64
		local buildingRect = {leftBorderX = centerX-halfSide, 
			rightBorderX = centerX+halfSide, 
			topBorderY = centerY+halfSide, 
			bottomBorderY = centerY-halfSide}
			
		if BuildingHelper:IsRectangularAreaBlocked(buildingRect) then
			FireGameEvent( 'custom_error_show', { player_ID = pID, _error = "Unable to build there" } )
			ClearParticleTable(player.ghost_particles)

			if keys.onCanceledCallback ~= nil then
				keys.onCanceledCallback();
			end
			return nil
		end
		
		-- Keep the particles alive until the building is built.
		--[[if player.stickyGhost ~= nil then
			ClearParticleTable(player.stickyGhost)
		end
		player.stickyGhost = shallowcopy(player.ghost_particles)
		player.ghost_particles = {}]]

		-- The spot is not blocked, so add it to the closed squares.
		local closed = {}
		
		for x=buildingRect.leftBorderX+32,buildingRect.rightBorderX-32,64 do
			for y=buildingRect.topBorderY-32,buildingRect.bottomBorderY+32,-64 do
				table.insert(closed,Vector(x,y,0))
			end
		end

		-- Make the caster move towards the point
		local dontMove = false
		local abilName = "move_to_point_" .. tostring(castRange)
		if AbilityKVs[abilName] == nil then
			print('[BuildingHelper] Error: ' .. abilName .. ' was not found in npc_abilities_custom.txt. Using the ability move_to_point_100')
			abilName = "move_to_point_100"
		end
		--[[if caster:GetAbilityCount() == 16 then
			print('[BuildingHelper] Error: Unable to add ' .. abilName .. ' to the unit. The unit has the max ability count of 16.')
			dontMove = true
		end]]

		-- If unit has other move_to_point abils, we should clean them up here
		AbilityIterator(caster, function(abil)
			local name = abil:GetAbilityName()
			if name ~= abilName and string.starts(name, "move_to_point_") then
				caster:RemoveAbility(name)
				--print("removed " .. name)
			end
		end)

		if not dontMove then
			caster:AddAbility(abilName)
			local abil = caster:FindAbilityByName(abilName)
			abil.succeeded = false
			abil:SetLevel(1)
			caster.orders[DoUniqueString("order")] = {["unitName"] = unitName, ["pos"] = vBuildingCenter, ["team"] = caster:GetTeam(),
				["buildingTable"] = buildingTable, ["squares_to_close"] = closed, ["keys"] = keys}
			Timers:CreateTimer(.03, function()
				--caster:CastAbilityOnPosition(vBuildingCenter, abil, 0)
				local casterIndex = caster:GetEntityIndex()
				local order = DOTA_UNIT_ORDER_CAST_POSITION
				local abilIndex = abil:GetEntityIndex()
				ExecuteOrderFromTable({ UnitIndex = casterIndex, OrderType = DOTA_UNIT_ORDER_CAST_POSITION, AbilityIndex = abilIndex, Position = vBuildingCenter, Queue = false}) 

				-- We need a thinker to check if the abil goes out of phase.
				-- If it does we need to remove the sticky ghost.
				--[[Timers:CreateTimer(.2, function()
					local active = caster:GetCurrentActiveAbility()
					if active == nil and not abil.succeeded then
						if player.stickyGhost ~= nil then
							print("Yep")
							ClearParticleTable(player.stickyGhost)
							return nil
						end
					end
					if abil.succeeded then
						return nil
					end
					return .03
				end)]]
			end)
		end
	end

	player:BeginGhost()
	FireGameEvent('build_command_executed', { player_id = pID, building_size = size })
end

function BuildingHelper:InitializeBuildingEntity(keys)
	local caster = keys.caster
	local builder = caster -- alias
	local orders = builder.orders
	local pos = keys.target_points[1]
	keys.ability.succeeded = true

	-- search and get the correct order
	local order = nil
	local key = ""
	for k,v in pairs(orders) do
		if v["pos"] == pos then
			order = v
			key = k
		end
	end

	if not order then
		print('[BuildingHelper] Error: Caster has no currBuildingOrder.')
		return
	end

	-- delete order
	orders[key] = nil

	local squaresToClose = order["squares_to_close"]

	-- let's still make sure we can build here. Someone else may have built a building here
	-- during the time walking to the spot.
	if BuildingHelper:IsAreaBlocked(squaresToClose) then
		return
	end

	-- get our very useful buildingTable
	local buildingTable = order["buildingTable"]
	-- keys from the "build" func in abilities.lua
	local keys2 = order["keys"]

	local playersHero = buildingTable["playersHero"]
	local player = buildingTable["player"]

	-- create building entity
	local unit = CreateUnitByName(order.unitName, order.pos, false, playersHero, nil, order.team)
	local building = unit --alias
	building.isBuilding = true
	-- store reference to the buildingTable in the unit.
	unit.buildingTable = buildingTable

	-- Close the squares
	BuildingHelper:CloseSquares(squaresToClose, "vector")
	-- store the squares in the unit for later.
	unit.squaresOccupied = shallowcopy(squaresToClose)
	unit.building = true

	-- Remove the sticky particles
	--[[local player = caster:GetPlayerOwner()
	if player.stickyGhost ~= nil then
		ClearParticleTable(player.stickyGhost)
	end]]

	local buildTime = buildingTable:GetVal("BuildTime", "float")
	if buildTime == nil then
		buildTime = .1
	end

	-- the gametime when the building should be completed.
	local fTimeBuildingCompleted=GameRules:GetGameTime()+buildTime
	-- whether we should update the building's health over the build time.
	local bUpdateHealth = buildingTable:GetVal("UpdateHealth", "bool")
	local fMaxHealth = unit:GetMaxHealth()
	-- health to add every tick until build time is completed.
	local nHealthInterval = (fMaxHealth*BUILDINGHELPER_THINK)/buildTime
	-- increase the health interval by 25%.
	nHealthInterval = nHealthInterval + .25*nHealthInterval

	if nHealthInterval < 1 then
		--print("[BuildingHelper] nHealthInterval is below 1. Setting nHealthInterval to 1. The unit will gain full health before the build time ends.\n" ..
		--	"Fix this by increasing the max health of your unit. Recommended unit max health is 1000.")
		nHealthInterval = 1
	end
	unit.bUpdatingHealth = false --Keep tracking if we're currently updating health.

	-- whether we should scale the building.
	local bScale = buildingTable:GetVal("Scale", "bool")
	-- the amount to scale to.
	local fMaxScale = buildingTable:GetVal("MaxScale", "float")
	if fMaxScale == nil then
		fMaxScale = 1
	end
	-- scale to add every tick until build time is completed.
	local fScaleInterval = (fMaxScale*BUILDINGHELPER_THINK)/buildTime
	fScaleInterval = fScaleInterval + .2*fScaleInterval -- scaling is a bit slow evidently, so make it faster
	-- start the building at 20% of max scale.
	local fCurrentScale=.2*fMaxScale
	local bScaling = false -- Keep tracking if we're currently model scaling.

	local bPlayerCanControl = buildingTable:GetVal("PlayerCanControl", "bool")
	if bPlayerCanControl then
		unit:SetControllableByPlayer(playersHero:GetPlayerID(), true)
		unit:SetOwner(playersHero)
	end

	if bUpdateHealth then
		unit:SetHealth(1)
		unit.bUpdatingHealth = true
		if bScale then
			unit:SetModelScale(fCurrentScale)
			--unit.fScaleInterval=unit.fScaleInterval-.1*unit.fScaleInterval
			bScaling=true
		end
	end

	-- health and scale timer
	unit.updateHealthTimer = DoUniqueString('health')
	Timers:CreateTimer(unit.updateHealthTimer, {
	endTime = .03,
    callback = function()
		if IsValidEntity(unit) then
			local timesUp = GameRules:GetGameTime() >= fTimeBuildingCompleted
			if not timesUp then
				if unit.bUpdatingHealth then
					if unit:GetHealth() < fMaxHealth then
						unit:SetHealth(unit:GetHealth()+nHealthInterval)
					else
						if keys2.onConstructionCompleted ~= nil then
							keys2.onConstructionCompleted(unit)
						end
						unit.bUpdatingHealth = false
					end
				end
				if bScaling then
					if fCurrentScale < fMaxScale then
						fCurrentScale = fCurrentScale+fScaleInterval
						unit:SetModelScale(fCurrentScale)
					else
						unit:SetModelScale(fMaxScale)
						bScaling = false
					end
				end
			else
				-- two cases of completion: 1. the unit reaches full health,
				-- 2. timesUp is true
				if keys2.onConstructionCompleted ~= nil then
					keys2.onConstructionCompleted(unit)
				end
				unit.bUpdatingHealth = false
			end

			-- clean up the timer if we don't need it.
			if not unit.bUpdatingHealth and not bScaling then
				return nil
			end
		-- not valid ent
		else
			return nil
		end
	    return BUILDINGHELPER_THINK
    end})

	-- OnBelowHalfHealth timer
	building.onBelowHalfHealthProc = false
	building.healthChecker = Timers:CreateTimer(.03, function()
		if IsValidEntity(building) then
			if building:GetHealth() < fMaxHealth/2.0 and not building.onBelowHalfHealthProc and not building.bUpdatingHealth then
				if keys2.fireEffect ~= nil then
					building:AddNewModifier(building, nil, keys2.fireEffect, nil)
				end
				keys2.onBelowHalfHealth(unit)
				building.onBelowHalfHealthProc = true
			elseif building:GetHealth() >= fMaxHealth/2.0 and building.onBelowHalfHealthProc and not building.bUpdatingHealth then
				if keys2.fireEffect then
					building:RemoveModifierByName(keys2.fireEffect)
				end
				keys2.onAboveHalfHealth(unit)
				building.onBelowHalfHealthProc = false
			end
		else
			return nil
		end

		return .2
	end)

	function unit:Remove(bForceKill)
		BuildingHelper:OpenSquares(unit.squaresOccupied "string")
		if bForceKill then
			unit:ForceKill(true)
		end
	end

	-- Remove gold, start cooldown ,etc
	local goldCost = buildingTable.goldCost
	local cooldown = buildingTable:GetVal("AbilityCooldown", "number")
	if cooldown == nil then
		cooldown = 0
	end
	-- remove gold from playersHero.
	if playersHero ~= nil then
		local newGold = playersHero:GetGold() - goldCost
		playersHero:SetGold(0, false)
		playersHero:SetGold(newGold, true)
	end
	buildingTable["abil"]:StartCooldown(cooldown)

	-- take out custom resources from player
	local resources = buildingTable.resources
	for k,v in pairs(resources) do
		player[k] = player[k] - v
		if player[k] < 0 then
			player[k] = 0
		end
	end

	if keys2.onConstructionStarted ~= nil then
		keys2.onConstructionStarted(unit)
	end
end

-- DEPRECATED
--[[
function BuildingHelper:AddBuilding(building)
	building.bUpdatingHealth = false
	building.bFireEffectEnabled = true
	building.fireEffect="modifier_jakiro_liquid_fire_burn"
	building.bForceUnits = false
	building.fMaxScale=1.0
	building.fCurrentScale = 0.0
	building.bScale=false
	building.hullSet = false
	building.packed = false
	building.BHSize = LastSize
	building.BHOwner = LastOwner
	building.BHParticleDummies = {}
	building.BHParticles = {}
	
	building:SetControllableByPlayer(building.BHOwner:GetPlayerID(), true)

	function building:PackWithDummies()
		--BH_A = math.pow(2,.5) --multi this by rad of building
		--BH_cos45 = math.pow(.5,.5) -- cos(45)
		local origin = building:GetAbsOrigin()
		local rad = building:GetPaddedCollisionRadius()
		local A = BH_A*rad
		local B = rad
		local discCenter = (A-B)/2
		local discRad = BH_cos45*discCenter
		local dist = B + discCenter
		local C = dist*BH_cos45
		-- Top right disc
		local tr_x = origin.x + C
		local tr_y = origin.y + C
		-- top left disc
		local tl_x = origin.x - C
		local tl_y = tr_y
		-- bot left disc
		local bl_x = tl_x
		local bl_y = origin.y - C
		-- bot right disc
		local br_x = tr_x
		local br_y = bl_y

		local s = building.BHSize*64
		--DebugDrawCircle(origin, Vector(0,255,0), 5, building:GetPaddedCollisionRadius(), false, 60)
		--DebugDrawBox(origin, Vector(-1*s/2,-1*s/2,0), Vector(s/2,s/2,0), 0, 0, 255, 0, 60)

		local topRight = CreateUnitByName("npc_bh_dummy", Vector(tr_x,tr_y,0), false, nil, nil, DOTA_TEAM_GOODGUYS)
		local dummyPadding = 10
		Timers:CreateTimer(function()
			topRight:FindAbilityByName("bh_dummy_unit"):SetLevel(1)
			dummyPadding = topRight:GetCollisionPadding()
			topRight:SetHullRadius(discRad-dummyPadding)
			--DebugDrawCircle(Vector(tr_x,tr_y,0), Vector(255,0,0), 5, topRight:GetPaddedCollisionRadius(), false, 60)
		end)

		local topLeft = CreateUnitByName("npc_bh_dummy", Vector(tl_x,tl_y,0), false, nil, nil, DOTA_TEAM_GOODGUYS)
		Timers:CreateTimer(function()
			topLeft:FindAbilityByName("bh_dummy_unit"):SetLevel(1)
			topLeft:SetHullRadius(discRad-dummyPadding)
			--DebugDrawCircle(Vector(tl_x,tl_y,0), Vector(255,0,0), 5, topLeft:GetPaddedCollisionRadius(), false, 60)
		end)

		local bottomLeft = CreateUnitByName("npc_bh_dummy", Vector(bl_x,bl_y,0), false, nil, nil, DOTA_TEAM_GOODGUYS)
		Timers:CreateTimer(function()
			bottomLeft:FindAbilityByName("bh_dummy_unit"):SetLevel(1)
			bottomLeft:SetHullRadius(discRad-dummyPadding)
			--DebugDrawCircle(Vector(bl_x,bl_y,0), Vector(255,0,0), 5, bottomLeft:GetPaddedCollisionRadius(), false, 60)
		end)

		local bottomRight = CreateUnitByName("npc_bh_dummy", Vector(br_x,br_y,0), false, nil, nil, DOTA_TEAM_GOODGUYS)
		Timers:CreateTimer(function()
			bottomRight:FindAbilityByName("bh_dummy_unit"):SetLevel(1)
			bottomRight:SetHullRadius(discRad-dummyPadding)
			--DebugDrawCircle(Vector(br_x,br_y,0), Vector(255,0,0), 5, bottomRight:GetPaddedCollisionRadius(), false, 60)
		end)

		building.packers = {topRight, topLeft, bottomLeft, bottomRight}
		building.packed = true
	end
	function building:RemoveBuilding(bKill)
		local center = building:GetAbsOrigin()
		local halfSide = (building.BHSize/2.0)*64
		local buildingRect = {leftBorderX = center.x-halfSide, 
			rightBorderX = center.x+halfSide, 
			topBorderY = center.y+halfSide, 
			bottomBorderY = center.y-halfSide}
		local removeCount=0
		for x=buildingRect.leftBorderX+32,buildingRect.rightBorderX-32,64 do
			for y=buildingRect.topBorderY-32,buildingRect.bottomBorderY+32,-64 do
				for v,b in pairs(BUILDING_SQUARES) do
					if v == VectorString(Vector(x,y,0)) then
						BUILDING_SQUARES[v]=nil
						removeCount=removeCount+1
						if bKill then
							building:SetAbsOrigin(Vector(center.x,center.y,center.z-200))
							building:ForceKill(true)
						end
					end
				end
			end
		end
		-- remove the packers.
		if building.packed and building.packers ~= nil then
			for i,unit in ipairs(building.packers) do
				unit:ForceKill(true)
			end
		end
	end

	-- Dynamic packing.
	function building:Pack()
		-- setup global dummy if not already setup.
		if not BHGlobalDummySet then
			BHDummy = CreateUnitByName("npc_bh_dummy", Vector(0, 0, 0), false, nil, nil, DOTA_TEAM_GOODGUYS)
			Timers:CreateTimer(function()
	      		local abil = BHDummy:FindAbilityByName("bh_dummy_unit")
				abil:SetLevel(1)
				BHGlobalDummySet = true
	   	    end)
		end
		if not building.hullSet then
			building:SetHull()
			building.hullSet = true
		end
		building:PackWithDummies()
	end

	function building:SetHull()
		building:SetHullRadius(building.BHSize*64/2-building:GetCollisionPadding())
	end

	if (AUTO_SET_HULL) then
		building:SetHull()
		building.hullSet = true
	end

	-- Auto packing
	if PACK_ENABLED then
		-- setup global dummy if not already setup.
		if not BHGlobalDummySet then
			BHDummy = CreateUnitByName("npc_bh_dummy", Vector(0, 0, 0), false, nil, nil, DOTA_TEAM_GOODGUYS)
			Timers:CreateTimer(function()
	      		local abil = BHDummy:FindAbilityByName("bh_dummy_unit")
				abil:SetLevel(1)
				BHGlobalDummySet = true
	   	    end)
		end
		if not building.hullSet then
			building:SetHull()
			building.hullSet = true
		end
		building:PackWithDummies()
	end

	-- find clear space for building owner on the next frame.
	  Timers:CreateTimer(function()
      	FindClearSpaceForUnit(building.BHOwner, building.BHOwner:GetAbsOrigin(), true)
   	  end)

	--[[for id,unit in pairs(BH_UNITS) do
		if unit.bNeedsToJump then
			--print("jumping")
			FindClearSpaceForUnit(unit, unit:GetAbsOrigin(), true)
			unit.bNeedsToJump=false
		end
	end

	
	-- fire effect timer
	if FIRE_EFFECTS_ENABLED then
		building.fireTimer = DoUniqueString('fire')
		Timers:CreateTimer(building.fireTimer, {
	    callback = function()
			if building.bFireEffectEnabled and IsValidEntity(building) then
				if building:GetHealth() <= building:GetMaxHealth()/2 and building.bUpdatingHealth == false then
					if building:HasModifier(building.fireEffect) == false then
						building:AddNewModifier(building, nil, building.fireEffect, nil)
					end
				elseif building:GetHealth() > building:GetMaxHealth()/2 and building:HasModifier(building.fireEffect) then
					building:RemoveModifierByName(building.fireEffect)
				end
			-- fire disabled or not valid ent.
			else
				return nil
			end
		    return .25
	    end})
	end
end]]

function BuildingHelper:CloseSquares( vSquareCenters, type )
	-- these are vectors not strings.
	if #vSquareCenters > 0 then
		for i,v in ipairs(vSquareCenters) do
			if type == "vector" then
				BUILDING_SQUARES[VectorString(v)]=true
			else
				BUILDING_SQUARES[v]=true
			end
		end
	end
end

BuildingHelper.FireEffect = "modifier_jakiro_liquid_fire_burn"
function BuildingHelper:SetDefaultFireEffect( sFireEffect )
	self.FireEffect = sFireEffect
end

function BuildingHelper:OpenSquares( vSquareCenters, type )
	-- these are strings, not vectors
	if #vSquareCenters > 0 then
		for i,v in ipairs(vSquareCenters) do
			if type == "vector" then
				BUILDING_SQUARES[VectorString(v)]=false
			else
				BUILDING_SQUARES[v]=false
			end
		end
	end
end

function BuildingHelper:IsAreaBlocked( vSquareCenters )
	for i,v in ipairs(vSquareCenters) do
		if IsSquareBlocked(v, false) then
			return true
		end
	end
	return false
end

------------------------ UTILITY FUNCTIONS --------------------------------------------

function VectorString(v)
  return 'x: ' .. v.x .. ' y: ' .. v.y .. ' z: ' .. v.z
end

function BuildingHelper:IsRectangularAreaBlocked(boundingRect)
	for x=boundingRect.leftBorderX+32,boundingRect.rightBorderX-32,64 do
		for y=boundingRect.topBorderY-32,boundingRect.bottomBorderY+32,-64 do
			local vect = Vector(x,y,0)
			if GRIDNAV_SQUARES[VectorString(vect)] or BUILDING_SQUARES[VectorString(vect)] then
				return true
			end
		end
	end
	return false
end

function IsSquareBlocked( sqCenter, bVectorForm )
	if bVectorForm then
		sqCenter = Vector(sqCenter.x, sqCenter.y, 0)
		return GRIDNAV_SQUARES[VectorString(sqCenter)] or BUILDING_SQUARES[VectorString(sqCenter)]
	else
		return GRIDNAV_SQUARES[sqCenter] or BUILDING_SQUARES[sqCenter]
	end

end

function SnapToGrid64(coord)
	return 64*math.floor(0.5+coord/64)
end

function SnapToGrid32(coord)
	return 32+64*math.floor(coord/64)
end

function BuildingHelper:PrintSquareFromCenterPoint(v)
	local z = GetGroundPosition(v, nil).z
	DebugDrawBox(v, Vector(-32,-32,0), Vector(32,32,1), 255, 0, 0, 255, 30)
end

function BuildingHelper:PrintSquareFromCenterPointShort(v)
	DebugDrawBox(v, Vector(-32,-32,0), Vector(32,32,1), 255, 0, 0, 255, .1)
end

function ClearParticleTable( t )
	while #t > 0 do
		local id = t[1]
		ParticleManager:DestroyParticle(id, true)
		--if #table > 0 and table[1] == id then
			table.remove(t, 1)
		--end
	end
end

-- ********* UTILITY FUNCTIONS **************
-- Returns a shallow copy of the passed table.
function shallowcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in pairs(orig) do
            copy[orig_key] = orig_value
        end
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

function AbilityIterator(unit, callback)
    for i=0, unit:GetAbilityCount()-1 do
        local abil = unit:GetAbilityByIndex(i)
        if abil ~= nil then
            callback(abil)
        end
    end
end

function string.starts(String,Start)
   return string.sub(String,1,string.len(Start))==Start
end

function string.ends(String,End)
   return End=='' or string.sub(String,-string.len(End))==End
end

function TableLength( t )
	if t == nil or t == {} then
		return 0
	end
    local len = 0
    for k,v in pairs(t) do
        len = len + 1
    end
    return len
end
