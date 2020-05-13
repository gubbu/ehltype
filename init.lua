ehltype = {}
--TODO add translation.
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
        "button[1.75,2.3;3,0.8;set_text;"..text.."]",
        "checkbox[0.375,2.3;reverse;"..reverse..";"..is_selected.."]", --the is_selected is needed, otherwise the player would be confused by the meaning of his previous inputs.
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

minetest.register_tool(minetest.get_current_modname()..":typewriter",
    {
        description = "a typewriter",
        inventory_image = "ehltype_typewriter.png",
        groups = {tool = 1},
        on_place = function(itemstack, placer, pointed_thing)
            if pointed_thing.type == "node" and placer:is_player() then
                local pointed_velocity = {x = pointed_thing.above.x-pointed_thing.under.x, y = pointed_thing.above.y-pointed_thing.under.y, z = pointed_thing.above.z-pointed_thing.under.z}
                local name = placer:get_player_name()
                local current_meta = itemstack:get_meta()
                local current_text = current_meta:get_string("current_word")
                --minetest.chat_send_all(name.." is placing text:".. current_text .." in the direction: " .. minetest.serialize(pointed_velocity))
                -- checking for creative mode, copied from the screwdriver mod: https://github.com/minetest-game-mods/screwdriver/blob/master/init.lua
                if not (creative and creative.is_enabled_for and creative.is_enabled_for(name)) then
                    --adding wear depending on the texts lenght.
                    itemstack:add_wear(65535/math.abs(200-#current_text))
                    --minetest.chat_send_player(name, name..", current wear"..itemstack:get_wear())
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
                --checking area protection
                local current_position = {x=pointed_thing.above.x, y=pointed_thing.above.y, z=pointed_thing.above.z}
                for _i=1,#current_text do
                    if minetest.is_protected(current_position, name) then
                        minetest.chat_send_player(name, name..", your text overlaps with a protected area of an other player! You can not place it there.")
                        return
                    end
                    current_position = {x=current_position.x+pointed_velocity.x, y=current_position.y+pointed_velocity.y, z=current_position.z+pointed_velocity.z}
                end
                --finally placing the text.
                ehltype.place_text_in_world(current_text, pointed_thing.above, pointed_velocity, 1)
            end
            return itemstack
        end,
        on_use = function(itemstack, placer, pointed_thing)
            if placer:is_player() then
                local name = placer:get_player_name()
                minetest.show_formspec(name, "ehltype:typewriter", ehltype.typewriter_formspec(itemstack))
            end
        end
    })

minetest.register_craft({
    output = "ehltype:typewriter",
    recipe = {
        {"default:stick", "default:coal_lump", "default:stick"},
        {"default:steel_ingot", "default:paper", "default:steel_ingot"},
        {"default:steel_ingot", "default:steel_ingot", "default:steel_ingot"},
    }
})
