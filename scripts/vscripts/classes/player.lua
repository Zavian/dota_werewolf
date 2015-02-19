Player = {}
Player.__index = Player
BASE_NAME = "building_wwt_farm_TEST"

-- This class will contain a Player's information

function Player.create(id, lumber)
	local plr = {}
	setmetatable(plr, Player)

	plr.isInWater = false
	plr.timeInWater = 0

	plr._NOW = "human"

	plr._HumanSpells = {"wwt_lumber_collector0", "adrenaline_rush", "poseidon", "toxic_bomb", "spear_shot",
					"fish_net", "midas", "awesome", "call_dog", "scarecrow"}
	plr.learnedHumanSpells = {"wwt_lumber_collector0", "adrenaline_rush"}

	plr._WerewolfSpells = {"prowl", "tremendous_strength", "sprint", "acute_sense", "cannibalistic_urges"}

	plr.humanAbilityPoints = 1
	plr.werewolfAbilityPoints = 1

	plr.id = id 			-- Player's ID (ranging from 0 to 9)
	plr.lumber = lumber 	-- Player's lumber
	plr.set = false 		-- If the player has been initially set (gold to 150 at beginning)
	plr.BASE_TRIGGER = nil 	-- The base's trigger which will determine where the people will give the lumber
	plr.oldTree = nil 		-- The player's old tree if he is going to give the lumber at base
	plr.carried_lumber = 0 	-- How much lumber is the player carrying
	plr.color = {} 			-- The team color of the player

	plr.MODEL = nil 		-- The player's model name

	plr.Units = {} 			-- The player's units
	plr.Buildings = {} 		-- The player's buildings
	plr.Team = nil 			-- The player's team number

	return plr
end
--[[
	This will return an array of the players that have spawned
]]
function getSetuppedAndAlivePlayers()
	local array = {}
	for i=0, (DOTA_MAX_TEAM_PLAYERS-1) do
		if(Players[i] ~= nil) then
			if(Players[i]:isSet()) then
				if(PlayerResource:GetPlayer(i):GetAssignedHero():IsAlive()) then
					table.insert(array, i)
				end
			end
		end
	end
	return array
end

function Player:IsNow()
	return self._NOW
end

function Player:setModel(model)
	self.MODEL = model
end

function Player:getModel()
	return self.MODEL
end

function Player:transform(hero, toWerewolf)
	local oldPosition = hero:GetAbsOrigin()
	local oldFoward = hero:GetForwardVector()
	if(toWerewolf) then
		-- Human to Wolf
		local XP = 0
		self._NOW = "werewolf"
		if(self.werewolfXP ~= nil) then
			XP = self.werewolfXP
		end
		self.humanXP = hero:GetCurrentXP()
		self.humanGold = hero:GetGold()
		-- Need to hide the lumber

		self:storeSpells(hero, true)

		
		PlayerResource:ReplaceHeroWith(self.id, "npc_dota_hero_lycan", 0, XP)	
		hero = PlayerResource:GetPlayer(self.id):GetAssignedHero()		
		--hero:SetModel("models/heroes/lycan/lycan_wolf.vmdl")

		self:learnSpells(hero, true)

		--local modifier = "modifier_lycan_shapeshift"
		--local modifierData = {
		--	duration = 240,
		--	speed = 400,
		--	bonus_night_vision = 0,
		--	crit_chance = 0,
		--	crit_damage = 0,
		--	transformation_time = 0
		--}
		--hero:AddNewModifier(hero, nil, modifier, modifierData)
		--giveCustomModifier(hero, hero, "shapeshift", self.id)
		RemoveCosmeticsFromWolf(hero)

	else
		-- Wolf to Human
		local XP = 0
		self._NOW = "human"
		if(self.humanXP ~= nil) then
			XP = self.humanXP
		end
		self.werewolfXP = hero:GetCurrentXP()

		self:storeSpells(hero, false)

		PlayerResource:ReplaceHeroWith(self.id, "npc_dota_hero_omniknight", self.humanGold, XP)	
		hero = PlayerResource:GetPlayer(self.id):GetAssignedHero()	
		-- Need to show the lumber
		hero:SetModel(self.MODEL)

		self:learnSpells(hero, false)
	end
	hero:SetAbsOrigin(oldPosition)
	hero:SetForwardVector(oldFoward)
end	

function Player:storeSpells(hero, toWerewolf)
	if(toWerewolf) then
		-- Human to Wolf
		self.humanAbilityPoints = hero:GetAbilityPoints()
		self.learnedHumanSpells = {}
		for i = 1, table.getn(self._HumanSpells) do
			-- If the hero has a level of the ability I will store it
			if(hero:FindAbilityByName(self._HumanSpells[i]) ~= nil) then
				if(hero:FindAbilityByName(self._HumanSpells[i]):GetLevel() == 1) then
					table.insert(self.learnedHumanSpells, self._HumanSpells[i])
				end
			end
	    end
	    print("Spells stored for the human")
	    PrintTable(self.learnedHumanSpells)
	else
		-- Wolf to Human
		self.werewolfAbilityPoints = hero:GetAbilityPoints()
		self.learnedWerewolfSpells = {}
		for i=1,table.getn(self._WerewolfSpells) do
			if(hero:FindAbilityByName(self._WerewolfSpells[i]):GetLevel() > 0) then
				self.learnedWerewolfSpells[self._WerewolfSpells[i]] = hero:FindAbilityByName(self._WerewolfSpells[i]):GetLevel()
			end
		end
	end
end

function Player:learnSpells(hero, toWerewolf)
	if(toWerewolf) then
		-- Human to Wolf
		if(self.learnedWerewolfSpells ~= nil) then
			for i=1,table.getn(self._WerewolfSpells) do
				print(self._WerewolfSpells[i])
				if(self.learnedWerewolfSpells[self._WerewolfSpells[i]] ~= nil) then
					hero:FindAbilityByName(self._WerewolfSpells[i]):SetLevel(self.learnedWerewolfSpells[self._WerewolfSpells[i]])
				end
			end
		end
		hero:SetAbilityPoints(self.werewolfAbilityPoints)
	else
		-- Wolf to Human
		if(self.learnedHumanSpells ~= nil) then
			for i=1, #self.learnedHumanSpells do
				print("Human " .. self.id .. "learning " .. self.learnedHumanSpells[i])
				hero:FindAbilityByName(self.learnedHumanSpells[i]):SetLevel(1)
			end
		end
		hero:SetAbilityPoints(self.humanAbilityPoints)
	end
end

function Player:setTeam(team, color, hero)
	print("Entered in setTeam")
	PlayerResource:SetCustomTeamAssignment( self.id, team)
	self.Team = team
	Players[self.id]:setColor(hero, color)
end

function Player:getTeam()
	return self.Team
end

function Player:getColor()
	return self.color
end

function Player:setColor(hero, color)
	print("Entered in setColor")
	hero:SetCustomHealthLabel(  "", color[1], color[2], color[3] )
	self.color = color
end


--[[
	This will get the input of all the unit creation spells
	so that can do the magic
	[NEED REWORK]
]]
function summonDetect(keys)
	Players[keys.caster:GetPlayerOwnerID()]:createUnit(
		keys.Summon,
		keys.caster,
		keys.target_points[1]
		--keys.Cost,
		--keys.TimeToBuild,
	)
end

function Player:createUnit(name, caster, location)
	local unit = CreateUnitByName(name, location, false, nil, nil, caster:GetTeam())
	unit:SetControllableByPlayer( self.id, true )
	unit.vOwner = caster:GetOwner()
	if(name == "npc_wwt_worker") then
		-- Need to select the level of lumber collector
		unit:FindAbilityByName("wwt_lumber_collector0"):SetLevel(1)
	end
	if(self.Units == nil) then
		self.Units[1] = Unit.create(unit:GetEntityIndex(), self.id)
	else
		self.Units[table.getn(self.Units) + 1] = Unit.create(unit:GetEntityIndex(), self.id)
	end
	PrintTable(self.Units)
end


function Player:setCarriedLumber(number)
	self.carried_lumber = number
end

function Player:getCarriedLumber()
	return self.carried_lumber
end

function Player:setBASE_TRIGGER(trigger)
	self.BASE_TRIGGER = trigger
end

function Player:getBASE_TRIGGER()
	return self.BASE_TRIGGER
end

--[[
	This will get the input of all the building creation spells
	so that can do the magic
]]
--function buildDetect(keys)
--	--print(keys.target_points[1])
--	--CreateUnitByName("building_wwt_farm_TEST", keys.target_points[1], true, keys.caster, keys.caster, keys.caster:GetTeam())
--
--	Players[keys.caster:GetPlayerOwnerID()]:build(
--		keys.Build,
--		keys.caster,
--		keys.target_points[1],
--		keys.Cost,
--		keys.TimeToBuild,
--		keys.Scale
--	)
--end

--[[
	Return: Base's position
]]
function Player:getBase()
	for i=1,table.getn(self.Buildings) do
		if(self.Buildings[i]:getName() == BASE_NAME) then
			return self.Buildings[i]:getPosition()
		end
	end
	return -1
end

function Player:getUnitById(id)
	--PrintTable(self.Units)
	--print("banana")
	for i=1, table.getn(self.Units) do
		if(self.Units[i]:getId() == id) then
			--print("Returning Units["..i.."]")
			--PrintTable(self.Units[i])
			return self.Units[i]
		end
	end
	return -1
end

function create_building_entity( keys )
	BuildingHelper:InitializeBuildingEntity(keys)
end


function build(keys)
	-- keys.target_points[1]
	-- local point = BuildingHelper:AddBuildingToGrid(location, 4, caster)
	-- if point == -1 or point == nil then
	-- 		-- Need to make as3 error
	-- 		print("[WWT] Someone tried to create a building in a random place")
	-- 	return
	-- else
	-- 	if(caster:GetGold() >= cost) then
	-- 		local gold = caster:GetGold() - cost
	-- 		caster:SetGold(0, false)
	-- 		caster:SetGold(gold, true)

	-- 		local farm = CreateUnitByName(name, point, false, nil, nil, caster:GetTeam())
	-- 		BuildingHelper:AddBuilding(farm)

	-- 		if(self.Buildings == nil) then
	-- 			self.Buildings[1] = Building.create(farm:GetEntityIndex(), name, self.id, location)
	-- 		else
	-- 			self.Buildings[table.getn(self.Buildings) + 1] = Building.create(farm:GetEntityIndex(), name, self.id, location)
	-- 		end

	-- 		if(name == BASE_NAME) then
	-- 			local trigger = Entities:FindByName(nil, "baseTrigger")
	-- 			trigger.Name = self.id .. "bTrigger"
	-- 			trigger:SetAbsOrigin(point)
	-- 		end
			

	-- 		farm:UpdateHealth(buildTime, true, scale)
	-- 		farm:SetControllableByPlayer( caster:GetPlayerID(), true )
	-- 	else

	-- 		print("[WWT] Someone tried to create a building without money")
	-- 		-- Need to make as3 error
	-- 	end
	-- end
	local player = keys.caster:GetPlayerOwner()
	local pID = player:GetPlayerID()
	player.lumber = Players[pID]:getLumber()
	local returnTable = BuildingHelper:AddBuilding(keys)
	--print("Lumber: " .. player.lumber)
	--print("Stone: " .. player.stone)
	--handle errors if any
	if TableLength(returnTable) > 0 then
		--PrintTable(returnTable)
		if returnTable["error"] == "not_enough_resources" then
			local resourceTable = returnTable["resourceTable"]
			-- resourceTable is like this: {["lumber"] = 3, ["stone"] = 6}
			-- so resourceName = cost-playersResourceAmount
			-- the api searches for player[resourceName]. you need to keep this number updated
			-- throughout your game
			local firstResource = nil
			for k,v in pairs(resourceTable) do
				if not firstResource then
					firstResource = k
				end
				if Debug_BH then
					print("P" .. pID .. " needs " .. v .. " more " .. k .. ".")
				end
			end
			local capitalLetter = firstResource:sub(1,1):upper()
			firstResource = capitalLetter .. firstResource:sub(2)
			FireGameEvent( 'custom_error_show', { player_ID = pID, _error = "Not enough " .. firstResource .. "." } )
			return
		end
	end

	keys:OnConstructionStarted(function(unit)
		print("Started construction of " .. unit:GetUnitName())
		-- Unit is the building be built.
		-- Play construction sound
		-- FindClearSpace for the builder
		FindClearSpaceForUnit(keys.caster, keys.caster:GetAbsOrigin(), true)
		-- start the building with 0 mana.
		unit:SetMana(0)
	end)
	keys:OnConstructionCompleted(function(unit)
		print("Completed construction of " .. unit:GetUnitName())
		-- Play construction complete sound.
		-- Give building its abilities
		-- add the mana
		unit:SetMana(unit:GetMaxMana())
	end)

	-- These callbacks will only fire when the state between below half health/above half health changes.
	-- i.e. it won't unnecessarily fire multiple times.
	keys:OnBelowHalfHealth(function(unit)
		if Debug_BH then
			print(unit:GetUnitName() .. " is below half health.")
		end
	end)

	keys:OnAboveHalfHealth(function(unit)
		if Debug_BH then
			print(unit:GetUnitName() .. " is above half health.")
		end
	end)

	--[[keys:OnCanceled(function()
		print(keys.ability:GetAbilityName() .. " was canceled.")
	end)]]

	-- Have a fire effect when the building goes below 50% health.
	-- It will turn off it building goes above 50% health again.
	keys:EnableFireEffect("modifier_jakiro_liquid_fire_burn")
	player.lumber = nil
end

function Player.allSet()
	for playerID = 0, (DOTA_MAX_TEAM_PLAYERS-1) do
		if(Players[playerID]:isSet() == false) then
			return false
		end
	end
	return true
end

function Player:getHero()
	for i = 0, i < table.getn(Players) do
		if(Players[i]:getId() == i) then
			return PlayerResource:GetPlayer(Players[i]:getId()):GetAssignedHero()
		end
	end
end 

function Player:setOldTree(tree)
	self.oldTree = tree
end

function Player:getOldTree(tree)
	return self.oldTree
end

function Player:isSet()
	return self.set
end

function Player:setupped()
	self.set = true
end

function Player:getId()
	return self.id
end

function Player:getLumber()
	return self.lumber
end

function Player:setLumber(lumber, add)
	if(add) then
		self.lumber = self.lumber + lumber
		PopupLumber(PlayerResource:GetPlayer(self.id):GetAssignedHero(), lumber)
	else
		self.lumber = lumber
	end
end

function Player:remLumber(lumber)
	if(lumber > self.lumber) then
	return false -- Error
	else self.lumber = self.lumber - lumber
	end
end
