-- Scrub Sniffer: one-click player lookup from the group finder
local ADDON_NAME = "ScrubSniffer"
local BASE_URL = "https://scrub-sniffer.vercel.app/"
local PREFIX = "|cff00ccff[Scrub Sniffer]|r "

-- Saved variables (initialized on ADDON_LOADED)
ScrubSnifferDB = ScrubSnifferDB or {}

local function GetRegion()
    return ScrubSnifferDB.region or "us"
end

---------------------------------------------------------------------------
-- URL helpers
---------------------------------------------------------------------------
local function BuildURL(name, realm)
    -- Strip spaces from realm (e.g. "Area 52" -> "Area52") for the query param
    realm = realm:gsub("%s", "")
    return BASE_URL .. "?name=" .. name .. "&server=" .. realm .. "&region=" .. GetRegion()
end

---------------------------------------------------------------------------
-- Clipboard popup
---------------------------------------------------------------------------
-- WoW has no clipboard API, so we show an EditBox with the URL pre-selected.
-- The player just hits Ctrl+C then pastes in their browser.

local clipboardFrame = CreateFrame("Frame", "ScrubSnifferClipboard", UIParent, "BackdropTemplate")
clipboardFrame:SetSize(420, 80)
clipboardFrame:SetPoint("CENTER")
clipboardFrame:SetFrameStrata("DIALOG")
clipboardFrame:SetMovable(true)
clipboardFrame:EnableMouse(true)
clipboardFrame:RegisterForDrag("LeftButton")
clipboardFrame:SetScript("OnDragStart", clipboardFrame.StartMoving)
clipboardFrame:SetScript("OnDragStop", clipboardFrame.StopMovingOrSizing)
clipboardFrame:Hide()

clipboardFrame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 24,
    insets = { left = 6, right = 6, top = 6, bottom = 6 },
})

local title = clipboardFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
title:SetPoint("TOP", 0, -10)
title:SetText("Scrub Sniffer — Ctrl+C to copy, then paste in browser")

local editBox = CreateFrame("EditBox", "ScrubSnifferEditBox", clipboardFrame, "InputBoxTemplate")
editBox:SetSize(380, 20)
editBox:SetPoint("TOP", title, "BOTTOM", 0, -6)
editBox:SetAutoFocus(true)
editBox:SetFontObject(ChatFontNormal)

editBox:SetScript("OnEscapePressed", function(self)
    clipboardFrame:Hide()
end)
editBox:SetScript("OnEnterPressed", function(self)
    clipboardFrame:Hide()
end)
-- Re-select all text if focus lost or user clicks in the box
editBox:SetScript("OnEditFocusGained", function(self)
    self:HighlightText()
end)
editBox:SetScript("OnCursorChanged", function(self)
    self:HighlightText()
end)

local closeBtn = CreateFrame("Button", nil, clipboardFrame, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", -2, -2)

local function ShowClipboard(url)
    editBox:SetText(url)
    clipboardFrame:Show()
    editBox:SetFocus()
    editBox:HighlightText()
    print(PREFIX .. "Link ready — Ctrl+C to copy, then paste in your browser!")
end

---------------------------------------------------------------------------
-- Core lookup
---------------------------------------------------------------------------
local function LookupPlayer(fullName)
    if not fullName then return end
    -- fullName may be "Name-Realm" or just "Name" (same realm)
    local name, realm = strsplit("-", fullName)
    if not realm or realm == "" then
        realm = GetNormalizedRealmName()
    end
    if not name or name == "" then
        print(PREFIX .. "Could not determine player name.")
        return
    end
    local url = BuildURL(name, realm)
    ShowClipboard(url)
end

---------------------------------------------------------------------------
-- LFG Applicant Integration
---------------------------------------------------------------------------
-- Hook into the context menu that appears when clicking an applicant name
-- in the Premade Groups applicant list. Adds a "Scrub Sniff" option.

local function GetApplicantName(applicantID)
    local name = C_LFGList.GetApplicantMemberInfo(applicantID, 1)
    return name
end

local function HookApplicantMenu()
    if Menu and Menu.ModifyMenu then
        Menu.ModifyMenu("MENU_LFG_FRAME_MEMBER_APPLY", function(owner, rootDescription, contextData)
            -- owner is the applicant member frame; its parent has applicantID
            local memberFrame = owner
            if not memberFrame then return end
            local parentFrame = memberFrame:GetParent()
            if not parentFrame or not parentFrame.applicantID then return end
            local memberIdx = memberFrame.memberIdx or 1
            local name = C_LFGList.GetApplicantMemberInfo(parentFrame.applicantID, memberIdx)
            if not name then return end
            rootDescription:CreateDivider()
            rootDescription:CreateButton("Scrub Sniff", function()
                LookupPlayer(name)
            end)
        end)
    end
end

---------------------------------------------------------------------------
-- Right-click unit menu (party/raid/target frames)
---------------------------------------------------------------------------
-- In modern WoW (11.x), unit popup menus use Menu.ModifyMenu.
-- We add a "Scrub Sniff" option when right-clicking a player unit.

local function HookUnitMenus()
    -- Menu.ModifyMenu is the modern API for injecting menu items
    if Menu and Menu.ModifyMenu then
        Menu.ModifyMenu("MENU_UNIT_SELF", function(owner, rootDescription, contextData)
            -- skip self
        end)

        local function AddSniffOption(owner, rootDescription, contextData)
            if not contextData or not contextData.unit then return end
            local unit = contextData.unit
            if not UnitIsPlayer(unit) then return end

            local fullName, realm = UnitFullName(unit)
            if not realm or realm == "" then
                realm = GetNormalizedRealmName()
            end
            if fullName then
                local lookup = fullName .. "-" .. realm
                rootDescription:CreateDivider()
                rootDescription:CreateTitle("Scrub Sniffer")
                rootDescription:CreateButton("Copy Lookup URL", function()
                    LookupPlayer(lookup)
                end)
            end
        end

        -- Hook all relevant unit menus
        for _, menuTag in ipairs({
            "MENU_UNIT_PARTY",
            "MENU_UNIT_PLAYER",
            "MENU_UNIT_RAID_PLAYER",
            "MENU_UNIT_FRIEND",
            "MENU_UNIT_ENEMY_PLAYER",
        }) do
            Menu.ModifyMenu(menuTag, AddSniffOption)
        end
    end
end

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------
SLASH_SCRUBSNIFFER1 = "/sniff"
SlashCmdList["SCRUBSNIFFER"] = function(msg)
    msg = strtrim(msg or "")

    -- /sniff region <code>  — change region
    local regionCmd = msg:match("^region%s+(%a+)")
    if regionCmd then
        regionCmd = regionCmd:lower()
        ScrubSnifferDB.region = regionCmd
        print(PREFIX .. "Region set to: " .. regionCmd)
        return
    end

    -- /sniff <Name-Realm>  — manual lookup
    if msg ~= "" then
        LookupPlayer(msg)
        return
    end

    -- /sniff with no args — look up current target
    if UnitExists("target") and UnitIsPlayer("target") then
        local name, realm = UnitFullName("target")
        if not realm or realm == "" then
            realm = GetNormalizedRealmName()
        end
        if name then
            LookupPlayer(name .. "-" .. realm)
            return
        end
    end

    print(PREFIX .. "Usage:")
    print("  /sniff PlayerName-Realm")
    print("  /sniff  (with a player targeted)")
    print("  /sniff region us|eu|kr|tw")
end

---------------------------------------------------------------------------
-- Event handling
---------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")

eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        ScrubSnifferDB = ScrubSnifferDB or {}
        if not ScrubSnifferDB.region then
            ScrubSnifferDB.region = "us"
        end
        HookApplicantMenu()
        HookUnitMenus()
        print(PREFIX .. "Loaded. Type /sniff for help.")
    end
end)
