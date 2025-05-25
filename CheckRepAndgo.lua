-- RyntazHub AutoRob - V6.0.1 (UI Creation & Stability Fix)
-- Based on V5.3.2, ensuring UI elements are created and visible.

local Player = game:GetService("Players").LocalPlayer
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService") -- Added for potential future use
local TeamsService = game:GetService("Teams")

local Character, Humanoid, RootPart
local currentRobberyCoroutine = nil
local isRobbingGlobally = false
local autoRobEnabledState = false -- For toggle button state
local controlUiScreenGui -- Make screenGui for control UI accessible globally

-- Debug Print Function
local function logInfo(category, message)
    print(string.format("[%s V6.0.1] [%s] %s", os.date("%H:%M:%S"), category, message))
end

local function waitForCharacter()
    logInfo("System", "Waiting for character...")
    local attempts = 0
    repeat attempts = attempts + 1
        if Player and Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") and Player.Character:FindFirstChildOfClass("Humanoid") then
            Character = Player.Character; Humanoid = Character:FindFirstChildOfClass("Humanoid"); RootPart = Character:FindFirstChild("HumanoidRootPart")
            if Humanoid and RootPart then logInfo("System", "Character found."); return true end
        end; task.wait(0.3)
    until attempts > 60
    logInfo("ERROR", "Character not found after timeout."); return false
end

Player.CharacterAdded:Connect(function(newChar)
    Character=newChar; Humanoid=newChar:WaitForChild("Humanoid",15); RootPart=newChar:WaitForChild("HumanoidRootPart",15)
    logInfo("System", "Character respawned/added.")
    if isRobbingGlobally and currentRobberyCoroutine then
        logInfo("RobCtrl", "Character died during robbery. Stopping sequence.")
        task.cancel(currentRobberyCoroutine); currentRobberyCoroutine=nil; isRobbingGlobally=false
    end
end)

local HEISTS_BASE_PATH_STRING = "Workspace.Heists"
local TARGET_HEISTS_TO_ROB_SEQUENCE = {"JewelryStore", "Bank", "Casino"}
local CRIMINAL_TEAM_NAME = "Criminals"
local CRIMINAL_BASE_TELEPORT_CFRAME = CFrame.new(100, 10, 100) -- *** คุณต้องใส่ CFrame ที่ถูกต้อง ***

local AutoHeistSettings = {
    teleportSpeedFactor = 180, interactionDelay = 0.2,
    delayAfterSuccessfulLootAction = 0.7, delayAfterHeistCompletion = 3.5,
    stopOnErrorInSequence = true
}

local HEIST_SPECIFIC_CONFIG = {
    JewelryStore = { DisplayName = "ร้านเพชร", PathString = HEISTS_BASE_PATH_STRING .. ".JewelryStore", RequiresCriminalTeam = true, EntryTeleportCFrame = CFrame.new(-82.8, 85.5, 807.5), RobberyActions = {{ Name = "เก็บเครื่องเพชร", ActionType = "IterateAndFireEvent", ItemContainerPath = "EssentialParts.JewelryBoxes", RemoteEventPath = "EssentialParts.JewelryBoxes.JewelryManager.Event", EventArgsFunc = function(lootInstance) return {lootInstance} end, FireCountPerItem = 2, TeleportOffsetPerItem = Vector3.new(0,1.8,1.8), DelayBetweenItems = 0.1, DelayBetweenFires = 0.05, RobDelayAfterAction = 0.2 }}, PostRobberyAction = { Type = "TeleportToCriminalBase", Delay = 0.5 }},
    Bank = { DisplayName = "ธนาคาร", PathString = HEISTS_BASE_PATH_STRING .. ".Bank", RequiresCriminalTeam = true, EntryTeleportCFrame = CFrame.new(730.5,108.0,562.5), RobberyActions = {{ Name = "เปิดประตูห้องมั่นคง", ActionType = "Touch", TargetPath = "EssentialParts.VaultDoor.Touch", TeleportOffset = Vector3.new(0,0,-2.2), RobDelayAfterAction = 3.0 }, { Name = "เก็บเงิน CashStack", ActionType = "IterateAndFindInteract", ItemContainerPath = "Interior.CashStack.Model", ItemNameHint = "Cash", InteractionHint = {Type="RemoteEvent", NameHint="CollectCash", Args=function(item) return {item, 1000} end}, TeleportOffsetPerItem = Vector3.new(0,0.5,0), DelayBetweenItems = 0.2, FireCountPerItem = 1, RobDelayAfterAction = 0.3 }, { Name = "เก็บเงิน Model Cash", ActionType = "IterateAndFindInteract", ItemContainerPath = "Interior.Model", ItemNameHint = "Cash", InteractionHint = {Type="RemoteEvent", NameHint="CollectMoney", Args=function(item) return {item, 500} end}, TeleportOffsetPerItem = Vector3.new(0,0.5,0), DelayBetweenItems = 0.2, FireCountPerItem = 1, RobDelayAfterAction = 0.3 }}, PostRobberyAction = { Type = "TeleportToCriminalBase", Delay = 0.5 }},
    Casino = { DisplayName = "คาสิโน", PathString = HEISTS_BASE_PATH_STRING .. ".Casino", RequiresCriminalTeam = true, EntryTeleportCFrame = CFrame.new(1690.2,30.5,523.5), RobberyActions = {{ Name = "แฮ็กคอมพิวเตอร์", ActionType = "ProximityPrompt", TargetPath = "Interior.HackComputer.HackComputer", ProximityPromptActionHint = "Hack", HoldDuration = 2.5, TeleportOffset = Vector3.new(0,1,-1.8), RobDelayAfterAction = 1.5 }, { Name = "เก็บเงินห้องนิรภัย", ActionType = "IterateAndFindInteract", ItemContainerPath = "Interior.Vault", ItemNameHint = "Cash", InteractionHint = {Type="RemoteEvent", NameHint="TakeVaultCash", Args=function(item) return {item} end}, TeleportOffsetPerItem = Vector3.new(0,0.5,0), DelayBetweenItems = 0.3, FireCountPerItem = 1, RobDelayAfterAction = 0.3 }}, PostRobberyAction = { Type = "TeleportToCriminalBase", Delay = 0.5 }}
}
local THEME_COLORS = {Accent=Color3.fromRGB(0,255,120),Secondary=Color3.fromRGB(35,40,50),Text=Color3.fromRGB(210,215,220),ButtonHover=Color3.fromRGB(50,55,70),Error=Color3.fromRGB(255,80,80)}

local function findInstance(pathStringOrInstance, childPath) local root=nil;if type(pathStringOrInstance)=="string"then local current=game;for component in pathStringOrInstance:gmatch("([^%.]+)")do if current then current=current:FindFirstChild(component)else return nil end end;root=current elseif typeof(pathStringOrInstance)=="Instance"then root=pathStringOrInstance end;if not root then return nil end;return childPath and root:FindFirstChild(childPath,true)or root end
local function teleportTo(targetCFrame, actionName) if not RootPart then logInfo("Teleport", string.format("%s - RootPart is nil.", actionName or "General")); return false end; logInfo("Teleport", string.format("%s - Moving to %.1f, %.1f, %.1f", actionName or "General", targetCFrame.X, targetCFrame.Y, targetCFrame.Z)); local success, err = pcall(function() RootPart.CFrame = targetCFrame end); if not success then logInfo("Teleport", string.format("%s - Failed: %s", actionName or "General", err)); return false end; local arrived=false;local timeout=0;repeat task.wait(0.05);timeout=timeout+0.05;if RootPart and(RootPart.Position-targetCFrame.Position).Magnitude<2 then arrived=true end until arrived or timeout>1.0;if not arrived then logInfo("Teleport", string.format("%s - Warning: May not have reached CFrame.",actionName or "General"))else logInfo("Teleport",string.format("%s - Arrived.",actionName or "General"))end;task.wait(0.15);return true end
local function findRemote(parentInst,nameHint)if not parentInst then return nil end;for _,D in ipairs(parentInst:GetDescendants())do if D:IsA("RemoteEvent")and D.Name:lower():match(nameHint:lower())then return D end end;for _,D in ipairs(parentInst:GetDescendants())do if D:IsA("RemoteFunction")and D.Name:lower():match(nameHint:lower())then return D end end;return nil end
local function findPrompt(parentInst,actionHint)if not parentInst then return nil end;for _,D in ipairs(parentInst:GetDescendants())do if D:IsA("ProximityPrompt")then if D.ActionText and D.ActionText:lower():match(actionHint:lower())then return D elseif D.ObjectText and D.ObjectText:lower():match(actionHint:lower())then return D end end end;return nil end
local function createStyledButton(parent,text,size,pos,color,textColor,fontSize)local b=Instance.new("TextButton",parent);b.Text=text;b.Size=size;b.Position=pos;b.BackgroundColor3=color or THEME_COLORS.Secondary;b.TextColor3=textColor or THEME_COLORS.Text;b.Font=Enum.Font.SourceSansSemibold;b.TextSize=fontSize or 13;b.ClipsDescendants=true;local c=Instance.new("UICorner",b);c.CornerRadius=UDim.new(0,4);return b end

local function setPlayerVisibility(visible)
    if not Character then return end; isPlayerInvisible = not visible
    local targetTransparency = visible and 0 or 1; local targetCollide = visible
    for _, part in ipairs(Character:GetDescendants()) do if part:IsA("BasePart") or part:IsA("Accessory") then if part:IsA("Accessory") then local handle = part:FindFirstChild("Handle"); if handle and handle:IsA("BasePart") then handle.Transparency = targetTransparency; handle.CanCollide = targetCollide end else part.Transparency = targetTransparency; part.CanCollide = targetCollide end end end
    local head = Character:FindFirstChild("Head"); if head then local bb = head:FindFirstChildOfClass("BillboardGui"); if bb then bb.Enabled = visible end; if not visible then head.Transparency=1;head.CanCollide=false else head.Transparency=0;head.CanCollide=true end end
    logInfo("Visibility", "Player visibility set to: " .. tostring(visible))
end

local function attemptSingleRobberyAction(actionConfig, heistFolder, heistDisplayName) if not (Character and Humanoid and HumanoidRootPart and Humanoid.Health > 0) then logInfo("Robbery",string.format("[%s] Char dead. Skip: %s", heistDisplayName, actionConfig.Name)); return false end; logInfo("Robbery",string.format("  [%s Action] %s", heistDisplayName, actionConfig.Name)); local targetInstance; local teleportBaseCFrame; if actionConfig.TargetPath then targetInstance = findInstance(heistFolder, actionConfig.TargetPath); if not targetInstance then logInfo("Error",string.format("    [%s] TargetPath not found: %s", heistDisplayName, actionConfig.TargetPath)); return false end; teleportBaseCFrame = (targetInstance:IsA("Model") and targetInstance:GetPivot() or targetInstance.CFrame) elseif actionConfig.ActionType:match("Iterate") then teleportBaseCFrame = heistFolder:GetPivot() else logInfo("Error",string.format("    [%s] Action '%s' needs TargetPath or is Iterate type.", heistDisplayName, actionConfig.Name)); return false end; if not teleportTo(teleportBaseCFrame * CFrame.new(actionConfig.TeleportOffset or Vector3.new()), actionConfig.Name .. " (Init)") then return false end; local robSuccessful = false; if actionConfig.ActionType == "Touch" and targetInstance then if typeof(firetouchinterest) == "function" and targetInstance:IsA("BasePart") then logInfo("Robbery", "    Firing touch for: "..targetInstance.Name); pcall(firetouchinterest, targetInstance, RootPart, 0); task.wait(0.05); pcall(firetouchinterest, targetInstance, RootPart, 1); robSuccessful = true else logInfo("Robbery", "    firetouchinterest N/A or target not BasePart.") end elseif actionConfig.ActionType == "ProximityPrompt" and targetInstance then local prompt = findPrompt(targetInstance, actionConfig.ProximityPromptActionHint or targetInstance.Name); if prompt then if typeof(fireproximityprompt) == "function" then logInfo("Robbery",string.format("    Firing PP: %s (Hold: %.1fs)", prompt.ActionText or prompt.ObjectText or "?", actionConfig.HoldDuration or 0)); pcall(fireproximityprompt, prompt, actionConfig.HoldDuration or 0); robSuccessful = true else logInfo("Robbery", "    fireproximityprompt N/A.") end else logInfo("Robbery", "    PP not found for: "..targetInstance.Name.." Hint: "..actionConfig.ProximityPromptActionHint) end elseif (actionConfig.ActionType == "RemoteEvent" or actionConfig.ActionType == "IterateAndFireEvent") then local itemsToProcess = {}; local remoteEventInstance; local searchBaseForItems = actionConfig.ItemContainerPath and findInstance(heistFolder, actionConfig.ItemContainerPath) or heistFolder; if not searchBaseForItems then logInfo("Error", "    ItemContainerPath not found: " .. (actionConfig.ItemContainerPath or "N/A")); return false end; if actionConfig.ActionType == "IterateAndFireEvent" then if actionConfig.ItemQuery then itemsToProcess = actionConfig.ItemQuery(searchBaseForItems) else for _,child in ipairs(searchBaseForItems:GetChildren()) do if (child:IsA("Model") or child:IsA("BasePart")) and (not actionConfig.ItemNameHint or child.Name:lower():match(actionConfig.ItemNameHint:lower())) then table.insert(itemsToProcess, child) end end end else if targetInstance then table.insert(itemsToProcess, targetInstance) else logInfo("Error", "    TargetPath needed for SingleEvent."); return false end end; if #itemsToProcess == 0 then logInfo("Info", "    No items found for: " .. actionConfig.Name); return true end; if actionConfig.RemoteEventPath then remoteEventInstance = findInstance(Workspace, actionConfig.RemoteEventPath) or findInstance(searchBaseForItems, actionConfig.RemoteEventPath) or (itemsToProcess[1] and itemsToProcess[1]:FindFirstChild(actionConfig.RemoteEventPath, true)) elseif actionConfig.RemoteEventNameHint then remoteEventInstance = findRemote(itemsToProcess[1], actionConfig.RemoteEventNameHint) or findRemote(itemsToProcess[1] and itemsToProcess[1].Parent, actionConfig.RemoteEventNameHint) or findRemote(heistFolder, actionConfig.RemoteEventNameHint) end; if not remoteEventInstance or not remoteEventInstance:IsA("RemoteEvent") then logInfo("Error", "    RemoteEvent not found for: "..actionConfig.Name.." (Hint: ".. (actionConfig.RemoteEventPath or actionConfig.RemoteEventNameHint or "N/A")..")"); return false end; for i, itemInst in ipairs(itemsToProcess) do if not (Character and Humanoid.Health > 0 and currentRobberyCoroutine) then logInfo("Robbery", "    Sequence interrupted."); return false end; if not teleportTo((itemInst:IsA("Model") and itemInst:GetPivot() or itemInst.CFrame) * CFrame.new(actionConfig.TeleportOffsetPerItem or actionConfig.TeleportOffset or Vector3.new()), actionConfig.Name .. " Item " .. i) then return false end; local argsToFire = {}; if actionConfig.EventArgsFunc then argsToFire = actionConfig.EventArgsFunc(itemInst) or {} end; logInfo("Robbery",string.format("    Firing RE: %s for %s (%d/%d)", remoteEventInstance.Name, itemInst.Name, i, #itemsToProcess)); for fc = 1, actionConfig.FireCountPerItem or 1 do if not (Character and Humanoid.Health > 0 and currentRobberyCoroutine) then logInfo("Robbery", "    Interrupted fire loop."); return false end; local s,e = pcall(function() remoteEventInstance:FireServer(unpack(argsToFire)) end); if not s then logInfo("Error","      Fire failed: "..tostring(e)) end; task.wait(actionConfig.DelayBetweenFires or 0.05) end; robSuccessful = true; if #itemsToProcess > 1 and i < #itemsToProcess then task.wait(actionConfig.DelayBetweenItems or 0.15) end end end; if robSuccessful then print(string.format("    Action '%s' completed.", actionConfig.Name)) else print(string.format("    Action '%s' failed.", actionConfig.Name)) end; if actionConfig.RobDelayAfterAction then print(string.format("    Waiting %.2fs after action '%s'", actionConfig.RobDelayAfterAction, actionConfig.Name)); task.wait(actionConfig.RobDelayAfterAction) end; return robSuccessful end
function executeFullHeistRobbery(heistName) local config = HEIST_SPECIFIC_CONFIG[heistName]; if not config then print("[Heist] No config for: " .. heistName); return false end; local heistFolder = findInstance(config.PathString); if not heistFolder then print("[Heist] Heist folder not found: " .. config.PathString); return false end; print(string.format("--- Starting Heist: %s ---", config.DisplayName)); if config.EntryTeleportCFrame and RootPart then if not teleportTo(config.EntryTeleportCFrame, config.DisplayName .. " Entry") then return false end; task.wait(0.5) end; for i, actionConfig in ipairs(config.RobberyActions or {}) do if not currentRobberyCoroutine then print("[Heist] Robbery cancelled by user."); return false end; if not (Character and Humanoid and Humanoid.Health > 0) then print("[Heist] Character died, stopping: " .. config.DisplayName); return false end; if not attemptSingleRobberyAction(actionConfig, heistFolder, config.DisplayName) then print(string.format("[Heist] Action '%s' in %s failed. Stopping this heist.", actionConfig.Name, config.DisplayName)); return false end; task.wait(AutoHeistSettings.interactionDelay) end; print(string.format("--- Heist: %s - Completed ---", config.DisplayName)); if config.PostRobberyAction and config.PostRobberyAction.Type == "TeleportToCriminalBase" and RootPart then print("    Teleporting to Criminal Base..."); task.wait(config.PostRobberyAction.Delay or 0.5); teleportTo(CRIMINAL_BASE_TELEPORT_CFRAME, heistName .. " to Base") end; if config.DelayAfterHeist then print(string.format("Waiting %.1fs after %s", config.DelayAfterHeist, config.DisplayName)); task.wait(config.DelayAfterHeist) end; return true end
local function ServerHop()print("[ServerHop] Attempting...");local s,e=pcall(function()local S={};local R=HttpService:RequestAsync({Url="https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?sortOrder=Desc&limit=100&excludeFullGames=true",Method="GET"});if not R or not R.Success or not R.Body then print("[ServerHop] Fail get list:",R and R.Body or "No resp");return end;local B=HttpService:JSONDecode(R.Body);if B and B.data then for _,v in next,B.data do if type(v)=="table"and tonumber(v.playing)and tonumber(v.maxPlayers)and v.playing<v.maxPlayers and v.id~=game.JobId then table.insert(S,1,v.id)end end end;print("[ServerHop] Found",#S,"servers.");if #S>0 then TeleportService:TeleportToPlaceInstance(game.PlaceId,S[math.random(1,#S)],Player)else print("[ServerHop] No other servers.");if #Player:GetPlayers()<=1 then Player:Kick("Rejoining...");task.wait(1);TeleportService:Teleport(game.PlaceId,Player)else TeleportService:TeleportToPlaceInstance(game.PlaceId,game.JobId,Player)end end end);if not s then print("[ServerHop] PcallFail:",e);TeleportService:TeleportToPlaceInstance(game.PlaceId,game.JobId,Player)end end

function executeAllRobberiesAndHop()
    if isRobbingGlobally then print("[AutoRob] Sequence already running."); return end
    isRobbingGlobally = true; currentRobberyCoroutine = coroutine.running()
    print("--- Starting Full Auto-Robbery Sequence (V6.0.1) ---"); local overallStartTime = tick()
    if AutoHeistSettings.MAKE_INVISIBLE_DURING_ROB then setPlayerVisibility(false) end

    for i, heistName in ipairs(TARGET_HEISTS_TO_ROB_SEQUENCE) do
        if not currentRobberyCoroutine then print("[AutoRob] Full sequence cancelled."); break end
        if not (Character and Humanoid and Humanoid.Health > 0) then print("[AutoRob] Character died, stopping sequence."); break end
        local playerTeam = getPlayerTeam(); if playerTeam and HEIST_SPECIFIC_CONFIG[heistName] and HEIST_SPECIFIC_CONFIG[heistName].RequiresCriminalTeam and playerTeam.Name ~= CRIMINAL_TEAM_NAME then print(string.format("[AutoRob] Skipping %s: Not on Criminals team.", HEIST_SPECIFIC_CONFIG[heistName].DisplayName)); goto next_heist_in_sequence end

        local heistConfig = HEIST_SPECIFIC_CONFIG[heistName]
        if heistConfig then
            print(string.format("[AutoRob] Preparing for heist: %s (%d/%d)", heistConfig.DisplayName or heistName, i, #TARGET_HEISTS_TO_ROB_SEQUENCE))
            if not executeFullHeistRobbery(heistName) then
                print(string.format("[AutoRob] Heist %s failed/interrupted.", heistConfig.DisplayName or heistName))
                if AutoHeistSettings.stopOnErrorInSequence then print("[AutoRob] StopOnError is true. Halting sequence."); break end
            end
        else print("[AutoRob] Warning: No config for heist key: " .. heistName) end
        
        ::next_heist_in_sequence::
        if i < #TARGET_HEISTS_TO_ROB_SEQUENCE and currentRobberyCoroutine then
            local waitTime = AutoHeistSettings.delayAfterHeistCompletion
            print(string.format("[AutoRob] Waiting %.1fs before next heist...", waitTime))
            local waited = 0; while waited < waitTime and currentRobberyCoroutine do task.wait(0.1); waited = waited + 0.1 end
        end
    end
    
    if AutoHeistSettings.MAKE_INVISIBLE_DURING_ROB then setPlayerVisibility(true) end
    if currentRobberyCoroutine then print(string.format("--- Sequence Completed in %.2fs. Server Hopping. ---", tick() - overallStartTime)); ServerHop() end
    isRobbingGlobally = false; currentRobberyCoroutine = nil
end

local function createControlUI_V6()
    local playerGui = Player:WaitForChild("PlayerGui"); if not playerGui then print("[UI Error] PlayerGui V6 not found!"); return nil end
    if controlUiScreenGui and controlUiScreenGui.Parent then controlUiScreenGui:Destroy() end -- ล้าง UI เก่า ถ้ามี
    controlUiScreenGui = Instance.new("ScreenGui",playerGui); controlUiScreenGui.Name="RyntazAutoRobV6_Ctrl"; controlUiScreenGui.ResetOnSpawn=false; controlUiScreenGui.DisplayOrder=1000; controlUiScreenGui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
    
    -- Intro UI (Fullscreen text)
    local introTextLabel = Instance.new("TextLabel", controlUiScreenGui); introTextLabel.Name="IntroText"; introTextLabel.Size=UDim2.new(1,0,1,0); introTextLabel.BackgroundTransparency=1; introTextLabel.Text="FinalRob By RyntazHub"; introTextLabel.TextColor3=Color3.new(1,1,1); introTextLabel.Font=Enum.Font.SourceSansBold; introTextLabel.TextScaled=true; introTextLabel.ZIndex=2000
    task.spawn(function() local colors={Color3.fromHSV(0,1,1),Color3.fromHSV(0.1667,1,1),Color3.fromHSV(0.3333,1,1),Color3.fromHSV(0.5,1,1),Color3.fromHSV(0.6667,1,1),Color3.fromHSV(0.8333,1,1),Color3.fromHSV(1,1,1)}; local i=1; while introTextLabel.Parent do introTextLabel.TextColor3=colors[i];i=i+1;if i>#colors then i=1 end;task.wait(0.1)end end)
    task.spawn(function() for i=1,50 do introTextLabel.TextTransparency=i/50;task.wait(0.015)end; task.wait(0.3); introTextLabel.Text="กำลังเตรียมระบบ RyntazHub..."; for i=50,1,-1 do introTextLabel.TextTransparency=i/50;task.wait(0.01)end; task.wait(0.8); for i=1,50 do introTextLabel.TextTransparency=i/50;task.wait(0.015)end; if introTextLabel and introTextLabel.Parent then introTextLabel.Visible=false end end)
    task.wait(2.8) -- รอ Intro ให้จบ

    local main=Instance.new("Frame",controlUiScreenGui);main.Name="ControlPanel";main.Size=UDim2.new(0,200,0,130);main.Position=UDim2.new(0.02,10,0.5,-65);main.BackgroundColor3=Color3.fromRGB(28,28,35);main.BorderColor3=THEME_COLORS.Accent;main.BorderSizePixel=1;local c=Instance.new("UICorner",main);c.CornerRadius=UDim.new(0,5);local l=Instance.new("UIListLayout",main);l.Padding=UDim.new(0,5);l.HorizontalAlignment=Enum.HorizontalAlignment.Center;l.VerticalAlignment=Enum.VerticalAlignment.Top;l.SortOrder=Enum.SortOrder.LayoutOrder
    local title=Instance.new("TextLabel",main);title.Name="Title";title.LayoutOrder=1;title.Size=UDim2.new(1,-10,0,20);title.Text="RyntazRob V6.0.1";title.TextColor3=THEME_COLORS.Accent;title.Font=Enum.Font.Michroma;title.TextSize=11;title.BackgroundTransparency=1
    statusTextLabel=Instance.new("TextLabel",main);statusTextLabel.Name="Status";statusTextLabel.LayoutOrder=2;statusTextLabel.Size=UDim2.new(1,-10,0,18);statusTextLabel.Text="สถานะ: ว่าง";statusTextLabel.TextColor3=THEME_COLORS.TextDim;statusTextLabel.Font=Enum.Font.Code;statusTextLabel.TextSize=11;statusTextLabel.BackgroundTransparency=1;statusTextLabel.TextWrapped=true
    local startButton=createStyledButton(main,"เริ่มปล้นทั้งหมด",UDim2.new(0.9,0,0,28),UDim2.new(),Color3.fromRGB(60,180,100),Color3.new(0,0,0),13);startButton.LayoutOrder=3
    startButton.MouseButton1Click:Connect(function()if not isRobbingGlobally then task.spawn(executeAllRobberiesAndHop)else print("[ARob] In progress.")end end)
    local stopButton=createStyledButton(main,"หยุดปล้น",UDim2.new(0.9,0,0,28),UDim2.new(),Color3.fromRGB(200,60,60),Color3.new(1,1,1),13);stopButton.LayoutOrder=4
    stopButton.MouseButton1Click:Connect(function()if currentRobberyCoroutine then isRobbingGlobally=false;task.cancel(currentRobberyCoroutine);currentRobberyCoroutine=nil;logInfo("Control","สั่งหยุดการปล้นแล้ว");updateStatus("หยุดโดยผู้ใช้") if MAKE_INVISIBLE_DURING_ROB then setPlayerVisibility(true) end else logInfo("Control","ไม่มีการปล้นให้หยุด")end end)
    logInfo("UI", "Control UI Created.")
end

-- Initialize
if waitForCharacter() then
    pcall(createControlUI_V6) 
    if AUTO_START_ROBBERY_AFTER_INTRO then
        logInfo("System", "Auto-start. รอ 3.5 วินาที (หลัง Intro)...")
        task.wait(3.5) 
        if not isRobbingGlobally then 
            if Player:WaitForChild("PlayerGui"):FindFirstChild("RyntazAutoRobV6_Ctrl") then -- Check if UI still exists
                task.spawn(executeAllRobberiesAndHop) 
            else
                logInfo("System", "UI ถูกทำลาย, ยกเลิก AutoStart")
            end
        end
    else
        logInfo("System", "Auto-start ปิดอยู่. คลิกปุ่ม 'เริ่มปล้นทั้งหมด'.")
        updateStatus("พร้อม, รอคำสั่ง")
    end
else
    logInfo("System", "สคริปต์หยุดทำงาน: ไม่สามารถโหลด Character ได้")
end

_G.RyntazHubRobV6 = {
    StartAll = executeAllRobberiesAndHop,
    StartHeist = function(heistName) if not isRobbingGlobally and HEIST_SPECIFIC_CONFIG[heistName] then isRobbingGlobally=true; currentRobberyCoroutine=task.spawn(function() executeFullHeistRobbery(heistName); isRobbingGlobally=false; currentRobberyCoroutine=nil; if MAKE_INVISIBLE_DURING_ROB then setPlayerVisibility(true) end end) else print("Cannot start specific heist or already robbing.") end end,
    Stop = function() if currentRobberyCoroutine then isRobbingGlobally=false;task.cancel(currentRobberyCoroutine);currentRobberyCoroutine=nil;logInfo("GlobalAPI","Stopped."); updateStatus("หยุดโดย API"); if MAKE_INVISIBLE_DURING_ROB then setPlayerVisibility(true) end else print("Nothing to stop via API.")end end,
    ToggleInvisible = function() setPlayerVisibility(isPlayerInvisible) end -- Note: This toggles based on current script state
}
logInfo("System", "RyntazHub V6.0.1 Loaded. Use _G.RyntazHubRobV6 or UI button.")
