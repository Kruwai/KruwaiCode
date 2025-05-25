-- RyntazHub AutoRob - V6.0.2 (Integrated Concepts)
-- ผสมผสานแนวคิดจากโค้ดเก่าของผู้ใช้เข้ากับ RyntazHub V6.0.1

local Player = game:GetService("Players").LocalPlayer
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeamsService = game:GetService("Teams")
local TeleportService = game:GetService("TeleportService")

local Character, Humanoid, RootPart
local currentRobberyCoroutine = nil
local isRobbingGlobally = false

local function waitForCharacter()
    print("[RyntazHub V6.0.2] Waiting for character...")
    local attempts = 0
    repeat attempts = attempts + 1
        if Player and Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") and Player.Character:FindFirstChildOfClass("Humanoid") then
            Character = Player.Character; Humanoid = Character:FindFirstChildOfClass("Humanoid"); RootPart = Character:FindFirstChild("HumanoidRootPart")
            if Humanoid and RootPart then print("[RyntazHub V6.0.2] Character found."); return true end
        end; task.wait(0.2)
    until attempts > 75
    print("[RyntazHub V6.0.2] ERROR: Character not found after timeout."); return false
end

if not waitForCharacter() then print("RyntazHub ERROR: Character not loaded, script will not fully initialize."); return end
Player.CharacterAdded:Connect(function(newChar) Character=newChar; Humanoid=newChar:WaitForChild("Humanoid",15); RootPart=newChar:WaitForChild("HumanoidRootPart",15); print("[RyntazHub V6.0.2] Character respawned."); if isRobbingGlobally and currentRobberyCoroutine then print("[RyntazHub V6.0.2] Char died during rob. Stopping."); task.cancel(currentRobberyCoroutine); currentRobberyCoroutine=nil; isRobbingGlobally=false; updateStatus("หยุดปล้น (ตัวละครตาย)") end end)

-- ================= CONFIGURATION =================
local HEISTS_BASE_PATH_STRING = "Workspace.Heists" -- Path เต็มจาก game
local TARGET_HEISTS_TO_ROB_SEQUENCE = {"JewelryStore", "Bank", "Casino", "MiniRobberies"} -- เพิ่ม MiniRobberies เข้าไป
local CRIMINAL_TEAM_NAME = "Criminals" 
local CRIMINAL_BASE_TELEPORT_CFRAME = CFrame.new(250, 10, 250) -- *** แก้ไขเป็นตำแหน่งฐานโจรที่ถูกต้อง ***
local OBJECT_SELECTION_PATH_FOR_MINI_ROBBERIES = "Workspace.ObjectSelection" -- Path จากโค้ดเก่าของคุณ

local AutoHeistSettings = {
    teleportSpeedFactor = 180, interactionDelay = 0.15,
    delayAfterSuccessfulLootAction = 0.5, delayAfterHeistCompletion = 3.0,
    stopOnErrorInSequence = false,
    makeInvisibleDuringRob = false -- ตั้งเป็น true ถ้าต้องการให้ล่องหน
}

-- ชื่อ Object สำหรับ Mini Robberies จากโค้ดเก่าของคุณ
local MiniRobberiesNames = { "Cash", "CashRegister", "DiamondBox", "Laptop", "Phone", "Luggage", "ATM", "TV", "Safe" }

local HEIST_SPECIFIC_CONFIG = {
    JewelryStore = {
        DisplayName = "ร้านเพชร", PathString = HEISTS_BASE_PATH_STRING .. ".JewelryStore", RequiresCriminalTeam = true,
        EntryTeleportCFrame = CFrame.new(-82.8, 85.5, 807.5), -- จุดยืนกลางๆ (ปรับถ้าจำเป็น)
        RobberyActions = {
            {
                Name = "เก็บเครื่องเพชร", ActionType = "IterateAndFireEvent",
                ItemContainerPath = "EssentialParts.JewelryBoxes", -- Path จาก Log
                ItemQuery = function(container) local items = {}; for _,c in ipairs(container:GetChildren()) do if c:IsA("Model") or c:IsA("BasePart") then table.insert(items, c) end end; return items end,
                RemoteEventPath = "EssentialParts.JewelryBoxes.JewelryManager.Event", -- Path จาก Log
                EventArgsFunc = function(lootInstance) return {lootInstance} end,
                FireCountPerItem = 5, -- จากโค้ดเก่าของคุณ
                TeleportOffsetPerItem = Vector3.new(0,1.8,1.8),
                DelayBetweenItems = 0.2, DelayBetweenFires = 0.05, RobDelayAfterAction = 0.1
            }
        },
        PostRobberyAction = { Type = "TeleportToCriminalBase", Delay = 0.5 },
        DelayAfterHeist = AutoHeistSettings.delayAfterHeistCompletion
    },
    Bank = {
        DisplayName = "ธนาคาร", PathString = HEISTS_BASE_PATH_STRING .. ".Bank", RequiresCriminalTeam = true,
        EntryTeleportCFrame = CFrame.new(730.5, 108.0, 562.5),
        RobberyActions = {
            { Name = "เปิดประตูห้องมั่นคง", ActionType = "Touch", TargetPath = "EssentialParts.VaultDoor.Touch", TeleportOffset = Vector3.new(0,0,-2.2), RobDelayAfterAction = 3.0 },
            { Name = "เก็บเงิน Bank (CashStack)", ActionType = "IterateAndFindInteract", ItemContainerPath = "Interior.CashStack.Model", ItemNameHint = "Cash", InteractionHint = {Type="RemoteEvent", NameHint="CollectCashBank", Args=function(item) return {item, math.random(800,1200)} end}, TeleportOffsetPerItem = Vector3.new(0,0.1,0), DelayBetweenItems = 0.5, FireCountPerItem = 1, RobDelayAfterAction = 0.3 }
        },
        PostRobberyAction = { Type = "TeleportToCriminalBase", Delay = 0.5 },
        DelayAfterHeist = AutoHeistSettings.delayAfterHeistCompletion
    },
    Casino = {
        DisplayName = "คาสิโน", PathString = HEISTS_BASE_PATH_STRING .. ".Casino", RequiresCriminalTeam = true,
        EntryTeleportCFrame = CFrame.new(1690.2, 30.5, 523.5),
        RobberyActions = {
            { Name = "แฮ็กคอมพิวเตอร์", ActionType = "ProximityPrompt", TargetPath = "Interior.HackComputer.HackComputer", ProximityPromptActionHint = "Hack", HoldDuration = 2.5, TeleportOffset = Vector3.new(0,1,-1.8), RobDelayAfterAction = 1.5 },
            { Name = "เก็บเงิน Casino (Vault)", ActionType = "IterateAndFindInteract", ItemContainerPath = "Interior.Vault", ItemNameHint = "Cash", InteractionHint = {Type="RemoteEvent", NameHint="TakeCasinoCash", Args=function(item) return {item} end}, TeleportOffsetPerItem = Vector3.new(0,0.1,0), DelayBetweenItems = 0.5, FireCountPerItem = 1, RobDelayAfterAction = 0.3 }
        },
        PostRobberyAction = { Type = "TeleportToCriminalBase", Delay = 0.5 },
        DelayAfterHeist = AutoHeistSettings.delayAfterHeistCompletion
    },
    MiniRobberies = { -- Heist พิเศษสำหรับ Mini Robberies
        DisplayName = "ปล้นย่อย (Mini Robberies)", PathString = OBJECT_SELECTION_PATH_FOR_MINI_ROBBERIES, RequiresCriminalTeam = false, -- Mini robberies อาจจะไม่ต้องเป็น Criminal
        EntryTeleportCFrame = nil, -- ไม่จำเป็นต้องมี Entry point ตายตัว
        RobberyActions = {
            {
                Name = "ปล้น Mini Robbery Items", ActionType = "IterateMiniRobberies",
                -- ItemContainerPath และ ItemQuery ไม่ได้ใช้ใน ActionType นี้โดยตรง
                TeleportOffsetPerItem = Vector3.new(0,2.5,0), -- Offset จาก Pivot ของ Mini Robbery Item
                FireCountPerItem = 2, -- จากโค้ดเก่าของคุณคือ 20 แต่ลดลงก่อน
                DelayBetweenItems = 0.8,
                DelayBetweenFires = 0.1,
                RobDelayAfterAction = 0.3
            }
        },
        DelayAfterHeist = 2.0
    }
}
local THEME_COLORS = {Accent=Color3.fromRGB(0,255,120),Secondary=Color3.fromRGB(35,40,50),Text=Color3.fromRGB(210,215,220),ButtonHover=Color3.fromRGB(50,55,70),Error=Color3.fromRGB(255,80,80)}
local mainFrame, outputContainer, titleBar, statusBar, statusTextLabel, timerTextLabel; local allLoggedMessages={}; local isMinimized=not INITIAL_UI_VISIBLE; local originalMainFrameSize=UDim2.new(0.45,0,0.30,0); local startTime

local function createStyledButton(p,t,s,pos,c,tc,fs)local b=Instance.new("TextButton",p);b.Text=t;b.Size=s;b.Position=pos;b.BackgroundColor3=c or THEME_COLORS.Secondary;b.TextColor3=tc or THEME_COLORS.Text;b.Font=Enum.Font.SourceSansSemibold;b.TextSize=fs or 13;b.ClipsDescendants=true;local cr=Instance.new("UICorner",b);cr.CornerRadius=UDim.new(0,4);return b end
local function logOutputWrapper(category,message)local ts=os.date("[%H:%M:%S] ");print(ts.."["..category.."] "..tostring(message))end -- Log ไปที่ print() เท่านั้น
local function updateStatus(text)if statusTextLabel and statusTextLabel.Parent then statusTextLabel.Text="สถานะ: "..text end;print("[Status] "..text)end
local function findInstance(pathStringOrInstance, childPath) local root=nil;if type(pathStringOrInstance)=="string"then local current=game;for component in pathStringOrInstance:gmatch("([^%.]+)")do if current then current=current:FindFirstChild(component)else return nil end end;root=current elseif typeof(pathStringOrInstance)=="Instance"then root=pathStringOrInstance end;if not root then return nil end;return childPath and root:FindFirstChild(childPath,true)or root end
local function teleportTo(targetCFrame, actionName) if not RootPart then print(string.format("[Teleport-%s] RootPart is nil.",actionName or"General")); return false end; print(string.format("[Teleport-%s] Moving to %.1f, %.1f, %.1f",actionName or"General",targetCFrame.X,targetCFrame.Y,targetCFrame.Z)); local success, err = pcall(function() RootPart.CFrame = targetCFrame end); if not success then print(string.format("[Teleport-%s] Failed: %s",actionName or"General",err)); return false end; local arrived=false;local timeout=0;repeat task.wait(0.05);timeout=timeout+0.05;if RootPart and(RootPart.Position-targetCFrame.Position).Magnitude<3 then arrived=true end until arrived or timeout>1.0; if not arrived then print(string.format("[Teleport-%s] Warning: May not have reached CFrame (Dist: %.1f).",actionName or "General", (RootPart.Position - targetCFrame.Position).Magnitude)) end; task.wait(0.1); return true end
local function findRemote(parentInst,nameHint)if not parentInst then return nil end;for _,D in ipairs(parentInst:GetDescendants())do if D:IsA("RemoteEvent")and D.Name:lower():match(nameHint:lower())then return D end end;return nil end
local function findPrompt(parentInst,actionHint)if not parentInst then return nil end;for _,D in ipairs(parentInst:GetDescendants())do if D:IsA("ProximityPrompt")then if D.ActionText and D.ActionText:lower():match(actionHint:lower())then return D elseif D.ObjectText and D.ObjectText:lower():match(actionHint:lower())then return D end end end;return nil end
local function getEventFromDescendants(v) for _, d in ipairs(v:GetDescendants()) do if d:IsA("RemoteEvent") then return d end end; return nil end -- จากโค้ดเก่า

function setPlayerVisibility(visible)
    if not Character then return end
    isPlayerInvisible = not visible
    local targetTransparency = visible and 0 or 1
    local targetCollide = visible 
    for _, part in ipairs(Character:GetDescendants()) do
        if part:IsA("BasePart") or part:IsA("Accessory") then
            if part:IsA("Accessory") then local handle = part:FindFirstChild("Handle"); if handle and handle:IsA("BasePart") then handle.Transparency = targetTransparency; handle.CanCollide = targetCollide end
            else part.Transparency = targetTransparency; part.CanCollide = targetCollide end
        end
    end
    local head = Character:FindFirstChild("Head"); if head then local bb = head:FindFirstChildOfClass("BillboardGui"); if bb then bb.Enabled = visible end; if not visible then head.Transparency = 1; head.CanCollide = false else head.Transparency = 0; head.CanCollide = true end end
    print("[Visibility] Player visibility set to: " .. tostring(visible))
end

local function attemptSingleRobberyAction(actionConfig, heistFolder, heistDisplayName)
    if not (Character and Humanoid and HumanoidRootPart and Humanoid.Health > 0) then print(string.format("[%s] Char dead/missing. Skip: %s", heistDisplayName, actionConfig.Name)); return false end
    print(string.format("  [%s Action] %s", heistDisplayName, actionConfig.Name))
    local targetInstance; local teleportBaseCFrame
    if actionConfig.TargetPath then targetInstance = findInstance(heistFolder, actionConfig.TargetPath); if not targetInstance then print(string.format("    [Error-%s] TargetPath not found: %s", heistDisplayName, actionConfig.TargetPath)); return false end; teleportBaseCFrame = (targetInstance:IsA("Model") and targetInstance:GetPivot() or targetInstance.CFrame)
    elseif actionConfig.ActionType:match("Iterate") or actionConfig.ActionType == "IterateMiniRobberies" then teleportBaseCFrame = heistFolder and heistFolder:IsA("Model") and heistFolder:GetPivot() or (heistFolder and heistFolder.PrimaryPart and heistFolder.PrimaryPart.CFrame) or RootPart.CFrame
    else print(string.format("    [Error-%s] Action '%s' needs TargetPath or Iterate type.", heistDisplayName, actionConfig.Name)); return false end
    
    if actionConfig.ActionType ~= "IterateMiniRobberies" then -- Mini robberies will TP per item
        if not teleportTo(teleportBaseCFrame * CFrame.new(actionConfig.TeleportOffset or Vector3.new()), actionConfig.Name .. " (Init)") then return false end
    end

    local robSuccessful = false
    if actionConfig.ActionType == "Touch" and targetInstance then if typeof(firetouchinterest) == "function" and targetInstance:IsA("BasePart") then print("    Firing touch for: "..targetInstance.Name); pcall(firetouchinterest, targetInstance, RootPart, 0); task.wait(0.05); pcall(firetouchinterest, targetInstance, RootPart, 1); robSuccessful = true else print("    firetouchinterest N/A or target not BasePart.") end
    elseif actionConfig.ActionType == "ProximityPrompt" and targetInstance then local prompt = findPrompt(targetInstance, actionConfig.ProximityPromptActionHint or targetInstance.Name); if prompt then if typeof(fireproximityprompt) == "function" then print(string.format("    Firing PP: %s (Hold: %.1fs)", prompt.ActionText or prompt.ObjectText or "Unknown", actionConfig.HoldDuration or 0)); pcall(fireproximityprompt, prompt, actionConfig.HoldDuration or 0); robSuccessful = true else print("    fireproximityprompt N/A.") end else print("    Prompt not found for: "..targetInstance.Name) end
    elseif (actionConfig.ActionType == "RemoteEvent" or actionConfig.ActionType == "IterateAndFireEvent" or actionConfig.ActionType == "IterateMiniRobberies") then
        local itemsToProcess = {}; local remoteEventInstance
        local searchBaseForItems
        if actionConfig.ActionType == "IterateMiniRobberies" then
            searchBaseForItems = findInstance(OBJECT_SELECTION_PATH_FOR_MINI_ROBBERIES)
            if not searchBaseForItems then print("    [Error] MiniRobberies ObjectSelection Path not found: " .. OBJECT_SELECTION_PATH_FOR_MINI_ROBBERIES); return false end
            for _, v_obj in ipairs(searchBaseForItems:GetChildren()) do
                if table.find(MiniRobberiesNames, v_obj.Name) and not v_obj:FindFirstChild("Nope") and getEventFromDescendants(v_obj) then
                    table.insert(itemsToProcess, v_obj)
                end
            end
        else
            searchBaseForItems = actionConfig.ItemContainerPath and findInstance(heistFolder, actionConfig.ItemContainerPath) or heistFolder
            if not searchBaseForItems then print("    [Error] ItemContainerPath not found: " .. (actionConfig.ItemContainerPath or "N/A")); return false end
            if actionConfig.ActionType == "IterateAndFireEvent" then if actionConfig.ItemQuery then itemsToProcess = actionConfig.ItemQuery(searchBaseForItems) else for _,child in ipairs(searchBaseForItems:GetChildren()) do if (child:IsA("Model") or child:IsA("BasePart")) and (not actionConfig.ItemNameHint or child.Name:lower():match(actionConfig.ItemNameHint:lower())) then table.insert(itemsToProcess, child) end end end
            else if targetInstance then table.insert(itemsToProcess, targetInstance) else print("    [Error] TargetPath needed for SingleEvent."); return false end end
        end

        if #itemsToProcess == 0 then print("    No items found for: " .. actionConfig.Name); return true end

        for i, itemInst in ipairs(itemsToProcess) do
            if not (Character and Humanoid.Health > 0 and currentRobberyCoroutine) then print("    Robbery sequence interrupted."); return false end
            if not teleportTo((itemInst:IsA("Model") and itemInst:GetPivot() or itemInst.CFrame) * CFrame.new(actionConfig.TeleportOffsetPerItem or actionConfig.TeleportOffset or Vector3.new(0,2,0)), actionConfig.Name .. " Item " .. i) then return false end
            
            if actionConfig.ActionType == "IterateMiniRobberies" then
                remoteEventInstance = getEventFromDescendants(itemInst)
            elseif actionConfig.RemoteEventPath then 
                remoteEventInstance = findInstance(Workspace, actionConfig.RemoteEventPath) or findInstance(searchBaseForItems, actionConfig.RemoteEventPath) or (itemInst and itemInst:FindFirstChild(actionConfig.RemoteEventPath, true))
            elseif actionConfig.RemoteEventNameHint then 
                remoteEventInstance = findRemote(itemInst, actionConfig.RemoteEventNameHint) or findRemote(itemInst.Parent, actionConfig.RemoteEventNameHint) or findRemote(heistFolder, actionConfig.RemoteEventNameHint)
            end

            if not remoteEventInstance or not remoteEventInstance:IsA("RemoteEvent") then print("    [Error] RemoteEvent not found for item:", itemInst.Name, "(Path/Hint:", actionConfig.RemoteEventPath or actionConfig.RemoteEventNameHint or "N/A", ")"); goto next_item_in_iterate end
            
            local argsToFire = {}; if actionConfig.EventArgsFunc then argsToFire = actionConfig.EventArgsFunc(itemInst) or {} end
            print(string.format("    Firing RE: %s for %s (Item %d/%d)", remoteEventInstance.Name, itemInst.Name, i, #itemsToProcess))
            for fc = 1, actionConfig.FireCountPerItem or 1 do
                if not (Character and Humanoid.Health > 0 and currentRobberyCoroutine) then print("    Robbery interrupted fire loop."); return false end
                local s,e = pcall(function() remoteEventInstance:FireServer(unpack(argsToFire)) end); if not s then print("      Error firing: "..tostring(e)) end
                task.wait(actionConfig.DelayBetweenFires or 0.1)
            end
            robSuccessful = true
            if #itemsToProcess > 1 and i < #itemsToProcess then task.wait(actionConfig.DelayBetweenItems or 0.2) end
            ::next_item_in_iterate::
        end
    end
    if robSuccessful then print(string.format("    Action '%s' processing completed.", actionConfig.Name)) else print(string.format("    Action '%s' failed or no valid interaction path.", actionConfig.Name)) end
    if actionConfig.RobDelayAfterAction then print(string.format("    Waiting %.2fs after action '%s'", actionConfig.RobDelayAfterAction, actionConfig.Name)); task.wait(actionConfig.RobDelayAfterAction) end
    return robSuccessful
end

function executeFullHeistRobbery(heistName) local config = HEIST_SPECIFIC_CONFIG[heistName]; if not config then print("[Heist] No config for: " .. heistName); return false end; local heistFolder = findInstance(config.PathString); if not heistFolder then print("[Heist] Heist folder not found: " .. config.PathString); return false end; print(string.format("--- Starting Heist: %s ---", config.DisplayName)); if config.EntryTeleportCFrame and RootPart then if not teleportTo(config.EntryTeleportCFrame, config.DisplayName .. " Entry") then return false end; task.wait(0.3) end; for i, actionConfig in ipairs(config.RobberyActions or {}) do if not currentRobberyCoroutine then print("[Heist] Robbery cancelled by user."); return false end; if not (Character and Humanoid and Humanoid.Health > 0) then print("[Heist] Character died, stopping: " .. config.DisplayName); return false end; if not attemptSingleRobberyAction(actionConfig, heistFolder, config.DisplayName) then print(string.format("[Heist] Action '%s' in %s failed. Stopping.", actionConfig.Name, config.DisplayName)); return false end; task.wait(AutoHeistSettings.interactionDelay) end; if config.PostRobberyAction and config.PostRobberyAction.Type == "TeleportToCriminalBase" then print("[HeistInfo] Teleporting to Criminal Base for "..config.DisplayName); task.wait(config.PostRobberyAction.Delay or 0.1); teleportTo(CRIMINAL_BASE_TELEPORT_CFRAME, "Criminal Base") end; print(string.format("--- Heist: %s - Completed ---", config.DisplayName)); if config.DelayAfterHeist then print(string.format("Waiting %.1fs after %s", config.DelayAfterHeist, config.DisplayName)); task.wait(config.DelayAfterHeist) end; return true end
local function ServerHop()print("[ServerHop] Attempting...");local s,e=pcall(function()local S={};local R=HttpService:RequestAsync({Url="https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?sortOrder=Desc&limit=100&excludeFullGames=true",Method="GET"});if not R or not R.Success or not R.Body then print("[ServerHop] Fail get list:",R and R.Body or "No resp");return end;local B=HttpService:JSONDecode(R.Body);if B and B.data then for _,v in next,B.data do if type(v)=="table"and tonumber(v.playing)and tonumber(v.maxPlayers)and v.playing<v.maxPlayers and v.id~=game.JobId then table.insert(S,1,v.id)end end end;print("[ServerHop] Found",#S,"servers.");if #S>0 then TeleportService:TeleportToPlaceInstance(game.PlaceId,S[math.random(1,#S)],Player)else print("[ServerHop] No other servers.");if #Player:GetPlayers()<=1 then Player:Kick("Rejoining...");task.wait(1);TeleportService:Teleport(game.PlaceId,Player)else TeleportService:TeleportToPlaceInstance(game.PlaceId,game.JobId,Player)end end end);if not s then print("[ServerHop] PcallFail:",e);TeleportService:TeleportToPlaceInstance(game.PlaceId,game.JobId,Player)end end

function executeAllRobberiesAndHop()
    if isRobbingGlobally then print("[AutoRob] Sequence already running."); return end
    isRobbingGlobally = true; currentRobberyCoroutine = coroutine.running()
    print("--- Starting Full Auto-Robbery Sequence (V6.0.2) ---"); startTime = tick()
    updateStatus("เริ่มลำดับการปล้น...")
    
    local playerTeam = getPlayerTeam()
    if not playerTeam or playerTeam.Name ~= CRIMINAL_TEAM_NAME then
        print(string.format("[AutoRob] ผู้เล่นไม่ได้อยู่ในทีม '%s'. ไม่สามารถเริ่มการปล้นได้.", CRIMINAL_TEAM_NAME))
        updateStatus("ต้องอยู่ทีม " .. CRIMINAL_TEAM_NAME); isRobbingGlobally = false; currentRobberyCoroutine = nil; return
    end

    if AutoHeistSettings.makeInvisibleDuringRob then setPlayerVisibility(false) end

    for i, heistName in ipairs(TARGET_HEISTS_TO_ROB_SEQUENCE) do
        if not currentRobberyCoroutine then print("[AutoRob] การปล้นทั้งหมดถูกยกเลิก"); break end
        if not (Character and Humanoid and Humanoid.Health > 0) then print("[AutoRob] ตัวละครตาย, หยุดการปล้นทั้งหมด"); break end
        
        local heistConfig = HEIST_SPECIFIC_CONFIG[heistName]
        if heistConfig then
            updateStatus(string.format("กำลังปล้น: %s (%d/%d)", heistConfig.DisplayName or heistName, i, #TARGET_HEISTS_TO_ROB_SEQUENCE))
            if not executeFullHeistRobbery(heistName) then
                updateStatus(string.format("การปล้น %s ล้มเหลว/ถูกขัดจังหวะ", heistConfig.DisplayName or heistName))
                if AutoHeistSettings.stopOnErrorInSequence then print("[AutoRob] หยุดการปล้นทั้งหมดเนื่องจาก Heist ก่อนหน้าล้มเหลว."); break end
            end
        else updateStatus("ข้าม: ไม่พบ Config สำหรับ " .. heistName) end
        
        if i < #TARGET_HEISTS_TO_ROB_SEQUENCE and currentRobberyCoroutine then
            local waitTime = AutoHeistSettings.delayAfterHeistCompletion
            updateStatus(string.format("รอ %.1fวินาที ก่อนปล้นที่ต่อไป...", waitTime))
            local waited = 0; while waited < waitTime and currentRobberyCoroutine do task.wait(0.1); waited = waited + 0.1 end
        end
    end
    
    if AutoHeistSettings.makeInvisibleDuringRob then setPlayerVisibility(true) end
    if currentRobberyCoroutine then 
        updateStatus(string.format("ลำดับการปล้นทั้งหมดเสร็จสิ้น (%.2fวิ). กำลังย้ายเซิร์ฟเวอร์...", tick() - startTime))
        ServerHop()
    end
    isRobbingGlobally = false; currentRobberyCoroutine = nil
end

local controlScreenGui
local function createControlUI_V6()
    if controlScreenGui and controlScreenGui.Parent then controlScreenGui:Destroy() end
    local playerGui = Player:WaitForChild("PlayerGui"); if not playerGui then print("[UI Error] PlayerGui V6 not found!"); return end
    controlScreenGui = Instance.new("ScreenGui",playerGui);controlScreenGui.Name="RyntazAutoRobV6_Ctrl";controlScreenGui.ResetOnSpawn=false;controlScreenGui.DisplayOrder=1000;controlScreenGui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
    
    local main=Instance.new("Frame",controlScreenGui);main.Name="ControlPanel";main.Size=UDim2.new(0,200,0,130);main.Position=UDim2.new(0.01,10,0.5,-65);main.BackgroundColor3=Color3.fromRGB(28,28,35);main.BorderColor3=THEME_COLORS.Accent;main.BorderSizePixel=1;local c=Instance.new("UICorner",main);c.CornerRadius=UDim.new(0,5);local l=Instance.new("UIListLayout",main);l.Padding=UDim.new(0,5);l.HorizontalAlignment=Enum.HorizontalAlignment.Center;l.VerticalAlignment=Enum.VerticalAlignment.Top;l.SortOrder=Enum.SortOrder.LayoutOrder
    
    local title=Instance.new("TextLabel",main);title.Name="Title";title.LayoutOrder=1;title.Size=UDim2.new(1,-10,0,20);title.Text="RyntazRob V6.0.2";title.TextColor3=THEME_COLORS.Accent;title.Font=Enum.Font.Michroma;title.TextSize=11;title.BackgroundTransparency=1
    statusTextLabel=Instance.new("TextLabel",main);statusTextLabel.Name="Status";statusTextLabel.LayoutOrder=2;statusTextLabel.Size=UDim2.new(1,-10,0,18);statusTextLabel.Text="สถานะ: ว่าง";statusTextLabel.TextColor3=THEME_COLORS.TextDim;statusTextLabel.Font=Enum.Font.Code;statusTextLabel.TextSize=10;statusTextLabel.BackgroundTransparency=1;statusTextLabel.TextWrapped=true;statusTextLabel.TextYAlignment = Enum.TextYAlignment.Top
    
    local startButton=createStyledButton(main,"เริ่มปล้นทั้งหมด",UDim2.new(0.9,0,0,28),UDim2.new(),Color3.fromRGB(60,180,100),Color3.new(0,0,0),12);startButton.LayoutOrder=3
    startButton.MouseButton1Click:Connect(function()if not isRobbingGlobally then task.spawn(executeAllRobberiesAndHop)else print("[ARob] In progress.")end end)
    
    local stopButton=createStyledButton(main,"หยุดปล้น",UDim2.new(0.9,0,0,28),UDim2.new(),Color3.fromRGB(200,60,60),Color3.new(1,1,1),12);stopButton.LayoutOrder=4
    stopButton.MouseButton1Click:Connect(function()if currentRobberyCoroutine then isRobbingGlobally=false;task.cancel(currentRobberyCoroutine);currentRobberyCoroutine=nil;print("[ARob] Stopped.");updateStatus("หยุดโดยผู้ใช้") else print("[ARob] Nothing to stop.")end end)
    print("[RyntazHub V6.0.2] Control UI Created.")
end

if waitForCharacter() then
    pcall(createControlUI_V6)
    local autoStartRobbery = true -- << ตั้งเป็น true เพื่อให้เริ่มปล้นอัตโนมัติ
    if autoStartRobbery then
        print("[RyntazHub V6.0.2] Auto-start. Waiting 3s...")
        task.wait(3)
        if not isRobbingGlobally then task.spawn(executeAllRobberiesAndHop) end
    else
        print("[RyntazHub V6.0.2] Auto-start ปิดอยู่. คลิกปุ่ม 'เริ่มปล้นทั้งหมด'.")
        updateStatus("พร้อม, รอคำสั่ง")
    end
else
    print("[RyntazHub V6.0.2] Script terminated: Character not loaded.")
end

_G.RyntazHubRob = {
    Start = executeAllRobberiesAndHop,
    Stop = function() if currentRobberyCoroutine then isRobbingGlobally=false;task.cancel(currentRobberyCoroutine);currentRobberyCoroutine=nil;print("[RyntazHubRob.Stop] Stopped.");updateStatus("หยุดโดยผู้ใช้");if AutoHeistSettings.makeInvisibleDuringRob then setPlayerVisibility(true) end else print("[RyntazHubRob.Stop] Nothing to stop.")end end,
    SetInvisible = function(state) setPlayerVisibility(not state) end,
    TeleportToHeistEntry = function(heistNameKey) local config=HEIST_SPECIFIC_CONFIG[heistNameKey];if config and config.EntryTeleportCFrame and RootPart then teleportTo(config.EntryTeleportCFrame,heistNameKey.." Entry")else print("Cannot teleport to entry for: "..tostring(heistNameKey))end end
}
print("[RyntazHub V6.0.2] Loaded. Use _G.RyntazHubRob.Start() or UI button.")
