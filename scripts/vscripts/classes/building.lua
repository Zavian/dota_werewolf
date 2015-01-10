Building = {}
Building.__index = Building


function Building.create(id, name, owner, position)
	local bld = {}
	setmetatable(bld, Building)

	bld.id = id
	bld.position = position
	bld.name = name

	return bld
end

function Building:getId()
	return self.id
end

function Building:getName()
	return self.name
end

function Building:getPosition()
	return self.position
end
