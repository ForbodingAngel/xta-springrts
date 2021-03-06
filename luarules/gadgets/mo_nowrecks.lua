function gadget:GetInfo()
  return {
    name      = "mo_nowrecks",
    desc      = "mo_nowrecks",
    author    = "TheFatController",
    date      = "19 Jan 2008",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true  --  loaded by default?
  }
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

if (not gadgetHandler:IsSyncedCode()) then
  return
end

local enabled = tonumber(Spring.GetModOptions().mo_nowrecks) or 0

if (enabled == 0) then 
  return false
end

function gadget:AllowFeatureCreation(featureDefID, teamID, x, y, z)
  local featureName = (FeatureDefs[featureDefID].tooltip or "nil")
  if string.find(featureName, 'Wreckage') then
    return false
  elseif string.find(featureName, 'Shards') then
    return false
  elseif string.find(featureName, 'Rubble') then
    return false
  elseif string.find(featureName, 'Heap') then
    return false
  end
  return true
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------