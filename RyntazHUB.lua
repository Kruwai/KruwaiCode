-- AutoRob (Super Simplified) - V5.0
-- เน้นการปล้น, เทเลพอร์ต, และ Server Hop (ถ้าต้องการ) - UI น้อยที่สุด

local Player = game:GetService("Players").LocalPlayer
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService") -- สำหรับ ServerHop
local TeleportService = game:GetService("TeleportService") -- สำหรับ ServerHop
local RunService = game:GetService("RunService")

local Character
local Humanoid
local HumanoidRootPart
local currentRobberyCoroutine = nil
local isRobbingGlobally = false

local function waitForCharacter()
    print("[AutoRob V5] Waiting for character...")
    local attempts = 0
    repeat
        attempts = attempts + 1
        if Player and Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") and Player.Character:FindFirstChildOfClass("Humanoid") then
            Character = Player.Character
            Humanoid = Character:FindFirstChildOfClass("Humanoid")
            RootPart = Character:FindFirstChild("HumanoidRootPart")
            if Humanoid and RootPart then print("[AutoRob V5] Character found."); return true end
        end
        task.wait(0.3)
    until attempts > 60
    print("[AutoRob V5] ERROR: Character not found after timeout."); return false
end

Player.CharacterAdded:Connect(function(newChar)
    Character = newChar
    Humanoid = newChar:WaitForChild("Humanoid", 15)
    RootPart = newChar:WaitForChild("HumanoidRootPart", 15)
    print("[AutoRob V5] Character respawned/added.")
    if isRobbingGlobally then -- ถ้ากำลังปล้นอยู่แล้วตัวละครตาย ให้พยายามเริ่ม Heist ปัจจุบันใหม่ หรือ Heist ถัดไป
        print("[AutoRob V5] Character died during robbery. Attempting to resume/restart logic if a sequence was active.")
        -- อาจจะต้องมี Logic เพิ่มเติมเพื่อ Resume ให้ถูกจุด หรือแค่เริ่ม Heist ปัจจุบันใหม่
    end
end)

-- ================= CONFIGURATION (สำคัญมาก - อ้างอิงจาก Log ของคุณ) =================
local HEISTS_BASE_PATH_STRING = "Workspace.Heists"
local TARGET_HEISTS_TO_ROB_SEQUENCE = {"JewelryStore", "Bank", "Casino"}

local HEIST_SPECIFIC_CONFIG = {
    JewelryStore = {
        DisplayName = "ร้านเพชร",
        PathString = HEISTS_BASE_PATH_STRING .. ".JewelryStore",
        EntryTeleportCFrame = nil, -- CFrame.new(-82, 86, 807), -- ไปที่หน้าตู้เลยก็ได้
        RobberyActions = {
            {
                Name = "เก็บเครื่องเพชร", ActionType = "IterateAndFireEvent",
                ItemContainerPath = "EssentialParts.JewelryBoxes",
                RemoteEventPath = "EssentialParts.JewelryBoxes.JewelryManager.Event",
                EventArgsFunc = function(lootInstance) return {lootInstance} end,
                FireCountPerItem = 2, TeleportOffsetPerItem = Vector3.new(0, 1.8, 1.8), -- ใกล้ขึ้น
                DelayBetweenItems = 0.15, DelayBetweenFires = 0.1
            }
        }
    },
    Bank = {
        DisplayName = "ธนาคาร", PathString = HEISTS_BASE_PATH_STRING .. ".Bank",
        EntryTeleportCFrame = CFrame.new(730, 108, 565),
        RobberyActions = {
            {
                Name = "เปิดประตูห้องมั่นคง", ActionType = "Touch", TargetPath = "EssentialParts.VaultDoor.Touch",
                TeleportOffset = Vector3.new(0, 0, -2.2), RobDelayAfter = 1.5
            },
            {
                Name = "เก็บเงิน CashStack", ActionType = "IterateAndFindInteract",
                ItemContainerPath = "Interior.CashStack.Model", ItemNameHint = "Cash", -- จาก Log: Workspace.Heists.Bank.Interior.CashStack.Model.Cash
                InteractionHint = {Type="RemoteEvent", NameHint="CollectCash", Args=function(item) return {item, 1000} end}, -- *** สมมติชื่อ Event และ Args ***
                TeleportOffset = Vector3.new(0,0.5,0), DelayBetweenItems = 0.2, FireCountPerItem = 1
            },
            {
                Name = "เก็บเงิน Model Cash", ActionType = "IterateAndFindInteract",
                ItemContainerPath = "Interior.Model", ItemNameHint = "Cash", -- จาก Log: Workspace.Heists.Bank.Interior.Model.Cash
                InteractionHint = {Type="RemoteEvent", NameHint="CollectMoney", Args=function(item) return {item, 500} end}, -- *** สมมติชื่อ Event และ Args ***
                TeleportOffset = Vector3.new(0,0.5,0), DelayBetweenItems = 0.2, FireCountPerItem = 1
            }
        }
    },
    Casino = {
        DisplayName = "คาสิโน", PathString = HEISTS_BASE_PATH_STRING .. ".Casino",
        EntryTeleportCFrame = CFrame.new(1690, 30, 525),
        RobberyActions = {
            {
                Name = "แฮ็กคอมพิวเตอร์", ActionType = "ProximityPrompt", TargetPath = "Interior.HackComputer.HackComputer", -- จาก Log
                ProximityPromptActionHint = "Hack", HoldDuration = 2.0, TeleportOffset = Vector3.new(0,1,-1.5), RobDelayAfter = 1.0
            },
            {
                Name = "เก็บเงิน CashGiver", ActionType = "IterateAndFindInteract",
                ItemContainerPath = "EssentialParts.CasinoDoor", ItemNameHint = "CashGiver", -- จาก Log
                InteractionHint = {Type="RemoteEvent", NameHint="GiveCash", Args=function(item) return {} end}, -- *** สมมติ ***
                TeleportOffset = Vector3.new(0,0.5,0), DelayBetweenItems = 0.2, FireCountPerItem = 1
            },
            {
                Name = "เก็บเงินใน Interior", ActionType = "IterateAndFindInteract",
                ItemContainerPath = "Interior", ItemNameHint = "Cash", -- จาก Log: Model.Cash และ CashStack.Model.Cash
                InteractionHint = {Type="RemoteEvent", NameHint="CollectCasinoCash", Args=function(item) return {item} end}, -- *** สมมติ ***
                TeleportOffset = Vector3.new(0,0.5,0), DelayBetweenItems = 0.2, FireCountPerItem = 1
            }
        }
    }
}

-- ================= HELPER FUNCTIONS =================
local function findInstance(pathStringOrInstance, childPath)
    local root = nil
    if type(pathStringOrInstance) == "string" then
        local current = game
        for component in pathStringOrInstance:gmatch("([^%.]+)") do
            if current then current = current:FindFirstChild(component) else return nil end
        end
        root = current
    elseif typeof(pathStringOrInstance) == "Instance" then
        root = pathStringOrInstance
    end
    if not root then return nil end
    return childPath and root:FindFirstChild(childPath, true) or root
end

local function teleportTo(targetCFrame)
    if not RootPart then print("[Teleport] RootPart is nil."); return false end
    local s,e = pcall(function() RootPart.CFrame = targetCFrame end)
    if not s then print("[Teleport] Failed:", e); return false end
    RunService.Stepped:Wait() -- Wait for physics update
    return true
end

local function findRemote(parentInst, nameHint)
    if not parentInst then return nil end
    for _, D in ipairs(parentInst:GetDescendants()) do if D:IsA("RemoteEvent") and D.Name:lower():match(nameHint:lower()) then return D end end
    for _, D in ipairs(parentInst:GetDescendants()) do if D:IsA("RemoteFunction") and D.Name:lower():match(nameHint:lower()) then return D end end
    return nil
end

local function findPrompt(parentInst, actionHint)
    if not parentInst then return nil end
    for _, D in ipairs(parentInst:GetDescendants()) do
        if D:IsA("ProximityPrompt") then
            if D.ActionText and D.ActionText:lower():match(actionHint:lower()) then return D
            elseif D.ObjectText and D.ObjectText:lower():match(actionHint:lower()) then return D end
        end
    end
    return nil
end

-- ================= ROBBERY LOGIC =================
local function attemptSingleRobberyAction(actionConfig, heistFolder)
    if not (Character and Humanoid and Humanoid.Health > 0) then print("[Robbery] Character dead or missing."); return false end
    print(string.format("  [Action] %s", actionConfig.Name))

    local targetInstance
    if actionConfig.TargetPath then
        targetInstance = findInstance(heistFolder, actionConfig.TargetPath)
        if not targetInstance then print("    [Error] TargetPath not found: " .. actionConfig.TargetPath); return false end
    end

    local robSuccessful = false
    if not teleportTo((targetInstance and (targetInstance:IsA("Model") and targetInstance:GetPivot() or targetInstance.CFrame) or heistFolder:GetPivot()) * CFrame.new(actionConfig.TeleportOffset or Vector3.new())) then return false end

    if actionConfig.ActionType == "Touch" and targetInstance then
        if typeof(firetouchinterest) == "function" and targetInstance:IsA("BasePart") then
            print("    Firing touch interest for:", targetInstance.Name)
            pcall(firetouchinterest, targetInstance, RootPart, 0); task.wait(0.05)
            pcall(firetouchinterest, targetInstance, RootPart, 1); robSuccessful = true
        else print("    firetouchinterest not available or target not BasePart.") end
    elseif actionConfig.ActionType == "ProximityPrompt" and targetInstance then
        local prompt = findPrompt(targetInstance, actionConfig.ProximityPromptActionHint or targetInstance.Name)
        if prompt then
            if typeof(fireproximityprompt) == "function" then
                print(string.format("    Firing ProximityPrompt: %s (Hold: %.1fs)", prompt.ActionText or prompt.ObjectText or "Unknown", actionConfig.HoldDuration or 0))
                pcall(fireproximityprompt, prompt, actionConfig.HoldDuration or 0); robSuccessful = true
            else print("    fireproximityprompt not available.") end
        else print("    ProximityPrompt not found for:", targetInstance.Name, "Hint:", actionConfig.ProximityPromptActionHint) end
    elseif (actionConfig.ActionType == "RemoteEvent" or actionConfig.ActionType == "IterateAndFireEvent") then
        local itemsToProcess = {}
        local remoteEventInstance
        local searchBaseForItems = actionConfig.ItemContainerPath and findInstance(heistFolder, actionConfig.ItemContainerPath) or heistFolder

        if not searchBaseForItems then print("    [Error] ItemContainerPath not found: " .. (actionConfig.ItemContainerPath or "N/A")); return false end

        if actionConfig.ActionType == "IterateAndFireEvent" then
            if actionConfig.ItemQuery then itemsToProcess = actionConfig.ItemQuery(searchBaseForItems)
            else for _,child in ipairs(searchBaseForItems:GetChildren()) do if (child:IsA("Model") or child:IsA("BasePart")) and (not actionConfig.ItemNameHint or child.Name:lower():match(actionConfig.ItemNameHint:lower())) then table.insert(itemsToProcess, child) end end end
        else -- SingleEvent
            if targetInstance then table.insert(itemsToProcess, targetInstance)
            else print("    [Error] TargetPath needed for SingleEvent if not IterateAndFireEvent on ItemContainerPath."); return false end
        end
        
        if #itemsToProcess == 0 then print("    No items found for: " .. actionConfig.Name); return true end -- No items to rob, consider it "success" for this action

        if actionConfig.RemoteEventPath then remoteEventInstance = findInstance(Workspace, actionConfig.RemoteEventPath) -- Path from Workspace
        elseif actionConfig.RemoteEventNameHint then remoteEventInstance = findRemote(searchBaseForItems, actionConfig.RemoteEventNameHint) or findRemote(heistFolder, actionConfig.RemoteEventNameHint) end

        if not remoteEventInstance or not remoteEventInstance:IsA("RemoteEvent") then print("    [Error] RemoteEvent not found for action:", actionConfig.Name, "(Path/Hint:", actionConfig.RemoteEventPath or actionConfig.RemoteEventNameHint or "N/A", ")"); return false end

        for i, itemInst in ipairs(itemsToProcess) do
            if not (Character and Humanoid.Health > 0 and currentRobberyCoroutine) then print("    Robbery sequence interrupted."); return false end
            if not teleportTo((itemInst:IsA("Model") and itemInst:GetPivot() or itemInst.CFrame) * CFrame.new(actionConfig.TeleportOffsetPerItem or actionConfig.TeleportOffset or Vector3.new())) then return false end
            
            local argsToFire = {}; if actionConfig.EventArgsFunc then argsToFire = actionConfig.EventArgsFunc(itemInst) or {} end
            print(string.format("    Firing RE: %s for %s (Item %d/%d)", remoteEventInstance.Name, itemInst.Name, i, #itemsToProcess))
            for fc = 1, actionConfig.FireCountPerItem or 1 do
                if not (Character and Humanoid.Health > 0 and currentRobberyCoroutine) then print("    Robbery interrupted during fire loop."); return false end
                local s,e = pcall(function() remoteEventInstance:FireServer(unpack(argsToFire)) end)
                if not s then print("      Error firing event: "..tostring(e)) end
                task.wait(actionConfig.DelayBetweenFires or 0.05)
            end
            robSuccessful = true
            if #itemsToProcess > 1 and i < #itemsToProcess then task.wait(actionConfig.DelayBetweenItems or 0.1) end
        end
    end

    if robSuccessful then print(string.format("    Action '%s' completed.", actionConfig.Name))
    else print(string.format("    Action '%s' failed or no interaction method.", actionConfig.Name)) end
    if actionConfig.RobDelayAfter then task.wait(actionConfig.RobDelayAfter) end
    return robSuccessful
end

function executeFullHeistRobbery(heistName)
    local config = HEIST_SPECIFIC_CONFIG[heistName]
    if not config then print("[Heist] No config for: " .. heistName); return false end
    local heistFolder = findInstance(config.PathString)
    if not heistFolder then print("[Heist] Heist folder not found: " .. config.PathString); return false end

    print(string.format("--- Starting Heist: %s ---", config.DisplayName))
    if config.EntryTeleportCFrame and RootPart then
        if not teleportTo(config.EntryTeleportCFrame) then return false end
        task.wait(0.3)
    end

    for i, actionConfig in ipairs(config.RobberyActions or {}) do
        if not currentRobberyCoroutine then print("[Heist] Robbery sequence cancelled by user."); return false end
        if not (Character and Humanoid and Humanoid.Health > 0) then print("[Heist] Character died, stopping heist: " .. config.DisplayName); return false end
        
        if not attemptSingleRobberyAction(actionConfig, heistFolder) then
            print(string.format("[Heist] Action '%s' in %s failed. Stopping this heist.", actionConfig.Name, config.DisplayName))
            return false
        end
        task.wait(0.1) 
    end
    print(string.format("--- Heist: %s - Sequence Completed ---", config.DisplayName))
    return true
end

local function ServerHop()
    print("[ServerHop] Attempting to server hop...")
    local success, err = pcall(function()
        local servers = {}; local req = HttpService:RequestAsync({Url = "https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?sortOrder=Desc&limit=100&excludeFullGames=true", Method = "GET"})
        if not req or not req.Success or not req.Body then print("[ServerHop] Failed to get server list:", req and req.Body or "No response"); return end
        local body = HttpService:JSONDecode(req.Body)
        if body and body.data then for _, v in next, body.data do if type(v) == "table" and tonumber(v.playing) and tonumber(v.maxPlayers) and v.playing < v.maxPlayers and v.id ~= game.JobId then table.insert(servers, 1, v.id) end end end
        print("[ServerHop] Found", #servers, "available servers.")
        if #servers > 0 then TeleportService:TeleportToPlaceInstance(game.PlaceId, servers[math.random(1, #servers)], Player)
        else print("[ServerHop] No other servers. Rejoining."); if #Player:GetPlayers() <= 1 then Player:Kick("Rejoining..."); task.wait(1); TeleportService:Teleport(game.PlaceId, Player) else TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, Player) end end
    end)
    if not success then print("[ServerHop] Pcall failed:", err); TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, Player) end
end

function executeAllRobberiesAndHop()
    if isRobbingGlobally then print("[AutoRob] Sequence already running."); return end
    isRobbingGlobally = true
    currentRobberyCoroutine = coroutine.running()
    print("--- Starting Full Auto-Robbery Sequence (V5.0) ---")
    local overallStartTime = tick()
    
    for i, heistName in ipairs(ROB_ORDER) do
        if not currentRobberyCoroutine then print("[AutoRob] Full sequence cancelled by stop."); break end
        if not (Character and Humanoid and Humanoid.Health > 0) then print("[AutoRob] Character died, stopping sequence."); break end
        
        print(string.format("[AutoRob] Preparing for heist: %s (%d/%d)", HEIST_SPECIFIC_CONFIG[heistName] and HEIST_SPECIFIC_CONFIG[heistName].DisplayName or heistName, i, #ROB_ORDER))
        if not executeFullHeistRobbery(heistName) then
            print(string.format("[AutoRob] Heist %s failed or was interrupted.", HEIST_SPECIFIC_CONFIG[heistName] and HEIST_SPECIFIC_CONFIG[heistName].DisplayName or heistName))
        end
        
        if i < #ROB_ORDER and currentRobberyCoroutine then
            local waitTime = math.random(3, 7) 
            print(string.format("[AutoRob] Waiting %.1fs before next heist...", waitTime))
            local waited = 0
            while waited < waitTime and currentRobberyCoroutine do task.wait(0.1); waited = waited + 0.1 end
        end
    end
    
    if currentRobberyCoroutine then 
        print(string.format("--- Full Auto-Robbery Sequence Completed in %.2f seconds. Initiating Server Hop. ---", tick() - overallStartTime))
        ServerHop()
    end
    isRobbingGlobally = false
    currentRobberyCoroutine = nil
end

local function stopRobbery()
    if currentRobberyCoroutine then
        isRobbingGlobally = false
        task.cancel(currentRobberyCoroutine) -- Attempt to cancel
        currentRobberyCoroutine = nil
        print("[AutoRob] Robbery sequence stopped by user.")
    else
        print("[AutoRob] No robbery sequence is currently running.")
    end
end


-- ================= UI (Very Simple) =================
local function createControlUI()
    if CoreGui:FindFirstChild("RyntazAutoRobV5_Control") then CoreGui.RyntazAutoRobV5_Control:Destroy() end
    local screenGui = Instance.new("ScreenGui", CoreGui)
    screenGui.Name = "RyntazAutoRobV5_Control"
    screenGui.ResetOnSpawn = false
    screenGui.DisplayOrder = 1000

    local main = Instance.new("Frame", screenGui)
    main.Size = UDim2.new(0, 200, 0, 100)
    main.Position = UDim2.new(0.02, 0, 0.5, -50)
    main.BackgroundColor3 = Color3.fromRGB(30,30,35)
    main.BorderColor3 = Color3.fromRGB(80,180,255)
    main.BorderSizePixel = 1
    local c = Instance.new("UICorner", main); c.CornerRadius = UDim.new(0,5)
    local l = Instance.new("UIListLayout", main); l.Padding = UDim.new(0,5); l.HorizontalAlignment = Enum.HorizontalAlignment.Center; l.VerticalAlignment = Enum.VerticalAlignment.Center

    local title = Instance.new("TextLabel", main)
    title.Size = UDim2.new(1,-10,0,20); title.Text = "Ryntaz AutoRob V5"; title.TextColor3 = Color3.fromRGB(0,255,120); title.Font=Enum.Font.Michroma; title.TextSize=14; title.BackgroundTransparency=1

    local startButton = createStyledButton(main, "เริ่มปล้นทั้งหมด", UDim2.new(0.9,0,0,30), UDim2.new(), Color3.fromRGB(0,150,80), Color3.new(1,1,1), 13)
    startButton.MouseButton1Click:Connect(function()
        if not isRobbingGlobally then
            task.spawn(executeAllRobberiesAndHop)
        else
            print("[AutoRob] Robbery is already in progress.")
        end
    end)

    local stopButton = createStyledButton(main, "หยุดปล้น", UDim2.new(0.9,0,0,30), UDim2.new(), Color3.fromRGB(180,50,50), Color3.new(1,1,1), 13)
    stopButton.MouseButton1Click:Connect(stopRobbery)
end


-- ================= INITIALIZATION & AUTO-START =================
local autoStartRobbery = true -- ตั้งเป็น true เพื่อให้เริ่มปล้นอัตโนมัติ

if waitForCharacter() then
    createControlUI() -- สร้าง UI ควบคุม
    if autoStartRobbery then
        print("[AutoRob V5] Auto-start enabled. Waiting 3 seconds then starting sequence...")
        task.wait(3)
        if not isRobbingGlobally then -- เช็คอีกครั้งเผื่อผู้ใช้กดปุ่มไปแล้ว
             task.spawn(executeAllRobberiesAndHop)
        end
    else
        print("[AutoRob V5] Auto-start disabled. Click 'เริ่มปล้นทั้งหมด' button or call 'executeAllRobberiesAndHop()' manually.")
    end
else
    print("[AutoRob V5] Could not start: Character failed to load.")
end
