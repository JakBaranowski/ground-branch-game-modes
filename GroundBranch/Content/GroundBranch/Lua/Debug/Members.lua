local Members = {}

Members.__index = Members

function Members.IterateMembers(object, parent)
	print("# " .. parent)
	Members.IterateMembersInner(object, 3)
end

function Members.IterateMembersInner(object, depth, current)
	if current == nil then
		current = 1
	end

	if depth <= current then
		return
	end

	local tab = string.rep("#", current + 1) .. " "

	if type(object) == "table" then
		for key, value in pairs(object) do
			print(tab .. key .. " | " .. tostring(value))
			Members.IterateMembersInner(value, depth, current + 1)
		end

	elseif type(object) == "userdata" then
		for key, value in pairs(getmetatable(object)) do
			print(tab .. key .. " | " .. tostring(value))
			Members.IterateMembersInner(value, depth, current + 1)
		end

	elseif type(object) == "function" then
		local info = debug.getinfo(object)
		print(tab .. "nparams: " .. info.nparams .. " vararg: " .. tostring(info.isvararg))
		return

	else
		print(tab .. tostring(object) .. " | " .. type(object))
		return

	end

end

return Members
