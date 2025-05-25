-- RyntazHub AutoRob - V6.0 (Advanced Heist Logic)
-- Based on V2.6.3, implementing more detailed robbery sequences.

local Player = game:GetService("Players").LocalPlayer
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeamsService = game:GetService("Teams")

local Character, Humanoid, RootPart
local currentRobberyCoroutine = nil
local isRobbingGlobally = false
local autoRobEnabled = false -- สถานะของ AutoRob Mode (สำหรับปุ่ม Toggle)

local function getPlayerTeam()
    if Player and Player.Team then
        return Player.Team
    end
    return nil
end

local function waitForCharacter()
    print("[RyntazHub V6] Waiting for character...")
    local attempts = 0
    repeat attempts = attempts + 1
        if Player and Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") and Player.Character:FindFirstChildOfClass("Humanoid") then
            Character = Player.Character; Humanoid = Character:FindFirstChildOfClass("Humanoid"); RootPart = Character:FindFirstChild("HumanoidRootPart")
            if Humanoid and RootPart then print("[RyntazHub V6] Character found."); return true end
        end; task.wait(0.2)
    until attempts > 75
    print("[RyntazHub V6] ERROR: Character not found after timeout."); return false
end

if not waitForCharacter() then print("RyntazHub ERROR: Character not loaded, script will not fully initialize."); return end

Player.CharacterAdded:Connect(function(newChar)
    Character = newChar; Humanoid = newChar:WaitForChild("Humanoid",15); RootPart = newChar:WaitForChild("HumanoidRootPart",15)
    print("[RyntazHub V6] Character respawned/added.")
    if isRobbingGlobally and currentRobberyCoroutine then
        print("[RyntazHub V6] Character died. Stopping current robbery.")
        task.cancel(currentRobberyCoroutine); currentRobberyCoroutine = nil; isRobbingGlobally = false
    end
end)

-- ================= CONFIGURATION =================
local HEISTS_BASE_PATH_STRING = "Workspace.Heists"
local TARGET_HEISTS_TO_ROB_SEQUENCE = {"JewelryStore", "Bank", "Casino"} -- ลำดับการปล้น
local CRIMINAL_TEAM_NAME = "Criminals" -- **ปรับชื่อทีมอาชญากรให้ถูกต้อง**
local CRIMINAL_BASE_TELEPORT_CFRAME = CFrame.new(0, 10, 0) -- ***ใส่ CFrame ของฐานโจรที่นี่***

local AutoHeistSettings = {
    teleportSpeedFactor = 180,
    interactionDelay = 0.25,
    delayAfterSuccessfulLootAction = 0.8, -- รอหลังเก็บของแต่ละชิ้น/ทำ Action ย่อยสำเร็จ
    delayAfterHeistCompletion = 4.0, -- รอหลังปล้น Heist นั้นๆ เสร็จทั้งหมด
    stopOnErrorInSequence = true -- ถ้าเป็น true, การปล้น Heist หนึ่งล้มเหลว จะหยุดการปล้นทั้งหมด
}

local HEIST_SPECIFIC_CONFIG = {
    JewelryStore = {
        DisplayName = "ร้านเพชร", PathString = HEISTS_BASE_PATH_STRING .. ".JewelryStore",
        RequiresCriminalTeam = true,
        EntryTeleportCFrame = CFrame.new(-82.8, 85.5, 807.5),
        RobberyActions = {
            {
                Name = "ต่อยกระจกตู้โชว์ (สมมติ)", ActionType = "SimulateBreak", -- ActionType ใหม่
                TargetContainerPath = "EssentialParts.JewelryBoxes", -- ที่เก็บตู้โชว์
                TargetNameHint = "JewelryBox", -- หรือชื่อตู้โชว์ (ถ้ามีหลายแบบ)
                BreakToolName = nil, -- ชื่อ Tool ที่ใช้ต่อย (ถ้ามี, nil คือมือเปล่า/Exploit)
                BreakDuration = 0.5, -- เวลาจำลองการต่อย
                TeleportOffsetPerTarget = Vector3.new(0, 1.8, 1.5), -- ยืนหน้าตู้
                DelayAfterAction = 0.5 -- รอหลังต่อยกระจกแต่ละตู้
            },
            {
                Name = "เก็บเครื่องเพชร", ActionType = "IterateAndFireEvent",
                ItemContainerPath = "EssentialParts.JewelryBoxes", -- ที่เก็บเพชร (อาจจะซ้อนอยู่ใน JewelryBox Model)
                ItemNameHint = "Diamond", -- หรือชื่อเพชร/ของมีค่าที่ปรากฏหลังกระจกแตก
                RemoteEventPath = "EssentialParts.JewelryBoxes.JewelryManager.Event",
                EventArgsFunc = function(lootInstance) return {lootInstance} end,
                FireCountPerItem = 1,
                TeleportOffsetPerItem = Vector3.new(0, 1.5, 1.5), -- เข้าไปเก็บ
                DelayBetweenItems = AutoHeistSettings.delayAfterSuccessfulLootAction,
                DelayBetweenFires = 0.1
            }
        },
        PostRobberyAction = { Type = "TeleportToCriminalBase", Delay = 1.0 }
    },
    Bank = {
        DisplayName = "ธนาคาร", PathString = HEISTS_BASE_PATH_STRING .. ".Bank",
        RequiresCriminalTeam = true,
        EntryTeleportCFrame = CFrame.new(730.5, 108.0, 562.5),
        RobberyActions = {
            { Name = "เปิดประตูห้องมั่นคง", ActionType = "Touch", TargetPath = "EssentialParts.VaultDoor.Touch", TeleportOffset = Vector3.new(0,0,-2.2), RobDelayAfterAction = 3.5 },
            { Name = "เก็บเงิน CashStack", ActionType = "IterateAndFindInteract", ItemContainerPath = "Interior.CashStack.Model", ItemNameHint = "Cash", InteractionHint = {Type="RemoteEvent", NameHint="CollectCash", Args=function(item) return {item, 1000} end}, TeleportOffsetPerItem = Vector3.new(0,0.1,0), DelayBetweenItems = AutoHeistSettings.delayAfterSuccessfulLootAction, FireCountPerItem = 1 }
        },
        PostRobberyAction = { Type = "TeleportToCriminalBase", Delay = 1.0 }
    },
    Casino = {
        DisplayName = "คาสิโน", PathString = HEISTS_BASE_PATH_STRING .. ".Casino",
        RequiresCriminalTeam = true,
        EntryTeleportCFrame = CFrame.new(1690.2, 30.5, 523.5),
        RobberyActions = {
            { Name = "แฮ็กคอมพิวเตอร์", ActionType = "ProximityPrompt", TargetPath = "Interior.HackComputer.HackComputer", ProximityPromptActionHint = "Hack", HoldDuration = 3.0, TeleportOffset = Vector3.new(0,1,-1.8), RobDelayAfterAction = 2.0 },
            { Name = "เก็บเงินห้องนิรภัย", ActionType = "IterateAndFindInteract", ItemContainerPath = "Interior.Vault", ItemNameHint = "Cash", InteractionHint = {Type="RemoteEvent", NameHint="TakeVaultCash", Args=function(item) return {item} end}, TeleportOffsetPerItem = Vector3.new(0,0.1,0), DelayBetweenItems = AutoHeistSettings.delayAfterSuccessfulLootAction, FireCountPerItem = 1 }
        },
        PostRobberyAction = { Type = "TeleportToCriminalBase", Delay = 1.0 }
    }
}
-- (ส่วน THEME_COLORS, UI Functions: copyToClipboard, createStyledButton, introAnimationV2, logOutputWrapper, updateStatus เหมือนเดิมจาก V2.6.3)
local THEME_COLORS = {Accent=Color3.fromRGB(0,255,120),Secondary=Color3.fromRGB(35,40,50),Text=Color3.fromRGB(210,215,220),ButtonHover=Color3.fromRGB(50,55,70),Error=Color3.fromRGB(255,80,80)}
local mainFrame, outputContainer, titleBar, statusBar, statusTextLabel, timerTextLabel, robButtonsFrame; local allLoggedMessages={}; local isMinimized=not INITIAL_UI_VISIBLE; local originalMainFrameSize=UDim2.new(0.45,0,0.30,0); local startTime
local function copyToClipboard(t)local s,m=pcall(function()if typeof(setclipboard)=="function"then setclipboard(t);return true end;if typeof(writefile)=="function"then writefile("rh_clip.txt",t);return true end;return false end);print(s and(m and"[Clip] OK"or"[Clip] FAIL")or"[Clip] NoFunc");if statusTextLabel and statusTextLabel.Parent then local oS=statusTextLabel.Text;statusTextLabel.Text=s and(m and"Clipboard: OK"or"FAIL")or"N/A";task.delay(2,function()if statusTextLabel and statusTextLabel.Parent then statusTextLabel.Text=oS end end)end;return m end
local function createStyledButton(p,t,s,pos,c,tc,fs)local b=Instance.new("TextButton",p);b.Text=t;b.Size=s;b.Position=pos;b.BackgroundColor3=c or THEME_COLORS.Secondary;b.TextColor3=tc or THEME_COLORS.Text;b.Font=Enum.Font.SourceSansSemibold;b.TextSize=fs or 13;b.ClipsDescendants=true;local cr=Instance.new("UICorner",b);cr.CornerRadius=UDim.new(0,4);b.MouseEnter:Connect(function()TweenService:Create(b,TweenInfo.new(0.1),{BackgroundColor3=THEME_COLORS.ButtonHover}):Play()end);b.MouseLeave:Connect(function()TweenService:Create(b,TweenInfo.new(0.1),{BackgroundColor3=c or THEME_COLORS.Secondary}):Play()end);return b end
local function introAnimationV2(pg) local iF=Instance.new("Frame",pg);iF.Name="Intro";iF.Size=UDim2.new(1,0,1,0);iF.BackgroundTransparency=1;iF.ZIndex=2000;local tL=Instance.new("TextLabel",iF);tL.Name="RText";tL.Size=UDim2.new(0,0,0,0);tL.Position=UDim2.new(0.5,0,0.5,0);tL.AnchorPoint=Vector2.new(0.5,0.5);tL.Font=Enum.Font.Michroma;tL.Text="";tL.TextColor3=THEME_COLORS.Accent;tL.TextScaled=false;tL.TextSize=1;tL.TextTransparency=1;tL.Rotation=-10;local fT="RyntazHub V6";local tD=0.5;local sD=0.6;local fD=0.25;TweenService:Create(tL,TweenInfo.new(tD,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{TextSize=60,TextTransparency=0,Rotation=0,Size=UDim2.new(0.4,0,0.12,0)}):Play();for i=1,#fT do tL.Text=string.sub(fT,1,i);task.wait(tD/#fT*0.5)end;task.wait(sD);TweenService:Create(tL,TweenInfo.new(fD,Enum.EasingStyle.Quad,Enum.EasingDirection.In),{TextTransparency=1,Rotation=5,Position=UDim2.new(0.5,0,0.45,0)}):Play();task.delay(fD+0.1,function()if iF and iF.Parent then iF:Destroy()end end)end
local function logOutputWrapper(category,message)local ts=os.date("[%H:%M:%S] ");local oM=message;local fMFC=ts.."["..category.."] "..oM;print(fMFC);table.insert(allLoggedMessages,fMFC);if mainFrame and outputContainer then local entry=Instance.new("TextLabel",outputContainer);entry.Name="Log";entry.Text=ts.."<b>["..category.."]</b> "..message;entry.RichText=true;entry.TextColor3=(category:match("Error")or category:match("Fail"))and Color3.fromRGB(255,100,100)or(category:match("Success"))and Color3.fromRGB(100,255,100)or THEME_COLORS.TextDim;entry.Font=Enum.Font.Code;entry.TextSize=11;entry.TextXAlignment=Enum.TextXAlignment.Left;entry.TextWrapped=true;entry.Size=UDim2.new(1,-8,0,0);entry.AutomaticSize=Enum.AutomaticSize.Y;entry.BackgroundColor3=Color3.fromRGB(25,25,30);entry.BackgroundTransparency=0.7;local co=Instance.new("UICorner",entry);co.CornerRadius=UDim.new(0,2);local th=5;for _,c in ipairs(outputContainer:GetChildren())do if c:IsA("TextLabel")then th=th+c.AbsoluteSize.Y+outputContainer.UIListLayout.Padding.Offset end end;outputContainer.CanvasSize=UDim2.new(0,0,0,th);if outputContainer.CanvasSize.Y.Offset>outputContainer.AbsoluteSize.Y then outputContainer.CanvasPosition=Vector2.new(0,outputContainer.CanvasSize.Y.Offset-outputContainer.AbsoluteSize.Y)end end end
local function updateStatus(text)if statusTextLabel and statusTextLabel.Parent then statusTextLabel.Text="สถานะ: "..text end;print("[Status] "..text)end

local function createControlUI_V6()
    if mainFrame and mainFrame.Parent then mainFrame.Parent:Destroy() end
    local playerGui = Player:WaitForChild("PlayerGui"); if not playerGui then print("[UI Error] PlayerGui V6 not found!"); return end
    local screenGui = Instance.new("ScreenGui",playerGui);screenGui.Name="RyntazAutoRobV6_Ctrl";screenGui.ResetOnSpawn=false;screenGui.DisplayOrder=1000;screenGui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
    
    introAnimationV2(screenGui); task.wait(1.2)

    mainFrame = Instance.new("Frame",screenGui);main.Name="MainFrame";main.Size=UDim2.new(0,220,0,130);main.Position=UDim2.new(0.02,0,0.5,-65);main.BackgroundColor3=THEME_COLORS.Background;main.BorderColor3=THEME_COLORS.Accent;main.BorderSizePixel=1;local c=Instance.new("UICorner",main);c.CornerRadius=UDim.new(0,5);local l=Instance.new("UIListLayout",main);l.Padding=UDim.new(0,5);l.HorizontalAlignment=Enum.HorizontalAlignment.Center;l.VerticalAlignment=Enum.VerticalAlignment.Top;l.SortOrder=Enum.SortOrder.LayoutOrder
    
    local title=Instance.new("TextLabel",main);title.Name="Title";title.LayoutOrder=1;title.Size=UDim2.new(1,-10,0,20);title.Text="RyntazRob V6";title.TextColor3=THEME_COLORS.Accent;title.Font=Enum.Font.Michroma;title.TextSize=12;title.BackgroundTransparency=1
    
    statusTextLabel = Instance.new("TextLabel",main);statusTextLabel.Name="Status";statusTextLabel.LayoutOrder=2;statusTextLabel.Size=UDim2.new(1,-10,0,18);statusTextLabel.Text="สถานะ: ว่าง";statusTextLabel.TextColor3=THEME_COLORS.TextDim;statusTextLabel.Font=Enum.Font.Code;statusTextLabel.TextSize=11;statusTextLabel.BackgroundTransparency=1;statusTextLabel.TextWrapped=true
    
    local startButton = createStyledButton(main,"เริ่มปล้นทั้งหมด",UDim2.new(0.9,0,0,30),UDim2.new(),THEME_COLORS.Accent,THEME_COLORS.Background,13);startButton.LayoutOrder=3
    startButton.MouseButton1Click:Connect(function()
        if not isRobbingGlobally then 
            logOutputWrapper("Control", "สั่งเริ่มปล้นทั้งหมด...")
            currentRobberyCoroutine = task.spawn(executeAllRobberiesAndHop)
        else 
            logOutputWrapper("Control", "การปล้นกำลังทำงานอยู่แล้ว")
        end 
    end)
    
    local stopButton = createStyledButton(main,"หยุดปล้น",UDim2.new(0.9,0,0,30),UDim2.new(),THEME_COLORS.Error,Color3.new(1,1,1),13);stopButton.LayoutOrder=4
    stopButton.MouseButton1Click:Connect(function()
        if currentRobberyCoroutine then 
            isRobbingGlobally = false; task.cancel(currentRobberyCoroutine); currentRobberyCoroutine = nil
            logOutputWrapper("Control", "สั่งหยุดการปล้นแล้ว")
            updateStatus("หยุดโดยผู้ใช้")
            if MAKE_INVISIBLE_DURING_ROB then setPlayerVisibility(true) end -- ทำให้มองเห็นเมื่อหยุด
        else 
            logOutputWrapper("Control", "ไม่มีการปล้นที่กำลังทำงานอยู่ให้หยุด")
        end 
    end)
    mainFrame.Visible = true
end

-- (Helper Functions: findInstance, teleportTo, findRemote, findPrompt คงเดิมจาก V5.3.1)
-- (Robbery Logic: attemptSingleRobberyAction, executeFullHeistRobbery, ServerHop, executeAllRobberiesAndHop คงเดิมจาก V5.3.1)
-- (แต่จะมีการเรียก setPlayerVisibility(false/true) ใน executeAllRobberiesAndHop)
-- (และ attemptSingleRobberyAction จะมีการเพิ่ม RobDelayAfterAction ตาม Config)

-- ฟังก์ชันที่คัดลอกมาและปรับปรุงเล็กน้อย
function attemptSingleRobberyAction(actionConfig, heistFolder, heistDisplayName)
    if not (Character and Humanoid and HumanoidRootPart and Humanoid.Health > 0) then print(string.format("[%s] Character dead/missing. Skipping action: %s", heistDisplayName, actionConfig.Name)); return false end
    updateStatus(string.format("%s: %s", heistDisplayName, actionConfig.Name))
    local targetInstance; local teleportBaseCFrame
    if actionConfig.TargetPath then targetInstance = findInstance(heistFolder, actionConfig.TargetPath); if not targetInstance then print(string.format("    [Error-%s] TargetPath not found: %s", heistDisplayName, actionConfig.TargetPath)); return false end; teleportBaseCFrame = (targetInstance:IsA("Model") and targetInstance:GetPivot() or targetInstance.CFrame)
    elseif actionConfig.ActionType:match("Iterate") then teleportBaseCFrame = heistFolder:GetPivot() else print(string.format("    [Error-%s] Action '%s' needs TargetPath or is Iterate type.", heistDisplayName, actionConfig.Name)); return false end
    if not teleportTo(teleportBaseCFrame * CFrame.new(actionConfig.TeleportOffset or Vector3.new()), actionConfig.Name .. " (Init)") then return false end
    local robSuccessful = false
    if actionConfig.ActionType == "Touch" and targetInstance then if typeof(firetouchinterest) == "function" and targetInstance:IsA("BasePart") then print("    Firing touch interest for:", targetInstance.Name); pcall(firetouchinterest, targetInstance, RootPart, 0); task.wait(0.05); pcall(firetouchinterest, targetInstance, RootPart, 1); robSuccessful = true else print("    firetouchinterest not available or target not BasePart.") end
    elseif actionConfig.ActionType == "ProximityPrompt" and targetInstance then local prompt = findPrompt(targetInstance, actionConfig.ProximityPromptActionHint or targetInstance.Name); if prompt then if typeof(fireproximityprompt) == "function" then print(string.format("    Firing PP: %s (Hold: %.1fs)", prompt.ActionText or prompt.ObjectText or "Unknown", actionConfig.HoldDuration or 0)); pcall(fireproximityprompt, prompt, actionConfig.HoldDuration or 0); robSuccessful = true else print("    fireproximityprompt not available.") end else print("    ProximityPrompt not found for:", targetInstance.Name, "Hint:", actionConfig.ProximityPromptActionHint) end
    elseif (actionConfig.ActionType == "RemoteEvent" or actionConfig.ActionType == "IterateAndFireEvent") then local itemsToProcess = {}; local remoteEventInstance; local searchBaseForItems = actionConfig.ItemContainerPath and findInstance(heistFolder, actionConfig.ItemContainerPath) or heistFolder; if not searchBaseForItems then print("    [Error] ItemContainerPath not found: " .. (actionConfig.ItemContainerPath or "N/A")); return false end; if actionConfig.ActionType == "IterateAndFireEvent" then if actionConfig.ItemQuery then itemsToProcess = actionConfig.ItemQuery(searchBaseForItems) else for _,child in ipairs(searchBaseForItems:GetChildren()) do if (child:IsA("Model") or child:IsA("BasePart")) and (not actionConfig.ItemNameHint or child.Name:lower():match(actionConfig.ItemNameHint:lower())) then table.insert(itemsToProcess, child) end end end else if targetInstance then table.insert(itemsToProcess, targetInstance) else print("    [Error] TargetPath needed for SingleEvent."); return false end end; if #itemsToProcess == 0 then print("    No items found for: " .. actionConfig.Name); return true end; if actionConfig.RemoteEventPath then remoteEventInstance = findInstance(Workspace, actionConfig.RemoteEventPath) or findInstance(searchBaseForItems, actionConfig.RemoteEventPath) or (itemsToProcess[1] and itemsToProcess[1]:FindFirstChild(actionConfig.RemoteEventPath, true)) elseif actionConfig.RemoteEventNameHint then remoteEventInstance = findRemote(itemsToProcess[1], actionConfig.RemoteEventNameHint) or findRemote(itemsToProcess[1] and itemsToProcess[1].Parent, actionConfig.RemoteEventNameHint) or findRemote(heistFolder, actionConfig.RemoteEventNameHint) end; if not remoteEventInstance or not remoteEventInstance:IsA("RemoteEvent") then print("    [Error] RemoteEvent not found for action:", actionConfig.Name, "(Path/Hint:", actionConfig.RemoteEventPath or actionConfig.RemoteEventNameHint or "N/A", ")"); return false end; for i, itemInst in ipairs(itemsToProcess) do if not (Character and Humanoid.Health > 0 and currentRobberyCoroutine) then print("    Robbery sequence interrupted."); return false end; if not teleportTo((itemInst:IsA("Model") and itemInst:GetPivot() or itemInst.CFrame) * CFrame.new(actionConfig.TeleportOffsetPerItem or actionConfig.TeleportOffset or Vector3.new()), actionConfig.Name .. " Item " .. i) then return false end; local argsToFire = {}; if actionConfig.EventArgsFunc then argsToFire = actionConfig.EventArgsFunc(itemInst) or {} end; print(string.format("    Firing RE: %s for %s (Item %d/%d)", remoteEventInstance.Name, itemInst.Name, i, #itemsToProcess)); for fc = 1, actionConfig.FireCountPerItem or 1 do if not (Character and Humanoid.Health > 0 and currentRobberyCoroutine) then print("    Robbery interrupted fire loop."); return false end; local s,e = pcall(function() remoteEventInstance:FireServer(unpack(argsToFire)) end); if not s then print("      Error firing event: "..tostring(e)) end; task.wait(actionConfig.DelayBetweenFires or 0.1) end; robSuccessful = true; if #itemsToProcess > 1 and i < #itemsToProcess then task.wait(actionConfig.DelayBetweenItems or 0.2) end end
    end; if robSuccessful then print(string.format("    Action '%s' completed.", actionConfig.Name)) else print(string.format("    Action '%s' failed or no interaction.", actionConfig.Name)) end; if actionConfig.RobDelayAfterAction then print(string.format("    Waiting %.2fs after action '%s'", actionConfig.RobDelayAfterAction, actionConfig.Name)); task.wait(actionConfig.RobDelayAfterAction) end; return robSuccessful end
function executeFullHeistRobbery(heistName) local config = HEIST_SPECIFIC_CONFIG[heistName]; if not config then print("[Heist] No config for: " .. heistName); return false end; local heistFolder = findInstance(config.PathString); if not heistFolder then print("[Heist] Heist folder not found: " .. config.PathString); return false end; print(string.format("--- เริ่มปล้น: %s ---", config.DisplayName)); if config.EntryTeleportCFrame and RootPart then if not teleportTo(config.EntryTeleportCFrame, config.DisplayName .. " Entry") then return false end; task.wait(0.5) end; for i, actionConfig in ipairs(config.RobberyActions or {}) do if not currentRobberyCoroutine then print("[Heist] การปล้นถูกยกเลิก"); return false end; if not (Character and Humanoid and Humanoid.Health > 0) then print("[Heist] ตัวละครตาย, หยุดปล้น: " .. config.DisplayName); return false end; if not attemptSingleRobberyAction(actionConfig, heistFolder, config.DisplayName) then print(string.format("[Heist] Action '%s' ใน %s ล้มเหลว. หยุด Heist นี้.", actionConfig.Name, config.DisplayName)); return false end; task.wait(AutoHeistSettings.interactionDelay) end; print(string.format("--- ปล้น %s สำเร็จ ---", config.DisplayName)); if config.DelayAfterHeist then print(string.format("รอ %.1fs หลังปล้น %s", config.DelayAfterHeist, config.DisplayName)); task.wait(config.DelayAfterHeist) end; return true end
local function ServerHop()print("[ServerHop] Attempting...");local s,e=pcall(function()local S={};local R=HttpService:RequestAsync({Url="https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?sortOrder=Desc&limit=100&excludeFullGames=true",Method="GET"});if not R or not R.Success or not R.Body then print("[ServerHop] Fail get list:",R and R.Body or "No resp");return end;local B=HttpService:JSONDecode(R.Body);if B and B.data then for _,v in next,B.data do if type(v)=="table"and tonumber(v.playing)and tonumber(v.maxPlayers)and v.playing<v.maxPlayers and v.id~=game.JobId then table.insert(S,1,v.id)end end end;print("[ServerHop] Found",#S,"servers.");if #S>0 then TeleportService:TeleportToPlaceInstance(game.PlaceId,S[math.random(1,#S)],Player)else print("[ServerHop] No other servers.");if #Player:GetPlayers()<=1 then Player:Kick("Rejoining...");task.wait(1);TeleportService:Teleport(game.PlaceId,Player)else TeleportService:TeleportToPlaceInstance(game.PlaceId,game.JobId,Player)end end end);if not s then print("[ServerHop] PcallFail:",e);TeleportService:TeleportToPlaceInstance(game.PlaceId,game.JobId,Player)end end

function executeAllRobberiesAndHop()
    if isRobbingGlobally then print("[AutoRob] Sequence is already running."); return end
    isRobbingGlobally = true; currentRobberyCoroutine = coroutine.running()
    print("--- เริ่มการปล้นทั้งหมดอัตโนมัติ (V5.3.2) ---"); startTime = tick()
    updateStatus("เริ่มลำดับการปล้น...")
    if MAKE_INVISIBLE_DURING_ROB then setPlayerVisibility(false) end

    for i, heistName in ipairs(TARGET_HEISTS_TO_ROB_SEQUENCE) do
        if not currentRobberyCoroutine then print("[AutoRob] การปล้นทั้งหมดถูกยกเลิก"); break end
        if not (Character and Humanoid and Humanoid.Health > 0) then print("[AutoRob] ตัวละครตาย, หยุดการปล้นทั้งหมด"); break end
        
        local heistConfig = HEIST_SPECIFIC_CONFIG[heistName]
        if heistConfig then
            updateStatus(string.format("กำลังเตรียมปล้น: %s (%d/%d)", heistConfig.DisplayName or heistName, i, #TARGET_HEISTS_TO_ROB_SEQUENCE))
            if not executeFullHeistRobbery(heistName) then
                updateStatus(string.format("การปล้น %s ล้มเหลว/ถูกขัดจังหวะ", heistConfig.DisplayName or heistName))
                if AutoHeistSettings.stopOnError then print("[AutoRob] หยุดการปล้นทั้งหมดเนื่องจาก Heist ก่อนหน้าล้มเหลว."); break end
            end
        else updateStatus("ข้าม: ไม่พบ Config สำหรับ " .. heistName) end
        
        if i < #TARGET_HEISTS_TO_ROB_SEQUENCE and currentRobberyCoroutine then
            local waitTime = AutoHeistSettings.delayAfterHeistCompletion
            updateStatus(string.format("รอ %.1fวินาที ก่อนปล้นที่ต่อไป...", waitTime))
            local waited = 0; while waited < waitTime and currentRobberyCoroutine do task.wait(0.1); waited = waited + 0.1 end
        end
    end
    
    if MAKE_INVISIBLE_DURING_ROB then setPlayerVisibility(true) end
    if currentRobberyCoroutine then 
        updateStatus(string.format("ลำดับการปล้นทั้งหมดเสร็จสิ้น (%.2fวิ). กำลังย้ายเซิร์ฟเวอร์...", tick() - startTime))
        ServerHop()
    end
    isRobbingGlobally = false; currentRobberyCoroutine = nil
end

task.spawn(function() while true do if mainFrame and mainFrame.Parent and timerTextLabel and startTime then timerTextLabel.Text = string.format("เวลา: %.1fs", tick() - startTime) elseif timerTextLabel then timerTextLabel.Text = "เวลา: --.-s" end; task.wait(0.1) end end)

if waitForCharacter() then
    pcall(createControlUI_V6) 
    if AUTO_START_ROBBERY_AFTER_INTRO then
        print("[AutoRob V5.3.2] Auto-start. รอ 3.5 วินาที (หลัง Intro)...")
        task.wait(3.5) 
        if not isRobbingGlobally then task.spawn(executeAllRobberiesAndHop) end
    else
        print("[AutoRob V5.3.2] Auto-start ปิดอยู่. คลิกปุ่ม 'เริ่มปล้นทั้งหมด'.")
        updateStatus("พร้อม, รอคำสั่ง")
    end
else
    print("[AutoRob V5.3.2] สคริปต์หยุดทำงาน: ไม่สามารถโหลด Character ได้")
end

_G.RyntazHubRob = {
    Start = executeAllRobberiesAndHop,
    Stop = function() if currentRobberyCoroutine then isRobbingGlobally=false;task.cancel(currentRobberyCoroutine);currentRobberyCoroutine=nil;print("[RyntazHubRob.Stop] Stopped.") else print("[RyntazHubRob.Stop] Nothing to stop.")end end,
    SetInvisible = function(state) setPlayerVisibility(not state) end, -- _G.RyntazHubRob.SetInvisible(true) for invisible
    TeleportToHeistEntry = function(heistNameKey)
        local config = HEIST_SPECIFIC_CONFIG[heistNameKey]
        if config and config.EntryTeleportCFrame and RootPart then
            teleportTo(config.EntryTeleportCFrame, heistNameKey .. " Entry")
        else print("Cannot teleport to entry for: "..tostring(heistNameKey)) end
    end
}
print("[RyntazHub V5.3.2] Loaded. Use _G.RyntazHubRob.Start() or UI button.")
