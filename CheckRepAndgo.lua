-- RyntazHub AutoRob - V5.3.2 (Incorporating "FinalRob" Concepts)
-- Based on V5.3.1, adding intro UI and visibility concepts.

local Player = game:GetService("Players").LocalPlayer
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")

local Character
local Humanoid
local HumanoidRootPart
local currentRobberyCoroutine = nil
local isRobbingGlobally = false
local isPlayerInvisible = false -- สถานะการล่องหน

local function waitForCharacter()
    print("[RyntazHub V5.3.2] Waiting for character...")
    local attempts = 0
    repeat
        attempts = attempts + 1
        if Player and Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") and Player.Character:FindFirstChildOfClass("Humanoid") then
            Character = Player.Character
            Humanoid = Character:FindFirstChildOfClass("Humanoid")
            RootPart = Character:FindFirstChild("HumanoidRootPart")
            if Humanoid and RootPart then print("[RyntazHub V5.3.2] Character found."); return true end
        end
        task.wait(0.3)
    until attempts > 60
    print("[RyntazHub V5.3.2] ERROR: Character not found after timeout."); return false
end

Player.CharacterAdded:Connect(function(newChar)
    Character = newChar
    Humanoid = newChar:WaitForChild("Humanoid", 15)
    RootPart = newChar:WaitForChild("HumanoidRootPart", 15)
    print("[RyntazHub V5.3.2] Character respawned/added.")
    if isPlayerInvisible then -- ถ้าเคยล่องหนไว้ ให้ล่องหนอีกครั้งเมื่อเกิดใหม่
        task.wait(0.5) -- รอให้ Part โหลดครบ
        setPlayerVisibility(false)
    end
    if isRobbingGlobally and currentRobberyCoroutine then
        print("[RyntazHub V5.3.2] Character died during robbery. Stopping current sequence.")
        task.cancel(currentRobberyCoroutine)
        currentRobberyCoroutine = nil
        isRobbingGlobally = false
    end
end)

-- ================= CONFIGURATION =================
local HEISTS_BASE_PATH_STRING = "Workspace.Heists"
local TARGET_HEISTS_TO_ROB_SEQUENCE = {"JewelryStore", "Bank", "Casino"}
local AUTO_START_ROBBERY_AFTER_INTRO = true -- ตั้งเป็น true เพื่อให้เริ่มปล้นอัตโนมัติหลัง Intro
local MAKE_INVISIBLE_DURING_ROB = true -- ตั้งเป็น true เพื่อให้ล่องหนระหว่างปล้น

local HEIST_SPECIFIC_CONFIG = {
    JewelryStore = {
        DisplayName = "ร้านเพชร", PathString = HEISTS_BASE_PATH_STRING .. ".JewelryStore", EntryTeleportCFrame = CFrame.new(-82.8, 85.5, 807.5),
        RobberyActions = {{ Name = "เก็บเครื่องเพชร", ActionType = "IterateAndFireEvent", ItemContainerPath = "EssentialParts.JewelryBoxes", RemoteEventPath = "EssentialParts.JewelryBoxes.JewelryManager.Event", EventArgsFunc = function(lootInstance) return {lootInstance} end, FireCountPerItem = 2, TeleportOffsetPerItem = Vector3.new(0, 1.8, 1.8), DelayBetweenItems = 0.15, DelayBetweenFires = 0.1, RobDelayAfterAction = 0.2 }}
    },
    Bank = {
        DisplayName = "ธนาคาร", PathString = HEISTS_BASE_PATH_STRING .. ".Bank", EntryTeleportCFrame = CFrame.new(730, 108, 565),
        RobberyActions = {{ Name = "เปิดประตูห้องมั่นคง", ActionType = "Touch", TargetPath = "EssentialParts.VaultDoor.Touch", TeleportOffset = Vector3.new(0, 0, -2.2), RobDelayAfterAction = 1.5 }, { Name = "เก็บเงิน CashStack", ActionType = "IterateAndFindInteract", ItemContainerPath = "Interior.CashStack.Model", ItemNameHint = "Cash", InteractionHint = {Type="RemoteEvent", NameHint="CollectCash", Args=function(item) return {item, 1000} end}, TeleportOffset = Vector3.new(0,0.5,0), DelayBetweenItems = 0.2, FireCountPerItem = 1, RobDelayAfterAction = 0.3 }, { Name = "เก็บเงิน Model Cash", ActionType = "IterateAndFindInteract", ItemContainerPath = "Interior.Model", ItemNameHint = "Cash", InteractionHint = {Type="RemoteEvent", NameHint="CollectMoney", Args=function(item) return {item, 500} end}, TeleportOffset = Vector3.new(0,0.5,0), DelayBetweenItems = 0.2, FireCountPerItem = 1, RobDelayAfterAction = 0.3 }}
    },
    Casino = {
        DisplayName = "คาสิโน", PathString = HEISTS_BASE_PATH_STRING .. ".Casino", EntryTeleportCFrame = CFrame.new(1690, 30, 525),
        RobberyActions = {{ Name = "แฮ็กคอมพิวเตอร์", ActionType = "ProximityPrompt", TargetPath = "Interior.HackComputer.HackComputer", ProximityPromptActionHint = "Hack", HoldDuration = 2.0, TeleportOffset = Vector3.new(0,1,-1.8), RobDelayAfterAction = 1.0 }, { Name = "เก็บเงิน CashGiver", ActionType = "IterateAndFindInteract", ItemContainerPath = "EssentialParts.CasinoDoor", ItemNameHint = "CashGiver", InteractionHint = {Type="RemoteEvent", NameHint="GiveCash", Args=function(item) return {} end}, TeleportOffset = Vector3.new(0,0.5,0), DelayBetweenItems = 0.2, FireCountPerItem = 1, RobDelayAfterAction = 0.3 }, { Name = "เก็บเงินใน Interior", ActionType = "IterateAndFindInteract", ItemContainerPath = "Interior.Vault", ItemNameHint = "Cash", InteractionHint = {Type="RemoteEvent", NameHint="TakeVaultCash", Args=function(item) return {item} end}, TeleportOffset = Vector3.new(0,0.5,0), DelayBetweenItems = 0.2, FireCountPerItem = 1, RobDelayAfterAction = 0.3 }}
    }
}
local THEME_COLORS = {Accent = Color3.fromRGB(0,255,120), Secondary = Color3.fromRGB(35,40,50), Text = Color3.fromRGB(210,215,220)} -- สีที่ใช้บ่อย

-- ================= HELPER FUNCTIONS (เหมือน V5.3.1) =================
local function findInstance(pathStringOrInstance, childPath) local root=nil;if type(pathStringOrInstance)=="string"then local current=game;for component in pathStringOrInstance:gmatch("([^%.]+)")do if current then current=current:FindFirstChild(component)else return nil end end;root=current elseif typeof(pathStringOrInstance)=="Instance"then root=pathStringOrInstance end;if not root then return nil end;return childPath and root:FindFirstChild(childPath,true)or root end
local function teleportTo(targetCFrame, actionName) if not RootPart then print(string.format("[Teleport-%s] RootPart is nil.", actionName or "General")); return false end; print(string.format("[Teleport-%s] Moving to %.1f, %.1f, %.1f", actionName or "General", targetCFrame.X, targetCFrame.Y, targetCFrame.Z)); local success, err = pcall(function() RootPart.CFrame = targetCFrame end); if not success then print(string.format("[Teleport-%s] Failed: %s", actionName or "General", err)); return false end; local arrived = false; local timeout = 0; repeat task.wait(0.05); timeout = timeout + 0.05; if RootPart and (RootPart.Position - targetCFrame.Position).Magnitude < 2 then arrived = true end until arrived or timeout > 1.0; if not arrived then print(string.format("[Teleport-%s] Warning: May not have reached CFrame.",actionName or "General")) end; task.wait(0.1); return true end
local function findRemote(parentInst,nameHint)if not parentInst then return nil end;for _,D in ipairs(parentInst:GetDescendants())do if D:IsA("RemoteEvent")and D.Name:lower():match(nameHint:lower())then return D end end;for _,D in ipairs(parentInst:GetDescendants())do if D:IsA("RemoteFunction")and D.Name:lower():match(nameHint:lower())then return D end end;return nil end
local function findPrompt(parentInst,actionHint)if not parentInst then return nil end;for _,D in ipairs(parentInst:GetDescendants())do if D:IsA("ProximityPrompt")then if D.ActionText and D.ActionText:lower():match(actionHint:lower())then return D elseif D.ObjectText and D.ObjectText:lower():match(actionHint:lower())then return D end end end;return nil end
local function createStyledButton(parent,text,size,pos,color,textColor,fontSize) local b=Instance.new("TextButton",parent);b.Text=text;b.Size=size;b.Position=pos;b.BackgroundColor3=color or THEME_COLORS.Secondary;b.TextColor3=textColor or THEME_COLORS.Text;b.Font=Enum.Font.SourceSansSemibold;b.TextSize=fontSize or 14;b.ClipsDescendants=true;local c=Instance.new("UICorner",b);c.CornerRadius=UDim.new(0,4);return b end

-- ================= PLAYER VISIBILITY FUNCTION =================
function setPlayerVisibility(visible)
    if not Character then return end
    isPlayerInvisible = not visible
    local targetTransparency = visible and 0 or 1
    local targetCollide = visible 

    for _, part in ipairs(Character:GetChildren()) do
        if part:IsA("BasePart") or part:IsA("Accessory") then
            if part:IsA("Accessory") then -- Handle accessories
                local handle = part:FindFirstChild("Handle")
                if handle and handle:IsA("BasePart") then
                    handle.Transparency = targetTransparency
                    handle.CanCollide = targetCollide
                end
            else -- Handle character parts
                part.Transparency = targetTransparency
                part.CanCollide = targetCollide
            end
        end
    end
    -- Name tag
    local head = Character:FindFirstChild("Head")
    if head then
        local billboard = head:FindFirstChildOfClass("BillboardGui")
        if billboard then billboard.Enabled = visible end
        -- Ensure head itself is also transparent if hiding
        if not visible then head.Transparency = 1; head.CanCollide = false else head.Transparency = 0; head.CanCollide = true end
    end
    print("[Visibility] Player visibility set to:", visible)
end

-- ================= ROBBERY LOGIC (จาก V5.3.1) =================
local function attemptSingleRobberyAction(actionConfig, heistFolder, heistDisplayName) if not (Character and Humanoid and HumanoidRootPart and Humanoid.Health > 0) then print(string.format("[%s] Character dead/missing. Skipping action: %s", heistDisplayName, actionConfig.Name)); return false end; print(string.format("  [%s Action] %s", heistDisplayName, actionConfig.Name)); local targetInstance; local teleportBaseCFrame; if actionConfig.TargetPath then targetInstance = findInstance(heistFolder, actionConfig.TargetPath); if not targetInstance then print(string.format("    [Error-%s] TargetPath not found: %s", heistDisplayName, actionConfig.TargetPath)); return false end; teleportBaseCFrame = (targetInstance:IsA("Model") and targetInstance:GetPivot() or targetInstance.CFrame) elseif actionConfig.ActionType:match("Iterate") then teleportBaseCFrame = heistFolder:GetPivot() else print(string.format("    [Error-%s] Action '%s' needs TargetPath or is Iterate type.", heistDisplayName, actionConfig.Name)); return false end; if not teleportTo(teleportBaseCFrame * CFrame.new(actionConfig.TeleportOffset or Vector3.new()), actionConfig.Name .. " (Initial for Action)") then return false end; local robSuccessful = false; if actionConfig.ActionType == "Touch" and targetInstance then if typeof(firetouchinterest) == "function" and targetInstance:IsA("BasePart") then print("    Firing touch interest for:", targetInstance.Name); pcall(firetouchinterest, targetInstance, RootPart, 0); task.wait(0.05); pcall(firetouchinterest, targetInstance, RootPart, 1); robSuccessful = true else print("    firetouchinterest not available or target not BasePart.") end elseif actionConfig.ActionType == "ProximityPrompt" and targetInstance then local prompt = findPrompt(targetInstance, actionConfig.ProximityPromptActionHint or targetInstance.Name); if prompt then if typeof(fireproximityprompt) == "function" then print(string.format("    Firing PP: %s (Hold: %.1fs)", prompt.ActionText or prompt.ObjectText or "Unknown", actionConfig.HoldDuration or 0)); pcall(fireproximityprompt, prompt, actionConfig.HoldDuration or 0); robSuccessful = true else print("    fireproximityprompt not available.") end else print("    ProximityPrompt not found for:", targetInstance.Name, "Hint:", actionConfig.ProximityPromptActionHint) end elseif (actionConfig.ActionType == "RemoteEvent" or actionConfig.ActionType == "IterateAndFireEvent") then local itemsToProcess = {}; local remoteEventInstance; local searchBaseForItems = actionConfig.ItemContainerPath and findInstance(heistFolder, actionConfig.ItemContainerPath) or heistFolder; if not searchBaseForItems then print("    [Error] ItemContainerPath not found: " .. (actionConfig.ItemContainerPath or "N/A")); return false end; if actionConfig.ActionType == "IterateAndFireEvent" then if actionConfig.ItemQuery then itemsToProcess = actionConfig.ItemQuery(searchBaseForItems) else for _,child in ipairs(searchBaseForItems:GetChildren()) do if (child:IsA("Model") or child:IsA("BasePart")) and (not actionConfig.ItemNameHint or child.Name:lower():match(actionConfig.ItemNameHint:lower())) then table.insert(itemsToProcess, child) end end end else if targetInstance then table.insert(itemsToProcess, targetInstance) else print("    [Error] TargetPath needed for SingleEvent."); return false end end; if #itemsToProcess == 0 then print("    No items found for: " .. actionConfig.Name); return true end; if actionConfig.RemoteEventPath then remoteEventInstance = findInstance(Workspace, actionConfig.RemoteEventPath) or findInstance(searchBaseForItems, actionConfig.RemoteEventPath) or (itemsToProcess[1] and itemsToProcess[1]:FindFirstChild(actionConfig.RemoteEventPath, true)) elseif actionConfig.RemoteEventNameHint then remoteEventInstance = findRemote(itemsToProcess[1], actionConfig.RemoteEventNameHint) or findRemote(itemsToProcess[1] and itemsToProcess[1].Parent, actionConfig.RemoteEventNameHint) or findRemote(heistFolder, actionConfig.RemoteEventNameHint) end; if not remoteEventInstance or not remoteEventInstance:IsA("RemoteEvent") then print("    [Error] RemoteEvent not found for action:", actionConfig.Name, "(Path/Hint:", actionConfig.RemoteEventPath or actionConfig.RemoteEventNameHint or "N/A", ")"); return false end; for i, itemInst in ipairs(itemsToProcess) do if not (Character and Humanoid.Health > 0 and currentRobberyCoroutine) then print("    Robbery sequence interrupted."); return false end; if not teleportTo((itemInst:IsA("Model") and itemInst:GetPivot() or itemInst.CFrame) * CFrame.new(actionConfig.TeleportOffsetPerItem or actionConfig.TeleportOffset or Vector3.new()), actionConfig.Name .. " Item " .. i) then return false end; local argsToFire = {}; if actionConfig.EventArgsFunc then argsToFire = actionConfig.EventArgsFunc(itemInst) or {} end; print(string.format("    Firing RE: %s for %s (Item %d/%d)", remoteEventInstance.Name, itemInst.Name, i, #itemsToProcess)); for fc = 1, actionConfig.FireCountPerItem or 1 do if not (Character and Humanoid.Health > 0 and currentRobberyCoroutine) then print("    Robbery interrupted fire loop."); return false end; local s,e = pcall(function() remoteEventInstance:FireServer(unpack(argsToFire)) end); if not s then print("      Error firing event: "..tostring(e)) end; task.wait(actionConfig.DelayBetweenFires or 0.05) end; robSuccessful = true; if #itemsToProcess > 1 and i < #itemsToProcess then task.wait(actionConfig.DelayBetweenItems or 0.1) end end end; if robSuccessful then print(string.format("    Action '%s' completed.", actionConfig.Name)) else print(string.format("    Action '%s' failed or no interaction.", actionConfig.Name)) end; if actionConfig.RobDelayAfterAction then print(string.format("    Waiting %.2fs after action '%s'", actionConfig.RobDelayAfterAction, actionConfig.Name)); task.wait(actionConfig.RobDelayAfterAction) end; return robSuccessful end
function executeFullHeistRobbery(heistName) local config=HEIST_SPECIFIC_CONFIG[heistName];if not config then print("[Heist] No config for: "..heistName);return false end;local heistFolder=findInstance(config.PathString);if not heistFolder then print("[Heist] Heist folder not found: "..config.PathString);return false end;print(string.format("--- Starting Heist: %s ---",config.DisplayName));if config.EntryTeleportCFrame and RootPart then if not teleportTo(config.EntryTeleportCFrame,config.DisplayName.." Entry")then return false end;task.wait(0.3)end;for i,actionConfig in ipairs(config.RobberyActions or{})do if not currentRobberyCoroutine then print("[Heist] Robbery cancelled by user.");return false end;if not(Character and Humanoid and Humanoid.Health>0)then print("[Heist] Character died, stopping: "..config.DisplayName);return false end;if not attemptSingleRobberyAction(actionConfig,heistFolder,config.DisplayName)then print(string.format("[Heist] Action '%s' in %s failed. Stopping.",actionConfig.Name,config.DisplayName));return false end;task.wait(AutoHeistSettings.interactionDelay)end;print(string.format("--- Heist: %s - Completed ---",config.DisplayName));if config.DelayAfterHeist then print(string.format("Waiting %.1fs after %s", config.DelayAfterHeist, config.DisplayName)); task.wait(config.DelayAfterHeist) end;return true end
local function ServerHop()print("[ServerHop] Attempting...");local s,e=pcall(function()local S={};local R=HttpService:RequestAsync({Url="https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?sortOrder=Desc&limit=100&excludeFullGames=true",Method="GET"});if not R or not R.Success or not R.Body then print("[ServerHop] Fail get list:",R and R.Body or "No resp");return end;local B=HttpService:JSONDecode(R.Body);if B and B.data then for _,v in next,B.data do if type(v)=="table"and tonumber(v.playing)and tonumber(v.maxPlayers)and v.playing<v.maxPlayers and v.id~=game.JobId then table.insert(S,1,v.id)end end end;print("[ServerHop] Found",#S,"servers.");if #S>0 then TeleportService:TeleportToPlaceInstance(game.PlaceId,S[math.random(1,#S)],Player)else print("[ServerHop] No other servers.");if #Player:GetPlayers()<=1 then Player:Kick("Rejoining...");task.wait(1);TeleportService:Teleport(game.PlaceId,Player)else TeleportService:TeleportToPlaceInstance(game.PlaceId,game.JobId,Player)end end end);if not s then print("[ServerHop] PcallFail:",e);TeleportService:TeleportToPlaceInstance(game.PlaceId,game.JobId,Player)end end

function executeAllRobberiesAndHop()
    if isRobbingGlobally then print("[AutoRob] Sequence already running."); return end
    isRobbingGlobally = true; currentRobberyCoroutine = coroutine.running()
    print("--- Starting Full Auto-Robbery Sequence (V5.3.2) ---"); local overallStartTime = tick()
    if MAKE_INVISIBLE_DURING_ROB then setPlayerVisibility(false) end

    for i, heistName in ipairs(TARGET_HEISTS_TO_ROB_SEQUENCE) do
        if not currentRobberyCoroutine then print("[AutoRob] Full sequence cancelled."); break end
        if not (Character and Humanoid and Humanoid.Health > 0) then print("[AutoRob] Character died, stopping sequence."); break end
        local heistConfig = HEIST_SPECIFIC_CONFIG[heistName]
        if heistConfig then
            print(string.format("[AutoRob] Preparing for heist: %s (%d/%d)", heistConfig.DisplayName or heistName, i, #TARGET_HEISTS_TO_ROB_SEQUENCE))
            if not executeFullHeistRobbery(heistName) then
                print(string.format("[AutoRob] Heist %s failed/interrupted.", heistConfig.DisplayName or heistName))
                if AutoHeistSettings.stopOnError then print("[AutoRob] StopOnError is true. Halting sequence."); break end
            end
        else print("[AutoRob] Warning: No config for heist key: " .. heistName) end
        if i < #TARGET_HEISTS_TO_ROB_SEQUENCE and currentRobberyCoroutine then
            local waitTime = math.random(2, 4) + (heistConfig and heistConfig.DelayAfterHeist or 1)
            print(string.format("[AutoRob] Waiting %.1fs before next heist...", waitTime))
            local waited = 0; while waited < waitTime and currentRobberyCoroutine do task.wait(0.1); waited = waited + 0.1 end
        end
    end
    if MAKE_INVISIBLE_DURING_ROB then setPlayerVisibility(true) end -- ทำให้มองเห็นอีกครั้ง
    if currentRobberyCoroutine then print(string.format("--- Sequence Completed in %.2fs. Server Hopping. ---", tick() - overallStartTime)); ServerHop() end
    isRobbingGlobally = false; currentRobberyCoroutine = nil
end

-- ================= INTRO UI AND CONTROL UI =================
local mainControlUI = {}

local function createIntroAndControlUI()
    if CoreGui:FindFirstChild("RyntazAutoRob_Control_V532") then CoreGui.RyntazAutoRob_Control_V532:Destroy() end
    local playerGui = Player:WaitForChild("PlayerGui"); if not playerGui then print("[UI Error] PlayerGui not found!"); return nil end
    
    mainControlUI.ScreenGui = Instance.new("ScreenGui", playerGui)
    mainControlUI.ScreenGui.Name = "RyntazAutoRob_Control_V532"
    mainControlUI.ScreenGui.ResetOnSpawn = false; mainControlUI.ScreenGui.DisplayOrder = 1000; mainControlUI.ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    -- Intro Animation UI (คล้ายโค้ดเก่าของคุณ)
    local introTextLabel = Instance.new("TextLabel", mainControlUI.ScreenGui)
    introTextLabel.Size = UDim2.new(1,0,1,0); introTextLabel.BackgroundTransparency = 1; introTextLabel.Text = "FinalRob By RyntazHub"
    introTextLabel.TextColor3 = Color3.new(1,1,1); introTextLabel.Font = Enum.Font.SourceSansBold; introTextLabel.TextScaled = true; introTextLabel.ZIndex = 2000
    
    task.spawn(function()
        local colors = {Color3.fromHSV(0,1,1),Color3.fromHSV(0.1667,1,1),Color3.fromHSV(0.3333,1,1),Color3.fromHSV(0.5,1,1),Color3.fromHSV(0.6667,1,1),Color3.fromHSV(0.8333,1,1),Color3.fromHSV(1,1,1)}
        local i=1; while introTextLabel.Parent do introTextLabel.TextColor3=colors[i];i=i+1;if i>#colors then i=1 end;task.wait(0.1)end
    end)
    task.spawn(function()
        for i=1,50 do introTextLabel.TextTransparency=i/50;task.wait(0.02)end -- Fade In
        task.wait(0.5)
        introTextLabel.Text = "RyntazHub กำลังเตรียมระบบ..." -- สามารถเปลี่ยนข้อความได้
        for i=50,1,-1 do introTextLabel.TextTransparency=i/50;task.wait(0.01)end -- Fade Out
        for i=1,50 do introTextLabel.TextTransparency=i/50;task.wait(0.02)end -- Fade In
        task.wait(1)
        for i=50,1,-1 do introTextLabel.TextTransparency=i/50;task.wait(0.01)end -- Fade Out
        if introTextLabel and introTextLabel.Parent then introTextLabel.Visible = false end -- ซ่อน TextLabel Intro
    end)
    
    task.wait(3.0) -- รอ Intro Animation ให้จบประมาณหนึ่ง

    -- Control UI
    local main = Instance.new("Frame", mainControlUI.ScreenGui)
    main.Name = "ControlPanel"
    main.Size = UDim2.new(0, 200, 0, 110); main.Position = UDim2.new(0.02, 0, 0.5, -55)
    main.BackgroundColor3 = Color3.fromRGB(28,28,35); main.BorderColor3 = THEME_COLORS.Accent; main.BorderSizePixel = 1
    local c=Instance.new("UICorner",main);c.CornerRadius=UDim.new(0,5);local l=Instance.new("UIListLayout",main);l.Padding=UDim.new(0,5);l.HorizontalAlignment=Enum.HorizontalAlignment.Center;l.VerticalAlignment=Enum.VerticalAlignment.Center;l.SortOrder=Enum.SortOrder.LayoutOrder
    
    local title=Instance.new("TextLabel",main);title.Name="Title";title.LayoutOrder=1;title.Size=UDim2.new(1,-10,0,20);title.Text="Ryntaz AutoRob V5.3.2";title.TextColor3=THEME_COLORS.Accent;title.Font=Enum.Font.Michroma;title.TextSize=10;title.BackgroundTransparency=1
    
    local startButton=createStyledButton(main,"เริ่มปล้นทั้งหมด",UDim2.new(0.9,0,0,28),UDim2.new(),Color3.fromRGB(60,180,100),Color3.new(1,1,1),13);startButton.LayoutOrder=2
    startButton.MouseButton1Click:Connect(function()if not isRobbingGlobally then task.spawn(executeAllRobberiesAndHop)else print("[ARob] In progress.")end end)
    
    local stopButton=createStyledButton(main,"หยุดปล้น",UDim2.new(0.9,0,0,28),UDim2.new(),Color3.fromRGB(200,60,60),Color3.new(1,1,1),13);stopButton.LayoutOrder=3
    stopButton.MouseButton1Click:Connect(function()if currentRobberyCoroutine then isRobbingGlobally=false;task.cancel(currentRobberyCoroutine);currentRobberyCoroutine=nil;print("[ARob] Stopped.")else print("[ARob] Nothing to stop.")end end)
    
    if introTextLabel and introTextLabel.Parent then introTextLabel:Destroy() end -- ทำลาย Intro Text Label หลังจาก UI หลักพร้อม
    print("[AutoRob V5.3.2] Control UI Created.")
end

-- ================= INITIALIZATION & AUTO-START =================
if waitForCharacter() then
    pcall(createIntroAndControlUI) -- เรียก UI ที่รวม Intro และ Control Panel
    if AUTO_START_ROBBERY_AFTER_INTRO then
        print("[AutoRob V5.3.2] Auto-start enabled. Waiting for intro + 2s...")
        task.wait(3.5) -- รอ Intro Animation และเผื่อเวลาเพิ่ม
        if not isRobbingGlobally then 
            if MAKE_INVISIBLE_DURING_ROB then setPlayerVisibility(false) end
            task.spawn(executeAllRobberiesAndHop) 
        end
    else
        print("[AutoRob V5.3.2] Auto-start disabled. Click button or call executeAllRobberiesAndHop()")
    end
else
    print("[AutoRob V5.3.2] Script terminated: Character not loaded.")
end
