Player = {}
Player.__index = Player
BASE_NAME = "building_wwt_farm_TEST"

-- This class will contain a Player's information

function Player.create(id, lumber)
	local plr = {}
	setmetatable(plr, Player)

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
function getSetuppedPlayers()
	local array = {}
	for i=0, (DOTA_MAX_TEAM_PLAYERS-1) do
		if(Players[i] ~= nil) then
			if(Players[i]:isSet()) then
				table.insert(array, i)
			end
		end
	end
	return array
end

function Player:setModel(model)
	self.MODEL = model
end

function Player:getModel()
	return self.MODEL
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
	--need if (worker)
	unit:FindAbilityByName("wwt_lumber_collector0"):SetLevel(1)
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
function buildDetect(keys)
	--print(keys.target_points[1])
	--CreateUnitByName("building_wwt_farm_TEST", keys.target_points[1], true, keys.caster, keys.caster, keys.caster:GetTeam())

	Players[keys.caster:GetPlayerOwnerID()]:build(
		keys.Build,
		keys.caster,
		keys.target_points[1],
		keys.Cost,
		keys.TimeToBuild,
		keys.Scale
	)
end

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

function Player:build(name, caster, location, cost, buildTime, scale)
	-- keys.target_points[1]
	local point = BuildingHelper:AddBuildingToGrid(location, 4, caster)
	if point == -1 then
			-- Need to make as3 error
			print("[WWT] Someone tried to create a building in a random place")
		return
	else
		if(caster:GetGold() >= cost) then
			local gold = caster:GetGold() - cost
			caster:SetGold(0, false)
			caster:SetGold(gold, true)

			local farm = CreateUnitByName(name, point, false, nil, nil, caster:GetTeam())
			BuildingHelper:AddBuilding(farm)

			if(self.Buildings == nil) then
				self.Buildings[1] = Building.create(farm:GetEntityIndex(), name, self.id, location)
			else
				self.Buildings[table.getn(self.Buildings) + 1] = Building.create(farm:GetEntityIndex(), name, self.id, location)
			end

			if(name == BASE_NAME) then
				local trigger = Entities:FindByName(nil, "baseTrigger")
				trigger.Name = self.id .. "bTrigger"
				trigger:SetAbsOrigin(point)
			end
			

			farm:UpdateHealth(buildTime, true, scale)
			farm:SetControllableByPlayer( caster:GetPlayerID(), true )
		else

			print("[WWT] Someone tried to create a building without money")
			-- Need to make as3 error
		end
	end
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