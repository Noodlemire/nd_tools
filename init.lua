--[[
Tools Using the Node Damage and Repair System
Copyright (C) 2020 Noodlemire

This library is free software; you can redistribute it and/or
modify it under the terms of the GNU Lesser General Public
License as published by the Free Software Foundation; either
version 2.1 of the License, or (at your option) any later version.

This library is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public
License along with this library; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
--]]

--Mod-specific global variable
nd_tools = {}

--A table that keeps track of players who are currently digging a node.
local digging_node_info = {}

--A table for keeping track of the exact times that objects were punched, for the "time_from_last_punch" variable.
local punch_times = {}



--If possible, attempt to damage the node-type pointed_thing with the given item.
--Yes, the pointed_thing has to be a node.
local function damage_node(player, itemstack, pointed_thing)
	--Get the pointed node and its definition right away.
	local node = minetest.get_node(pointed_thing.under)
	local def = minetest.registered_nodes[node.name]

	--Give up if an undefined node is targeted.
	if not def then return end

	--Now that we know we have a definition, we can get the dig params according to the tool used.
	local dig_params = minetest.get_dig_params(def.groups, itemstack:get_tool_capabilities())

	--If the node was determined to be diggable...
	if dig_params.diggable then
		--Attempt to damage it. If it failed to be damaged after all, give up.
		if not node_damage.damage(pointed_thing.under, node, player) then return end
		--Refresh the itemstack to avoid an issue where, if you tried to dig a node using itself, the dug node would cease to exist.
		itemstack = player:get_wielded_item()

		--Create an entry for this tool use, targeting the node and timed knowing that four hits total will destroy a node.
		digging_node_info[player:get_player_name()] = {time = dig_params.time / 4, target = pointed_thing}
		--Wear the tool at 1/4 the rate, since it takes four hits to destroy a node.
		itemstack:add_wear(dig_params.wear / 4)

		--If the node was already at the 3rd damage stage...
		if def.groups.node_damage == 3 then
			--Play the dig sound
			minetest.sound_play(def.sounds.dug, {gain = 1.0, pos = pointed_thing.under}, true)
		else
			--Otherwise, play the dig sound only as a default
			local dig_sound = def.sounds.dig

			--Try to get a place sound if it exists
			if not dig_sound or dig_sound == "__group" then
				dig_sound = def.sounds.place
			end

			--Play whichever sound was found, related to simply punching a node.
			minetest.sound_play(dig_sound, {gain = 1.0, pos = pointed_thing.under}, true)
		end

		--Finally, return the itemstack itself
		return itemstack
	end
end



--Whenever a player leaves, their digging info is discarded.
minetest.register_on_leaveplayer(function(player)
	digging_node_info[player:get_player_name()] = nil
end)

--This function causes on_use to be called repeatedly whenever left mouse button is held.
controls.register_on_hold(function(player, control, time)
	if control == "LMB" then
		--Check the player's wielded item
		local tool = player:get_wielded_item()

		--If the tool is not part of the nd_tools system...
		if minetest.get_item_group(tool:get_name(), "nd_tools") <= 0 then
			--If the player was previously digging something...
			if digging_node_info[player:get_player_name()] then
				--Stop digging by only deleting the stored target node info. This allows the dig time to still work when rapidly clicking.
				digging_node_info[player:get_player_name()].target = nil
			end

			--Either way, stop here.
			return
		end

		--Get the position of the player's eyes, to determine pointed_thing
		local pos = player:get_pos()
		pos.y = pos.y + player:get_properties().eye_height
		--Get the tool's definition, to check its digparams and range
		local def = tool:get_definition()
		--Create a ray between the player's eyes and where they're looking, limited by their tool's range
		local ray = Raycast(pos, vector.add(pos, vector.multiply(player:get_look_dir(), def.range or minetest.registered_items[""].range or 4)))

		--Store a pointed_thing based on the first walkable node found
		local pointed_thing = nil
		for pt in ray do
			if pt.type == "node" then
				pointed_thing = pt
				break
			end
		end

		--If a pointed thing was found...
		if pointed_thing then
			--If the player was digging something before
			if digging_node_info[player:get_player_name()] then
				--Make them dig the new node instead
				digging_node_info[player:get_player_name()].target = pointed_thing
			else
				--If there's no data at all, it means the timer ran out, so it's safe to also damage the node right away.
				damage_node(player, tool, pointed_thing)
			end

			--Ensure the definition and on_use exist
			if def and def.on_use then
				--Call on_use, and store what it returns
				tool = def.on_use(tool, player, pointed_thing)

				--If on_use returned something, replace the player's wielded item with it.
				if tool then
					player:set_wielded_item(tool)
				end
			end
		--Otherwise, if the player was digging something before, stop digging it.
		elseif digging_node_info[player:get_player_name()] then
			digging_node_info[player:get_player_name()].target = nil
		end
	end
end)

--Upon release of left mouse button...
controls.register_on_release(function(player, control, held_time)
	if control == "LMB" and digging_node_info[player:get_player_name()] then
		--Stop digging by only deleting the stored target node info. This allows the dig time to still work when rapidly clicking.
		digging_node_info[player:get_player_name()].target = nil
	end
end)

--During every globalstep, regardless of which button is held...
minetest.register_globalstep(function(dtime)
	--For each player...
	for _, player in pairs(minetest.get_connected_players()) do
		--Store the name right away
		local pname = player:get_player_name()

		--If they weren't digging anything, stop.
		if not digging_node_info[pname] then
			return
		end

		--If there's still time left before the player can dig something, decrease that time and stop.
		if digging_node_info[pname].time > 0 then
			digging_node_info[pname].time = digging_node_info[pname].time - dtime
			return
		end

		--If the player isn't still trying to dig something, stop.
		if not digging_node_info[pname].target then
			return
		end

		--If the player is trying to dig something...
		if controls.players[pname].LMB then
			--Finally damage whatever they are digging, and store the result
			local item = damage_node(player, player:get_wielded_item(), digging_node_info[pname].target)

			--If there was a result, update the player's wielded item to it.
			if item then
				player:get_inventory():set_stack("main", player:get_wield_index(), item)
			end
		end
	end
end)

--Once all the mods have loaded...
minetest.register_on_mods_loaded(function()
	--Look through every registered item
	for name, def in pairs(minetest.registered_items) do
		--If the item doesn't already have its own on_use function, and it isn't set to deny the nd_tools functionality...
		if def.on_use == nil and minetest.get_item_group(name, "nd_tools_deny") == 0 then
			--Get the def's groups and add nd_tools to it.
			local groups = def.groups or {}
			groups.nd_tools = 1

			--Override the item to formally set the groups in...
			minetest.override_item(name, {
				groups = groups,

				--Give the item an on_use function
				on_use = function(itemstack, user, pointed_thing)
					--Look up the most recent on_use call if it exists, while storing the current time.
					local old_time = punch_times[user:get_player_name()] or 0
					punch_times[user:get_player_name()] = os.clock()

					--If nothing is punched, give up.
					if pointed_thing.type == "nothing" then 
						return itemstack
					--If an object is punched, replicate the default punching behavior.
					--The difference between old and current time is used to create the "time_from_last_punch" variable.
					elseif pointed_thing.type == "object" then
						local wear = pointed_thing.ref:punch(user, os.clock() - old_time, itemstack:get_tool_capabilities(), user:get_look_dir())

						if not minetest.is_creative_enabled(user:get_player_name()) then
							itemstack:add_wear(wear)
						end

						return itemstack
					end

					--Store the user's name
					local pname = user:get_player_name()

					--If they were digging something before, update it to this new target.
					if digging_node_info[pname] then
						digging_node_info[pname].target = pointed_thing
					end

					--Otherwise, as long as the player isn't on cooldown from their last damaged node...
					if not (digging_node_info[pname] and digging_node_info[pname].time > 0) then
						--Finally attempt to damage the node.
						return damage_node(user, itemstack, pointed_thing)
					end
				end,
			})
		end
	end
end)



--If a form of glue already exists because of the Mesecons mod...
if minetest.registered_items["mesecons_materials:glue"] then
	--Add the needed group so mallets can use it
	local groups = minetest.registered_items["mesecons_materials:glue"].groups
	groups.nd_tools_glue = 9

	--Override the item to formally set the group in place
	minetest.override_item("mesecons_materials:glue", {groups = groups})
else
	--Otherwise, create our own
	minetest.register_craftitem("nd_tools:glue", {
		image = "nd_tools_glue.png",
	    	description="Glue",
		groups = {nd_tools_glue = 9}
	})

	--To create this variant of glue, simply cook any item in the "sapling" group. Should have fairly high compatability.
	minetest.register_craft({
		type = "cooking",
		output = "nd_tools:glue 2",
		recipe = "group:sapling",
		cooktime = 2
	})
end



--This is the function you can use to make a new mallet.
function nd_tools.register_mallet(name, durability, efficiency, hand_matl, head_matl)
	--Convert the given description into a usable name format. It is turned to lowercase, and spaces are turned to underscores.
	local n = name:lower():gsub(' ', '_')
	--Also get the current modname for an automatic prefix.
	local prefix = minetest.get_current_modname()

	--Register the new mallet with all of that in mind...
	minetest.register_tool(prefix..":mallet_"..n, {
		description = name.." Mallet",

		--All mallets to into the given group
		groups = {nd_mallet = 1},

		--Keep in mind how the naming works when making an inventory image.
		inventory_image = prefix.."_mallet_"..n..".png",

		--Efficiency affects how many uses you can get out of each consumed glue. Higher is better.
		efficiency = efficiency,

		--On left-click...
		on_use = function(itemstack, user, pointed_thing)
			--Get the user's inventory
			local inv = user:get_inventory()
			--Get the metadata to check the glue level
			local meta = itemstack:get_meta()
			local glue = meta:get_int("nd_tools:glue")

			--If more glue is needed...
			if glue <= 0 then
				--Iterate through only the user's main inventory
				for i = 1, inv:get_size("main") do
					--Get the current stack
					local gluestack = inv:get_stack("main", i)

					--Check if it has the "nd_tools_glue" category, which any item can use if it should be able to fuel mallets.
					if minetest.get_item_group(gluestack:get_name(), "nd_tools_glue") > 0 then
						--Set the glue level and remove 1 piece of glue.
						--The default glue level is equal to the number given to the group itself, multiplied by the mallet's efficiency.
						glue = math.ceil(minetest.get_item_group(gluestack:get_name(), "nd_tools_glue") * (itemstack:get_definition().efficiency or 1))
						gluestack:take_item()
						inv:set_stack("main", i, gluestack)

						--Once we found one piece of glue, we can stop the loop and keep going to the next part of the function.
						break
					end
				end
			end

			--If there is any glue on the hammer...
			if glue > 0 then
				--Get the pointed node and its definition
				local node = minetest.get_node(pointed_thing.under)
				local def = minetest.registered_nodes[node.name]

				--Check if it was capable of being repaired. If not, give up.
				if not node_damage.repair(pointed_thing.under, node, player) then return end

				--Apply appropriate wear to the mallet
				itemstack:add_wear(65535 / durability)

				--Decrease the glue level by 1
				glue = glue - 1
				meta:set_int("nd_tools:glue", glue)

				--Play a quieter sound, closer to a footstep than the louder breaking noise.
				minetest.sound_play(def.sounds.footstep, {gain = 1.0, pos = pointed_thing.under}, true)

				return itemstack
			else
				--If there's still no glue, it's good to notify the player of the problem.
				minetest.chat_send_player(user:get_player_name(), "You must have some kind of glue in your inventory to repair nodes with your mallet.")
			end
		end
	})

	--If crafting materials were provided, create a default recipe out of them and the glue group.
	--You can choose not to provide materials for this, but if you don't, you're responsible for distributing the matter yourself.
	if hand_matl and head_matl then
		minetest.register_craft({
			output = prefix..":mallet_"..n,
			recipe = {
				{head_matl, "group:nd_tools_glue", head_matl},
				{"", hand_matl, ""},
				{"", hand_matl, ""}
			}
		})
	end
end



--Mallets for the default ores, scaled to a similar power level but given no other special gimmicks.
if minetest.get_modpath("default") then
	nd_tools.register_mallet("Wood", 15, nil, "group:stick", "group:wood")
	nd_tools.register_mallet("Stone", 25, nil, "group:stick", "group:stone")
	nd_tools.register_mallet("Bronze", 35, nil, "group:stick", "default:bronze_ingot")
	nd_tools.register_mallet("Steel", 35, nil, "group:stick", "default:steel_ingot")
	nd_tools.register_mallet("Mese", 44, nil, "group:stick", "default:mese_crystal")
	nd_tools.register_mallet("Diamond", 50, nil, "group:stick", "default:diamond")
end

--Hardtrees provides its own tier of very weak rock tools. Probably won't ever get made, but oh well.
if minetest.get_modpath("hardtrees") then
	nd_tools.register_mallet("Rock", 8, nil, "group:stick", "hardtrees:rock")
end

--Silver and Mithril are distinct for being slow but having high durability. Speed isn't a factor, so instead it gets decreased efficiency.
if minetest.get_modpath("moreores") then
	nd_tools.register_mallet("Silver", 105, 0.5, "group:stick", "moreores:silver_ingot")
	nd_tools.register_mallet("Mithril", 215, 0.5, "group:stick", "moreores:mithril_ingot")
end

--The rest of these are probably about what you might expect. All three are adjusted according to their general power level.

if minetest.get_modpath("ethereal") then
	nd_tools.register_mallet("Crystal", 60, nil, "default:steel_ingot", "ethereal:crystal_ingot")
end

if minetest.get_modpath("obsidianstuff") then
	nd_tools.register_mallet("Obsidian", 60, nil, "default:obsidian_shard", "obsidianstuff:ingot")
end

if minetest.get_modpath("cloud_items") then
	nd_tools.register_mallet("Cloud", 80, nil, "group:stick", "cloud_items:cloud_ingot")
end
