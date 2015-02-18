function Poseidon_created(keys)
	local caster = keys.caster
	print(caster:GetAbsOrigin())
	PrintTable(caster:GetAbsOrigin())
	local position = caster:GetAbsOrigin()
	print(position.z)
	caster.oldZ = position.z
	local newPosition = position
	newPosition.z = -140.0
	caster:SetAbsOrigin(newPosition)
	caster:SetMoveCapability(DOTA_UNIT_CAP_MOVE_NONE)

	local dummy_unit = CreateUnitByName("npc_wwt_dummy_invisible", position, false, nil, nil, caster:GetTeam())
	local particle = ParticleManager:CreateParticle("particles/units/heroes/hero_wisp/wisp_relocate_marker.vpcf", PATTACH_ABSORIGIN_FOLLOW, dummy_unit)
	ParticleManager:SetParticleControl(particle, 0, dummy_unit:GetAbsOrigin())
	ParticleManager:SetParticleControl(particle, 1, Vector(particle_radius,0,0))
	giveCustomModifier(dummy_unit, dummy_unit, "unselectable")
	caster.marker = dummy_unit

	caster:RemoveAbility("poseidon")
	caster:AddAbility("poseidon_remove")
	caster:FindAbilityByName("poseidon_remove"):SetLevel(1)
end

function Poseidon_destroyed(keys)
	local caster = keys.caster
	print(caster:GetAbsOrigin())
	PrintTable(caster:GetAbsOrigin())
	local position = caster:GetAbsOrigin()
	print(position.z)
	local newPosition = position
	newPosition.z = caster.oldZ -- This is the default one
	caster:SetAbsOrigin(newPosition)
	caster:SetMoveCapability(DOTA_UNIT_CAP_MOVE_GROUND)
	caster.marker:Destroy()

	caster:RemoveAbility("poseidon_remove")
	caster:AddAbility("poseidon")
	caster:FindAbilityByName("poseidon"):SetLevel(1)
	caster:FindAbilityByName("poseidon"):StartCooldown(keys.Cooldown)
end