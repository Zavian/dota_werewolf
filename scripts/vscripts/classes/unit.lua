Unit = {}
Unit.__index = Unit

function Unit.create(id, owner)
	local unt = {}
	setmetatable(unt, Unit)

	unt.owner = owner
	unt.id = id
	unt.oldTree = nil
	unt.carried_lumber = 0

	return unt
end

function Unit:getId()
	return self.id
end

function Unit:getOwner()
	return self.owner
end


function Unit:setOldTree(tree)
	self.oldTree = tree
end

function Unit:getOldTree()
	return self.oldTree
end

function Unit:setCarriedLumber(number)
	self.carried_lumber = number
end

function Unit:getCarriedLumber()
	return self.carried_lumber
end