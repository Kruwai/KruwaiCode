-- RyntazHub AutoRob - V2.6.4 (Focused Scan & AutoRob)
-- (ฐานจาก V2.6.3 เพิ่มระบบ AutoRob และปุ่มควบคุม)

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

local function waitForCharacter()
    print("[RyntazHub V2.6.4] Waiting for character...")
    local attempts = 0
    repeat attempts = attempts + 1
        if Player and Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") and Player.Character:FindFirstChildOfClass("Humanoid") then
            Character = Player.Character; Humanoid = Character:FindFirstChildOfClass("Humanoid"); RootPart = Character:FindFirstChild("HumanoidRootPart")
            if Humanoid and RootPart then print("[RyntazHub V2.6.4] Character found."); return true end
        end; task.wait(0.2)
    until attempts > 75
    print("[RyntazHub V2.6.4] ERROR: Character not found after timeout."); return false
end

if not waitForCharacter() then print("RyntazHub ERROR: Character not loaded, script will not fully initialize."); return end
Player.CharacterAdded:Connect(function(newChar) Character=newChar; Humanoid=newChar:WaitForChild("Humanoid",15); RootPart=newChar:WaitForChild("HumanoidRootPart",15); print("[RyntazHub V2.6.4] Character respawned."); if isRobbingGlobally and currentRobberyCoroutine then print("[RyntazHub V2.6.4] Char died during rob. Stopping."); task.cancel(currentRobberyCoroutine); currentRobberyCoroutine=nil; isRobbingGlobally=false; updateStatus("หยุดปล้น (ตัวละครตาย)") end end)

local HEISTS_BASE_PATH_STRING = "Heists"
local TARGET_HEISTS_IN_WORKSPACE_FOR_SCAN = {"Bank", "Casino", "JewelryStore"}
local TARGET_HEISTS_TO_ROB_SEQUENCE = {"JewelryStore", "Bank", "Casino"}
local CRIMINAL_TEAM_NAME = "Criminals" 
local CRIMINAL_BASE_TELEPORT_CFRAME = CFrame.new(200, 10, 200) -- *** แก้ไขเป็นตำแหน่งจริง ***

local AutoHeistSettings = { teleportSpeedFactor = 180, interactionDelay = 0.2, delayAfterSuccessfulLootAction = 0.6, delayAfterHeistCompletion = 2.5, stopOnErrorInSequence = false }

local HEIST_SPECIFIC_CONFIG = {
    JewelryStore = {
        DisplayName = "ร้านเพชร", PathString = Workspace.Heists.JewelryStore, RequiresCriminalTeam = true,
        EntryTeleportCFrame = CFrame.new(-82.8, 85.5, 807.5),
        RobberyActions = {
            { Name = "เก็บเครื่องเพชร", ActionType = "IterateAndFireEvent", ItemContainerPath = "EssentialParts.JewelryBoxes", RemoteEventPath = "EssentialParts.JewelryBoxes.JewelryManager.Event", EventArgsFunc = function(lootInstance) return {lootInstance} end, FireCountPerItem = 2, TeleportOffsetPerItem = Vector3.new(0,1.8,1.8), DelayBetweenItems = 0.1, DelayBetweenFires = 0.05, RobDelayAfterAction = 0.2 }
        },
        PostRobberyAction = { Type = "TeleportToCriminalBase", Delay = 0.5 }
    },
    Bank = {
        DisplayName = "ธนาคาร", PathString = Workspace.Heists.Bank, RequiresCriminalTeam = true,
        EntryTeleportCFrame = CFrame.new(730.5, 108.0, 562.5),
        RobberyActions = {
            { Name = "เปิดประตูห้องมั่นคง", ActionType = "Touch", TargetPath = "EssentialParts.VaultDoor.Touch", TeleportOffset = Vector3.new(0,0,-2.2), RobDelayAfterAction = 3.0 },
            { Name = "เก็บเงิน CashStack", ActionType = "IterateAndFindInteract", ItemContainerPath = "Interior.CashStack.Model", ItemNameHint = "Cash", InteractionHint = {Type="RemoteEvent", NameHint="CollectCash", Args=function(item) return {item, 1000} end}, TeleportOffsetPerItem = Vector3.new(0,0.1,0), DelayBetweenItems = 0.2, FireCountPerItem = 1, RobDelayAfterAction = 0.3 }
        },
        PostRobberyAction = { Type = "TeleportToCriminalBase", Delay = 0.5 }
    },
    Casino = {
        DisplayName = "คาสิโน", PathString = Workspace.Heists.Casino, RequiresCriminalTeam = true,
        EntryTeleportCFrame = CFrame.new(1690.2, 30.5, 523.5),
        RobberyActions = {
            { Name = "แฮ็กคอมพิวเตอร์", ActionType = "ProximityPrompt", TargetPath = "Interior.HackComputer.HackComputer", ProximityPromptActionHint = "Hack", HoldDuration = 2.0, TeleportOffset = Vector3.new(0,1,-1.8), RobDelayAfterAction = 1.5 },
            { Name = "เก็บเงินห้องนิรภัย", ActionType = "IterateAndFindInteract", ItemContainerPath = "Interior.Vault", ItemNameHint = "Cash", InteractionHint = {Type="RemoteEvent", NameHint="TakeVaultCash", Args=function(item) return {item} end}, TeleportOffsetPerItem = Vector3.new(0,0.1,0), DelayBetweenItems = 0.3, FireCountPerItem = 1, RobDelayAfterAction = 0.3 }
        },
        PostRobberyAction = { Type = "TeleportToCriminalBase", Delay = 0.5 }
    }
}
local THEME_COLORS = {Background=Color3.fromRGB(18,20,23),Primary=Color3.fromRGB(25,28,33),Secondary=Color3.fromRGB(35,40,50),Accent=Color3.fromRGB(0,255,120),Text=Color3.fromRGB(210,215,220),TextDim=Color3.fromRGB(130,135,140),ButtonHover=Color3.fromRGB(50,55,70),CloseButton=Color3.fromRGB(255,95,86),MinimizeButton=Color3.fromRGB(255,189,46),MaximizeButton=Color3.fromRGB(40,200,65)}
local mainFrame,outputContainer,titleBar,statusBar,statusTextLabel,timerTextLabel;local allLoggedMessages={};local isMinimized=not INITIAL_UI_VISIBLE;local originalMainFrameSize=UDim2.new(0.6,0,0.75,0);local startTime
local function copyToClipboard(t)local s,m=pcall(function()if typeof(setclipboard)=="function"then setclipboard(t);return true end;if typeof(writefile)=="function"then writefile("ryntaz_clipboard.txt",t);return true end;return false end);print(s and(m and"[Clipboard] Copied."or"[Clipboard] Failed.")or"[Clipboard] No function.");if SHOW_UI_OUTPUT and statusTextLabel and statusTextLabel.Parent then local oS=statusTextLabel.Text;statusTextLabel.Text=s and(m and"Clipboard: OK"or"FAIL")or"N/A";task.delay(2,function()if statusTextLabel and statusTextLabel.Parent then statusTextLabel.Text=oS end end)end;return m end
local function createStyledButton(p,t,s,pos,c,tc,fs)local b=Instance.new("TextButton",p);b.Text=t;b.Size=s;b.Position=pos;b.BackgroundColor3=c or THEME_COLORS.Secondary;b.TextColor3=tc or THEME_COLORS.Text;b.Font=Enum.Font.SourceSansSemibold;b.TextSize=fs or 14;b.ClipsDescendants=true;local cr=Instance.new("UICorner",b);cr.CornerRadius=UDim.new(0,4);b.MouseEnter:Connect(function()TweenService:Create(b,TweenInfo.new(0.1),{BackgroundColor3=THEME_COLORS.ButtonHover}):Play()end);b.MouseLeave:Connect(function()TweenService:Create(b,TweenInfo.new(0.1),{BackgroundColor3=c or THEME_COLORS.Secondary}):Play()end);return b end
local function introAnimationV2(pg)local iF=Instance.new("Frame",pg);iF.Name="Intro";iF.Size=UDim2.new(1,0,1,0);iF.BackgroundTransparency=1;iF.ZIndex=2000;local tL=Instance.new("TextLabel",iF);tL.Name="RText";tL.Size=UDim2.new(0,0,0,0);tL.Position=UDim2.new(0.5,0,0.5,0);tL.AnchorPoint=Vector2.new(0.5,0.5);tL.Font=Enum.Font.Michroma;tL.Text="";tL.TextColor3=THEME_COLORS.Accent;tL.TextScaled=false;tL.TextSize=1;tL.TextTransparency=1;tL.Rotation=-10;local fT="Ryntaz Hub V6";local tD=0.6;local sD=0.5;local fD=0.3;TweenService:Create(tL,TweenInfo.new(tD,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{TextSize=60,TextTransparency=0,Rotation=0,Size=UDim2.new(0.5,0,0.15,0)}):Play();for i=1,#fT do tL.Text=string.sub(fT,1,i);task.wait(tD/#fT*0.6)end;task.wait(sD);TweenService:Create(tL,TweenInfo.new(fD,Enum.EasingStyle.Quad,Enum.EasingDirection.In),{TextTransparency=1,Rotation=5,Position=UDim2.new(0.5,0,0.45,0)}):Play();task.delay(fD+0.1,function()if iF and iF.Parent then iF:Destroy()end end)end
local function logOutputWrapper(category,message)local ts=os.date("[%H:%M:%S] ");local oM=message;local fMFC=ts.."["..category.."] "..oM;print(fMFC);table.insert(allLoggedMessages,fMFC);if SHOW_UI_OUTPUT and mainFrame and outputContainer then local entry=Instance.new("TextLabel",outputContainer);entry.Name="Log";entry.Text=ts.."<b>["..category.."]</b> "..message;entry.RichText=true;entry.TextColor3=(category:match("Error")or category:match("Fail"))and Color3.fromRGB(255,100,100)or(category:match("Success"))and Color3.fromRGB(100,255,100)or THEME_COLORS.TextDim;entry.Font=Enum.Font.Code;entry.TextSize=12;entry.TextXAlignment=Enum.TextXAlignment.Left;entry.TextWrapped=true;entry.Size=UDim2.new(1,-8,0,0);entry.AutomaticSize=Enum.AutomaticSize.Y;entry.BackgroundColor3=THEME_COLORS.Primary;entry.BackgroundTransparency=0.7;local co=Instance.new("UICorner",entry);co.CornerRadius=UDim.new(0,2);local th=5;for _,c in ipairs(outputContainer:GetChildren())do if c:IsA("TextLabel")then th=th+c.AbsoluteSize.Y+outputContainer.UIListLayout.Padding.Offset end end;outputContainer.CanvasSize=UDim2.new(0,0,0,th);if outputContainer.CanvasSize.Y.Offset>outputContainer.AbsoluteSize.Y then outputContainer.CanvasPosition=Vector2.new(0,outputContainer.CanvasSize.Y.Offset-outputContainer.AbsoluteSize.Y)end end end
local function updateStatus(text,overallPercentage)if SHOW_UI_OUTPUT and statusTextLabel and statusTextLabel.Parent then local currentText="สถานะ: "..text;if overallPercentage then currentText=currentText..string.format(" (รวม: %.0f%%)",overallPercentage)end;statusTextLabel.Text=currentText end;print("[StatusUpdate] "..text..(overallPercentage and string.format(" (รวม: %.0f%%)",overallPercentage)or""))end
local function findRemote(parentInst,nameHint)if not parentInst then return nil end;for _,D in ipairs(parentInst:GetDescendants())do if D:IsA("RemoteEvent")and D.Name:lower():match(nameHint:lower())then return D end end;for _,D in ipairs(parentInst:GetDescendants())do if D:IsA("RemoteFunction")and D.Name:lower():match(nameHint:lower())then return D end end;return nil end
local function findPrompt(parentInst,actionHint)if not parentInst then return nil end;for _,D in ipairs(parentInst:GetDescendants())do if D:IsA("ProximityPrompt")then if D.ActionText and D.ActionText:lower():match(actionHint:lower())then return D elseif D.ObjectText and D.ObjectText:lower():match(actionHint:lower())then return D end end end;return nil end
local function createMainUI_V6()
    if mainFrame and mainFrame.Parent then mainFrame.Parent:Destroy() end
    local playerGui = Player:WaitForChild("PlayerGui"); if not playerGui then print("[UI Error] PlayerGui V6 not found!"); return end
    local screenGui = Instance.new("ScreenGui",playerGui);screenGui.Name="RyntazAutoRobV6_MainCtrl";screenGui.ResetOnSpawn=false;screenGui.DisplayOrder=999;screenGui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
    introAnimationV2(screenGui); task.wait(1.4)
    mainFrame=Instance.new("Frame",screenGui);mainFrame.Name="MainFrame";mainFrame.Size=UDim2.new(0,260,0,150);mainFrame.Position=UDim2.new(0.02,10,0.5,-75);mainFrame.BackgroundColor3=THEME_COLORS.Background;mainFrame.BorderColor3=THEME_COLORS.Accent;mainFrame.BorderSizePixel=1;local c=Instance.new("UICorner",mainFrame);c.CornerRadius=UDim.new(0,5);
    titleBar=Instance.new("Frame",mainFrame);titleBar.Name="TitleBar";titleBar.Size=UDim2.new(1,0,0,28);titleBar.BackgroundColor3=THEME_COLORS.Primary;local tc=Instance.new("UICorner",titleBar);tc.CornerRadius=UDim.new(0,4);
    local titleText=Instance.new("TextLabel",titleBar);titleText.Name="Title";titleText.Size=UDim2.new(1,-50,1,0);titleText.Position=UDim2.new(0.5,0,0.5,0);titleText.AnchorPoint=Vector2.new(0.5,0.5);titleText.Text="RyntazRob V6.0";titleText.TextColor3=THEME_COLORS.Accent;titleText.Font=Enum.Font.Michroma;titleText.TextSize=12;titleText.BackgroundTransparency=1;titleText.TextXAlignment = Enum.TextXAlignment.Center
    local closeBtn=createStyledButton(titleBar,"X",UDim2.new(0,20,0.8,0),UDim2.new(1,-25,0.1,0),THEME_COLORS.Error,Color3.new(1,1,1),12)
    closeBtn.MouseButton1Click:Connect(function() screenGui:Destroy(); if currentRobberyCoroutine then task.cancel(currentRobberyCoroutine); isRobbingGlobally=false; print("[UI] Robbery stopped & UI closed.") end end)
    local contentFrame=Instance.new("Frame",mainFrame);contentFrame.Name="Content";contentFrame.Size=UDim2.new(1,-10,1,-38);contentFrame.Position=UDim2.new(0,5,0,33);contentFrame.BackgroundTransparency=1;local l=Instance.new("UIListLayout",contentFrame);l.Padding=UDim.new(0,5);l.HorizontalAlignment=Enum.HorizontalAlignment.Center;l.VerticalAlignment=Enum.VerticalAlignment.Top;l.SortOrder=Enum.SortOrder.LayoutOrder
    statusTextLabel=Instance.new("TextLabel",contentFrame);statusTextLabel.Name="Status";statusTextLabel.LayoutOrder=1;statusTextLabel.Size=UDim2.new(1,-0,0,18);statusTextLabel.Text="สถานะ: พร้อม (UI V6)";statusTextLabel.TextColor3=THEME_COLORS.TextDim;statusTextLabel.Font=Enum.Font.Code;statusTextLabel.TextSize=11;statusTextLabel.BackgroundTransparency=1;statusTextLabel.TextWrapped=true;statusTextLabel.TextYAlignment = Enum.TextYAlignment.Top
    local startButton=createStyledButton(contentFrame,"เริ่มปล้นทั้งหมด",UDim2.new(1,0,0,30),UDim2.new(),THEME_COLORS.Accent,THEME_COLORS.Background,13);startButton.LayoutOrder=2
    startButton.MouseButton1Click:Connect(function()if not isRobbingGlobally then task.spawn(executeAllRobberiesAndHop)else logOutputWrapper("Control","ปล้นอยู่แล้ว")end end)
    local stopButton=createStyledButton(contentFrame,"หยุดปล้น",UDim2.new(1,0,0,30),UDim2.new(),THEME_COLORS.Error,Color3.new(1,1,1),13);stopButton.LayoutOrder=3
    stopButton.MouseButton1Click:Connect(function()if currentRobberyCoroutine then isRobbingGlobally=false;task.cancel(currentRobberyCoroutine);currentRobberyCoroutine=nil;logOutputWrapper("Control","สั่งหยุดปล้น");updateStatus("หยุดโดยผู้ใช้")else logOutputWrapper("Control","ไม่มีอะไรให้หยุด")end end)
    mainFrame.Draggable = true; mainFrame.Active = true;
    logOutputWrapper("UI", "Control UI (V6) Created.")
end

local function attemptSingleRobberyAction(actionConfig, heistFolder, heistDisplayName) if not (Character and Humanoid and HumanoidRootPart and Humanoid.Health > 0) then logOutputWrapper("RobError", string.format("[%s] ตัวละครตาย/หาย. ข้าม: %s", heistDisplayName, actionConfig.Name)); return false end; updateStatus(string.format("%s: %s", heistDisplayName, actionConfig.Name)); local targetInstance; local teleportBaseCFrame; if actionConfig.TargetPath then targetInstance = findInstance(heistFolder, actionConfig.TargetPath); if not targetInstance then logOutputWrapper("RobError", string.format("    [Error-%s] TargetPath ไม่พบ: %s", heistDisplayName, actionConfig.TargetPath)); return false end; teleportBaseCFrame = (targetInstance:IsA("Model") and targetInstance:GetPivot() or targetInstance.CFrame) elseif actionConfig.ActionType:match("Iterate") then teleportBaseCFrame = heistFolder:GetPivot() else logOutputWrapper("RobError", string.format("    [Error-%s] Action '%s' ต้องการ TargetPath หรือเป็น Iterate type.", heistDisplayName, actionConfig.Name)); return false end; if not teleportTo(teleportBaseCFrame * CFrame.new(actionConfig.TeleportOffset or Vector3.new()), actionConfig.Name .. " (Init)") then return false end; local robSuccessful = false; if actionConfig.ActionType == "Touch" and targetInstance then if typeof(firetouchinterest) == "function" and targetInstance:IsA("BasePart") then logOutputWrapper("RobAction", "    Firing touch interest for: ".. targetInstance.Name); pcall(firetouchinterest, targetInstance, RootPart, 0); task.wait(0.05); pcall(firetouchinterest, targetInstance, RootPart, 1); robSuccessful = true else logOutputWrapper("RobInfo","    firetouchinterest N/A หรือ target ไม่ใช่ BasePart.") end elseif actionConfig.ActionType == "ProximityPrompt" and targetInstance then local prompt = findPrompt(targetInstance, actionConfig.ProximityPromptActionHint or targetInstance.Name); if prompt then if typeof(fireproximityprompt) == "function" then logOutputWrapper("RobAction",string.format("    Firing PP: %s (Hold: %.1fs)", prompt.ActionText or prompt.ObjectText or "Unknown", actionConfig.HoldDuration or 0)); pcall(fireproximityprompt, prompt, actionConfig.HoldDuration or 0); robSuccessful = true else logOutputWrapper("RobInfo","    fireproximityprompt N/A.") end else logOutputWrapper("RobWarning","    ProximityPrompt ไม่พบสำหรับ: ".. targetInstance.Name.." Hint: "..tostring(actionConfig.ProximityPromptActionHint)) end elseif (actionConfig.ActionType == "RemoteEvent" or actionConfig.ActionType == "IterateAndFireEvent") then local itemsToProcess = {}; local remoteEventInstance; local searchBaseForItems = actionConfig.ItemContainerPath and findInstance(heistFolder, actionConfig.ItemContainerPath) or heistFolder; if not searchBaseForItems then logOutputWrapper("RobError", "    [Error] ItemContainerPath ไม่พบ: " .. (actionConfig.ItemContainerPath or "N/A")); return false end; if actionConfig.ActionType == "IterateAndFireEvent" then if actionConfig.ItemQuery then itemsToProcess = actionConfig.ItemQuery(searchBaseForItems) else for _,child in ipairs(searchBaseForItems:GetChildren()) do if (child:IsA("Model") or child:IsA("BasePart")) and (not actionConfig.ItemNameHint or child.Name:lower():match(actionConfig.ItemNameHint:lower())) then table.insert(itemsToProcess, child) end end end else if targetInstance then table.insert(itemsToProcess, targetInstance) else logOutputWrapper("RobError","    [Error] TargetPath needed for SingleEvent."); return false end end; if #itemsToProcess == 0 then logOutputWrapper("RobInfo","    No items for: " .. actionConfig.Name); return true end; if actionConfig.RemoteEventPath then remoteEventInstance = findInstance(Workspace, actionConfig.RemoteEventPath) or findInstance(searchBaseForItems, actionConfig.RemoteEventPath) or (itemsToProcess[1] and itemsToProcess[1]:FindFirstChild(actionConfig.RemoteEventPath, true)) elseif actionConfig.RemoteEventNameHint then remoteEventInstance = findRemote(itemsToProcess[1], actionConfig.RemoteEventNameHint) or findRemote(itemsToProcess[1] and itemsToProcess[1].Parent, actionConfig.RemoteEventNameHint) or findRemote(heistFolder, actionConfig.RemoteEventNameHint) end; if not remoteEventInstance or not remoteEventInstance:IsA("RemoteEvent") then logOutputWrapper("RobError","    [Error] RemoteEvent not found for "..actionConfig.Name.." (Path/Hint: "..tostring(actionConfig.RemoteEventPath or actionConfig.RemoteEventNameHint)..")"); return false end; for i, itemInst in ipairs(itemsToProcess) do if not (Character and Humanoid.Health > 0 and currentRobberyCoroutine) then logOutputWrapper("RobInfo","    Robbery interrupted."); return false end; if not teleportTo((itemInst:IsA("Model") and itemInst:GetPivot() or itemInst.CFrame) * CFrame.new(actionConfig.TeleportOffsetPerItem or actionConfig.TeleportOffset or Vector3.new()), actionConfig.Name .. " Item " .. i) then return false end; local argsToFire = {}; if actionConfig.EventArgsFunc then argsToFire = actionConfig.EventArgsFunc(itemInst) or {} end; logOutputWrapper("RobAction",string.format("    Firing RE: %s for %s (%d/%d)", remoteEventInstance.Name, itemInst.Name, i, #itemsToProcess)); for fc = 1, actionConfig.FireCountPerItem or 1 do if not (Character and Humanoid.Health > 0 and currentRobberyCoroutine) then logOutputWrapper("RobInfo","    Robbery interrupted fire loop."); return false end; local s,e = pcall(function() remoteEventInstance:FireServer(unpack(argsToFire)) end); if not s then logOutputWrapper("RobError","      Error firing: "..tostring(e)) end; task.wait(actionConfig.DelayBetweenFires or 0.05) end; robSuccessful = true; if #itemsToProcess > 1 and i < #itemsToProcess then task.wait(actionConfig.DelayBetweenItems or 0.1) end end end; if robSuccessful then logOutputWrapper("RobSuccess",string.format("    Action '%s' completed.", actionConfig.Name)) else logOutputWrapper("RobFail",string.format("    Action '%s' failed/no interaction.", actionConfig.Name)) end; if actionConfig.RobDelayAfterAction then logOutputWrapper("RobInfo",string.format("    Waiting %.2fs after action '%s'", actionConfig.RobDelayAfterAction, actionConfig.Name)); task.wait(actionConfig.RobDelayAfterAction) end; return robSuccessful end
function executeFullHeistRobbery(heistName) local config = HEIST_SPECIFIC_CONFIG[heistName]; if not config then logOutputWrapper("HeistError", "No config for: " .. heistName); return false end; local heistFolder = findInstance(config.PathString); if not heistFolder then logOutputWrapper("HeistError", "Heist folder not found: " .. config.PathString); return false end; logOutputWrapper("HeistStart",string.format("--- เริ่มปล้น: %s ---", config.DisplayName)); if config.EntryTeleportCFrame and RootPart then if not teleportTo(config.EntryTeleportCFrame, config.DisplayName .. " Entry") then return false end; task.wait(0.3) end; for i, actionConfig in ipairs(config.RobberyActions or {}) do if not currentRobberyCoroutine then logOutputWrapper("HeistInfo", "การปล้นถูกยกเลิกโดยผู้ใช้"); return false end; if not (Character and Humanoid and Humanoid.Health > 0) then logOutputWrapper("HeistInfo", "ตัวละครตาย, หยุดปล้น: " .. config.DisplayName); return false end; if not attemptSingleRobberyAction(actionConfig, heistFolder, config.DisplayName) then logOutputWrapper("HeistError",string.format("Action '%s' ใน %s ล้มเหลว. หยุด Heist นี้.", actionConfig.Name, config.DisplayName)); return false end; task.wait(AutoHeistSettings.interactionDelay) end; logOutputWrapper("HeistSuccess",string.format("--- ปล้น %s สำเร็จ ---", config.DisplayName)); if config.PostRobberyAction and config.PostRobberyAction.Type == "TeleportToCriminalBase" then logOutputWrapper("HeistInfo", "กำลังเทเลพอร์ตไปฐานโจร..."); task.wait(config.PostRobberyAction.Delay or 0.1); teleportTo(CRIMINAL_BASE_TELEPORT_CFRAME, "Criminal Base") end; if config.DelayAfterHeist then logOutputWrapper("HeistInfo",string.format("รอ %.1fs หลังปล้น %s", config.DelayAfterHeist, config.DisplayName)); task.wait(config.DelayAfterHeist) end; return true end
local function ServerHop() printDebug("[ServerHop] Attempting..."); local s,e=pcall(function() local S={}; local R=HttpService:RequestAsync({Url="https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?sortOrder=Desc&limit=100&excludeFullGames=true",Method="GET"}); if not R or not R.Success or not R.Body then printDebug("[ServerHop] Fail get list: "..(R and R.Body or "No resp")); return end; local B=HttpService:JSONDecode(R.Body); if B and B.data then for _,v in next,B.data do if type(v)=="table"and tonumber(v.playing)and tonumber(v.maxPlayers)and v.playing<v.maxPlayers and v.id~=game.JobId then table.insert(S,1,v.id)end end end; printDebug("[ServerHop] Found "..#S.." servers."); if #S>0 then TeleportService:TeleportToPlaceInstance(game.PlaceId,S[math.random(1,#S)],Player) else printDebug("[ServerHop] No other servers."); if #Player:GetPlayers()<=1 then Player:Kick("Rejoining...");task.wait(1);TeleportService:Teleport(game.PlaceId,Player)else TeleportService:TeleportToPlaceInstance(game.PlaceId,game.JobId,Player)end end end); if not s then printDebug("[ServerHop] PcallFail: "..tostring(e)); TeleportService:TeleportToPlaceInstance(game.PlaceId,game.JobId,Player) end end

function executeAllRobberiesAndHop()
    if isRobbingGlobally then logOutputWrapper("RobCtrl","การปล้นกำลังทำงานอยู่แล้ว"); return end
    isRobbingGlobally = true; currentRobberyCoroutine = coroutine.running()
    logOutputWrapper("System", "--- เริ่มการปล้นทั้งหมดอัตโนมัติ (V6.0.1) ---"); startTime = tick()
    updateStatus("เริ่มลำดับการปล้น...")
    
    local playerTeam = getPlayerTeam()
    if not playerTeam or playerTeam.Name ~= CRIMINAL_TEAM_NAME then
        logOutputWrapper("RobError", string.format("ผู้เล่นไม่ได้อยู่ในทีม '%s'. ไม่สามารถเริ่มการปล้นได้.", CRIMINAL_TEAM_NAME))
        isRobbingGlobally = false; currentRobberyCoroutine = nil; updateStatus("ต้องอยู่ทีม " .. CRIMINAL_TEAM_NAME); return
    end

    if MAKE_INVISIBLE_DURING_ROB then setPlayerVisibility(false) end

    for i, heistName in ipairs(TARGET_HEISTS_TO_ROB_SEQUENCE) do
        if not currentRobberyCoroutine then logOutputWrapper("RobCtrl","การปล้นทั้งหมดถูกยกเลิก"); break end
        if not (Character and Humanoid and Humanoid.Health > 0) then logOutputWrapper("RobCtrl","ตัวละครตาย, หยุดการปล้นทั้งหมด"); break end
        
        local heistConfig = HEIST_SPECIFIC_CONFIG[heistName]
        if heistConfig then
            logOutputWrapper("Sequence", string.format("เริ่มปล้น: %s (%d/%d)", heistConfig.DisplayName or heistName, i, #TARGET_HEISTS_TO_ROB_SEQUENCE))
            if not executeFullHeistRobbery(heistName) then
                logOutputWrapper("SequenceError", string.format("การปล้น %s ล้มเหลวหรือถูกขัดจังหวะ.", heistConfig.DisplayName or heistName))
                if AutoHeistSettings.stopOnErrorInSequence then logOutputWrapper("RobCtrl","หยุดการปล้นทั้งหมดเนื่องจาก Heist ก่อนหน้าล้มเหลว."); break end
            end
        else logOutputWrapper("SequenceWarning", "ไม่พบ Config สำหรับ Heist key: " .. heistName) end
        
        if i < #TARGET_HEISTS_TO_ROB_SEQUENCE and currentRobberyCoroutine then
            local waitTime = AutoHeistSettings.delayAfterHeistCompletion
            updateStatus(string.format("รอ %.1fวินาที ก่อนปล้นที่ต่อไป...", waitTime))
            local waited = 0; while waited < waitTime and currentRobberyCoroutine do task.wait(0.1); waited = waited + 0.1 end
        end
    end
    
    if MAKE_INVISIBLE_DURING_ROB then setPlayerVisibility(true) end
    if currentRobberyCoroutine then 
        updateStatus(string.format("ลำดับการปล้นทั้งหมดเสร็จสิ้น (%.2fวิ). กำลังย้ายเซิร์ฟเวอร์...", tick() - startTime))
        logOutputWrapper("System", string.format("ลำดับการปล้นทั้งหมดเสร็จสิ้นใน %.2f วินาที. กำลังเริ่ม Server Hop.", tick() - startTime))
        ServerHop()
    end
    isRobbingGlobally = false; currentRobberyCoroutine = nil
end

task.spawn(function() while true do if mainFrame and mainFrame.Parent and timerTextLabel and startTime then timerTextLabel.Text = string.format("เวลา: %.1fs", tick() - startTime) elseif timerTextLabel then timerTextLabel.Text = "เวลา: --.-s" end; task.wait(0.1) end end)

if waitForCharacter() then
    local successUI, errUI = pcall(createControlUI_V6)
    if not successUI then printDebug("ERROR creating Control UI: " .. tostring(errUI)) end
    
    local autoStartRobbery = false -- <<<< เปลี่ยนเป็น false เพื่อให้กดปุ่มเอง
    if autoStartRobbery then
        printDebug("[AutoRob V6.0.1] Auto-start. Waiting 3s...")
        task.wait(3)
        if not isRobbingGlobally then task.spawn(executeAllRobberiesAndHop) end
    else
        printDebug("[AutoRob V6.0.1] Auto-start ปิดอยู่. คลิกปุ่ม 'เริ่มปล้นทั้งหมด'.")
        updateStatus("พร้อม, รอคำสั่ง")
    end
else
    printDebug("[AutoRob V6.0.1] Script terminated: Character not loaded.")
end

_G.RyntazHubRob = {
    Start = executeAllRobberiesAndHop,
    Stop = function() if currentRobberyCoroutine then isRobbingGlobally=false;task.cancel(currentRobberyCoroutine);currentRobberyCoroutine=nil;printDebug("[RyntazHubRob.Stop] Stopped.");updateStatus("หยุดโดยผู้ใช้");if MAKE_INVISIBLE_DURING_ROB then setPlayerVisibility(true) end else printDebug("[RyntazHubRob.Stop] Nothing to stop.")end end,
    SetInvisible = function(state) setPlayerVisibility(not state) end,
    TeleportToHeistEntry = function(heistNameKey) local config=HEIST_SPECIFIC_CONFIG[heistNameKey];if config and config.EntryTeleportCFrame and RootPart then teleportTo(config.EntryTeleportCFrame,heistNameKey.." Entry")else printDebug("Cannot teleport to entry for: "..tostring(heistNameKey))end end
}
printDebug("[RyntazHub V6.0.1] Loaded. Use _G.RyntazHubRob.Start() or UI button.")
