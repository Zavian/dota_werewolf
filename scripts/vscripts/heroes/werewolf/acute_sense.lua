function AcuteSense_casted(keys)
	local level = keys.Level
	local caster = keys.caster
	local modifier = "modifier_slark_shadow_dance"
	local modifierData = {
		duration = keys.Duration,
		fade_time = 0.0,
		bonus_movement_speed = 30,
		bonus_regen_pct = 3,
		activation_delay = 0.5,
		neutral_disable	= 2.0
	}
	if(level == 1) then
		-- When the acute sense is level 1
		local entities = Entities:FindAllByName("npc_dota_hero_omniknight")
		PrintTable(entities)
		for i=1, table.getn(entities) do
			local location = entities[i]:GetAbsOrigin()
			local dummy_unit = CreateUnitByName("npc_dummy_ping", location, false, nil, nil, caster:GetTeam())
			dummy_unit:AddNewModifier(dummy_unit, nil, modifier, modifierData) -- This for invisibility purposes
			Timers:CreateTimer({
			  	endTime = keys.Duration,
			  	callback = function()
			  	  dummy_unit:Destroy()
			  	end
	  		})
		end
	else
		-- When the acute sense is level 2
		local entities = Entities:FindAllByName("npc_dota_hero_omniknight")
		PrintTable(entities)
		for i=1, table.getn(entities) do
			local location = entities[i]:GetAbsOrigin()
			local dummy_unit = CreateUnitByName("npc_dummy_ping", location, false, nil, nil, caster:GetTeam())
			dummy_unit:AddNewModifier(dummy_unit, nil, modifier, modifierData) -- This for invisibility purposes

			modifier = "modifier_item_observer_ward"
			modifierData = {
				lifetime = keys.Duration,
				vision_range= 1600,
				health = 3000
			}
			dummy_unit:AddNewModifier(dummy_unit, nil, modifier, modifierData)

			Timers:CreateTimer({
			  	endTime = keys.Duration,
			  	callback = function()
			  	  dummy_unit:Destroy()
			  	end
	  		})
		end
	end
end