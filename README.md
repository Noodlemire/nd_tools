-------------------------------------------------------------------------------------------------------------
Tools Using the Node Damage and Repair System
[nd_tools]
-------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------
About
-------------------------------------------------------------------------------------------------------------
This is a mod that takes the node_damage API and applies it to every item in the game, effectively replacing the usual digging interactions. The actual digging times should be about the same, but you get long-lasting node damage, which must be manually repaired or replaced if something important (like a house wall) gets damaged.

To help in repairing, you can make a variety of "mallets" with support from a wide variety of mods that add ores. Mallets work like any usual tool, except instead of breaking blocks, they repair them. However, mallets also need you to have glue in your inventory to work. This mod can either add its own glue or rely on Mesecon's glue if it exists, and each piece of glue allows to 9 repairs to be done.

An api.txt file is provided if you wish to work with this system or make new mallets in your own mod.

-------------------------------------------------------------------------------------------------------------
Dependencies and Support
-------------------------------------------------------------------------------------------------------------
Required mods:
* node\_damage: https://content.minetest.net/packages/Noodlemire/node_damage/
* controls: https://github.com/mt-mods/controls (This fork is necessary for updated support)

Optional mods:
* cloud_items
* default
* ethereal
* hardtrees
* mesecons_materials
* moreores

-------------------------------------------------------------------------------------------------------------
License
-------------------------------------------------------------------------------------------------------------
The LGPL v2.1 License is used with this mod. See https://www.gnu.org/licenses/old-licenses/lgpl-2.1.en.html or LICENSE.txt for more details.

-------------------------------------------------------------------------------------------------------------
Installation
-------------------------------------------------------------------------------------------------------------
Download, unzip, and place within the usual minetest/current/mods folder, and it will behave in relation to the Minetest engine like any other mod. However, the first time its loaded, it won't do anything until the world is reloaded once. The reload is necessary so this mod can query all of the nodes that will exist in this world, which is necessary to automatically register cracked versions of them regardless of mod load order. This process will need repeating if any new mods are installed after this one.
