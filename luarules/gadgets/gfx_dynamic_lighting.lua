-- NOTES:
--   games that rely on custom model shaders are SOL
--
--   for projectile lights, ttl values are arbitrarily
--   large to make the lights survive until projectiles
--   die (see ProjectileDestroyed() for the reason why)
--
--   for "propelled" projectiles (rockets/missiles/etc)
--   ttls should be the actual ttl-values so attached
--   lights die when their "engine" cuts out, but this
--   gets complex (eg. flighttime is not available)
--
--   Explosion() occurs before ProjectileDestroyed(),
--   so for best effect maxDynamic{Map, Model}Lights
--   should be >= 2 (so there is "always" room to add
--   the explosion light while a projectile light has
--   not yet been removed)
--   we work around this by giving explosion lights a
--   (slighly) higher priority than the corresponding
--   projectile lights
local allDynLightDefs = include("LuaRules/Configs/gfx_dynamic_lighting_defs.lua")
local modDynLightDefs = allDynLightDefs[Game.modShortName] or {}
local weaponLightDefs = modDynLightDefs.weaponLightDefs or {}
local Echo = Spring.Echo


if (gadgetHandler:IsSyncedCode()) then
	local SpringGetProjectileDefID = Spring.GetProjectileDefID

	local projectileLightDefs = {}
	local explosionLightDefs = {}
	local GetGroundHeight = Spring.GetGroundHeight
	
	local nukeWeapons = {
		[WeaponDefNames["nuclear_missile"].id] = true
	}
			
	function gadget:GetInfo()
		return { 		
			-- put this gadget in a lower layer than fx_watersplash and exp_no_air_nuke
			-- (which both want noGFX) so the short-circuit evaluation in gh:Explosion()
			-- does not cut us out
			enabled = true,
			layer = -1,
	 	}
 	end

	-- register/deregister for the synced Projectile*/Explosion call-ins
	function gadget:Initialize()
		local modOptions = Spring.GetModOptions()
		if (modOptions ~= nil and (modOptions.lowcpu == "1" or modOptions.dynamiclights == "0")) then
			gadgetHandler:RemoveGadget(self)
			return
		end

		for weaponDefName, weaponLightDef in pairs(weaponLightDefs) do
			local weaponDef = WeaponDefNames[weaponDefName]
			if (weaponDef ~= nil) then
				projectileLightDefs[weaponDef.id] = weaponLightDef.projectileLightDef or false
				explosionLightDefs[weaponDef.id] = weaponLightDef.explosionLightDef or false
				Script.SetWatchWeapon(weaponDef.id, true)
			end
		end
	end
	function gadget:Shutdown()
		for weaponDefName, _ in pairs(weaponLightDefs) do
			local weaponDef = WeaponDefNames[weaponDefName]

			if (weaponDef ~= nil) then
				Script.SetWatchWeapon(weaponDef.id, false)
			end
		end
	end

	-- if other gadgets set watching of weapons that don't use dynamic lighting, we're sending
	-- too many calls to unsynced part, therefore, check if the projectile has a dynamic light
	function gadget:ProjectileCreated(projectileID, projectileOwnerID, projectileWeaponDefID)
		if (projectileLightDefs[projectileWeaponDefID]) then
			SendToUnsynced("DL_ProjectileCreated", projectileID, projectileOwnerID, projectileWeaponDefID)
		end
	end

	function gadget:ProjectileDestroyed(projectileID)
		-- returns weaponDefID for weapon-projectiles, nil otherwise
		
		local pDefID = SpringGetProjectileDefID(projectileID)
		
		if (projectileLightDefs[pDefID] ~= nil) then
			SendToUnsynced("DL_ProjectileDestroyed", projectileID)
		end
	end

	function gadget:Explosion(weaponDefID, posx, posy, posz, ownerID)
		if (explosionLightDefs[weaponDefID]) then 
			if (not nukeWeapons[weaponDefID]) or (posy-GetGroundHeight(posx,posz) < 100)  then -- dont show if nuke explodes in air
				SendToUnsynced("DL_ProjectileExplosion", weaponDefID, posx, posy, posz)
			end
		end
		return false
	end


else
	function gadget:GetInfo()
		return {
			name    = "gfx_dynamic_lighting.lua",
			desc    = "dynamic lighting in the Spring RTS engine",
			author  = "Kloot",
			date    = "January 15, 2011",
			license = "GPL v2",
			enabled = true,
		}
	end

	local projectileLightDefs = {} -- indexed by unitDefID
	local explosionLightDefs = {} -- indexed by weaponDefID
	local projectileLights = {} -- indexed by projectileID
	local explosionLights = {} -- indexed by "explosionID"

	local unsyncedEventHandlers = {}

	local SpringGetProjectilePosition      = Spring.GetProjectilePosition
	local SpringAddMapLight                = Spring.AddMapLight
	local SpringAddModelLight              = Spring.AddModelLight
	local SpringSetMapLightTrackingState   = Spring.SetMapLightTrackingState
	local SpringSetModelLightTrackingState = Spring.SetModelLightTrackingState
	local SpringUpdateMapLight             = Spring.UpdateMapLight
	local SpringUpdateModelLight           = Spring.UpdateModelLight


	local function LoadLightDefs()
		-- type(v) := {[1] = number, [2] = number, [3] = number}
		-- type(s) := number
		local function vector_scalar_add(v, s) return {v[1] + s, v[2] + s, v[3] + s} end
		local function vector_scalar_mul(v, s) return {v[1] * s, v[2] * s, v[3] * s} end
		local function vector_scalar_div(v, s) return {v[1] / s, v[2] / s, v[3] / s} end

		for weaponDefName, weaponLightDef in pairs(weaponLightDefs) do
			local weaponDef = WeaponDefNames[weaponDefName]
			local projectileLightDef = weaponLightDef.projectileLightDef
			local explosionLightDef = weaponLightDef.explosionLightDef

			if (weaponDef ~= nil) then
				projectileLightDefs[weaponDef.id] = projectileLightDef
				explosionLightDefs[weaponDef.id] = explosionLightDef

				-- NOTE: these rates are not sensible if the decay-type is exponential
				if (projectileLightDef ~= nil and projectileLightDef.decayFunctionType ~= nil) then
					projectileLightDefs[weaponDef.id].ambientDecayRate  = vector_scalar_div(projectileLightDef.ambientColor or {0.0, 0.0, 0.0}, projectileLightDef.ttl or 1.0)
					projectileLightDefs[weaponDef.id].diffuseDecayRate  = vector_scalar_div(projectileLightDef.diffuseColor or {0.0, 0.0, 0.0}, projectileLightDef.ttl or 1.0)
					projectileLightDefs[weaponDef.id].specularDecayRate = vector_scalar_div(projectileLightDef.specularColor or {0.0, 0.0, 0.0}, projectileLightDef.ttl or 1.0)
				end

				if (explosionLightDef ~= nil and explosionLightDef.decayFunctionType ~= nil) then
					explosionLightDefs[weaponDef.id].ambientDecayRate  = vector_scalar_div(explosionLightDef.ambientColor or {0.0, 0.0, 0.0}, explosionLightDef.ttl or 1.0)
					explosionLightDefs[weaponDef.id].diffuseDecayRate  = vector_scalar_div(explosionLightDef.diffuseColor or {0.0, 0.0, 0.0}, explosionLightDef.ttl or 1.0)
					explosionLightDefs[weaponDef.id].specularDecayRate = vector_scalar_div(explosionLightDef.specularColor or {0.0, 0.0, 0.0}, explosionLightDef.ttl or 1.0)
				end
			end
		end
	end




	local function ProjectileCreated(_, projectileID, projectileOwnerID, projectileWeaponDefID)
		local projectileLightDef = projectileLightDefs[projectileWeaponDefID]

		if (projectileLightDef == nil) then
			return true
		end

		projectileLights[projectileID] = {
			[1] = SpringAddMapLight(projectileLightDef),
			[2] = SpringAddModelLight(projectileLightDef),
			-- [3] = projectileOwnerID,
			-- [4] = projectileWeaponDefID,
		}

		SpringSetMapLightTrackingState(projectileLights[projectileID][1], projectileID, true, false)
		SpringSetModelLightTrackingState(projectileLights[projectileID][2], projectileID, true, false)
		return true
	end

	local function ProjectileDestroyed(_, projectileID)
		if (projectileLights[projectileID] == nil) then
			return true
		end

		-- set the TTL to 0 upon the projectile's destruction
		-- (since all projectile lights start with arbitrarily
		-- large values, which ensures we don't have to update
		-- ttls manually to keep our lights alive) so the light
		-- gets marked for removal
		local projectileLightPos = {SpringGetProjectilePosition(projectileID)} -- {ppx, ppy, ppz}
		local projectileLightTbl = {position = projectileLightPos, ttl = 0}

		-- NOTE: unnecessary (death-dependency system take care of it)
		-- SpringSetMapLightTrackingState(projectileLights[projectileID][1], projectileID, false, false)
		-- SpringSetModelLightTrackingState(projectileLights[projectileID][2], projectileID, false, false)

		SpringUpdateMapLight(projectileLights[projectileID][1], projectileLightTbl)
		SpringUpdateModelLight(projectileLights[projectileID][2], projectileLightTbl)

		-- get rid of this light
		projectileLights[projectileID] = nil
		return true
	end


	local function ProjectileExplosion(_, weaponDefID, posx, posy, posz)
		local explosionLightDef = explosionLightDefs[weaponDefID]

		if (explosionLightDef == nil) then
			return true
		end

		local explosionLightAlt = explosionLightDef.altitudeOffset or 0.0
		local explosionLightPos = {posx, posy + explosionLightAlt, posz}
		-- NOTE: explosions are non-tracking, so need to supply position
		-- FIXME:? explosion "ID"'s would require bookkeeping in :Update
		local explosionLightTbl = {position = explosionLightPos, }
		local numExplosions     = 1

		explosionLights[numExplosions] = {
			[1] = SpringAddMapLight(explosionLightDef),
			[2] = SpringAddModelLight(explosionLightDef),
		}

		SpringUpdateMapLight(explosionLights[numExplosions][1], explosionLightTbl)
		SpringUpdateModelLight(explosionLights[numExplosions][2], explosionLightTbl)
		return true
	end

	function gadget:Initialize()
		local modOptions = Spring.GetModOptions()
		if modOptions and (modOptions.lowcpu == "1" or modOptions.dynamiclights == "0") then 
			gadgetHandler:RemoveGadget(self) 
			return
		end

		local maxMapLights = Spring.GetConfigInt("MaxDynamicMapLights") or 0
		local maxMdlLights = Spring.GetConfigInt("MaxDynamicModelLights") or 0

		if (maxMapLights <= 0 and maxMdlLights <= 0) then
			Spring.Echo("[" .. (self:GetInfo()).name .. "] client has disabled dynamic lighting")
			gadgetHandler:RemoveGadget(self)
			return
		else
			Spring.SetConfigInt("MaxDynamicMapLights", math.max(maxMapLights, 4))
			Spring.SetConfigInt("MaxDynamicModelLights", math.max(maxMdlLights, 4))
		end

		gadgetHandler:AddSyncAction('DL_ProjectileCreated', ProjectileCreated)
		gadgetHandler:AddSyncAction('DL_ProjectileDestroyed', ProjectileDestroyed)
		gadgetHandler:AddSyncAction('DL_ProjectileExplosion', ProjectileExplosion)
		
		-- fill the {projectile, explosion}LightDef tables
		LoadLightDefs()
	end

end

