function Midas_casted(keys)
	local target = keys.target
	if(target:GetLevel() < 5) then
		giveCustomModifier(keys.caster, target, "midas")
	else
		-- Need to create flash error
		keys.caster:Stop()
		print("Someone tried to transmute a level 5 or superior")
	end
end

function Midas_created(keys)
	--keys.target:Kill(nil, nil)
end