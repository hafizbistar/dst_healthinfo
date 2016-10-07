------------------------ PART I -------------------------
------------------------ Common -------------------------
--- DS? DST? Host? Dedicated? Who know??
local _G=GLOBAL
local require = GLOBAL.require
local TheNet = _G.rawget(_G,"TheNet")
show_type = _G.tonumber(GetModConfigData("show_type")) or 0
local divider = _G.tonumber(GetModConfigData("divider")) or 0
local ds = {"-","[","(","{","<"} ds=ds[divider] or ""
local de = {"-","]",")","}",">"} de=de[divider] or ""

local random_health_value = (_G.tonumber(GetModConfigData("random_health_value")) or 0) --DST feature
if (random_health_value==0 and show_type==3) or (random_health_value ~= 0 and show_type ~= 0 and show_type ~= 3) then
	print("WARNING: Wrong show type option in Health Info mod. Change your settings of the mod.")
	show_type=0 --fix.
end
if random_health_value ~= 0 then
	VARIATION_PRECENT = " (±"..(random_health_value*100).."%)"
	VARIATION_HP_MIN = _G.tonumber(GetModConfigData("random_range")) or 0 --0.1
	VARIATION_HP_MAX = 1 - VARIATION_HP_MIN --0.9
end

--Removing the info from some places in the game code (only for DST).
local type_patterns = { "%d+%%", "%d+ / [?%d]+ %d+%%", "%d+ %(±%d+%%%)" }; type_patterns[0] = "%d+ / [?%d]+"
local CUT_PATTERN = "^(.*) "..(ds~="" and "%"..ds or "")..tostring(type_patterns[show_type])..(de~="" and "%"..de or "").."$"
--print("Health Info Pattern: "..CUT_PATTERN)

--API Edition
mods=_G.rawget(_G,"mods")or(function()local m={}_G.rawset(_G,"mods",m)return m end)()
if mods.HealthInfo ~= nil then
	print("ERROR: You are trying to enable the mod twice!")
	return --Protection from double enabling.
end
local t = { CUT_PATTERN = CUT_PATTERN, version = modinfo.version, env = env }
mods.HealthInfo = t

local SHOULD_OVERWRITE_ACTION = nil

local DISABLE_HELATHINFO_RECURSIVE = 0 --Must be disabled if > 0

t.AddString = function(name,cur,mx) --cur and mx are float!
	if DISABLE_HELATHINFO_RECURSIVE == 0 and type(name) == "string" then
		if show_type == 0 or mx==-1 then
			name = name.." "..ds..math.floor(cur+0.5).." / "..(mx==-1 and "?" or math.floor(mx+0.5)) ..de -- +0.5 means round fn
		elseif show_type == 1 then
			name = name.." "..ds..math.floor(cur*100/(mx or 1)+0.5).."%"..de
		elseif show_type == 2 then
			name = name.." "..ds..math.floor(cur+0.5).." / "..math.floor(mx+0.5) .." "..math.floor(cur*100/(mx or 1)+0.5).."%"..de
		elseif show_type == 3 then --random value
			name = name.." "..ds..math.floor(cur+0.5)..VARIATION_PRECENT..de
		end
	end
	return name
end


--Small easy tech function for injection
local function InjectFull(comp,fn_name,fn)
	--print("Full Inject: ",tostring(comp),tostring(fn_name),tostring(fn))
	local old_fn = comp[fn_name]
	t["old_"..fn_name] = old_fn --Saving and publishing all old functions. Someone may need it.
	comp[fn_name] = function(self,...)
		local res = old_fn(self,...)
		return fn(res,self,...)
	end
end

local controller = require "components/playercontroller"
InjectFull(controller,"GetLeftMouseAction",function(lmb)
	if not lmb then
		return lmb
	end
	if not(lmb.target and lmb.invobject == nil and lmb.target ~= lmb.doer) then
		--No DisplayName. We should add info in lmb:GetActionString().
		SHOULD_OVERWRITE_ACTION = true
	end
	return lmb
end)

--Clear overwriting info (just for sure)
InjectFull(controller,"GetRightMouseAction",function(res)
	SHOULD_OVERWRITE_ACTION = nil
	return res
end)
InjectFull(controller,"DoAction",function(res)
	SHOULD_OVERWRITE_ACTION = nil
	return res --j
end)

--local b_action = require "bufferedaction"
InjectFull(_G.BufferedAction,"GetActionString",function(str,self)
	if SHOULD_OVERWRITE_ACTION then
		if self.target and DISABLE_HELATHINFO_RECURSIVE == 0 then
			if TheNet ~= nil and self.target.health_info then
				--print("OVERWRITE (TheNet)")
				str = t.AddString(str,self.target.health_info,self.target.health_info_max)
			elseif TheNet == nil and self.target.components.health then
				--print("OVERWRITE (DS)")
				str = t.AddString(str,self.target.components.health.currenthealth,self.target.components.health.maxhealth)
			end
		end
		SHOULD_OVERWRITE_ACTION = nil
	end
	return str
end)


-------------Mini code for DS version------------
if TheNet == nil then
	--print("THIS IS SINGLE DS VERSION")
	InjectFull(_G.EntityScript,"GetDisplayName",function(name,inst)
		local comp = inst.components.health or inst.components.boathealth
		if comp ~= nil then
			name = t.AddString(name,comp.currenthealth,comp.maxhealth)
		end
		return name
	end)

	return --EXIT THE MOD if this is DS version.
end

---------------------------- PART II -----------------------
---------------------------- Only DST ----------------------
-- Client? Server? Who knows?

local IsServer = TheNet:GetIsServer()
local IsDedicated = TheNet:IsDedicated()
--print("IS_SERVER = "..tostring(IsServer))
--print("IS_DEDICATED = "..tostring(IsDedicated))

--Very fast decisions.
modimport "black_white_lists.lua" --Predefined white and black lists for fast speed and high compatibility.

local use_blacklist = GetModConfigData("use_blacklist")
if use_blacklist == "false" then --Fool protection.
	use_blacklist = false
end
local BLACK_FILTER_CACHED = use_blacklist and BLACK_FILTER or {}
local WHITE_FILTER_CACHED = WHITE_FILTER
--[[do
	local cnt = 0
	for k,v in pairs(WHITE_FILTER) do
		WHITE_FILTER_CACHED[k]=v
		cnt=cnt+1
	end
	print("Health Info: black list contains "..cnt.." records.")
end--]]
t.BLACK_FILTER = BLACK_FILTER
t.WHITE_FILTER = WHITE_FILTER
t.BLACK_FILTER_CACHED = BLACK_FILTER_CACHED --sharing tables
t.WHITE_FILTER_CACHED = WHITE_FILTER_CACHED

--API functions for using our cache directly.
--NB! Your mod must be "all_clients_require_mod" if you want to use it without crash!
t.AddToWhiteList = function(prefab)
	WHITE_FILTER_CACHED[prefab] = true
end
t.AddToBlackList = function(prefab)
	BLACK_FILTER_CACHED[prefab] = true
end

--Our cool filters with Black Jack

local unknwon_prefabs = _G.tonumber(GetModConfigData("unknwon_prefabs")) or 0 --ignore by default

local function BlackFilter(inst)
	if not (inst.Network ~= nil and inst.Transform ~= nil) then --and inst.prefab == "spider") then
		--print(inst.prefab.." - now in BLACKLIST")
		return true
	end
	if  (
		inst:HasTag("no_healthinfo") or
		inst:HasTag("yamche") or
		inst.prefab == "balloon"
		)
	then
		return true
	end
end


local function WhiteFilter(inst)
	if inst:HasTag("healthinfo") then
		return true --Always true with Health Info friendly mods.
	end
	if unknwon_prefabs == 0 then --ignore
		return false
	end
	if unknwon_prefabs == 1 then --only players
		return inst:HasTag("player")
	end
	if unknwon_prefabs == 2 then --some creatures
		return inst:HasTag("player") or inst:HasTag("smallcreature") or inst:HasTag("animal") or inst:HasTag("monster")
			or inst:HasTag("largecreature") or inst:HasTag("epic")
	end
	--else unknwon_prefabs == 3 (all known tags)
	if  (
		inst:HasTag("hive") or
		inst:HasTag("eyeturret") or
		inst:HasTag("houndmound") or
		inst:HasTag("ghost") or
		inst:HasTag("insect") or
		inst:HasTag("spider") or
		inst:HasTag("chess") or
		inst:HasTag("mech") or
		--inst:HasTag("mound") or
		inst:HasTag("shadow") or
		--inst:HasTag("tree") or
		--inst:HasTag("veggie") or
		inst:HasTag("shell") or
		inst:HasTag("rocky") or
		inst:HasTag("smallcreature") or
		inst:HasTag("largecreature") or
		inst:HasTag("wall") or
		inst:HasTag("character") or
		inst:HasTag("companion") or
		inst:HasTag("glommer") or
		inst:HasTag("animal") or
		inst:HasTag("monster") or
		inst:HasTag("prey") or
		inst:HasTag("scarytoprey") or
		inst:HasTag("notraptrigger") or
		inst:HasTag("hostile") or
		inst:HasTag("cavedweller") or
		inst:HasTag("epic") or
		inst:HasTag("player")
		) 
		--and not
		--(
			--inst:HasTag("yamche")
			--Do not add here anything. There is "BlackFilter" function.
		--)
	then
		--print(inst.prefab.." - WhiteList")
		return true
	end
end

--New prefabs of the mods will be sent to the web server.
--So it will be added in white list in future.
local send_unknwon_prefabs = GetModConfigData("send_unknwon_prefabs")
if IsServer then
	local server_error_str = "" --Will be send to web server
	local server_error_str_sent = "" --Already sent string
	local save_sent_prefabs = {} --Associative array of sent prefabs
	function AddPrefabErrorString(prefab) --Add prefab to table that will be send later.
		if type(prefab) ~= "string" or save_sent_prefabs[prefab] then
			return
		end
		save_sent_prefabs[prefab] = true
		server_error_str = server_error_str .. (server_error_str ~= "" and "/" or "") .. prefab
	end
	local first_message = true
	function ShowErrorInfo(prefabs) --Show error about prefabs
		--Show info in log only if message did not sent.
		print("----------------- HEALTH INFO WARNING ------------------")
		if (first_message) then print("Please, show this log message to authors of Health Info mod.") end
		print("Unknown Prefabs: "..tostring(prefabs))
		if (first_message) then
			print("The mod should be fixed to support these prefabs.")
			print("Also you can change settings of the Health Info mod to be more useful but less compatible.")
			print('If you are mod developer, you can add the tag "healthinfo" to you prefab:')
			print('inst:AddTag("healthinfo")')
			print('Add tags before this line: inst.entity:SetPristine()')
			print('Thanks!')
			print("--------------------------------------------------------")
		end
		--print("--------------------------------------------------------")
		first_message = false
	end
	if send_unknwon_prefabs then
		local function SendStringToAuthors(s) --Send a string to the web server
			_G.TheSim:QueryServer("http://dst-translations.1gb.ru/unknown_prefabs.php?"..s, function(result, isSuccessful, resultCode)
				if not (isSuccessful and resultCode == 200 and type(result) == "string") then
					ShowErrorInfo(s)
				end
			end)
		end
		local function SendStringToAuthorsPeriodic(inst) --(inst is world) Periodic check if we should send new data.
			if server_error_str == "" then
				return
			end
			SendStringToAuthors(server_error_str)
			server_error_str = ""
		end
		AddPrefabPostInit("world",function(inst)
			inst.health_info_task = inst:DoPeriodicTask(30.17 + math.random(),SendStringToAuthorsPeriodic,10)
		end)
	end
end

--We need to decide to add or not to add health_info net variable BEFORE initialization.
--TRUE if we need health_info.
local function CheckInstHasHealth(inst)
	--Check for cached tables.
	if BLACK_FILTER_CACHED[inst.prefab] ~= nil then
		--print("already in black list")
		return
	end
	if WHITE_FILTER_CACHED[inst.prefab] ~= nil then
		return true
	end
	--Try to analyse via our cool filters.
	if BlackFilter(inst) then
		BLACK_FILTER_CACHED[inst.prefab] = true
		return
	end
	if WhiteFilter(inst) then
		WHITE_FILTER_CACHED[inst.prefab] = true
		return true
	end
	--All filter are passed without any result! That's too bad!
	--Decision for ALL unknown prefabs:
	--print("DEFAULT DECISION: "..inst.prefab.." - BLACK LIST")
	BLACK_FILTER_CACHED[inst.prefab] = true
	--Test health component.
	if inst.components.health or inst.components.boathealth then --ERROR! Can't synchronize it without updating the mod!
		if send_unknwon_prefabs then
			AddPrefabErrorString(inst.prefab)
		else
			ShowErrorInfo(inst.prefab)
		end
	end
end

--Two dirty client functions
--local random_health_value = (_G.tonumber(GetModConfigData("random_health_value")) or 0) --should be a number
local GetRandomMinMax = _G.GetRandomMinMax
local function OnHealthInfoDirty(inst)
	--print("----- OnHealthInfoDirty ["..inst.prefab.."] -----")
    inst.health_info_exact = inst.net_health_info:value()
	if random_health_value == 0 or inst.health_info_max_exact <= 0 then
		--print("SET EXACT(1): ",random_health_value,inst.health_info_max_exact)
		inst.health_info = inst.health_info_exact
		return
	end
	local hp_max = VARIATION_HP_MAX * inst.health_info_max_exact
	local hp_min = VARIATION_HP_MIN * inst.health_info_max_exact
	if inst.health_info_exact >= hp_max or inst.health_info_exact <= hp_min then
		--print("SET EXACT(2): ",random_health_value,inst.health_info_max_exact,hp_min,hp_max)
		inst.health_info = inst.health_info_exact
		return
	end
	--print("Check task")
	if inst.health_info_wait_task == nil then
		inst.health_info = GetRandomMinMax(inst.health_info_exact * (1-random_health_value), inst.health_info_exact * (1+random_health_value))
		inst.health_info_shown = inst.health_info_exact
		--print("Set task", inst.health_info, inst.health_info_exact)
		inst.health_info_wait_task = inst:DoTaskInTime(3,function(inst) --Can't change health while timer is running.
			inst.health_info_wait_task = nil
			--print("Run task", inst.health_info, inst.health_info_exact)
			if inst.health_info_shown ~= inst.health_info_exact then
				--print("...recursive...")
				OnHealthInfoDirty(inst) --recursive
			end
		end)
	end
end
function OnHealthInfoMaxDirty(inst)
	local old = inst.health_info_max_exact
	inst.health_info_max_exact = inst.net_health_info_max:value()
    inst.health_info_max = random_health_value ~= 0 and show_type == 0 and -1 or inst.health_info_max_exact
	if old == 0 and show_type == 3 and inst.health_info_max_exact > 0 and inst.health_info_exact ~= 0 then
		--print("...Call from max:")
		OnHealthInfoDirty(inst)
	end
end

--[[
local function debug_log(inst,mess)
	if inst.prefab == "rabbit" then
		print(inst.prefab,mess)
	end
end
--]]
local TheWorld = _G.TheWorld
if _G.TheNet.GetIsMasterSimulation then
	_G.getmetatable(_G.TheNet).__index.GetIsMasterSimulation = (function()
		local oldObj = _G.getmetatable(_G.TheNet).__index.GetIsMasterSimulation
		return function(... )
			TheWorld = _G.TheWorld
			return oldObj(...)
		end
	end)()
end
AddPrefabPostInit("world",function(inst)
	TheWorld = inst
end)

local boss32bit = { toadstool = true, dragonfly = true,} --Prefabs with over 65535 hp.

--Initialization of all prefabs.
local net_uint,net_ushortint = _G.net_uint,_G.net_ushortint
AddPrefabPostInitAny(function(inst)
	--print("NEW PREFAB - ",inst)
	--print("already in white list")
	if CheckInstHasHealth(inst) == nil then
		--debug_log(inst,"Bad prefab")
		return --Do not add health_info!
	end
	inst.health_info = 0
	inst.health_info_max = 0 --should be exact 0 because we will check it later if it's not zero.
	if boss32bit[inst.prefab] then --32bit. Max 4kkk hp.
		inst.net_health_info = net_uint(inst.GUID, "health_info", "health_info_dirty")
		inst.net_health_info_max = net_uint(inst.GUID, "health_info_max", "health_info_max_dirty")
	else --16bit. Maximum of 65535 health.
		inst.net_health_info = net_ushortint(inst.GUID, "health_info", "health_info_dirty")
		inst.net_health_info_max = net_ushortint(inst.GUID, "health_info_max", "health_info_max_dirty")
	end
	inst.health_info_max_exact = 0 --unknown for special options
	if not IsDedicated then
		--Means client OR host.
		--debug_log(inst,"not dedicated")
		inst:ListenForEvent("health_info_dirty", OnHealthInfoDirty)
		inst:ListenForEvent("health_info_max_dirty", OnHealthInfoMaxDirty)
	end
	if not TheWorld.ismastersim then
		--Means only client.
		--debug_log(inst,"ismastersim, return")
		return
	end
	--Only server code...
	if inst.components.health then
		--debug_log(inst,"has health "..tostring(inst.components.health.currenthealth).." "..tostring(inst.components.health.maxhealth))
		inst.net_health_info:set(inst.components.health.currenthealth)
		inst.net_health_info_max:set(inst.components.health.maxhealth)
	end
end)

--Inject in DisplayName function
if not IsDedicated then --also for host
	InjectFull(_G.EntityScript,"GetDisplayName",function(name,self)
		if self.health_info_max ~= nil and self.health_info_max ~= 0
			and not self:HasTag("playerghost") and DISABLE_HELATHINFO_RECURSIVE == 0
		then
			name = t.AddString(name,self.health_info,self.health_info_max)
		end
		return name
	end)
end

-----Only Server Side -----
if not IsServer then
	return
end

--------------------------------- PART III ------------------------------
------------------------- Only Server Side code -------------------------


local health = require "components/health"
InjectFull(health,"SetCurrentHealth",function(aaa,self)
	--print("Set health = "..tostring(self.currenthealth))
	if self.inst.health_info ~= nil then
		self.inst.net_health_info:set(self.currenthealth)
	end
end)
InjectFull(health,"SetMaxHealth",function(aaa,self)
	if self.inst.health_info ~= nil then
		self.inst.net_health_info:set(self.currenthealth)
		self.inst.net_health_info_max:set(self.maxhealth)
	end
end)
InjectFull(health,"DoDelta",function(aaa,self)
	if self.inst.health_info ~= nil then
		self.inst.net_health_info:set(self.currenthealth)
	end
end)

InjectFull(health,"OnRemoveFromEntity",function(aaa,self)
	if self.inst.health_info ~= nil then --Reset health to zero. (Health is removed)
		self.inst.net_health_info_max:set(0)
		--self.inst.health_info_max = 0 --Это не нужно. Хост посылает инфу самому себе.
	end
end)

if IsDedicated then
	return
end

--------------------------------- PART IV ------------------------------
------------------ Only HOST Side code (not dedicated!)-----------------
-- On dedicated server DisplayName inject is disable. So there is no need of preventing that function.

--We want to get white list and black list from the game.
--[[
AddPrefabPostInit("world",function(inst)
	inst:DoTaskInTime(5,function(inst)
		local a,b,c = {},{},{}
		for k,v in pairs(_G.Prefabs) do
			if k and v.fn and k~="world" and k~="forest" and k~="cave" and k~="shard_network" and not BLACK_FILTER[k]
				and k~="world_network" and k~="cave_network" and k~="maxwellthrone"
			then
				local pr = _G.SpawnPrefab(k)
				if pr then
					if pr.components and pr.components.health then
						a[k]=true
					else
						b[k]=true
					end
				else
					print("ERROR: Can't spawn \""..k..'"')
				end
				table.insert(c,pr)
			end
		end
		_G.rawset(_G,"a",a) --health
		_G.rawset(_G,"b",b) --no health
		_G.rawset(_G,"c",c)
		_G.arr({a,b})
	end)
end)
--]]


--Removing health data from game interface

--Skeleton info
AddPrefabPostInit("skeleton_player",function(inst)
	local old_fn = inst.SetSkeletonDescription
	inst.SetSkeletonDescription = function(inst, prefab, name, cause, pkname, ...)
		name = type(name)=="string" and name:match(CUT_PATTERN) or name
		pkname = type(pkname)=="string" and pkname:match(CUT_PATTERN) or pkname
		return old_fn(inst, prefab, name, cause, pkname, ...)
	end
end)

--Fixing global functions

local old_GetNewDeath = _G.rawget(_G,"GetNewDeathAnnouncementString")
if old_GetNewDeath then
	_G.GetNewDeathAnnouncementString = function(theDead, source, pkname, ...)
		pkname = type(pkname)=="string" and pkname:match(CUT_PATTERN) or pkname
		DISABLE_HELATHINFO_RECURSIVE = DISABLE_HELATHINFO_RECURSIVE + 1
		local message = old_GetNewDeath(theDead, source, pkname, ...)
		DISABLE_HELATHINFO_RECURSIVE = DISABLE_HELATHINFO_RECURSIVE - 1
		return message
	end
end

local old_GetNewRez = _G.rawget(_G,"GetNewRezAnnouncementString")
if old_GetNewRez then
	_G.GetNewRezAnnouncementString = function(theRezzed, source, ...)
		source = type(source)=="string" and source:match(CUT_PATTERN) or source
		DISABLE_HELATHINFO_RECURSIVE = DISABLE_HELATHINFO_RECURSIVE + 1
		local message = old_GetNewRez(theRezzed, source, ...)
		DISABLE_HELATHINFO_RECURSIVE = DISABLE_HELATHINFO_RECURSIVE - 1
		return message
	end
end







