require('util')								-- Functions to help debugging
require('WWT')								-- Where all the globals are stored
require('functions')						-- Functions used around the mod
require('/classes/player')					-- The class of the player
require('/classes/unit')					-- The class of the unit
require('/classes/building')				-- The class of the building
require('/libraries/buildinghelper')		-- Buildinghelper library (Thanks Myll)
require('/libraries/timers')				-- Timers library (Thanks BMD)


if WWT == nil then
	WWT = class({})
end

function Precache( context )	-- Function to Precache models that aren't in spells or so on
	PrecacheModel("models/props_debris/creep_camp001a.vmdl", context) 
	PrecacheModel("models/props_structures/bridge_statue001.vmdl", context)
	PrecacheModel("models/props_debris/shop_set_seat001.vmdl", context)
	PrecacheModel("models/heroes/lycan/lycan_wolf.vmdl", context)
	PrecacheModel("models/items/witchdoctor/tribal_mask.vmdl", context) --[[Returns:void
	( modelName, context ) - Manually precache a single model
	]]
	PrecacheResource("model_folder", "models/heroes/lycan", context)
	PrecacheResource("particle", "particles/units/heroes/hero_wisp/wisp_relocate_marker.vpcf", context)

	--[[
		Precache things we know we'll use.  Possible file types include (but not limited to):
		PrecacheResource( "model", "*.vmdl", context )
		PrecacheResource( "soundfile", "*.vsndevts", context )
		PrecacheResource( "particle", "*.vpcf", context )
		PrecacheResource( "particle_folder", "particles/folder", context )
	]]
end

-- Create the game mode when we activate
function Activate()
	GameRules.AddonTemplate = WWT()
	GameRules.AddonTemplate:InitGameMode()
end

function WWT:InitGameMode()
	print( "[WWT] Template addon is loaded." )
	print()
	print()
	GameRules:GetGameModeEntity():SetThink( "OnThink", self, "GlobalThink", 2 )

	-- Listener that tells when any entity gets hurt
	ListenToGameEvent('entity_hurt', Dynamic_Wrap(WWT, 'OnEntityHurt'), self)

	-- Listener that tells when any npc has spawned
	ListenToGameEvent('npc_spawned', Dynamic_Wrap(WWT, 'OnEntitySpawn'), self)

	-- Custom listener that is fired when lumber changes
	ListenToGameEvent('wwt_lumber_changed', Dynamic_Wrap(WWT, 'OnLumberChange'), self)
	
	-- Function that setups the custom teams and the colors
	self:MultiTeams()

	-- Function that setups the console commands
	self:RegisterCommands()
	
	GameRules:SetHeroRespawnEnabled( false )		-- Heroes can't respawn, I'll manage through code
	GameRules:SetUseUniversalShopMode( false )		-- The shop can't be accessed
	GameRules:SetSameHeroSelectionEnabled( true )	-- People can select the same hero
	GameRules:SetHeroSelectionTime( 30.0 )			-- People will have 30 seconds of selection time
	GameRules:SetPreGameTime( 10.0 )				-- After spawn there will be 10 seconds before the official beginning of the mod
	GameRules:SetPostGameTime( 60.0 )				-- The game will close after 60 seconds of the finish of the mod
	GameRules:SetTreeRegrowTime( 60.0 )				--
	GameRules:SetUseCustomHeroXPValues ( true )		--
	GameRules:SetGoldPerTick(0)						-- People won't have gold unless we'll script it

	BuildingHelper:BlockGridNavSquares(MAP_SIZE)	-- Setting up the gridnav so can be manipulated
	BuildingHelper:SetPacking(true)					-- All the buildings will have rectangular bounds

	createTrees()									-- Function that will make the trees targettable
end

-- Evaluate the state of the game
function WWT:OnThink()
	collectgarbage("collect")		-- Garbage collector for maintinig low RAM usage
	if(not GameRules:IsDaytime()) then -- If it's NightTime
		--print("It's not daytime")
		if(thereIsNoWolf) then 	-- and the wolf hasn't trasformed
			self:NightComes()	-- function that manages the transformation
		end
	else 
		--print("It's daytyime")
		thereIsNoWolf = true 	-- If it's DayTime
		if(theWerewolf ~= nil) then
			print(Players[theWerewolf]:IsNow())
			local hero = PlayerResource:GetPlayer(theWerewolf):GetAssignedHero()
			if(Players[theWerewolf]:IsNow() == "werewolf") then
				print("Transforming the werewolf")
				Players[theWerewolf]:transform(hero, false)	
			end		
		end
	end

	if GameRules:State_Get() == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
		-- This starts at 0.00
	elseif GameRules:State_Get() >= DOTA_GAMERULES_STATE_POST_GAME then
		return nil
	elseif GameRules:State_Get() == DOTA_GAMERULES_STATE_HERO_SELECTION then
		GameRules:GetGameModeEntity():SetThink( "assignClasses", self, 0 )
	end
	return 1
end

function WWT:MultiTeams()

	-- Defining the colors of the teams
	self.m_TeamColors = {}
	self.m_TeamColors[DOTA_TEAM_GOODGUYS] = { 255, 0, 0 }		-- RED
	self.m_TeamColors[DOTA_TEAM_BADGUYS] = { 0, 255, 0 }		-- GREEN
	self.m_TeamColors[DOTA_TEAM_CUSTOM_1] = { 0, 0, 255 }		-- BLUE
	self.m_TeamColors[DOTA_TEAM_CUSTOM_2] = { 255, 128, 64 }	-- ORANGE
	self.m_TeamColors[DOTA_TEAM_CUSTOM_3] = { 255, 255, 0 }		-- YELLOW
	self.m_TeamColors[DOTA_TEAM_CUSTOM_4] = { 128, 255, 0 }		-- GREEN
	self.m_TeamColors[DOTA_TEAM_CUSTOM_5] = { 128, 0, 255 }		-- PURPLE
	self.m_TeamColors[DOTA_TEAM_CUSTOM_6] = { 255, 0, 128 }		-- PINK
	self.m_TeamColors[DOTA_TEAM_CUSTOM_7] = { 0, 255, 255 }		-- TEAL (nobody knows it)
	self.m_TeamColors[DOTA_TEAM_CUSTOM_8] = { 255, 255, 255 }	-- WHITE
	--PrintTable(self.m_TeamColors)


	-- Defining the victory strings for future purposes
	self.m_VictoryMessages = {}
	self.m_VictoryMessages[DOTA_TEAM_GOODGUYS] = "#VictoryMessage_GoodGuys"
	self.m_VictoryMessages[DOTA_TEAM_BADGUYS] = "#VictoryMessage_BadGuys"
	self.m_VictoryMessages[DOTA_TEAM_CUSTOM_1] = "#VictoryMessage_Custom1"
	self.m_VictoryMessages[DOTA_TEAM_CUSTOM_2] = "#VictoryMessage_Custom2"
	self.m_VictoryMessages[DOTA_TEAM_CUSTOM_3] = "#VictoryMessage_Custom3"
	self.m_VictoryMessages[DOTA_TEAM_CUSTOM_4] = "#VictoryMessage_Custom4"
	self.m_VictoryMessages[DOTA_TEAM_CUSTOM_5] = "#VictoryMessage_Custom5"
	self.m_VictoryMessages[DOTA_TEAM_CUSTOM_6] = "#VictoryMessage_Custom6"
	self.m_VictoryMessages[DOTA_TEAM_CUSTOM_7] = "#VictoryMessage_Custom7"
	self.m_VictoryMessages[DOTA_TEAM_CUSTOM_8] = "#VictoryMessage_Custom8"

	self.Teams = {DOTA_TEAM_GOODGUYS, DOTA_TEAM_BADGUYS, DOTA_TEAM_CUSTOM_1, DOTA_TEAM_CUSTOM_2, DOTA_TEAM_CUSTOM_3, DOTA_TEAM_CUSTOM_4,
					DOTA_TEAM_CUSTOM_5, DOTA_TEAM_CUSTOM_6, DOTA_TEAM_CUSTOM_7, DOTA_TEAM_CUSTOM_8}
	self.teamToSet = 1
end

function WWT:NightComes() 
	print("Entered in NightComes")
	thereIsNoWolf = false
	if(theWerewolf == nil) then
		local a = getSetuppedAndAlivePlayers()									-- Deciding who'll be the wolf
		if(a[1] ~= nil) then 											--if the array has something
			theWerewolf = a[math.random(a[1], table.getn(a))]			-- Getting the possible players that can be the wolf
			print("The werewolf is the player number " .. theWerewolf)
		end
	end
	local hero = PlayerResource:GetPlayer(theWerewolf):GetAssignedHero()
	Players[theWerewolf]:transform(hero, true)
	PlayerResource:GetPlayer(theWerewolf):GetAssignedHero():FindAbilityByName("cannibalistic_urges"):SetLevel(1)
end


function WWT:OnEntityHurt(keys)
		local hero = EntIndexToHScript(keys.entindex_attacker)
		local attacked = EntIndexToHScript(keys.entindex_killed)
		--print(hero:GetUnitName())

	-- LUMBER COLLECTED
	if(attacked:GetUnitName() == "npc_wwt_dummy") then -- If I'm attacking a tree
		if(string.match(hero:GetUnitName(), "hero") or hero:GetUnitName() == "npc_wwt_worker") then -- and I am a hero or a worker
			local carriedLumber
			local playerOrUnit = selectPlayerOrUnit(hero, "entity") -- Look at the function
			

			if(playerOrUnit:getCarriedLumber() < 8) then
				playerOrUnit:setCarriedLumber(playerOrUnit:getCarriedLumber() + 1)	-- Increasing the unit's carried lumber
				--PrintTable(playerOrUnit)
			end
			local carriedLumber = playerOrUnit:getCarriedLumber()
			if(carriedLumber < 8) then			
				--print(carriedLumber .. "< 8")
				hero:RemoveAbility("wwt_lumber_collector" .. carriedLumber - 1)
				hero:RemoveModifierByName("lumber_collector")
				hero:AddAbility("wwt_lumber_collector" .. (carriedLumber))
				hero:FindAbilityByName("wwt_lumber_collector" .. (carriedLumber)):SetLevel(1)					
			elseif(carriedLumber == 8) then -- Need to define the other levels
				--print(carriedLumber .. "= 8")
				if(hero:FindAbilityByName("wwt_lumber_collector7") ~= nil) then
					hero:RemoveAbility("wwt_lumber_collector7")
					hero:RemoveModifierByName("lumber_collector")
					hero:AddAbility("wwt_lumber_collector8")
					hero:FindAbilityByName("wwt_lumber_collector8"):SetLevel(1)	
				end			

				local position = -1
				if(string.match(hero:GetUnitName(), "hero")) then
					position = Players[hero:GetPlayerOwnerID()]:getBase()
				else
					position = Players[hero.vOwner:GetPlayerID()]:getBase()
				end
				if(position ~= -1) then -- If I have my base (-1 = I don't have one)
					--local collectorLevel = hero:FindAbilityByName("wwt_lumber_collector" .. carriedLumber - 1):GetLevel()
					
					hero:MoveToPosition(position) -- Sending my hero to the base to deliver the lumber
					playerOrUnit:setOldTree(attacked)					
				else
					hero:Stop()
				end
			end
		end	
	end
end

function WWT:OnEntitySpawn(keys)
	if(treesSpawned) then
		local hero = EntIndexToHScript(keys.entindex)
		if(string.match(hero:GetClassname(), "hero")) then -- It means that a hero has spawned
			print("A hero has spawned")
			if(not Players[hero:GetPlayerOwnerID()]:isSet()) then
				hero:SetGold(0, false)	-- Resetting hero's gold
				hero:SetGold(150, true)
				hero:FindAbilityByName("wwt_lumber_collector0"):SetLevel(1)
				--hero:FindAbilityByName("adrenaline_rush"):SetLevel(1)
				
				playerID = hero:GetPlayerOwnerID()

				Players[playerID]:setModel(hero:GetModelName())

				-- Setting the team
				Players[playerID]:setTeam(self.Teams[self.teamToSet], self.m_TeamColors[self.Teams[self.teamToSet]], hero)
				print("Player " .. playerID .. " set to " .. self.teamToSet)
				PrintTable(self.m_TeamColors[self.teamToSet])
				self.teamToSet = self.teamToSet + 1
				print(self.teamToSet)

				Players[playerID]:setupped()
				print("Set player number " .. hero:GetPlayerOwnerID() .. " gold to 150")
			end
		end
	end
end

function WWT:assignClasses()
	-- Here will continuisly assign players to their classes
	for playerID = 0, (DOTA_MAX_TEAM_PLAYERS-1) do
		if(Players == nil) then -- First player to be added
			Players[playerID] = Player.create(playerID, 350)
			FireGameEvent('wwt_lumber_changed', { player = playerID, lumber = 350 })
		elseif(Players[playerID] == nil) then
			Players[playerID] = Player.create(playerID, 350)
			FireGameEvent('wwt_lumber_changed', { player = playerID, lumber = 350 })			
		end		
	end

	if Player.allSet() then return nil -- If everyone are setupped I will delete this Thinker
	else
		return 1
	end
end

function WWT:OnLumberChange(keys)
	-- This event it's used in the UI
end

function WWT:RegisterCommands()
	Convars:RegisterCommand( "GetAllPlayers", function(name, p)
	    --get the player that sent the command
	    local cmdPlayer = Convars:GetCommandClient()
	    if cmdPlayer then 
	        local array = {}
	        for playerID = 0, (DOTA_MAX_TEAM_PLAYERS-1) do
	        	PrintTable(PlayerResource:GetPlayer(playerID))
	        	print(PlayerResource:GetPlayerName(playerID))
	        	array[playerID] = tostring(playerID).." "..PlayerResource:GetPlayerName(playerID)
	        end
	        FireGameEvent('returning_players', { 
	        	player0 = array[0],
	        	player1 = array[1],
	        	player2 = array[2],
	        	player3 = array[3],
	        	player4 = array[4],
	        	player5 = array[5],
	        	player6 = array[6],
	        	player7 = array[7],
	        	player8 = array[8],
	        	player9 = array[9]
	        })
	        print("Triggered returning_players")
	        return array
	    end
	end, "Player names", 0 )

	Convars:RegisterCommand( "LearnAbility", function(name, p)
	    --get the player that sent the command
	    local cmdPlayer = Convars:GetCommandClient()
	    if cmdPlayer then 
	        if(DEBUG) then
	        	PlayerResource:GetPlayer(0):GetAssignedHero():AddAbility(p)
	        	PlayerResource:GetPlayer(0):GetAssignedHero():FindAbilityByName(p):SetLevel(1)
	        end
	    end
	end, "Learn an ability. You should be a developer for seeing which abilities you can learn...", 0 )
	Convars:RegisterCommand( "UnlearnAbility", function(name, p)
	    --get the player that sent the command
	    local cmdPlayer = Convars:GetCommandClient()
	    if cmdPlayer then 
	        if(DEBUG) then
	        	PlayerResource:GetPlayer(0):GetAssignedHero():RemoveAbility(p)
	        end
	    end
	end, "Unlearn an ability. You should be a developer for seeing which abilities you can unlearn...", 0 )
	Convars:RegisterCommand( "RemoveModifier", function(name, p)
	    --get the player that sent the command
	    local cmdPlayer = Convars:GetCommandClient()
	    if cmdPlayer then 
	        if(DEBUG) then
	        	PlayerResource:GetPlayer(0):GetAssignedHero():RemoveModifierByName(p)
	        end
	    end
	end, "Remove modifier. You should be a developer for seeing which modifier you can remove...", 0 )
end

