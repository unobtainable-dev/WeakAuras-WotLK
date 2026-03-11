if not WeakAuras.IsLibsOK() then return end
local AddonName = ...
local OptionsPrivate = select(2, ...)

-- Lua APIs
local pairs = pairs

-- WoW APIs
local CreateFrame, IsMouseButtonDown, SetCursor, GetMouseFocus, MouseIsOver, ResetCursor
  = CreateFrame, IsMouseButtonDown, SetCursor, GetMouseFocus, MouseIsOver, ResetCursor

local WeakAuras = WeakAuras
local L = WeakAuras.L

local frameChooserFrame
local frameChooserBox
local previewName = nil

local oldFocus
local oldFocusName

-- throttle timer (reduces CPU usage)
local updateElapsed = 0

local function recurseGetName(frame)
  local name = frame.GetName and frame:GetName() or nil
  if name then
     return name
  end
  local parent = frame.GetParent and frame:GetParent()
  if parent then
     for key, child in pairs(parent) do
        if child == frame then
           return (recurseGetName(parent) or "") .. "." .. key
        end
     end
  end
end

function OptionsPrivate.StartFrameChooser(data, path)
  local frame = OptionsPrivate.Private.OptionsFrame()
  OptionsPrivate.currentChooserEditBox = OptionsPrivate.Private.lastFrameChooserEditBox

  if not(frameChooserFrame) then
    frameChooserFrame = CreateFrame("Frame")

    frameChooserBox = CreateFrame("Frame", nil, frameChooserFrame)
    frameChooserBox:SetFrameStrata("TOOLTIP")
    frameChooserBox:EnableMouse(false)

    frameChooserBox:SetBackdrop({
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      edgeSize = 12,
      insets = {left = 0, right = 0, top = 0, bottom = 0}
    })

    frameChooserBox:SetBackdropBorderColor(0, 1, 0)
    frameChooserBox:Hide()
  end

  local givenValue = OptionsPrivate.Private.ValueFromPath(data, path)

frameChooserFrame:SetScript("OnUpdate", function(self, elapsed)
	SetCursor("CAST_CURSOR")
    -- 1. Throttling (Keep it at ~20fps for performance)
    updateElapsed = updateElapsed + elapsed
    if updateElapsed < 0.05 then return end
    updateElapsed = 0

    -- 2. CANCEL (Right Click)
    if(IsMouseButtonDown("RightButton")) then
      OptionsPrivate.Private.ValueToPath(data, path, givenValue)
      OptionsPrivate.StopFrameChooser(data)
      WeakAuras.Add(data) 
      WeakAuras.FillOptions() 
      return
    end

    -- 3. CONFIRM (Left Click)
    if(IsMouseButtonDown("LeftButton") and previewName) then
      OptionsPrivate.Private.ValueToPath(data, path, previewName)
      OptionsPrivate.StopFrameChooser(data)
      WeakAuras.FillOptions() -- Rebuild UI EXACTLY ONCE
      return
    end

	
    local focus = GetMouseFocus()
    local focusName = focus and recurseGetName(focus)

    -- (WeakAuras region detection logic...)
    if(focusName == "WorldFrame" or not focusName) then
        focusName = nil
        for id, regionData in pairs(OptionsPrivate.Private.regions) do
            if(regionData.region and regionData.region:IsVisible() and MouseIsOver(regionData.region)) then
                focusName = "WeakAuras:"..id
                focus = regionData.region
                break
            end
        end
    end

    if(focusName and focusName ~= oldFocusName) then
      previewName = focusName
      oldFocusName = focusName
      
      frameChooserBox:ClearAllPoints()
      frameChooserBox:SetPoint("bottomleft", focus, "bottomleft", -4, -4)
      frameChooserBox:SetPoint("topright", focus, "topright", 4, 4)
      frameChooserBox:Show()

      OptionsPrivate.Private.ValueToPath(data, path, focusName)
      
      WeakAuras.Add(data)
      
      if OptionsPrivate.SetGlowFramePreview then
          OptionsPrivate.SetGlowFramePreview(focusName)
      end
    end

    if not(focusName) then
      frameChooserBox:Hide()
    end
  end)
end

function OptionsPrivate.StopFrameChooser(data)
  if(frameChooserFrame) then
    frameChooserFrame:SetScript("OnUpdate", nil)
    frameChooserBox:Hide()
	
  end
previewName = nil
  ResetCursor()
  WeakAuras.Add(data)

  oldFocus = nil
  oldFocusName = nil
end