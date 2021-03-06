--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
  return {
    name      = "Z Selector",
    desc      = "Hold Z to select the same types of unit only v1.1",
    author    = "TheFatController",
    date      = "Oct 2013",
	version   = "1.1",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true  --  loaded by default?
  }
end

-- fixed by Jools
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local GetMouseState = Spring.GetMouseState
local mouseDown = false
local zDown = false
local selDefs = {}
local Echo = Spring.Echo

local function mouseRelease()
  local zSelection = {}
  local selUnits = Spring.GetSelectedUnitsSorted()
  for i,v in pairs(selUnits) do
    if (i ~= "n") and selDefs[i] then
      for _,k in ipairs(v) do 
        table.insert(zSelection, k)
      end
	  break
    end
  end
  Spring.SelectUnitArray(zSelection)
end

function widget:MousePress(x,y,button)
  if (button == 1) then 
    mouseDown = true
  end
end

function widget:DrawWorld()
  if mouseDown and (not select(3,GetMouseState())) then
   mouseDown = false
   if zDown then mouseRelease() end
  end
end

function widget:KeyPress(key, mods, isRepeat)
	if (key == 0x07A) and (not isRepeat) then
		local newSelDefs = Spring.GetSelectedUnitsCounts()
	
		if newSelDefs and newSelDefs.n>0 then
			selDefs = newSelDefs
		end
		zDown = true	
		return false
	end
end

function widget:KeyRelease(key, mods, isRepeat)
	if (key == 0x07A) then
		zDown = false
	end
	return false
 end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------