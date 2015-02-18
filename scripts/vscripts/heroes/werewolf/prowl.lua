function ProwlModifier_created(keys)
	local caster = keys.caster
	print(caster:GetHullRadius())
	local newHull = caster:GetHullRadius() - (caster:GetHullRadius() / 100) * 20
	caster:SetHullRadius(newHull)
	print(caster:GetHullRadius())
end

function Prowl_attack_landed(keys)
	local caster = keys.caster
	local target = keys.target
	local casterAngle = math.floor(caster:GetAnglesAsVector()[2])
	local targetAngle = math.floor(target:GetAnglesAsVector()[2])
	local triggerAngle = 50
	if(AngleDiff(casterAngle, targetAngle) > -triggerAngle and AngleDiff(casterAngle, targetAngle) < triggerAngle) then
 		dealDamage(caster, target, keys.BonusDamage)
	end
	caster:SetHullRadius(keys.DefaultHull) 
end