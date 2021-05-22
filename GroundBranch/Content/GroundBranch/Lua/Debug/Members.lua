local Members = {}

Members.__index = Members

function Members.IterateMembers(object, parent)
	print("# " .. parent)
	Members.IterateMembersInner(object, 3)
end

function Members.IterateMembersInner(object, depth, current)
	if depth <= 0 then
		return
	end
	if current == nil then
		current = 2
	end
	local tab = string.rep("#", current) .. " "

	if type(object) == "table" then
		for key, value in pairs(object) do
			if key ~= "script" then
				local ret = Members.IterateMembersInner(value, depth - 1, current + 1)
				if ret ~= nil then
					print(tab .. key .. Members.IterateMembersInner(value, depth - 1))
				else
					print(tab .. key)
				end
			end
		end

	elseif type(object) == "userdata" then
		for key, value in pairs(getmetatable(object)) do
			return Members.IterateMembersInner(value, depth - 1)
		end

	elseif type(object) == "function" then
		local info = debug.getinfo(object)
		return " nparams: " .. info.nparams .. " vararg: " .. tostring(info.isvararg)
	end

end

return Members
