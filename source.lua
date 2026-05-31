local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local MILITARY_ITEMS = {
    "Air Base",
    "Artillery Depot",
    "Rocket Bunker",
    "Mech Station",
    "Spider Base",
}

local FACTORY_ITEMS = {
    "Nuclear Reactor",
    "Data Center",
    "Blackhole Generator",
    "Area 51 Lab",
    "Antimatter Reactor",
    "Quantum Core Generator",
}

local TELEPORTS = {
    { name = "City",  pos = Vector3.new(14.75,   9.01,  -12.40)  },
    { name = "Lab 1", pos = Vector3.new(-6.28,   8.81, -210.85)  },
    { name = "Lab 2", pos = Vector3.new(210.62,  8.81, -128.78)  },
    { name = "Lab 3", pos = Vector3.new(231.53,  8.81,   99.75)  },
    { name = "Lab 4", pos = Vector3.new(5.15,    8.81,  210.79)  },
    { name = "Lab 5", pos = Vector3.new(0,       8.81,    0)     },
    { name = "Oil 1", pos = Vector3.new(-674.35, -7.19,  -2.39)  },
    { name = "Oil 2", pos = Vector3.new(-449.24, -7.19, -659.90) },
    { name = "Oil 3", pos = Vector3.new(453.95,  -7.19, -636.40) },
    { name = "Oil 4", pos = Vector3.new(661.50,  -7.19,    1.84) },
    { name = "Oil 5", pos = Vector3.new(494.04,  -7.19,  684.94) },
    { name = "Oil 6", pos = Vector3.new(-456.12, -7.19,  656.33) },
}

local ScanDelay   = 0.08
local BuyCooldown = 0.5

local Players             = game:GetService("Players")
local GuiService          = game:GetService("GuiService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local LocalPlayer         = Players.LocalPlayer

local autoBuyMilitary = false
local autoBuyFactory  = false
local selectedItems   = {}

for _, n in ipairs(MILITARY_ITEMS) do selectedItems[n] = false end
for _, n in ipairs(FACTORY_ITEMS)  do selectedItems[n] = false end

if not _G.AntiAFKConnected then
    LocalPlayer.Idled:Connect(function()
        local VU = game:GetService("VirtualUser")
        VU:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
        task.wait(0.5)
        VU:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
    end)
    _G.AntiAFKConnected = true
end

local function getBuyUI()
    local pg     = LocalPlayer.PlayerGui
    local mainUI = pg:FindFirstChild("MainUI")
    if not mainUI then return nil end
    local fs = mainUI:FindFirstChild("Fullscreen")
    if not fs then return nil end
    return fs:FindFirstChild("BuyUI")
end

local function isMenuOpen()
    local BuyUI = getBuyUI()
    if not BuyUI or not BuyUI.Parent then return false end
    if not BuyUI.Visible then return false end
    local fs = BuyUI.Parent
    if fs and not fs.Visible then return false end
    return true
end

local function getActiveTabName()
    if not isMenuOpen() then return nil end
    local BuyUI = getBuyUI()

    local candidates = {
        BuyUI:FindFirstChild("TabBar"),
        BuyUI:FindFirstChild("Tabs"),
    }
    local header = BuyUI:FindFirstChild("Header")
    if header then
        table.insert(candidates, header:FindFirstChild("Tabs"))
        table.insert(candidates, header:FindFirstChild("TabBar"))
    end

    for _, tabBar in ipairs(candidates) do
        if not tabBar then continue end
        for _, btn in ipairs(tabBar:GetChildren()) do
            if not (btn:IsA("TextButton") or btn:IsA("GuiButton") or btn:IsA("Frame")) then continue end
            local selected = false
            local sv = btn:FindFirstChild("Selected")
            if sv and sv:IsA("BoolValue") and sv.Value then
                selected = true
            elseif btn:IsA("TextButton") or btn:IsA("GuiButton") then
                if btn.BackgroundTransparency < 0.5 then selected = true end
            end
            if selected then
                return string.lower(btn.Name)
            end
        end
    end

    local titleLabel = BuyUI:FindFirstChild("TabTitle") or BuyUI:FindFirstChild("CurrentTab")
    if titleLabel and titleLabel:IsA("TextLabel") then
        return string.lower(titleLabel.Text)
    end

    return "unknown"
end

local function isMilitaryTabOpen()
    local t = getActiveTabName()
    if t == nil then return false end
    if t == "unknown" then return true end
    return string.find(t, "military") ~= nil
        or string.find(t, "war")      ~= nil
end

local function isFactoryTabOpen()
    local t = getActiveTabName()
    if t == nil then return false end
    if t == "unknown" then return true end
    return string.find(t, "factor") ~= nil
end

local function getItemsGrid()
    local BuyUI = getBuyUI()
    if not BuyUI then return nil end
    local grid = BuyUI:FindFirstChild("ItemsGrid")
    if grid then return grid end
    for _, child in ipairs(BuyUI:GetDescendants()) do
        if child.Name == "ItemsGrid" then return child end
    end
    return nil
end

local function isButtonInStock(button)
    if not button or not button.Parent then return false end
    if not button.Visible or button.AbsoluteSize.X <= 0 then return false end
    local textLabel = button:FindFirstChildOfClass("TextLabel")
    if textLabel then
        local t = string.lower(textLabel.Text)
        if string.find(t, "stock") or string.find(t, "out") then return false end
    end
    local card = button.Parent
    if card then
        local oos = card:FindFirstChild("Out of Stock!", true)
        if oos and oos:IsA("TextLabel") then
            if oos.Visible and oos.AbsoluteSize.X > 0 and oos.TextTransparency < 0.9 then
                return false
            end
        end
        local dim = card:FindFirstChild("Dimmed") or card:FindFirstChild("Disabled")
        if dim and dim.Visible then return false end
    end
    return true
end

local function findCard(itemsGrid, itemName)
    local cleanTarget = string.lower(itemName:gsub("%s+", ""))
    for _, card in ipairs(itemsGrid:GetChildren()) do
        if string.lower(card.Name:gsub("%s+", "")) == cleanTarget then return card end
    end
    for _, card in ipairs(itemsGrid:GetChildren()) do
        if card:FindFirstChild(itemName, true) then return card end
    end
    return nil
end

local function tryBuyList(itemList)
    if not isMenuOpen() then
        if GuiService.SelectedObject ~= nil then GuiService.SelectedObject = nil end
        return
    end
    local ItemsGrid = getItemsGrid()
    if not ItemsGrid then return end

    for _, itemName in ipairs(itemList) do
        if not selectedItems[itemName] then continue end
        if not isMenuOpen() then break end

        local card = findCard(ItemsGrid, itemName)
        if not card then continue end

        local buyButton = card:FindFirstChild("Buy") or card:FindFirstChildWhichIsA("GuiButton")
        if not buyButton then continue end
        if not isButtonInStock(buyButton) then continue end

        GuiService.SelectedObject = buyButton
        task.wait(0.02)

        if isMenuOpen() and isButtonInStock(buyButton) then
            VirtualInputManager:SendKeyEvent(true,  Enum.KeyCode.Return, false, game)
            task.wait(0.02)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
            task.wait(BuyCooldown)
        end

        GuiService.SelectedObject = nil
    end
end

task.spawn(function()
    while true do
        task.wait(ScanDelay)

        if autoBuyMilitary and isMilitaryTabOpen() then
            tryBuyList(MILITARY_ITEMS)
        end

        if autoBuyFactory and isFactoryTabOpen() then
            tryBuyList(FACTORY_ITEMS)
        end
    end
end)

local function teleportTo(pos)
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hrp then hrp.CFrame = CFrame.new(pos) end
end

local Window = Rayfield:CreateWindow({
    Name            = "MINI WAR Auto Buy",
    LoadingTitle    = "MINI WAR",
    LoadingSubtitle = "Auto Buy Module",
    Theme           = "Default",
    Icon            = 0,
    ConfigurationSaving = {
        Enabled    = true,
        FolderName = "MiniWarAutoBuy",
        FileName   = "config",
    },
    Discord   = { Enabled = false },
    KeySystem = false,
})

local TabMilitary  = Window:CreateTab("Auto Buy Military", "shield")
local TabFactory   = Window:CreateTab("Auto Buy Factory",  "factory")
local TabTeleport  = Window:CreateTab("Teleport",          "map-pin")
local TabInfo      = Window:CreateTab("\208\152\208\189\209\132\208\190\209\128\208\188\208\176\209\134\208\184\209\143",        "info")

TabMilitary:CreateSection("\208\163\208\191\209\128\208\176\208\178\208\187\208\181\208\189\208\184\208\181")

local MilitaryToggle = TabMilitary:CreateToggle({
    Name         = "Auto Buy Military",
    CurrentValue = false,
    Flag         = "AutoBuyMilitary",
    Callback     = function(value)
        autoBuyMilitary = value
        if not value and GuiService.SelectedObject ~= nil then
            GuiService.SelectedObject = nil
        end
    end,
})

TabMilitary:CreateKeybind({
    Name           = "\208\145\208\184\208\189\208\180 Military",
    CurrentKeybind = "P",
    HoldToInteract = false,
    Flag           = "KeybindMilitary",
    Callback       = function()
        autoBuyMilitary = not autoBuyMilitary
        MilitaryToggle:Set(autoBuyMilitary)
        Rayfield:Notify({
            Title    = "Auto Buy Military",
            Content  = autoBuyMilitary and "\208\146\208\186\208\187\209\142\209\135\209\145\208\189" or "\208\158\209\129\209\130\208\176\208\189\208\190\208\178\208\187\208\181\208\189",
            Duration = 2,
        })
    end,
})

TabMilitary:CreateSection("Military Items")

for _, itemName in ipairs(MILITARY_ITEMS) do
    TabMilitary:CreateToggle({
        Name         = itemName,
        CurrentValue = false,
        Flag         = "Item_" .. itemName:gsub("%s+", "_"),
        Callback     = function(value)
            selectedItems[itemName] = value
        end,
    })
end

TabFactory:CreateSection("\208\163\208\191\209\128\208\176\208\178\208\187\208\181\208\189\208\184\208\181")

local FactoryToggle = TabFactory:CreateToggle({
    Name         = "Auto Buy Factory",
    CurrentValue = false,
    Flag         = "AutoBuyFactory",
    Callback     = function(value)
        autoBuyFactory = value
        if not value and GuiService.SelectedObject ~= nil then
            GuiService.SelectedObject = nil
        end
    end,
})

TabFactory:CreateKeybind({
    Name           = "\208\145\208\184\208\189\208\180 Factory",
    CurrentKeybind = "O",
    HoldToInteract = false,
    Flag           = "KeybindFactory",
    Callback       = function()
        autoBuyFactory = not autoBuyFactory
        FactoryToggle:Set(autoBuyFactory)
        Rayfield:Notify({
            Title    = "Auto Buy Factory",
            Content  = autoBuyFactory and "\208\146\208\186\208\187\209\142\209\135\209\145\208\189" or "\208\158\209\129\209\130\208\176\208\189\208\190\208\178\208\187\208\181\208\189",
            Duration = 2,
        })
    end,
})

TabFactory:CreateSection("Factory Items")

for _, itemName in ipairs(FACTORY_ITEMS) do
    TabFactory:CreateToggle({
        Name         = itemName,
        CurrentValue = false,
        Flag         = "Item_" .. itemName:gsub("%s+", "_"),
        Callback     = function(value)
            selectedItems[itemName] = value
        end,
    })
end

TabTeleport:CreateSection("\208\155\208\190\208\186\208\176\209\134\208\184\208\184")

for _, tp in ipairs(TELEPORTS) do
    TabTeleport:CreateButton({
        Name     = "\226\134\146 " .. tp.name,
        Callback = function()
            teleportTo(tp.pos)
            Rayfield:Notify({
                Title    = "Teleport",
                Content  = "\208\162\208\181\208\187\208\181\208\191\208\190\209\128\209\130: " .. tp.name,
                Duration = 2,
            })
        end,
    })
end

TabInfo:CreateSection("\208\152\208\189\209\129\209\130\209\128\209\131\208\186\209\134\208\184\209\143")

TabInfo:CreateParagraph({
    Title   = "Auto Buy Military",
    Content = "1. \208\158\209\130\208\186\209\128\208\190\208\185 \208\188\208\176\208\179\208\176\208\183\208\184\208\189 \208\178 \208\184\208\179\209\128\208\181.\n2. \208\159\208\181\209\128\208\181\208\185\208\180\208\184 \208\189\208\176 \208\178\208\186\208\187\208\176\208\180\208\186\209\131 Military.\n3. \208\146 \209\129\208\186\209\128\208\184\208\191\209\130\208\181 (\208\178\208\186\208\187\208\176\208\180\208\186\208\176 Auto Buy Military) \208\178\208\186\208\187\209\142\209\135\208\184 \208\189\209\131\208\182\208\189\209\139\208\181 \208\191\209\128\208\181\208\180\208\188\208\181\209\130\209\139 toggle\208\176\208\188\208\184.\n4. \208\157\208\176\208\182\208\188\208\184 toggle Auto Buy Military \208\184\208\187\208\184 \208\177\208\184\208\189\208\180 P.\n\208\161\208\186\209\128\208\184\208\191\209\130 \208\191\208\190\208\186\209\131\208\191\208\176\208\181\209\130 \208\191\209\128\208\181\208\180\208\188\208\181\209\130 \208\162\208\158\208\155\208\172\208\154\208\158 \208\181\209\129\208\187\208\184 \208\190\208\189 \208\181\209\129\209\130\209\140 \208\178 \209\129\209\130\208\190\208\186\208\181 \208\184 \209\130\209\139 \208\189\208\176\209\133\208\190\208\180\208\184\209\136\209\140\209\129\209\143 \208\189\208\176 \208\178\208\186\208\187\208\176\208\180\208\186\208\181 Military \208\178 \208\188\208\176\208\179\208\176\208\183\208\184\208\189\208\181.",
})

TabInfo:CreateParagraph({
    Title   = "Auto Buy Factory",
    Content = "1. \208\158\209\130\208\186\209\128\208\190\208\185 \208\188\208\176\208\179\208\176\208\183\208\184\208\189 \208\178 \208\184\208\179\209\128\208\181.\n2. \208\159\208\181\209\128\208\181\208\185\208\180\208\184 \208\189\208\176 \208\178\208\186\208\187\208\176\208\180\208\186\209\131 Factory.\n3. \208\146 \209\129\208\186\209\128\208\184\208\191\209\130\208\181 (\208\178\208\186\208\187\208\176\208\180\208\186\208\176 Auto Buy Factory) \208\178\208\186\208\187\209\142\209\135\208\184 \208\189\209\131\208\182\208\189\209\139\208\181 \208\191\209\128\208\181\208\180\208\188\208\181\209\130\209\139 toggle\208\176\208\188\208\184.\n4. \208\157\208\176\208\182\208\188\208\184 toggle Auto Buy Factory \208\184\208\187\208\184 \208\177\208\184\208\189\208\180 O.\n\208\161\208\186\209\128\208\184\208\191\209\130 \208\191\208\190\208\186\209\131\208\191\208\176\208\181\209\130 \208\191\209\128\208\181\208\180\208\188\208\181\209\130 \208\162\208\158\208\155\208\172\208\154\208\158 \208\181\209\129\208\187\208\184 \208\190\208\189 \208\181\209\129\209\130\209\140 \208\178 \209\129\209\130\208\190\208\186\208\181 \208\184 \209\130\209\139 \208\189\208\176\209\133\208\190\208\180\208\184\209\136\209\140\209\129\209\143 \208\189\208\176 \208\178\208\186\208\187\208\176\208\180\208\186\208\181 Factory \208\178 \208\188\208\176\208\179\208\176\208\183\208\184\208\189\208\181.",
})

TabInfo:CreateParagraph({
    Title   = "Teleport",
    Content = "\208\146\208\190 \208\178\208\186\208\187\208\176\208\180\208\186\208\181 Teleport \208\189\208\176\208\182\208\188\208\184 \208\186\208\189\208\190\208\191\208\186\209\131 \209\129 \208\189\209\131\208\182\208\189\208\190\208\185 \208\187\208\190\208\186\208\176\209\134\208\184\208\181\208\185.\n\208\148\208\190\209\129\209\130\209\131\208\191\208\189\209\139: City, Lab 1\226\128\1475, Oil 1\226\128\1476.",
})

TabInfo:CreateParagraph({
    Title   = "\208\146\208\176\208\182\208\189\208\190",
    Content = "\208\149\209\129\208\187\208\184 \209\129\208\186\209\128\208\184\208\191\209\130 \208\189\208\181 \208\191\208\190\208\186\209\131\208\191\208\176\208\181\209\130 \226\128\148 \209\131\208\177\208\181\208\180\208\184\209\129\209\140 \209\135\209\130\208\190:\n\226\128\162 \208\156\208\181\208\189\209\142 \208\188\208\176\208\179\208\176\208\183\208\184\208\189\208\176 \208\190\209\130\208\186\209\128\209\139\209\130\208\190\n\226\128\162 \208\162\209\139 \208\189\208\176 \208\191\209\128\208\176\208\178\208\184\208\187\209\140\208\189\208\190\208\185 \208\178\208\186\208\187\208\176\208\180\208\186\208\181 (Military \208\184\208\187\208\184 Factory)\n\226\128\162 \208\159\209\128\208\181\208\180\208\188\208\181\209\130 \208\181\209\129\209\130\209\140 \208\178 \209\129\209\130\208\190\208\186\208\181\n\226\128\162 Toggle \208\191\209\128\208\181\208\180\208\188\208\181\209\130\208\176 \208\178\208\186\208\187\209\142\209\135\209\145\208\189\n\226\128\162 Auto Buy \208\178\208\186\208\187\209\142\209\135\209\145\208\189",
})

Rayfield:LoadConfiguration()

task.defer(function()
    for _, n in ipairs(MILITARY_ITEMS) do
        local flag = "Item_" .. n:gsub("%s+", "_")
        if Rayfield.Flags[flag] then selectedItems[n] = Rayfield.Flags[flag].CurrentValue end
    end
    for _, n in ipairs(FACTORY_ITEMS) do
        local flag = "Item_" .. n:gsub("%s+", "_")
        if Rayfield.Flags[flag] then selectedItems[n] = Rayfield.Flags[flag].CurrentValue end
    end
    if Rayfield.Flags["AutoBuyMilitary"] then
        autoBuyMilitary = Rayfield.Flags["AutoBuyMilitary"].CurrentValue
    end
    if Rayfield.Flags["AutoBuyFactory"] then
        autoBuyFactory = Rayfield.Flags["AutoBuyFactory"].CurrentValue
    end
end)
