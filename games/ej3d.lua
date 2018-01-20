if type(ScriptHawk) ~= "table" then 
	print("This script is not designed to run by itself");
	print("Please run ScriptHawk.lua from the parent directory instead");
	print("Thanks for using ScriptHawk :)");
	return;
end

local Game = {};

--------------------
-- Region/Version --
--------------------

-- 1 USA, 2 EU, 
Game.Memory = {
	["jim_pointer"] = {0x0C6810, 0x0C8670}, 
	["current_map"] = {0x0E9EF9, 0x0EBD59},
	["destination_map"] = {0x0E03E7, 0x0E2247},
	["destination_exit"] = {0x0E03E9, 0x0E2249},
	["subhub_entrance_cs"] = {0x0C624A, nil},
	--["controller_input"] = {0x0D4134, 0x0D5F94},
	["reload_map"] = {0x0E03E2,0x0E2242},
};

function Game.detectVersion(romName, romHash) 
	if romHash == "EAB14F23640CD6148D4888902CDCC00DD6111BF9" then -- US
		version = 1; 
	elseif romHash == "F02C1AFD18C1CBE309472CBE5B3B3F04B22DB7EE" then -- Europe
		version = 2;
	else
		return false;
	end

	return true;
end

--------------------
-- Jim Parameters --
--------------------

jim = {
	["y_rotation_1"] = 0x000; -- Float
	["y_rotation_2"] = 0x008; -- Float
	["x_position"] = 0x030; -- Float
	["y_position"] = 0x034; -- Float 
	["z_position"] = 0x038; -- Float
	["bagpipe_lock"] = 0x0C0; -- Byte
	["animation_timer"] = 0x0CA; -- 2 Byte
	["control_type"] = 0x0F4; -- 4 Byte (0 = Normal, 2 = Boss Fights, 4 = Void Process)
	["Health"] = 0x0FC; -- 4 Byte
	["Lives"] = 0x100; -- 4 Byte
	["gun_pointer"] = 0x104;
	["animation"] = 0x0C9; -- Byte
	["cutscene_lock"] = 0x2A3; -- Byte
	--["speed"] = 0x2C8; -- Float (Not too sure on this)
	["y_last_action"] = 0x338; -- Float
	["oob_timer"] = 0x455; -- Byte
	["first_person_angle_delta"] = 0x4D8; -- Float, Radians?
	["character_mode"] = 0x5B0; -- Byte (0 = Jim, 1+ = Kim)
}

--------------------
-- Gun Parameters --
--------------------

gun = {
	["red_gun"] = 0x000;
	["bubble_gun"] = 0x018;
	["rockets"] = 0x030;
	["flamethrower"] = 0x048;
	["bananamyte"] = 0x060;
	["laser"] = 0x078;
	["pea"] = 0x090;
	["egg"]	= 0x0A8;
	["fakegun"] = 0x0C0;
	["magnum"] = 0x0D8;
	["disco"] = 0x0F0;
	["knife"] = 0x108;
	["leprechaun"] = 0x120;
}

-------------------
-- Physics/Scale --
-------------------

Game.speedy_speeds = {.001, .01, .1, .5, 1, 2, 5, 10, 20 };
Game.speedy_index = 7;
Game.speedy_invert_LR = 1;

function Game.isPhysicsFrame()
	return not emu.islagged();
end

--------------
-- Position --
--------------

function Game.getXPosition()
	return mainmemory.readfloat(Game.Memory.jim_pointer[version] + jim.x_position, true);
end

function Game.getYPosition()
	return mainmemory.readfloat(Game.Memory.jim_pointer[version] + jim.y_position, true);
end

function Game.getZPosition()
	return mainmemory.readfloat(Game.Memory.jim_pointer[version] + jim.z_position, true);
end

function Game.setXPosition(value)
	mainmemory.writefloat(Game.Memory.jim_pointer[version] + jim.x_position, value, true);
end

function Game.setYPosition(value)
	mainmemory.writefloat(Game.Memory.jim_pointer[version] + jim.y_position, value, true);
end

function Game.setZPosition(value)
	mainmemory.writefloat(Game.Memory.jim_pointer[version] + jim.z_position, value, true);
end

--------------
-- Rotation --
--------------

Game.rot_speed = 10;
Game.max_rot_units = 360;

-- Rotation units can be fiddly sometimes.
-- These functions can return any number as long as it's consistent between get & set.
-- If the Game.max_rot_units value is correct (and minimum is 0) ScriptHawk will correctly convert in game units to both degrees (default) and radians

function Game.getXRotation() -- Optional
	return mainmemory.readfloat(Game.Memory.x_rotation[version], true);
end

function Game.getYRotation() -- Optional
	angle_1 = 90 * (mainmemory.readfloat(Game.Memory.jim_pointer[version] + jim.y_rotation_1, true) + 1);
	angle_2 = mainmemory.readfloat(Game.Memory.jim_pointer[version] + jim.y_rotation_2, true);
	
	if angle_2 < 0 then
		angle = (angle_1 * (0 - 1)) - 90;
	else
		angle = (angle_1 - 90);
	end
	
	return angle;
end

function Game.getZRotation()
	return mainmemory.readfloat(Game.Memory.z_rotation[version], true);
end

function Game.setXRotation(value)
	mainmemory.writefloat(Game.Memory.x_rotation[version], value, true);
end

function Game.setYRotation(value)
	mainmemory.writefloat(Game.Memory.y_rotation[version], value / 180, true);
end

function Game.setZRotation(value)
	mainmemory.writefloat(Game.Memory.z_rotation[version], value, true);
end

------------
-- Events --
------------

Game.maps = {
	"The Brain",
	"Memory Hub",
	"Coop D'Etat",
	"Barn to be Wild",
	"Psycrow",
	"Happiness Hub",
	"Lord to the Fries",
	"Are you Hungry Tonite?",
	"Fatty Roswell",
	"Fear Hub",
	"Mansion Lobby",
	"Poultrygeist",
	"Poultrygeist Too",
	"Death Wormed Up",
	"Boogie Nights of the Living Dead",
	"Professor Monkey for a Head",
	"Fantasy Hub",
	"Violent Death Valley",
	"The Good, The Bad and The Elderly",
	"Bob and Number Four",
	"Earthworm Kim",
	"Main Menu",
};

Game.animations = {
	[0] = "Walking",
	[1] = "Running",
	[2] = "Preparing to Run",
	[3] = "Idle",
	[4] = "Creeping",
	[5] = "Stopping",
	[6] = "Jumping",
	[7] = "Holding Gun",
	[8] = "Firing",
	[9] = "Grabbing Gun",
	-- [10] = "Wielding Gun", -- Not used?
	[11] = "Idle", -- Rope
	[12] = "Moving", -- Rope
	[13] = "Holding Gun", -- Rope
	[14] = "Firing", -- Rope
	[15] = "Grabbing Gun", -- Rope
	[16] = "Retracting Gun", -- Rope
	[17] = "Surfing", -- Pork Boarding, No Earthworm Turning
	[18] = "Surfing", -- Pork Boarding, Earthworm Turning 
	[19] = "Grabbing Ledge",
	[20] = "Damage", -- Laser Guns, Fall Damage
	[21] = "Damage", -- Knockback
	[22] = "Death",
	[23] = "Idle", -- Pulling Head
	[24] = "Breaking Wind",
	[25] = "Crouching/Rolling",
	[26] = "Udder Dance",
	[27] = "Whipping",
	[28] = "Whipping", -- Jumping
	[29] = "Floating", -- Spin Move in Air
	[30] = "Damage", -- Acid Bats
	[31] = "Dodging", -- Rope
	[32] = "Damage", -- Rope
	[33] = "Drowning",
	[34] = "Inflating", -- Balloon
	[35] = "Floating", -- Balloon
	[36] = "Ego Boost", -- Pork Boarding
	[37] = "Damage", -- Pork Boarding
	[38] = "Jumping", -- Pork Boarding
	[39] = "Bagpipes", -- Opening new hub
	[40] = "Prancing", -- Main Menu Pre/Post-Accordion
	[41] = "Playing", -- Main Menu Accordion
	[42] = "Falling", -- Main Menu Post Cows
	[43] = "Locked", -- Textbox
}

Game.takeMeThereType = "Checkbox"; 

function Game.setMap(index)
	mainmemory.writebyte(Game.Memory.destination_map[version], index - 1);
end

function Game.checkMapSoftlock()
	dest_exit = mainmemory.readbyte(Game.Memory.destination_exit[version]);
	dest_map = mainmemory.readbyte(Game.Memory.destination_map[version]);
	
	if dest_map == 1 or dest_map == 5 or dest_map == 9 or dest_map == 16 then -- Sub Hubs (Central Column Fix)
		if dest_exit > 0 and dest_exit < 4 then -- Coming from Boss/Level
			mainmemory.writebyte(Game.Memory.subhub_entrance_cs[version], 0);
		else -- Coming from 'The Brain'
			mainmemory.writebyte(Game.Memory.subhub_entrance_cs[version], 1);
		end 
	end
end

function Game.reloadMap()
	mainmemory.writebyte(Game.Memory.reload_map[version], 1);
	Game.checkMapSoftlock()
end

function Game.reloadMapHard()
	mainmemory.writebyte(Game.Memory.current_map[version], 255);
	Game.reloadMap()
end

function Game.getMapOSD()
	local currentMap = mainmemory.readbyte(Game.Memory.current_map[version]);
	local currentMapName = "Unknown";
	if Game.maps[currentMap + 1] ~= nil then
		currentMapName = Game.maps[currentMap + 1];
	end
	return currentMapName.." ("..currentMap..")";

end

function Game.setExit(index)
	mainmemory.writebyte(Game.Memory.destination_exit[version]);
end

function Game.getExitOSD()
	local currentExit = mainmemory.readbyte(Game.Memory.destination_exit[version]);
	return currentExit;
end

function Game.getAnimationOSD()
	local currentAnimation = mainmemory.readbyte(Game.Memory.jim_pointer[version] + jim.animation);
	local currentAnimationName = "Unknown ("..currentAnimation..")";
	if Game.animations[currentAnimation] ~= nil then
		currentAnimationName = Game.animations[currentAnimation];
	end
	return currentAnimationName;
end

function Game.getAnimationTimerOSD()
	local anim_timer = mainmemory.read_u16_be(Game.Memory.jim_pointer[version] + jim.animation_timer);
	return anim_timer;
end
	
function Game.applyInfinites()
	max_ammo_red_gun = 250;
	max_ammo_bubble_gun = 50;
	max_ammo_rockets = 25;
	max_ammo_flamethrower = 50;
	max_ammo_bananamyte = 1;
	max_ammo_laser = 6;
	max_ammo_pea = 50;
	max_ammo_egg = 25;
	max_ammo_fakegun = 0;
	max_ammo_magnum = 50;
	max_ammo_disco = 6;
	max_ammo_knife = 1;
	max_ammo_leprechaun = 5;
	max_lives = 3;
	max_health = 100;
	
	-------------------
	-- Set Infinites --
	-------------------
	
	-- Lives
	mainmemory.write_u32_be(Game.Memory.jim_pointer[version] + jim.Lives, max_lives);
	-- Health
	mainmemory.write_u32_be(Game.Memory.jim_pointer[version] + jim.Health, max_health);
	-- Red Gun
	mainmemory.write_u32_be(Game.Memory.jim_pointer[version] + jim.gun_pointer + gun.red_gun, max_ammo_red_gun);
	-- Bubble Gun
	mainmemory.write_u32_be(Game.Memory.jim_pointer[version] + jim.gun_pointer + gun.bubble_gun, max_ammo_bubble_gun);
	-- Rocket Launcher
	mainmemory.write_u32_be(Game.Memory.jim_pointer[version] + jim.gun_pointer + gun.rockets, max_ammo_rockets);
	-- Flamethrower
	mainmemory.write_u32_be(Game.Memory.jim_pointer[version] + jim.gun_pointer + gun.flamethrower, max_ammo_flamethrower);
	-- Bananamyte
	mainmemory.write_u32_be(Game.Memory.jim_pointer[version] + jim.gun_pointer + gun.bananamyte, max_ammo_bananamyte);
	-- Laser Gun
	mainmemory.write_u32_be(Game.Memory.jim_pointer[version] + jim.gun_pointer + gun.laser, max_ammo_laser);
	-- Pea Shooter
	mainmemory.write_u32_be(Game.Memory.jim_pointer[version] + jim.gun_pointer + gun.pea, max_ammo_pea);
	-- Egg Shooter
	mainmemory.write_u32_be(Game.Memory.jim_pointer[version] + jim.gun_pointer + gun.egg, max_ammo_egg);
	-- Fake unused gun
	mainmemory.write_u32_be(Game.Memory.jim_pointer[version] + jim.gun_pointer + gun.fakegun, max_ammo_fakegun);
	-- Magnum Gun
	mainmemory.write_u32_be(Game.Memory.jim_pointer[version] + jim.gun_pointer + gun.magnum, max_ammo_magnum);
	-- Disco Gun
	mainmemory.write_u32_be(Game.Memory.jim_pointer[version] + jim.gun_pointer + gun.disco, max_ammo_disco);
	-- Knife Boomerang
	mainmemory.write_u32_be(Game.Memory.jim_pointer[version] + jim.gun_pointer + gun.knife, max_ammo_knife);
	-- Leprechaun Launcher
	mainmemory.write_u32_be(Game.Memory.jim_pointer[version] + jim.gun_pointer + gun.leprechaun, max_ammo_leprechaun);
	
end

--function Game.killBoss()
--	mainmemory.writebyte(Game.Memory.boss_death_view[version],1);
--	mainmemory.writebyte(Game.Memory.boss_death_stage[version],1);
--end

------------------------------
-- Fix Controller Input Bug --
------------------------------

--function Game.fixInputBug()
	--joystick_x_input = mainmemory.readbyte(Game.Memory.controller_input[version] + 0x2);
	--if joystick_x_input == 127 then
	--	mainmemory.writebyte(Game.Memory.controller_input[version] + 0x2, 126);
	--end
	
--	joystick_x_input = mainmemory.readbyte(Game.Memory.controller_input[version] + 0x2);
--	if joystick_x_input == 127 then
--		joypad.setanalog({["P1 X Axis"] = 126})
--	end
--end

----------------
-- Flag Stuff --
----------------
Game.flagBlock = {
--  BRAIN
	["brain_udder_first"] = {0x0C6294,nil},
	["brain_unlock_kim"] = {0x2772A0,nil},
--  COOP D'ETAT
	["cde_udder_fridge"] = {0x0C627A,nil},
	["cde_udder_pants"] = {0x0C627B,nil},
	["cde_udder_chicken"] = {0x0C627C,nil},
--  BARN TO BE WILD
	["btbw_udder_quicksand"] = {nil,nil},
	["btbw_udder_barndoor"] = {nil,nil},
	["btbw_udder_crow"] = {nil,nil},
	["btbw_udder_jail"] = {nil,nil},
	["btbw_udder_obstacle"] = {nil,nil},
	["btbw_udder_balloon"] = {nil,nil},
	["btbw_udder_camera"] = {nil,nil},
--  PSYCROW
	["psy_udder_completion"] = {nil,nil},
--  LORD OF THE FRIES

--  ARE YOU HUNGRY TONITE?
	["ayht_udder_bean"] = {0x37BAF8,nil},
--  FATTY Roswell

--  POULTRYGEIST 
	["poultone_udder_beaver"] = {0x310010,nil},
	["poultone_udder_furniture"] = {0x310020,nil},
	["poultone_udder_hoover"] = {0x310028,nil},
--  POULTRYGEIST TOO
	
--  DEATH WORMED UP
	["dwu_udder_graves"] = {0x0C625B,nil},
	["dwu_udder_swamp"] = {0x0C625D,nil},
	["dwu_udder_balloon"] = {0x0C6260,nil},
--  BOOGIE NIGHTS OF THE LIVING DEAD 

--  PROFESSOR MONKEY FOR A HEAD

--  VIOLENT DEATH VALLEY

--  THE GOOD, THE BAD AND THE ELDERLY

--  BOB AND NUMBER Four

--  EARTHWORM KIM

}

local labelValue = 0;
function Game.initUI()
	ScriptHawk.UI.form_controls["Reload Map (Soft)"] = forms.button(ScriptHawk.UI.options_form, "Reload Map", Game.reloadMap, ScriptHawk.UI.col(5), ScriptHawk.UI.row(4), ScriptHawk.UI.col(4) + 10, ScriptHawk.UI.button_height);
	ScriptHawk.UI.form_controls["Reload Map (Hard)"] = forms.button(ScriptHawk.UI.options_form, "Hard Reload", Game.reloadMapHard, ScriptHawk.UI.col(10), ScriptHawk.UI.row(0), ScriptHawk.UI.col(4) + 10, ScriptHawk.UI.button_height);
end

function Game.drawUI()
	
end

function Game.eachFrame() 
	
end

function Game.realTime()
--	if forms.ischecked(ScriptHawk.UI.form_controls["Fix Input Bug"]) then
--		Game.fixInputBug();
--	end
end

Game.OSDPosition = {2, 70};
Game.OSD = {
	{"Map", Game.getMapOSD},
	{"Exit", Game.getExitOSD},
	{"Separator", 1},
	{"X", Game.getXPosition},
	{"Y", Game.getYPosition},
	{"Z", Game.getZPosition},
	{"Separator", 1},
	{"dY"},
	{"dXZ"},
	{"Separator", 1},
	{"Max dY"},
	{"Max dXZ"},
	{"Odometer"},
	{"Separator", 1},
	--{"Rot. X", Game.getXRotation},
	{"Animation", Game.getAnimationOSD},
	{"Animation Timer", Game.getAnimationTimerOSD},
	{"Facing", Game.getYRotation},
	--{"Rot. Z", Game.getZRotation},
};

return Game;