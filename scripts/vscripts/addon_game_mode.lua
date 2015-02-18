require('util')								-- Functions to help debugging
require('WWT')								-- Where all the globals are stored
require('functions')						-- Functions used around the mod
require('/classes/player')					-- The class of the player
require('/classes/unit')					-- The class of the unit
require('/classes/building')				-- The class of the building
require('/libraries/buildinghelper')		-- Buildinghelper library (Thanks Myll)
require('/libraries/timers')				-- Timers library (Thanks BMD)
require('/libraries/FlashUtil')

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