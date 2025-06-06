-- AutoRob (Reliable Sequence) - V5.3
-- เน้นการเทเลพอร์ตไปยังจุดโต้ตอบที่ถูกต้อง, ปล้น, รอผลลัพธ์, แล้วไปต่อ

local Player = game:GetService("Players").LocalPlayer
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")

local Character
local Humanoid
local HumanoidRootPart
local currentRobberyCoroutine = nil
local isRobbingGlobally = false -- ใช้ติดตามสถานะการปล้นโดยรวม

local function waitForCharacter()
    print("[AutoRob V5.3] Waiting for character...")
    local attempts = 0
    repeat
        attempts = attempts + 1
        if Player and Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") and Player.Character:FindFirstChildOfClass("Humanoid") then
            Character = Player.Character
            Humanoid = Character:FindFirstChildOfClass("Humanoid")
            RootPart = Character:FindFirstChild("HumanoidRootPart")
            if Humanoid and RootPart then print("[AutoRob V5.3] Character found."); return true end
        end
        task.wait(0.3)
    until attempts > 60
    print("[AutoRob V5.3] ERROR: Character not found after timeout."); return false
end

Player.CharacterAdded:Connect(function(newChar)
    Character = newChar
    Humanoid = newChar:WaitForChild("Humanoid", 15)
    RootPart = newChar:WaitForChild("HumanoidRootPart", 15)
    print("[AutoRob V5.3] Character respawned/added.")
    if isRobbingGlobally and currentRobberyCoroutine then
        print("[AutoRob V5.3] Character died during robbery. Stopping current sequence.")
        task.cancel(currentRobberyCoroutine)
        currentRobberyCoroutine = nil
        isRobbingGlobally = false
    end
end)

-- ================= CONFIGURATION (สำคัญมาก - คุณต้องปรับแก้ให้ตรงกับเกม) =================
local HEISTS_BASE_PATH_STRING = "Workspace.Heists"
local TARGET_HEISTS_TO_ROB_SEQUENCE = {"JewelryStore", "Bank", "Casino"}

local HEIST_SPECIFIC_CONFIG = {
    JewelryStore = {
        DisplayName = "ร้านเพชร", PathString = HEISTS_BASE_PATH_STRING .. ".JewelryStore",
        EntryTeleportCFrame = CFrame.new(-82.8, 85.5, 807.5), -- จุดยืนกลางๆ ร้านเพชร (ปรับให้ดี)
        RobberyActions = {
            {
                Name = "เก็บเครื่องเพชร", ActionType = "IterateAndFireEvent",
                ItemContainerPath = "EssentialParts.JewelryBoxes", -- Path ภายใน Heist Folder
                RemoteEventPath = "EssentialParts.JewelryBoxes.JewelryManager.Event", -- Path จาก Log
                EventArgsFunc = function(lootInstance) return {lootInstance} end,
                FireCountPerItem = 2,
                TeleportOffsetPerItem = Vector3.new(0, -1, 2.5), -- ยืนหน้าตู้โชว์แต่ละตู้ (ปรับให้แม่นยำ)
                DelayBetweenItems = 0.7, -- หน่วงเวลาระหว่างปล้นแต่ละตู้ให้นานขึ้น
                DelayBetweenFires = 0.2,
                RobDelayAfter = 0.5 -- หน่วงเวลาหลังปล้นตู้สุดท้ายของ Action นี้
            }
        }
    },
    Bank = {
        DisplayName = "ธนาคาร", PathString = HEISTS_BASE_PATH_STRING .. ".Bank",
        EntryTeleportCFrame = CFrame.new(730, 108, 565), -- หน้าธนาคาร
        RobberyActions = {
            {
                Name = "เปิดประตูห้องมั่นคง", ActionType = "Touch", TargetPath = "EssentialParts.VaultDoor.Touch",
                TeleportOffset = Vector3.new(0, 0, -2.2), RobDelayAfter = 3.0 -- เพิ่ม Delay รอประตูเปิดนานขึ้น
            },
            {
                Name = "เก็บเงิน CashStack", ActionType = "IterateAndFindInteract",
                ItemContainerPath = "Interior.CashStack.Model", ItemNameHint = "Cash",
                InteractionHint = {Type="RemoteEvent", NameHint="CollectCash", Args=function(item) return {item, 1000} end}, -- *** ต้องหา Event จริง ***
                TeleportOffset = Vector3.new(0,0.5,0), DelayBetweenItems = 0.8, FireCountPerItem = 1, RobDelayAfter = 0.5
            },
            {
                Name = "เก็บเงิน Model Cash", ActionType = "IterateAndFindInteract",
                ItemContainerPath = "Interior.Model", ItemNameHint = "Cash",
                InteractionHint = {Type="RemoteEvent", NameHint="CollectMoney", Args=function(item) return {item, 500} end}, -- *** ต้องหา Event จริง ***
                TeleportOffset = Vector3.new(0,0.5,0), DelayBetweenItems = 0.8, FireCountPerItem = 1, RobDelayAfter = 0.5
            }
        }
    },
    Casino = {
        DisplayName = "คาสิโน", PathString = HEISTS_BASE_PATH_STRING .. ".Casino",
        EntryTeleportCFrame = CFrame.new(1690, 30, 525),
        RobberyActions = {
            {
                Name = "แฮ็กคอมพิวเตอร์", ActionType = "ProximityPrompt", TargetPath = "Interior.HackComputer.HackComputer",
                ProximityPromptActionHint = "Hack", HoldDuration = 3.0, TeleportOffset = Vector3.new(0,1,-1.8), RobDelayAfter = 2.0
            },
            {
                Name = "เก็บเงิน CashGiver (ถ้ามี)", ActionType = "IterateAndFindInteract",
                ItemContainerPath = "EssentialParts.CasinoDoor", ItemNameHint = "CashGiver",
                InteractionHint = {Type="RemoteEvent", NameHint="GiveMyCash", Args=function(item) return {} end}, -- *** สมมติ ***
                TeleportOffset = Vector3.new(0,0.5,0), DelayBetweenItems = 0.5, FireCountPerItem = 1, RobDelayAfter = 0.3
            },
            {
                Name = "เก็บเงินในห้องนิรภัย", ActionType = "IterateAndFindInteract",
                ItemContainerPath = "Interior.Vault", ItemNameHint = "Cash", -- ต้องหา Path จริงของ Vault
                InteractionHint = {Type="RemoteEvent", NameHint="TakeVaultCash", Args=function(item) return {item} end}, -- *** สมมติ ***
                TeleportOffset = Vector3.new(0,0.5,0), DelayBetweenItems = 0.8, FireCountPerItem = 1, RobDelayAfter = 0.5
            }
        }
    }
}

local function findInstance(pathStringOrInstance, childPath) local root=nil;if type(pathStringOrInstance)=="string"then local current=game;for component in pathStringOrInstance:gmatch("([^%.]+)")do if current then current=current:FindFirstChild(component)else return nil end end;root=current elseif typeof(pathStringOrInstance)=="Instance"then root=pathStringOrInstance end;if not root then return nil end;return childPath and root:FindFirstChild(childPath,true)or root end
local function teleportTo(targetCFrame, actionName)
    if not RootPart then print(string.format("[Teleport-%s] RootPart is nil.", actionName or "General")); return false end
    print(string.format("[Teleport-%s] Moving to %.1f, %.1f, %.1f", actionName or "General", targetCFrame.X, targetCFrame.Y, targetCFrame.Z))
    local success, err = pcall(function() RootPart.CFrame = targetCFrame end)
    if not success then print(string.format("[Teleport-%s] Failed: %s", actionName or "General", err)); return false end
    local arrived = false
    local timeout = 0
    repeat -- รอให้ตัวละครไปถึงตำแหน่งจริงๆ หรือใกล้เคียง
        task.wait(0.05)
        timeout = timeout + 0.05
        if RootPart and (RootPart.Position - targetCFrame.Position).Magnitude < 2 then
            arrived = true
        end
    until arrived or timeout > 2 -- รอสูงสุด 2 วินาที
    if not arrived then print(string.format("[Teleport-%s] Warning: May not have reached exact CFrame.", actionName or "General")) end
    task.wait(0.15) -- หน่วงเพิ่มเล็กน้อย
    return true
end
local function findRemote(parentInst,nameHint)if not parentInst then return nil end;for _,D in ipairs(parentInst:GetDescendants())do if D:IsA("RemoteEvent")and D.Name:lower():match(nameHint:lower())then return D end end;for _,D in ipairs(parentInst:GetDescendants())do if D:IsA("RemoteFunction")and D.Name:lower():match(nameHint:lower())then return D end end;return nil end
local function findPrompt(parentInst,actionHint)if not parentInst then return nil end;for _,D in ipairs(parentInst:GetDescendants())do if D:IsA("ProximityPrompt")then if D.ActionText and D.ActionText:lower():match(actionHint:lower())then return D elseif D.ObjectText and D.ObjectText:lower():match(actionHint:lower())then return D end end end;return nil end

local function attemptSingleRobberyAction(actionConfig, heistFolder, heistDisplayName)
    if not (Character and Humanoid and HumanoidRootPart and Humanoid.Health > 0) then print(string.format("[%s] Character dead/missing. Skipping action: %s", heistDisplayName, actionConfig.Name)); return false end
    print(string.format("[%s] Action: %s", heistDisplayName, actionConfig.Name))

    local targetInstance; local teleportBaseCFrame
    if actionConfig.TargetPath then
        targetInstance = findInstance(heistFolder, actionConfig.TargetPath)
        if not targetInstance then print(string.format("  [Error-%s] TargetPath not found: %s", heistDisplayName, actionConfig.TargetPath)); return false end
        teleportBaseCFrame = (targetInstance:IsA("Model") and targetInstance:GetPivot() or targetInstance.CFrame)
    elseif actionConfig.ActionType:match("Iterate") then
        -- For iterate types, teleport will happen per item. This is a general TP for the area if needed.
        teleportBaseCFrame = heistFolder:GetPivot() -- Default to heist folder pivot
    else
         print(string.format("  [Error-%s] Action '%s' needs TargetPath or is Iterate type.", heistDisplayName, actionConfig.Name)); return false
    end

    if not teleportTo(teleportBaseCFrame * CFrame.new(actionConfig.TeleportOffset or Vector3.new()), actionConfig.Name) then return false end

    local robSuccessful = false
    if actionConfig.ActionType == "Touch" and targetInstance then
        if typeof(firetouchinterest) == "function" and targetInstance:IsA("BasePart") then print("    Firing touch interest for:", targetInstance.Name); pcall(firetouchinterest, targetInstance, RootPart, 0); task.wait(0.05); pcall(firetouchinterest, targetInstance, RootPart, 1); robSuccessful = true else print("    firetouchinterest not available or target not BasePart.") end
    elseif actionConfig.ActionType == "ProximityPrompt" and targetInstance then
        local prompt = findPrompt(targetInstance, actionConfig.ProximityPromptActionHint or targetInstance.Name)
        if prompt then if typeof(fireproximityprompt) == "function" then print(string.format("    Firing PP: %s (Hold: %.1fs)", prompt.ActionText or prompt.ObjectText or "Unknown", actionConfig.HoldDuration or 0)); pcall(fireproximityprompt, prompt, actionConfig.HoldDuration or 0); robSuccessful = true else print("    fireproximityprompt not available.") end else print("    ProximityPrompt not found for:", targetInstance.Name, "Hint:", actionConfig.ProximityPromptActionHint) end
    elseif (actionConfig.ActionType == "RemoteEvent" or actionConfig.ActionType == "IterateAndFireEvent") then
        local itemsToProcess = {}; local remoteEventInstance; local searchBaseForItems = actionConfig.ItemContainerPath and findInstance(heistFolder, actionConfig.ItemContainerPath) or heistFolder
        if not searchBaseForItems then print("    [Error] ItemContainerPath not found: " .. (actionConfig.ItemContainerPath or "N/A")); return false end
        if actionConfig.ActionType == "IterateAndFireEvent" then if actionConfig.ItemQuery then itemsToProcess = actionConfig.ItemQuery(searchBaseForItems) else for _,child in ipairs(searchBaseForItems:GetChildren()) do if (child:IsA("Model") or child:IsA("BasePart")) and (not actionConfig.ItemNameHint or child.Name:lower():match(actionConfig.ItemNameHint:lower())) then table.insert(itemsToProcess, child) end end end
        else if targetInstance then table.insert(itemsToProcess, targetInstance) else print("    [Error] TargetPath needed for SingleEvent."); return false end end
        if #itemsToProcess == 0 then print("    No items found for: " .. actionConfig.Name); return true end
        if actionConfig.RemoteEventPath then remoteEventInstance = findInstance(Workspace, actionConfig.RemoteEventPath) or findInstance(searchBaseForItems, actionConfig.RemoteEventPath) or (itemsToProcess[1] and itemsToProcess[1]:FindFirstChild(actionConfig.RemoteEventPath, true))
        elseif actionConfig.RemoteEventNameHint then remoteEventInstance = findRemote(itemsToProcess[1], actionConfig.RemoteEventNameHint) or findRemote(itemsToProcess[1] and itemsToProcess[1].Parent, actionConfig.RemoteEventNameHint) or findRemote(heistFolder, actionConfig.RemoteEventNameHint) end
        if not remoteEventInstance or not remoteEventInstance:IsA("RemoteEvent") then print("    [Error] RemoteEvent not found for action:", actionConfig.Name, "(Path/Hint:", actionConfig.RemoteEventPath or actionConfig.RemoteEventNameHint or "N/A", ")"); return false end
        for i, itemInst in ipairs(itemsToProcess) do if not (Character and Humanoid.Health > 0 and currentRobberyCoroutine) then print("    Robbery sequence interrupted."); return false end; if not teleportTo((itemInst:IsA("Model") and itemInst:GetPivot() or itemInst.CFrame) * CFrame.new(actionConfig.TeleportOffsetPerItem or actionConfig.TeleportOffset or Vector3.new()), actionConfig.Name .. " Item " .. i) then return false end; local argsToFire = {}; if actionConfig.EventArgsFunc then argsToFire = actionConfig.EventArgsFunc(itemInst) or {} end; print(string.format("    Firing RE: %s for %s (Item %d/%d)", remoteEventInstance.Name, itemInst.Name, i, #itemsToProcess)); for fc = 1, actionConfig.FireCountPerItem or 1 do if not (Character and Humanoid.Health > 0 and currentRobberyCoroutine) then print("    Robbery interrupted fire loop."); return false end; local s,e = pcall(function() remoteEventInstance:FireServer(unpack(argsToFire)) end); if not s then print("      Error firing: "..tostring(e)) end; task.wait(actionConfig.DelayBetweenFires or 0.05) end; robSuccessful = true; if #itemsToProcess > 1 and i < #itemsToProcess then task.wait(actionConfig.DelayBetweenItems or 0.1) end end
    end
    if robSuccessful then print(string.format("    Action '%s' completed.", actionConfig.Name)) else print(string.format("    Action '%s' failed or no interaction.", actionConfig.Name)) end
    if actionConfig.RobDelayAfter then print(string.format("    Waiting %.2fs after action '%s'", actionConfig.RobDelayAfter, actionConfig.Name)); task.wait(actionConfig.RobDelayAfter) end
    return robSuccessful
end

function executeFullHeistRobbery(heistName)
    local config = HEIST_SPECIFIC_CONFIG[heistName]; if not config then print("[Heist] No config for: " .. heistName); return false end
    local heistFolder = findInstance(config.PathString); if not heistFolder then print("[Heist] Heist folder not found: " .. config.PathString); return false end
    print(string.format("--- Starting Heist: %s ---", config.DisplayName))
    if config.EntryTeleportCFrame and RootPart then if not teleportTo(config.EntryTeleportCFrame, config.DisplayName .. " Entry") then return false end; task.wait(0.3) end
    for i, actionConfig in ipairs(config.RobberyActions or {}) do
        if not currentRobberyCoroutine then print("[Heist] Robbery cancelled by user."); return false end
        if not (Character and Humanoid and Humanoid.Health > 0) then print("[Heist] Character died, stopping: " .. config.DisplayName); return false end
        if not attemptSingleRobberyAction(actionConfig, heistFolder, config.DisplayName) then print(string.format("[Heist] Action '%s' in %s failed. Stopping this heist.", actionConfig.Name, config.DisplayName)); return false end
        task.wait(0.1) 
    end
    print(string.format("--- Heist: %s - Completed ---", config.DisplayName)); return true
end

local function ServerHop() print("[ServerHop] Attempting...");local s,e=pcall(function()local S={};local R=HttpService:RequestAsync({Url="https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?sortOrder=Desc&limit=100&excludeFullGames=true",Method="GET"});if not R or not R.Success or not R.Body then print("[ServerHop] Fail get list:",R and R.Body or "No resp");return end;local B=HttpService:JSONDecode(R.Body);if B and B.data then for _,v in next,B.data do if type(v)=="table"and tonumber(v.playing)and tonumber(v.maxPlayers)and v.playing<v.maxPlayers and v.id~=game.JobId then table.insert(S,1,v.id)end end end;print("[ServerHop] Found",#S,"servers.");if #S>0 then TeleportService:TeleportToPlaceInstance(game.PlaceId,S[math.random(1,#S)],Player)else print("[ServerHop] No other servers.");if #Player:GetPlayers()<=1 then Player:Kick("Rejoining...");task.wait(1);TeleportService:Teleport(game.PlaceId,Player)else TeleportService:TeleportToPlaceInstance(game.PlaceId,game.JobId,Player)end end end);if not s then print("[ServerHop] PcallFail:",e);TeleportService:TeleportToPlaceInstance(game.PlaceId,game.JobId,Player)end end

function executeAllRobberiesAndHop()
    if isRobbingGlobally then print("[AutoRob] Sequence already running."); return end
    isRobbingGlobally = true; currentRobberyCoroutine = coroutine.running()
    print("--- Starting Full Auto-Robbery Sequence (V5.3) ---"); local overallStartTime = tick()
    for i, heistName in ipairs(TARGET_HEISTS_TO_ROB_SEQUENCE) do
        if not currentRobberyCoroutine then print("[AutoRob] Full sequence cancelled."); break end
        if not (Character and Humanoid and Humanoid.Health > 0) then print("[AutoRob] Character died, stopping sequence."); break end
        local heistConfig = HEIST_SPECIFIC_CONFIG[heistName]
        if heistConfig then print(string.format("[AutoRob] Preparing for heist: %s (%d/%d)", heistConfig.DisplayName or heistName, i, #TARGET_HEISTS_TO_ROB_SEQUENCE))
            if not executeFullHeistRobbery(heistName) then print(string.format("[AutoRob] Heist %s failed/interrupted.", heistConfig.DisplayName or heistName)) end
        else print("[AutoRob] Warning: No config for: " .. heistName) end
        if i < #TARGET_HEISTS_TO_ROB_SEQUENCE and currentRobberyCoroutine then
            local waitTime = math.random(3, 6); print(string.format("[AutoRob] Waiting %.1fs before next heist...", waitTime))
            local waited = 0; while waited < waitTime and currentRobberyCoroutine do task.wait(0.1); waited = waited + 0.1 end
        end
    end
    if currentRobberyCoroutine then print(string.format("--- Sequence Completed in %.2fs. Server Hopping. ---", tick() - overallStartTime)); ServerHop() end
    isRobbingGlobally = false; currentRobberyCoroutine = nil
end

local function createControlUI_V5_3()
    if CoreGui:FindFirstChild("RyntazAutoRobV53_Ctrl") then CoreGui.RyntazAutoRobV53_Ctrl:Destroy() end
    local playerGui = Player:WaitForChild("PlayerGui"); if not playerGui then print("[UI Error] PlayerGui not found!"); return end
    local screenGui = Instance.new("ScreenGui",playerGui);screenGui.Name="RyntazAutoRobV53_Ctrl";screenGui.ResetOnSpawn=false;screenGui.DisplayOrder=1000;screenGui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
    local main=Instance.new("Frame",screenGui);main.Size=UDim2.new(0,180,0,100);main.Position=UDim2.new(0.01,10,0.5,-50);main.BackgroundColor3=Color3.fromRGB(28,28,32);main.BorderColor3=Color3.fromRGB(0,180,220);main.BorderSizePixel=1;local c=Instance.new("UICorner",main);c.CornerRadius=UDim.new(0,5);local l=Instance.new("UIListLayout",main);l.Padding=UDim.new(0,5);l.HorizontalAlignment=Enum.HorizontalAlignment.Center;l.VerticalAlignment=Enum.VerticalAlignment.Center;l.SortOrder=Enum.SortOrder.LayoutOrder
    local title=Instance.new("TextLabel",main);title.Name="Title";title.LayoutOrder=1;title.Size=UDim2.new(1,-10,0,20);title.Text="Ryntaz Rob V5.3";title.TextColor3=Color3.fromRGB(0,220,150);title.Font=Enum.Font.Michroma;title.TextSize=11;title.BackgroundTransparency=1
    local startButton=createStyledButton(main,"เริ่มปล้นทั้งหมด",UDim2.new(0.9,0,0,25),UDim2.new(),Color3.fromRGB(0,130,70),Color3.new(1,1,1),12);startButton.LayoutOrder=2
    startButton.MouseButton1Click:Connect(function()if not isRobbingGlobally then task.spawn(executeAllRobberiesAndHop)else print("[ARob] In progress.")end end)
    local stopButton=createStyledButton(main,"หยุดปล้น",UDim2.new(0.9,0,0,25),UDim2.new(),Color3.fromRGB(160,40,40),Color3.new(1,1,1),12);stopButton.LayoutOrder=3
    stopButton.MouseButton1Click:Connect(function()if currentRobberyCoroutine then isRobbingGlobally=false;task.cancel(currentRobberyCoroutine);currentRobberyCoroutine=nil;print("[ARob] Stopped.")else print("[ARob] Nothing to stop.")end end)
end

if waitForCharacter() then
    pcall(createControlUI_V5_3)
    local autoStartRobbery = true 
    if autoStartRobbery then
        print("[AutoRob V5.3] Auto-start enabled. Waiting 3s...")
        task.wait(3)
        if not isRobbingGlobally then task.spawn(executeAllRobberiesAndHop) end
    else
        print("[AutoRob V5.3] Auto-start disabled. Click button or call executeAllRobberiesAndHop()")
    end
else
    print("[AutoRob V5.3] Script terminated: Character not loaded.")
end
