<<<<<<< HEAD
ehltype = {}
--copied from ehlphabet mod

local function is_multibyte(ch)
    local byte = ch:byte()
    -- return (195 == byte) or (208 == byte) or (209 == byte)
    if not byte then
        return false
    else
        return (byte > 191)
    end
end

local function is_utf8(text)
    for i=1,#text do
        local ch = text:sub(i,i)
        if is_multibyte(ch) then
            return true
        end
    end
    return false
end

function ehltype.place_text_in_world(text, start, velocity, number_repeat)
    local count = 0
    --this variable is needed for getting utf8 also
    local skip_next = false
    for _j=1,number_repeat do
        for i=1,#text do
            if not skip_next then
                local ch = text:sub(i,i)
                local current_position = {x = start.x+velocity.x*count, y = start.y+velocity.y*count, z = start.z+velocity.z*count}
                if ch == " " then
                    minetest.set_node(current_position, { name = "ehlphabet:block" })
                else
                    --copied this part from the ehlphabet mod again
                    local mb = is_multibyte(ch)
                    -- old line gives error with Ä local key = mb and (ch:byte(1) .. ch:byte(2)) or ch:byte()
                    -- wroks not for utf8: local key = ch:byte()
                    local key = ch:byte()
                    if mb then
                        
                        key = key..(text:sub(i+1,i+1):byte() or "nil")
                        minetest.chat_send_all("trying to write utf8 symbol:"..key.."maybe this symbol is unknown")
                        skip_next = true
                    end
                    --check if the given node exists before placing it
                    local current_node_name = "ehlphabet:"..key
                    if minetest.registered_nodes[current_node_name] ~= nil then
                        minetest.set_node(current_position, { name = current_node_name })
                    else
                        -- NO SUPPORT for small utf8 symbols like öüä only the big ones: ÖÄÜ
                        minetest.chat_send_all(current_node_name.." is unknown, note that öüä (small letters) should be replaced with ÖÜÄ, [ and  ] do not work too!")
                    end
                end
                count = count + 1
            else
                skip_next = false
            end
        end
    end
end

function ehltype.can_place_text_in_world(text, start, velocity, number_repeat)
    local count = 0
    for _j=1,number_repeat do
        for i=1,#text do
            local current_position = {x = start.x+velocity.x*count, y = start.y+velocity.y*count, z = start.z+velocity.z*count}
            local current_name = minetest.get_node(current_position).name
            if current_name ~= "air" and current_name ~= "default:water_source" then
                --minetest.chat_send_all(current_name.." at "..minetest.serialize(current_position).." obstructs careless building.")
                return false
            end
            count = count + 1
        end
    end
    return true
end

function ehltype.typewriter_formspec(typewriter_itemstack)
    local text = "set_text"
    local reverse = "reverse"
    local text_place_reverse = "Write Reversed!"
    local metaref = typewriter_itemstack:get_meta()
    local current_word = metaref:get_string("current_word")
    local is_selected = "false"
    if metaref:get_int("reverse")==1 then
        is_selected = "true"
    end
    local formspec = {
        "formspec_version[3]",
        "size[6,3.476]",
        "field[0.375,1.25;5.25,0.8;text;"..text..";"..current_word.."]",
        --"field[0.375,1.25;5.25,0.8;text;"..text..";]",
        "button[1.75,2.3;3,0.8;set_text;"..text.."]",
        "checkbox[0.375,2.3;reverse;"..reverse..";"..is_selected.."]", --the is_selected is needed, otherwise the player would be confused by the meaning of his previous inputs.
        --"checkbox[0.375,2.3;reverse;"..reverse..";]"
    }
    -- table.concat is faster than string concatenation - `..`
    return table.concat(formspec, "")
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
    if formname ~= "ehltype:typewriter" then
        return
    end

    local current_item = player:get_wielded_item()
    local current_meta = current_item:get_meta()
    local pname = player:get_player_name()

    if fields.set_text then
        -- converting to uppercase if possible /not for utf8...
        local current_text = fields.text:upper()
        if current_meta:get_int("reverse") == 1 then
            --problem with this: can not simply reverse a utf8 string!
            if not is_utf8(current_text) then
                current_text = current_text:reverse()
            else
                minetest.chat_send_player(pname, pname..", you can not reverse text containing utf8 for now... no reversion applied.")
            end
        end
        --checking if all input characters can be written in ehlphabet block form:
        local skip_next = false
        for i=1,#current_text do
            if not skip_next then
                local ch = current_text:sub(i,i)
                local mb = is_multibyte(ch)
                local key = ch:byte()
                if mb then
                    key = key..current_text:sub(i+1,i+1):byte()
                    skip_next = true
                else
                    if ch == " " then
                        key = "block"
                    end
                end
                local current_node_name = "ehlphabet:"..key
                if minetest.registered_nodes[current_node_name] == nil then
                    minetest.chat_send_player(pname, pname..", your given text: "..current_text.." contains unsopported characters like(äöü{} or [])! ÄÖÜ are supported. no changes will be made. "..current_node_name.. " does not exist")
                    return
                end
            else
                skip_next = false
            end
        end
        -- if all characters are supported by ehlphabet: update meta
        current_meta:set_string("current_word", current_text)
        player:set_wielded_item(current_item)
        minetest.chat_send_player(pname, pname..", your typewriter was configured for the following text: "..current_text..".")
    end
    if fields.reverse then
        -- https://dev.minetest.net/formspec#checkbox to be verified seems to be true

        if current_meta:get_int("reverse") == 0 then
            current_meta:set_int("reverse", 1)
        else
            current_meta:set_int("reverse", 0)

        end
        --minetest.chat_send_all(" reverse =  "..current_meta:get_int("reverse"))
        player:set_wielded_item(current_item)
    end

end)

minetest.register_craftitem(minetest.get_current_modname()..":typewriter",
    {
        description = "a typewriter",
        inventory_image = "ehltype_typewriter.png",
        on_place = function(itemstack, placer, pointed_thing)
            if pointed_thing.type == "node" and placer:is_player() then
                local pointed_velocity = {x = pointed_thing.above.x-pointed_thing.under.x, y = pointed_thing.above.y-pointed_thing.under.y, z = pointed_thing.above.z-pointed_thing.under.z}
                local name = placer:get_player_name()
                local current_meta = itemstack:get_meta()
                local current_text = current_meta:get_string("current_word")
                --minetest.chat_send_all(name.." is placing text:".. current_text .." in the direction: " .. minetest.serialize(pointed_velocity))
                -- checking for creative mode, copied from the screwdriver mod not (creative and creative.is_enabled_for and creative.is_enabled_for(player_name))
                if not (creative and creative.is_enabled_for and creative.is_enabled_for(name)) then
                    --TODO: ading wear and checking all permissions
                    if not ehltype.can_place_text_in_world(current_text, pointed_thing.above, pointed_velocity, 1) then
                            minetest.chat_send_player(name, name..", the text that you want to write down was obstructed by a node that is not air and not water.")
                        return
                    end
                    local costs = #current_text
                    --what if costs > 99?
                    local inv = placer:get_inventory()
                    -- how many ehlphabetblocks are in the players inventory?
                    local stack = ItemStack("ehlphabet:block "..costs)
                    if inv:contains_item("main", stack) then
                        inv:remove_item("main", stack)
                     else
                        minetest.chat_send_player(name, name..", you need "..costs.." ehlphabet blocks in your inventory to write your text down in survival!")
                        return                         
                     end
                end
                ehltype.place_text_in_world(current_text, pointed_thing.above, pointed_velocity, 1)
            end
        end,
        on_use = function(itemstack, placer, pointed_thing)
            if placer:is_player() then
                local name = placer:get_player_name()
                minetest.show_formspec(name, "ehltype:typewriter", ehltype.typewriter_formspec(itemstack))
            end
        end
    })

=======
-- diamond_screwdriver/init.lua
-- soource: copied version of https://github.com/minetest/minetest_game/blob/master/mods/screwdriver/init.lua
diamond_screwdriver = {}

-- Load support for MT game translation.
local S = minetest.get_translator("diamond_screwdriver")


diamond_screwdriver.ROTATE_FACE = 1
diamond_screwdriver.ROTATE_AXIS = 2
diamond_screwdriver.disallow = function(pos, node, user, mode, new_param2)
	return false
end
diamond_screwdriver.rotate_simple = function(pos, node, user, mode, new_param2)
	if mode ~= diamond_screwdriver.ROTATE_FACE then
		return false
	end
end

-- For attached wallmounted nodes: returns true if rotation is valid
-- simplified version of minetest:builtin/game/falling.lua#L148.
local function check_attached_node(pos, rotation)
	local d = minetest.wallmounted_to_dir(rotation)
	local p2 = vector.add(pos, d)
	local n = minetest.get_node(p2).name
	local def2 = minetest.registered_nodes[n]
	if def2 and not def2.walkable then
		return false
	end
	return true
end

diamond_screwdriver.rotate = {}

local facedir_tbl = {
	[diamond_screwdriver.ROTATE_FACE] = {
		[0] = 1, [1] = 2, [2] = 3, [3] = 0,
		[4] = 5, [5] = 6, [6] = 7, [7] = 4,
		[8] = 9, [9] = 10, [10] = 11, [11] = 8,
		[12] = 13, [13] = 14, [14] = 15, [15] = 12,
		[16] = 17, [17] = 18, [18] = 19, [19] = 16,
		[20] = 21, [21] = 22, [22] = 23, [23] = 20,
	},
	[diamond_screwdriver.ROTATE_AXIS] = {
		[0] = 4, [1] = 4, [2] = 4, [3] = 4,
		[4] = 8, [5] = 8, [6] = 8, [7] = 8,
		[8] = 12, [9] = 12, [10] = 12, [11] = 12,
		[12] = 16, [13] = 16, [14] = 16, [15] = 16,
		[16] = 20, [17] = 20, [18] = 20, [19] = 20,
		[20] = 0, [21] = 0, [22] = 0, [23] = 0,
	},
}

diamond_screwdriver.rotate.facedir = function(pos, node, mode)
	local rotation = node.param2 % 32 -- get first 5 bits
	local other = node.param2 - rotation
	rotation = facedir_tbl[mode][rotation] or 0
	return rotation + other
end

diamond_screwdriver.rotate.colorfacedir = diamond_screwdriver.rotate.facedir

local wallmounted_tbl = {
	[diamond_screwdriver.ROTATE_FACE] = {[2] = 5, [3] = 4, [4] = 2, [5] = 3, [1] = 0, [0] = 1},
	[diamond_screwdriver.ROTATE_AXIS] = {[2] = 5, [3] = 4, [4] = 2, [5] = 1, [1] = 0, [0] = 3}
}

diamond_screwdriver.rotate.wallmounted = function(pos, node, mode)
	local rotation = node.param2 % 8 -- get first 3 bits
	local other = node.param2 - rotation
	rotation = wallmounted_tbl[mode][rotation] or 0
	if minetest.get_item_group(node.name, "attached_node") ~= 0 then
		-- find an acceptable orientation
		for i = 1, 5 do
			if not check_attached_node(pos, rotation) then
				rotation = wallmounted_tbl[mode][rotation] or 0
			else
				break
			end
		end
	end
	return rotation + other
end

diamond_screwdriver.rotate.colorwallmounted = diamond_screwdriver.rotate.wallmounted

-- Handles rotation
diamond_screwdriver.handler = function(itemstack, user, pointed_thing, mode, uses)
	if pointed_thing.type ~= "node" then
		return
	end

	local pos = pointed_thing.under
	local player_name = user and user:get_player_name() or ""

	if minetest.is_protected(pos, player_name) then
		minetest.record_protection_violation(pos, player_name)
		return
	end

	local node = minetest.get_node(pos)
	local ndef = minetest.registered_nodes[node.name]
	if not ndef then
		return itemstack
	end
	-- can we rotate this paramtype2?
	local fn = diamond_screwdriver.rotate[ndef.paramtype2]
	if not fn and not ndef.on_rotate then
		return itemstack
	end

	local should_rotate = true
	local new_param2
	if fn then
		new_param2 = fn(pos, node, mode)
	else
		new_param2 = node.param2
	end

	-- Node provides a handler, so let the handler decide instead if the node can be rotated
	if ndef.on_rotate then
		-- Copy pos and node because callback can modify it
		local result = ndef.on_rotate(vector.new(pos),
				{name = node.name, param1 = node.param1, param2 = node.param2},
				user, mode, new_param2)
		if result == false then -- Disallow rotation
			return itemstack
		elseif result == true then
			should_rotate = false
		end
	elseif ndef.on_rotate == false then
		return itemstack
	elseif ndef.can_dig and not ndef.can_dig(pos, user) then
		return itemstack
	end

	if should_rotate and new_param2 ~= node.param2 then
		node.param2 = new_param2
		minetest.swap_node(pos, node)
		minetest.check_for_falling(pos)
	end
    -- jsut commented this out
      --[[
	if not (creative and creative.is_enabled_for and
			creative.is_enabled_for(player_name)) then
		itemstack:add_wear(65535 / ((uses or 200) - 1))
	end
    ]]--
	return itemstack
end


-- diamond_screwdriver
minetest.register_tool("diamond_screwdriver:diamond_screwdriver", {
	description = S("diamond_screwdriver") .. "\n" .. S("(left-click rotates face, right-click rotates axis)"),
	inventory_image = "screwdriver.png^[colorize:#53eef3",
	groups = {tool = 1},
	on_use = function(itemstack, user, pointed_thing)
		diamond_screwdriver.handler(itemstack, user, pointed_thing, diamond_screwdriver.ROTATE_FACE, 200)
		return itemstack
	end,
	on_place = function(itemstack, user, pointed_thing)
		diamond_screwdriver.handler(itemstack, user, pointed_thing, diamond_screwdriver.ROTATE_AXIS, 200)
		return itemstack
	end,
})


minetest.register_craft({
	output = "diamond_screwdriver:diamond_screwdriver",
	recipe = {
		{"default:diamond"},
		{"group:stick"}
	}
})

minetest.register_alias("diamond_screwdriver:diamond_screwdriver1", "diamond_screwdriver:diamond_screwdriver")
minetest.register_alias("diamond_screwdriver:diamond_screwdriver2", "diamond_screwdriver:diamond_screwdriver")
minetest.register_alias("diamond_screwdriver:diamond_screwdriver3", "diamond_screwdriver:diamond_screwdriver")
minetest.register_alias("diamond_screwdriver:diamond_screwdriver4", "diamond_screwdriver:diamond_screwdriver")
>>>>>>> dfd5e81e0e679597e86042fec883b88a25e4de09
