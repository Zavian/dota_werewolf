print("[WWT] Functions loaded.")

function differenceFromAngles(alpha, beta)
    if alpha > beta then
        return alpha - beta
    end
    return beta-alpha
end

function EquipWeapon(event)

    local hero = event.caster
    local newWeaponModel = "models/items/witchdoctor/tribal_mask.vmdl"
    if hero.originalWeaponModel == nil then
    	hero.originalWeaponModel = "models/heroes/omniknight/hair.vmdl"
    end

    local model = hero:FirstMoveChild()
    while model ~= nil do
        if model:GetClassname() ~= "" and model:GetClassname() == "dota_item_wearable" then
            local modelName = model:GetModelName()
            --print(modelName)
            if modelName == hero.originalWeaponModel then
                -- Set the weapon model, save both the new and original model names in the caster handle to call OnUnequip
                print("FOUND "..modelName.." SWAPPING TO "..newWeaponModel)
                hero.originalWeaponModel = modelName
                hero.weapon = newWeaponModel
                model:SetModel(newWeaponModel)
            end
        end
        model = model:NextMovePeer()
        if model ~= nil and model:GetModelName() ~= "" then
            print("Next Peer:" .. model:GetModelName())
        end
    end
    print("------------------------")
end

function RemoveCosmeticsFromWolf(hero)
    local notToRemove = "models/heroes/lycan/lycan_wolf.vmdl"
    local model = hero:FirstMoveChild()
    while model ~= nil do
        if model:GetClassname() ~= "" and model:GetClassname() == "dota_item_wearable" then
            local modelName = model:GetModelName()
            --print(modelName)
            if modelName ~= notToRemove then
                print("FOUND "..notToRemove..". REMOVING "..modelName)
                model:SetModel(nil)
            end
        end
        model = model:NextMovePeer()
        if model ~= nil and model:GetModelName() ~= "" then
            print("Next Peer:" .. model:GetModelName())
        end
    end
    print("------------------------")
end

function UnequipWeapon( event )
    local hero = event.caster
    local originalWeaponModel = hero.originalWeaponModel
    local currentWeapon = hero.weapon

    local model = hero:FirstMoveChild()
    while model ~= nil do
        if model:GetClassname() ~= "" and model:GetClassname() == "dota_item_wearable" then
            local modelName = model:GetModelName()
            -- Set the weapon model back to the original
            if modelName == currentWeapon then
                hero.weapon = originalWeaponModel
                model:SetModel(originalWeaponModel)
            end
        end
        model = model:NextMovePeer()
        if model ~= nil and model:GetModelName() ~= "" then
            print("Next Peer:" .. model:GetModelName())
        end
    end

    print("------------------------")
end

function dealDamage(source, target, damage)
    if damage <= 0 or source == nil or target == nil then
	return
    end
    local dmgTable = {8192,4096,2048,1024,512,256,128,64,32,16,8,4,2,1}
    local item = CreateItem( "item_deal_damage", source, source)
    for i=1,#dmgTable do
	local val = dmgTable[i]
	local count = math.floor(damage / val)
	if count >= 1 then
	    item:ApplyDataDrivenModifier( source, target, "dealDamage" .. val, {duration=0} )
	    damage = damage - val
	end
    end
    UTIL_RemoveImmediate(item)
    item = nil
end

function giveCustomModifier(source, target, modifier, modifierData)
    local item
    local modifierData = modifierData or nil

    item = CreateItem( "item_custom_modifiers", source, source)
	item:ApplyDataDrivenModifier( source, target, modifier, modifierData)
end


function selectPlayerOrUnit(o, requestedType)
	--[[
		This function has been done just because I wanted to shrink the code
		This will determine if what I want is the hero's entity or an unit's entity
		As you can see for units you have to select o.vOwner for the Id
		For the hero it's just very simple
	]]
	if(requestedType == "entity") then
		if(string.match(o:GetUnitName(), "hero")) then
			return Players[o:GetPlayerOwnerID()]
		elseif(o:GetUnitName() == "npc_wwt_worker") then
			return Players[o.vOwner:GetPlayerID()]:getUnitById(o:entindex())
		end
	elseif(requestedType == "id") then
		if(string.match(o:GetUnitName(), "hero")) then
			return o:GetPlayerOwnerID()
		elseif(o:GetUnitName() == "npc_wwt_worker") then
			return o.vOwner:GetPlayerID()
		end
	end
	return nil
end

function baseTouched(trigger)
	-- This function will manage the AI for getting back
	-- to the old tree you was gathering
	--print("IS TOUCHING ME!")
	--print("Please, explain with this plush where he touched you")
	--print("*Voices saying: OMG*")
	--PrintTable(trigger)
	--PrintTable(trigger.activator)

	--[[
		This trigger will activate when a unit will enter into a base trigger
		So it will manage the retrieve of the lumber from the units and it will reset
			the lumber from the said unit
	]]
	local id = selectPlayerOrUnit(trigger.activator, "id")
	local callerid = tonumber(trigger.caller.Name:sub(1,1))
	if(id == callerid) then
		trigger.activator:Stop()
		local playerOrUnit = selectPlayerOrUnit(trigger.activator, "entity")
		print(trigger.activator:GetUnitName() == "npc_wwt_worker")
		if(playerOrUnit ~= nil) then
			local carriedLumber = playerOrUnit:getCarriedLumber()
			print(carriedLumber)
			if(carriedLumber == 8) then
				trigger.activator:RemoveAbility("wwt_lumber_collector8")
				trigger.activator:RemoveModifierByName("lumber_collector")
				trigger.activator:AddAbility("wwt_lumber_collector0")
				trigger.activator:FindAbilityByName("wwt_lumber_collector0"):SetLevel(1)
				Players[id]:setLumber(8, true)
				FireGameEvent(
					'wwt_lumber_changed', 
					{ 
						player = id, 
						lumber = Players[id]:getLumber() 
					}
				)
				playerOrUnit:setCarriedLumber(0)

				trigger.activator:MoveToTargetToAttack(playerOrUnit:getOldTree())			
			end
		end
	end
end

function OnStartTouch(trigger) 
	-- This will trigger on the teleporters
	PrintTable(trigger)

	local caller = trigger.caller:GetName()
	local to = ""

	-- Possible callers:
	-- teleport_{from}_{to}
	-- Example: teleport_wolf_south (wolf = the wolf cave)

	if(caller == "teleport_wolf_south") then
		to = "teleport_south"
	elseif(caller == "teleport_south_wolf") then
		to = "teleport_wolf"
	end


	FindClearSpaceForUnit(
		trigger.activator , 
		Entities:FindByName(nil, to):GetAbsOrigin(), 
		false
	)
	trigger.activator:Stop()
	if(trigger.activator:IsHero()) then
		SendToConsole("dota_camera_center")
		SendToConsole("-dota_camera_follow")
	end
end

