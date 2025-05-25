--[[
Enhanced Auto Heist Script V3.0 - พัฒนาจาก Explorer V2.6.3
เพิ่มฟีเจอร์: Auto Storage, Teleport, Auto Heist Functions
]]

local Player = game:GetService("Players").LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ================= DATA STORAGE SYSTEM =================
local StoredData = {
    HeistLocations = {},
    ProximityPrompts = {},
    RemoteEvents = {},
    RemoteFunctions = {},
    LootParts = {},
    Scripts = {},
    TouchParts = {}
}

local AutoHeistSettings = {
    enabled = false,
    currentHeist = nil,
    teleportSpeed = 0.5,
    interactionDelay = 1,
    autoLoot = true,
    autoBypassSecurity = true,
    safeMode = true
}

-- ================= ENHANCED CONFIGURATION =================
local CONFIG = {
    HEISTS_BASE_PATH = "Heists",
    TARGET_HEISTS = {"Bank", "Casino", "JewelryStore"},
    LOOT_KEYWORDS = {"moneybag", "goldbar", "artifact", "valuable", "contraband", "keycard", "access", "vault", "safe", "computer", "terminal", "loot", "item", "collectible", "cash", "diamond", "money"},
    SECURITY_KEYWORDS = {"security", "camera", "laser", "alarm", "guard", "detector"},
    INTERACTION_KEYWORDS = {"door", "gate", "entrance", "exit", "button", "lever", "switch"},
    AUTO_HEIST_ENABLED = true,
    SHOW_UI = true
}

-- ================= UI THEME (เหมือนเดิม) =================
local THEME_COLORS = {
    Background = Color3.fromRGB(18, 20, 23),
    Primary = Color3.fromRGB(25, 28, 33),
    Secondary = Color3.fromRGB(35, 40, 50),
    Accent = Color3.fromRGB(0, 255, 120),
    Text = Color3.fromRGB(210, 215, 220),
    TextDim = Color3.fromRGB(130, 135, 140),
    ButtonHover = Color3.fromRGB(50, 55, 70),
    CloseButton = Color3.fromRGB(255, 95, 86),
    Warning = Color3.fromRGB(255, 165, 0),
    Success = Color3.fromRGB(0, 255, 120)
}

-- ================= UI VARIABLES =================
local mainFrame, outputContainer, statusBar, statusTextLabel
local allLoggedMessages = {}
local startTime = tick()

-- ================= UTILITY FUNCTIONS =================
local function logMessage(category, message)
    local timestamp = os.date("[%H:%M:%S] ")
    local fullMessage = timestamp .. "[" .. category .. "] " .. message
    print(fullMessage)
    table.insert(allLoggedMessages, fullMessage)
    
    if CONFIG.SHOW_UI and outputContainer then
        -- Add to UI (simplified for space)
        local logLabel = Instance.new("TextLabel")
        logLabel.Size = UDim2.new(1, -10, 0, 20)
        logLabel.BackgroundColor3 = THEME_COLORS.Primary
        logLabel.TextColor3 = THEME_COLORS.Text
        logLabel.Font = Enum.Font.Code
        logLabel.TextSize = 12
        logLabel.Text = fullMessage
        logLabel.TextXAlignment = Enum.TextXAlignment.Left
        logLabel.Parent = outputContainer
    end
end

local function safeTeleport(targetPosition, callback)
    if not HumanoidRootPart then return false end
    
    logMessage("Teleport", "เริ่มเทเลพอร์ตไปยัง: " .. tostring(targetPosition))
    
    local originalPosition = HumanoidRootPart.CFrame
    local targetCFrame = CFrame.new(targetPosition + Vector3.new(0, 5, 0)) -- เพิ่มความสูงเล็กน้อย
    
    -- Tween teleport for smoother movement
    local tweenInfo = TweenInfo.new(AutoHeistSettings.teleportSpeed, Enum.EasingStyle.Quad)
    local tween = TweenService:Create(HumanoidRootPart, tweenInfo, {CFrame = targetCFrame})
    
    tween:Play()
    tween.Completed:Connect(function()
        logMessage("Teleport", "เทเลพอร์ตสำเร็จ!")
        if callback then callback() end
    end)
    
    return true
end

local function interactWithProximityPrompt(prompt)
    if not prompt or not prompt:IsA("ProximityPrompt") then return false end
    
    logMessage("Interaction", "กำลังโต้ตอบกับ: " .. prompt:GetFullName())
    
    -- Check if player is in range
    local part = prompt.Parent
    if part and part:IsA("BasePart") then
        local distance = (HumanoidRootPart.Position - part.Position).Magnitude
        if distance > prompt.MaxActivationDistance + 2 then
            logMessage("Interaction", "ระยะทางไกลเกินไป, กำลังเคลื่อนที่ใกล้ขึ้น...")
            safeTeleport(part.Position, function()
                task.wait(0.5)
                fireproximityprompt(prompt)
            end)
        else
            fireproximityprompt(prompt)
        end
    else
        fireproximityprompt(prompt)
    end
    
    return true
end

local function fireRemoteEvent(remote, ...)
    if not remote or not remote:IsA("RemoteEvent") then return false end
    
    logMessage("Remote", "กำลัง Fire RemoteEvent: " .. remote:GetFullName())
    
    local success, error = pcall(function()
        remote:FireServer(...)
    end)
    
    if success then
        logMessage("Remote", "Fire RemoteEvent สำเร็จ!")
        return true
    else
        logMessage("Remote", "Fire RemoteEvent ล้มเหลว: " .. tostring(error))
        return false
    end
end

local function invokeRemoteFunction(remote, ...)
    if not remote or not remote:IsA("RemoteFunction") then return nil end
    
    logMessage("Remote", "กำลัง Invoke RemoteFunction: " .. remote:GetFullName())
    
    local success, result = pcall(function()
        return remote:InvokeServer(...)
    end)
    
    if success then
        logMessage("Remote", "Invoke RemoteFunction สำเร็จ! ผลลัพธ์: " .. tostring(result))
        return result
    else
        logMessage("Remote", "Invoke RemoteFunction ล้มเหลว: " .. tostring(result))
        return nil
    end
end

-- ================= DATA COLLECTION FUNCTIONS =================
local function storeHeistData(instance, heistName)
    local heistData = {
        name = heistName,
        path = instance:GetFullName(),
        position = nil,
        proximityPrompts = {},
        remotes = {},
        lootParts = {},
        securitySystems = {},
        interactionPoints = {}
    }
    
    -- Find main position (usually the center or entrance)
    for _, child in ipairs(instance:GetDescendants()) do
        if child:IsA("BasePart") and (child.Name:lower():match("spawn") or child.Name:lower():match("entrance") or child.Name:lower():match("start")) then
            heistData.position = child.Position
            break
        end
    end
    
    -- If no specific spawn point, use first part found
    if not heistData.position then
        for _, child in ipairs(instance:GetDescendants()) do
            if child:IsA("BasePart") and not child:IsA("Terrain") then
                heistData.position = child.Position
                break
            end
        end
    end
    
    -- Collect ProximityPrompts
    for _, descendant in ipairs(instance:GetDescendants()) do
        if descendant:IsA("ProximityPrompt") then
            table.insert(heistData.proximityPrompts, {
                instance = descendant,
                path = descendant:GetFullName(),
                objectText = descendant.ObjectText or "",
                actionText = descendant.ActionText or "",
                holdDuration = descendant.HoldDuration,
                enabled = descendant.Enabled,
                parent = descendant.Parent
            })
            
            table.insert(StoredData.ProximityPrompts, descendant)
        end
        
        -- Collect Remotes
        if descendant:IsA("RemoteEvent") then
            table.insert(heistData.remotes, {type = "Event", instance = descendant, path = descendant:GetFullName()})
            table.insert(StoredData.RemoteEvents, descendant)
        elseif descendant:IsA("RemoteFunction") then
            table.insert(heistData.remotes, {type = "Function", instance = descendant, path = descendant:GetFullName()})
            table.insert(StoredData.RemoteFunctions, descendant)
        end
        
        -- Collect Loot Parts
        if descendant:IsA("BasePart") then
            local isLoot = false
            for _, keyword in ipairs(CONFIG.LOOT_KEYWORDS) do
                if descendant.Name:lower():match(keyword:lower()) then
                    isLoot = true
                    break
                end
            end
            
            if isLoot then
                table.insert(heistData.lootParts, {
                    instance = descendant,
                    path = descendant:GetFullName(),
                    position = descendant.Position,
                    name = descendant.Name
                })
                table.insert(StoredData.LootParts, descendant)
            end
            
            -- Check for touch parts
            if descendant:FindFirstChildOfClass("TouchTransmitter") then
                table.insert(StoredData.TouchParts, descendant)
            end
        end
    end
    
    StoredData.HeistLocations[heistName] = heistData
    logMessage("Storage", "เก็บข้อมูล Heist: " .. heistName .. " สำเร็จ! (Prompts: " .. #heistData.proximityPrompts .. ", Remotes: " .. #heistData.remotes .. ", Loot: " .. #heistData.lootParts .. ")")
end

-- ================= AUTO HEIST FUNCTIONS =================
local function executeHeistSequence(heistName)
    if not StoredData.HeistLocations[heistName] then
        logMessage("AutoHeist", "ไม่พบข้อมูล Heist: " .. heistName)
        return false
    end
    
    local heistData = StoredData.HeistLocations[heistName]
    AutoHeistSettings.currentHeist = heistName
    
    logMessage("AutoHeist", "เริ่มต้นการปล้น: " .. heistName)
    
    -- Step 1: Teleport to heist location
    if heistData.position then
        safeTeleport(heistData.position, function()
            task.wait(1)
            
            -- Step 2: Interact with all proximity prompts
            for i, promptData in ipairs(heistData.proximityPrompts) do
                if promptData.instance and promptData.instance.Parent then
                    logMessage("AutoHeist", "กำลังโต้ตอบกับ Prompt " .. i .. "/" .. #heistData.proximityPrompts)
                    interactWithProximityPrompt(promptData.instance)
                    task.wait(AutoHeistSettings.interactionDelay)
                end
            end
            
            -- Step 3: Fire relevant remote events
            for _, remoteData in ipairs(heistData.remotes) do
                if remoteData.instance and remoteData.instance.Parent then
                    if remoteData.type == "Event" then
                        fireRemoteEvent(remoteData.instance)
                    elseif remoteData.type == "Function" then
                        invokeRemoteFunction(remoteData.instance)
                    end
                    task.wait(0.5)
                end
            end
            
            -- Step 4: Collect loot
            if AutoHeistSettings.autoLoot then
                for i, lootData in ipairs(heistData.lootParts) do
                    if lootData.instance and lootData.instance.Parent then
                        logMessage("AutoHeist", "กำลังเก็บของ " .. i .. "/" .. #heistData.lootParts .. ": " .. lootData.name)
                        safeTeleport(lootData.position, function()
                            task.wait(0.5)
                            -- Try to touch the part or find associated prompts
                            local touchTransmitter = lootData.instance:FindFirstChildOfClass("TouchTransmitter")
                            if touchTransmitter then
                                lootData.instance:TouchTransmitter()
                            end
                            
                            -- Look for proximity prompts on loot
                            local prompt = lootData.instance:FindFirstChildOfClass("ProximityPrompt")
                            if prompt then
                                interactWithProximityPrompt(prompt)
                            end
                        end)
                        task.wait(1)
                    end
                end
            end
            
            logMessage("AutoHeist", "การปล้น " .. heistName .. " เสร็จสิ้น!")
        end)
    else
        logMessage("AutoHeist", "ไม่พบตำแหน่งของ Heist: " .. heistName)
        return false
    end
    
    return true
end

local function executeAllHeists()
    logMessage("AutoHeist", "เริ่มต้นการปล้นทั้งหมด...")
    
    for heistName, heistData in pairs(StoredData.HeistLocations) do
        if AutoHeistSettings.enabled then
            logMessage("AutoHeist", "กำลังดำเนินการปล้น: " .. heistName)
            executeHeistSequence(heistName)
            task.wait(3) -- รอระหว่าง heist
        else
            break
        end
    end
    
    logMessage("AutoHeist", "การปล้นทั้งหมดเสร็จสิ้น!")
end

-- ================= ENHANCED SCANNING FUNCTION =================
local function performEnhancedScan()
    logMessage("System", "เริ่มต้นการสแกนแบบ Enhanced...")
    
    -- Clear previous data
    StoredData = {
        HeistLocations = {},
        ProximityPrompts = {},
        RemoteEvents = {},
        RemoteFunctions = {},
        LootParts = {},
        Scripts = {},
        TouchParts = {}
    }
    
    -- Scan Heists folder
    local heistsFolder = Workspace:FindFirstChild(CONFIG.HEISTS_BASE_PATH)
    if heistsFolder then
        for _, heistName in ipairs(CONFIG.TARGET_HEISTS) do
            local heistFolder = heistsFolder:FindFirstChild(heistName)
            if heistFolder then
                storeHeistData(heistFolder, heistName)
            else
                logMessage("Error", "ไม่พบ Heist: " .. heistName)
            end
        end
    else
        logMessage("Error", "ไม่พบ Heists folder")
    end
    
    -- Scan ReplicatedStorage for additional remotes
    if ReplicatedStorage then
        for _, descendant in ipairs(ReplicatedStorage:GetDescendants()) do
            if descendant:IsA("RemoteEvent") then
                table.insert(StoredData.RemoteEvents, descendant)
            elseif descendant:IsA("RemoteFunction") then
                table.insert(StoredData.RemoteFunctions, descendant)
            end
        end
    end
    
    -- Summary
    local totalHeists = 0
    for _ in pairs(StoredData.HeistLocations) do totalHeists = totalHeists + 1 end
    
    logMessage("System", string.format("สแกนเสร็จสิ้น! พบ: Heists: %d, Prompts: %d, Events: %d, Functions: %d, Loot: %d", 
        totalHeists, #StoredData.ProximityPrompts, #StoredData.RemoteEvents, #StoredData.RemoteFunctions, #StoredData.LootParts))
end

-- ================= SIMPLE UI CREATION =================
local function createEnhancedUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "RyntazHub_AutoHeist_V3"
    screenGui.Parent = Player:WaitForChild("PlayerGui")
    screenGui.ResetOnSpawn = false
    
    mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0.4, 0, 0.6, 0)
    mainFrame.Position = UDim2.new(0.3, 0, 0.2, 0)
    mainFrame.BackgroundColor3 = THEME_COLORS.Background
    mainFrame.BorderSizePixel = 1
    mainFrame.BorderColor3 = THEME_COLORS.Accent
    mainFrame.Parent = screenGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = mainFrame
    
    -- Title
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, 0, 0, 30)
    titleLabel.BackgroundColor3 = THEME_COLORS.Primary
    titleLabel.Text = "RyntazHub Auto Heist V3.0"
    titleLabel.TextColor3 = THEME_COLORS.Accent
    titleLabel.Font = Enum.Font.Michroma
    titleLabel.TextSize = 16
    titleLabel.Parent = mainFrame
    
    -- Output container
    outputContainer = Instance.new("ScrollingFrame")
    outputContainer.Size = UDim2.new(1, -10, 1, -80)
    outputContainer.Position = UDim2.new(0, 5, 0, 35)
    outputContainer.BackgroundColor3 = THEME_COLORS.Primary
    outputContainer.BorderSizePixel = 0
    outputContainer.ScrollBarThickness = 6
    outputContainer.Parent = mainFrame
    
    local layout = Instance.new("UIListLayout")
    layout.Parent = outputContainer
    layout.Padding = UDim.new(0, 2)
    
    -- Control buttons
    local buttonFrame = Instance.new("Frame")
    buttonFrame.Size = UDim2.new(1, 0, 0, 40)
    buttonFrame.Position = UDim2.new(0, 0, 1, -40)
    buttonFrame.BackgroundColor3 = THEME_COLORS.Primary
    buttonFrame.Parent = mainFrame
    
    local scanBtn = Instance.new("TextButton")
    scanBtn.Size = UDim2.new(0.2, -2, 0.8, 0)
    scanBtn.Position = UDim2.new(0, 5, 0.1, 0)
    scanBtn.BackgroundColor3 = THEME_COLORS.Secondary
    scanBtn.TextColor3 = THEME_COLORS.Text
    scanBtn.Text = "SCAN"
    scanBtn.Font = Enum.Font.SourceSansBold
    scanBtn.Parent = buttonFrame
    
    local teleportBtn = Instance.new("TextButton")
    teleportBtn.Size = UDim2.new(0.2, -2, 0.8, 0)
    teleportBtn.Position = UDim2.new(0.2, 5, 0.1, 0)
    teleportBtn.BackgroundColor3 = THEME_COLORS.Secondary
    teleportBtn.TextColor3 = THEME_COLORS.Text
    teleportBtn.Text = "TELEPORT"
    teleportBtn.Font = Enum.Font.SourceSansBold
    teleportBtn.Parent = buttonFrame
    
    local autoHeistBtn = Instance.new("TextButton")
    autoHeistBtn.Size = UDim2.new(0.2, -2, 0.8, 0)
    autoHeistBtn.Position = UDim2.new(0.4, 5, 0.1, 0)
    autoHeistBtn.BackgroundColor3 = THEME_COLORS.Secondary
    autoHeistBtn.TextColor3 = THEME_COLORS.Text
    autoHeistBtn.Text = "AUTO HEIST"
    autoHeistBtn.Font = Enum.Font.SourceSansBold
    autoHeistBtn.Parent = buttonFrame
    
    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Size = UDim2.new(0.2, -2, 0.8, 0)
    toggleBtn.Position = UDim2.new(0.6, 5, 0.1, 0)
    toggleBtn.BackgroundColor3 = THEME_COLORS.Secondary
    toggleBtn.TextColor3 = THEME_COLORS.Text
    toggleBtn.Text = "TOGGLE: OFF"
    toggleBtn.Font = Enum.Font.SourceSansBold
    toggleBtn.Parent = buttonFrame
    
    local clearBtn = Instance.new("TextButton")
    clearBtn.Size = UDim2.new(0.2, -2, 0.8, 0)
    clearBtn.Position = UDim2.new(0.8, 5, 0.1, 0)
    clearBtn.BackgroundColor3 = THEME_COLORS.Secondary
    clearBtn.TextColor3 = THEME_COLORS.Text
    clearBtn.Text = "CLEAR"
    clearBtn.Font = Enum.Font.SourceSansBold
    clearBtn.Parent = buttonFrame
    
    -- Button events
    scanBtn.MouseButton1Click:Connect(function()
        task.spawn(performEnhancedScan)
    end)
    
    teleportBtn.MouseButton1Click:Connect(function()
        if next(StoredData.HeistLocations) then
            local firstHeist = next(StoredData.HeistLocations)
            local heistData = StoredData.HeistLocations[firstHeist]
            if heistData.position then
                safeTeleport(heistData.position)
            end
        else
            logMessage("Error", "ไม่พบข้อมูล Heist สำหรับ Teleport")
        end
    end)
    
    autoHeistBtn.MouseButton1Click:Connect(function()
        if AutoHeistSettings.enabled then
            task.spawn(executeAllHeists)
        else
            logMessage("Warning", "Auto Heist ถูกปิดอยู่ กดปุ่ม TOGGLE เพื่อเปิด")
        end
    end)
    
    toggleBtn.MouseButton1Click:Connect(function()
        AutoHeistSettings.enabled = not AutoHeistSettings.enabled
        toggleBtn.Text = "TOGGLE: " .. (AutoHeistSettings.enabled and "ON" or "OFF")
        toggleBtn.BackgroundColor3 = AutoHeistSettings.enabled and THEME_COLORS.Success or THEME_COLORS.Secondary
        logMessage("System", "Auto Heist: " .. (AutoHeistSettings.enabled and "เปิด" or "ปิด"))
    end)
    
    clearBtn.MouseButton1Click:Connect(function()
        for _, child in ipairs(outputContainer:GetChildren()) do
            if child:IsA("TextLabel") then
                child:Destroy()
            end
        end
        allLoggedMessages = {}
        logMessage("System", "ล้างข้อมูลแล้ว")
    end)
end

-- ================= INITIALIZATION =================
logMessage("System", "RyntazHub Auto Heist V3.0 - กำลังเริ่มต้น...")

if CONFIG.SHOW_UI then
    createEnhancedUI()
end

-- Auto scan on start
task.spawn(function()
    task.wait(1)
    performEnhancedScan()
end)

-- Additional utility functions for manual control
_G.RyntazHub = {
    StoredData = StoredData,
    Settings = AutoHeistSettings,
    Functions = {
        scan = performEnhancedScan,
        teleport = safeTeleport,
        executeHeist = executeHeistSequence,
        executeAll = executeAllHeists,
        interactPrompt = interactWithProximityPrompt,
        fireRemote = fireRemoteEvent,
        invokeRemote = invokeRemoteFunction
    }
}

logMessage("System", "Auto Heist System พร้อมใช้งาน! ใช้ _G.RyntazHub สำหรับควบคุมด้วย script")
