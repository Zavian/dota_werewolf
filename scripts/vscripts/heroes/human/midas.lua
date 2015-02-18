function Midas_casted(keys)
	local target = keys.target
	if(target:GetLevel() < 5) then
		giveCustomModifier(keys.caster, target, "midas")
	else
		-- Need to create flash error
		FireGameEvent("custom_error_show", { player_ID = keys.caster:GetPlayerID(), "You can't transmute creatures level 5 or superior"})
		
		keys.caster:Stop()
		--print("Someone tried to transmute a level 5 or superior")
	end
end

function Midas_created(keys)
	--keys.target:Kill(nil, nil)
end