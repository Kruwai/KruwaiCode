--[[
Script สํารวจ Heists และ ReplicatedStorage - V2.6.4 (Focused Scan & AutoRob Framework)
(ฐานจาก V2.6.3 เพิ่มระบบ AutoRob พื้นฐาน และปุ่มควบคุม)

เป้าหมาย: สแกน Heists และ ReplicatedStorage, หาจุดปล้น, และมีโครงสร้างสำหรับ AutoRob
สร้างขึ้นเพื่อวัตถุประสงค์ในการทดสอบและปรับปรุงความปลอดภัยเท่านั้น
]]

local Player = game:GetService("Players").LocalPlayer
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Character references
local Character
local Humanoid
local HumanoidRootPart

local function waitForCharacter()
    -- liveDebug("waitForCharacter: Called") -- Removed for cleaner final log unless debugging
    local attempts = 0
    repeat
        attempts = attempts + 1
        if Player and Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") and Player.Character:FindFirstChildOfClass("Humanoid") then
            Character = Player.Character
            Humanoid = Character:FindFirstChildOfClass("Humanoid")
            RootPart = Character:FindFirstChild("HumanoidRootPart")
            if Humanoid and RootPart then 
                -- liveDebug("waitForCharacter: Character and parts FOUND on attempt " .. attempts)
                return true 
            end
        end
        -- liveDebug("waitForCharacter: Attempt " .. attempts .. " - Still waiting...")
        task.wait(0.2)
    until attempts > 50 
    -- liveDebug("waitForCharacter: FAILED after 50 attempts.")
    return false
end
-- รอ Character โหลดครั้งแรก (สำคัญมาก)
if not waitForCharacter() then
    print("RyntazHub Error: ไม่สามารถโหลด Character ได้ สคริปต์จะหยุดทำงาน")
    return 
end

Player.CharacterAdded:Connect(function(newChar) -- Handle respawn
    Character = newChar
    Humanoid = newChar:WaitForChild("Humanoid", 10)
    RootPart = newChar:WaitForChild("HumanoidRootPart", 10)
    -- liveDebug("Character respawned.")
end)


-- ================= CONFIGURATION =================
local HEISTS_BASE_PATH_STRING = "Heists"
local TARGET_HEISTS_IN_WORKSPACE_FOR_SCAN = {"Bank", "Casino", "JewelryStore"} -- สำหรับปุ่ม "Rescan Focus"
local TARGET_HEISTS_TO_ROB_SEQUENCE = {"JewelryStore", "Bank", "Casino"} -- ลำดับการปล้นสำหรับ "Auto-Rob All"

local UI_OUTPUT_ENCRYPTION_METHOD = "None" -- "None", "Hex", "Base64"
local INITIAL_UI_VISIBLE = true

local EXTRA_LOOT_KEYWORDS = {"moneybag", "goldbar", "artifact", "valuable", "contraband", "keycard", "access", "vault", "safe", "computer", "terminal", "loot", "item", "collectible", "displaycase"}
local MINI_ROBBERIES_NAMES_EXTENDED = {
    "Cash", "CashRegister", "DiamondBox", "Laptop", "Phone", "Luggage", "ATM", "TV", "Safe",
    "Briefcase", "MoneyStack", "GoldStack", "Computer", "Terminal"
}
local SENSITIVE_SCRIPT_KEYWORDS = {"admin", "exploit", "hack", "remote", "event", "fire", "invoke", "money", "cash", "rob", "heist", "security", "bypass", "kill", "fly", "speed", "esp", "trigger", "pcall", "require", "network", "signal"}


-- ================= THEME & UI SETTINGS =================
local THEME_COLORS = {
    Background = Color3.fromRGB(18, 20, 23), Primary = Color3.fromRGB(25, 28, 33),
    Secondary = Color3.fromRGB(35, 40, 50), Accent = Color3.fromRGB(0, 255, 120),
    Text = Color3.fromRGB(210, 215, 220), TextDim = Color3.fromRGB(130, 135, 140),
    ButtonHover = Color3.fromRGB(50, 55, 70), CloseButton = Color3.fromRGB(255, 95, 86),
    MinimizeButton = Color3.fromRGB(255, 189, 46), MaximizeButton = Color3.fromRGB(40, 200, 65)
}

-- ================= UI ELEMENTS & FUNCTIONS =================
local mainFrame, outputContainer, titleBar, statusBar, statusTextLabel, timerTextLabel
local allLoggedMessages = {}; local isMinimized = not INITIAL_UI_VISIBLE
local originalMainFrameSize = UDim2.new(0.5, 0, 0.65, 0) -- ปรับขนาด UI
local startTime; local currentRobberyCoroutine = nil
local ScannedHeistData = {} -- Table เก็บข้อมูล Heist ที่สแกนเจอสำหรับ AutoRob

local function copyToClipboard(textToCopy) local s,m=pcall(function()if typeof(setclipboard)=="function"then setclipboard(textToCopy);return true end;if typeof(writefile)=="function"then writefile("ryntaz_clipboard.txt",textToCopy);return true end;return false end);print(s and(m and"[Clipboard] Copied/Saved."or"[Clipboard] Failed.")or"[Clipboard] No function.");if statusTextLabel and statusTextLabel.Parent then local oS=statusTextLabel.Text;statusTextLabel.Text=s and(m and"Clipboard: OK"or"Clipboard: FAIL")or"Clipboard: N/A";task.delay(2,function()if statusTextLabel and statusTextLabel.Parent then statusTextLabel.Text=oS end end)end;return m end
local function createStyledButton(parent,text,size,pos,color,textColor,fontSize)local b=Instance.new("TextButton",parent);b.Text=text;b.Size=size;b.Position=pos;b.BackgroundColor3=color or THEME_COLORS.Secondary;b.TextColor3=textColor or THEME_COLORS.Text;b.Font=Enum.Font.SourceSansSemibold;b.TextSize=fontSize or 14;b.ClipsDescendants=true;local c=Instance.new("UICorner",b);c.CornerRadius=UDim.new(0,4);b.MouseEnter:Connect(function()TweenService:Create(b,TweenInfo.new(0.1),{BackgroundColor3=THEME_COLORS.ButtonHover}):Play()end);b.MouseLeave:Connect(function()TweenService:Create(b,TweenInfo.new(0.1),{BackgroundColor3=color or THEME_COLORS.Secondary}):Play()end);return b end
local function introAnimationV2(parentGui)local iF=Instance.new("Frame",parentGui);iF.Name="Intro";iF.Size=UDim2.new(1,0,1,0);iF.BackgroundTransparency=1;iF.ZIndex=2000;local tL=Instance.new("TextLabel",iF);tL.Name="RText";tL.Size=UDim2.new(0,0,0,0);tL.Position=UDim2.new(0.5,0,0.5,0);tL.AnchorPoint=Vector2.new(0.5,0.5);tL.Font=Enum.Font.Michroma;tL.Text="";tL.TextColor3=THEME_COLORS.Accent;tL.TextScaled=false;tL.TextSize=1;tL.TextTransparency=1;tL.Rotation=-10;local fT="Ryntaz Hub";local tD=0.6;local sD=0.5;local fD=0.3;TweenService:Create(tL,TweenInfo.new(tD,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{TextSize=70,TextTransparency=0,Rotation=0,Size=UDim2.new(0.5,0,0.15,0)}):Play();for i=1,#fT do tL.Text=string.sub(fT,1,i);task.wait(tD/#fT*0.6)end;task.wait(sD);TweenService:Create(tL,TweenInfo.new(fD,Enum.EasingStyle.Quad,Enum.EasingDirection.In),{TextTransparency=1,Rotation=5,Position=UDim2.new(0.5,0,0.45,0)}):Play();task.delay(fD+0.1,function()if iF and iF.Parent then iF:Destroy()end end)end

local function createMainUI()
    if mainFrame and mainFrame.Parent then return end
    local screenGui = Instance.new("ScreenGui", Player:WaitForChild("PlayerGui")); screenGui.Name = "RyntazHub_V2_6_4"; screenGui.ResetOnSpawn = false; screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling; screenGui.DisplayOrder = 1000
    introAnimationV2(screenGui); task.wait(1.4)

    mainFrame = Instance.new("Frame", screenGui); mainFrame.Name = "MainFrame"; mainFrame.Size = UDim2.fromScale(0.01,0.01); mainFrame.Position = UDim2.new(0.5,0,0.5,0); mainFrame.AnchorPoint = Vector2.new(0.5,0.5); mainFrame.BackgroundColor3 = THEME_COLORS.Background; mainFrame.BorderSizePixel = 1; mainFrame.BorderColor3 = THEME_COLORS.Accent; mainFrame.ClipsDescendants = true; local fc=Instance.new("UICorner",mainFrame); fc.CornerRadius=UDim.new(0,6)
    titleBar = Instance.new("Frame", mainFrame); titleBar.Name = "TitleBar"; titleBar.Size = UDim2.new(1,0,0,30); titleBar.BackgroundColor3 = THEME_COLORS.Primary; titleBar.BorderSizePixel = 0; titleBar.ZIndex = 3
    local titleText = Instance.new("TextLabel", titleBar); titleText.Name = "TitleText"; titleText.Size = UDim2.new(1,-80,1,0); titleText.Position = UDim2.new(0.5,0,0.5,0); titleText.AnchorPoint = Vector2.new(0.5,0.5); titleText.BackgroundTransparency = 1; titleText.Font = Enum.Font.Michroma; titleText.Text = "RyntazHub :: Focused Explorer"; titleText.TextColor3 = THEME_COLORS.Accent; titleText.TextSize = 15; titleText.TextXAlignment = Enum.TextXAlignment.Center
    local btnS=UDim2.new(0,12,0,12); local btnY=0.5; local btnYO=-6; local cB=Instance.new("ImageButton",titleBar);cB.Name="Close";cB.Size=btnS;cB.Position=UDim2.new(0,10,btnY,btnYO);cB.Image="rbxassetid://13516625";cB.ImageColor3=THEME_COLORS.CloseButton;cB.BackgroundTransparency=1;cB.ZIndex=4; local mB=Instance.new("ImageButton",titleBar);mB.Name="Minimize";mB.Size=btnS;mB.Position=UDim2.new(0,30,btnY,btnYO);mB.Image="rbxassetid://13516625";mB.ImageColor3=THEME_COLORS.MinimizeButton;mB.BackgroundTransparency=1;mB.ZIndex=4; local mxB=Instance.new("ImageButton",titleBar);mxB.Name="Maximize";mxB.Size=btnS;mxB.Position=UDim2.new(0,50,btnY,btnYO);mxB.Image="rbxassetid://13516625";mxB.ImageColor3=THEME_COLORS.MaximizeButton;mxB.BackgroundTransparency=1;mxB.ZIndex=4
    outputContainer = Instance.new("ScrollingFrame", mainFrame); outputContainer.Name = "OutputContainer"; outputContainer.Size = UDim2.new(1,-10,1,-95); outputContainer.Position = UDim2.new(0,5,0,30); outputContainer.BackgroundColor3 = Color3.fromRGB(22,24,27); outputContainer.BorderSizePixel = 1; outputContainer.BorderColor3 = THEME_COLORS.Secondary; outputContainer.CanvasSize = UDim2.new(0,0,0,0); outputContainer.ScrollBarImageColor3 = THEME_COLORS.Accent; outputContainer.ScrollBarThickness = 8; outputContainer.ZIndex = 1; local oc = Instance.new("UICorner",outputContainer); oc.CornerRadius = UDim.new(0,4)
    local listLayout = Instance.new("UIListLayout", outputContainer); listLayout.Padding = UDim.new(0,2); listLayout.SortOrder = Enum.SortOrder.LayoutOrder; listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left; listLayout.FillDirection = Enum.FillDirection.Vertical
    statusBar = Instance.new("Frame", mainFrame); statusBar.Name = "StatusBar"; statusBar.Size = UDim2.new(1,-10,0,25); statusBar.Position = UDim2.new(0,5,1,-60); statusBar.BackgroundColor3 = THEME_COLORS.Primary; statusBar.BackgroundTransparency = 0.5; statusBar.ZIndex = 2; local sc=Instance.new("UICorner",statusBar);sc.CornerRadius=UDim.new(0,3)
    statusTextLabel = Instance.new("TextLabel",statusBar);statusTextLabel.Name="StatusText";statusTextLabel.Size=UDim2.new(0.75,-5,1,0);statusTextLabel.Position=UDim2.new(0,5,0,0);statusTextLabel.BackgroundTransparency=1;statusTextLabel.Font=Enum.Font.Code;statusTextLabel.Text="สถานะ: ว่าง.";statusTextLabel.TextColor3=THEME_COLORS.TextDim;statusTextLabel.TextSize=13;statusTextLabel.TextXAlignment=Enum.TextXAlignment.Left
    timerTextLabel = Instance.new("TextLabel",statusBar);timerTextLabel.Name="TimerText";timerTextLabel.Size=UDim2.new(0.25,-5,1,0);timerTextLabel.Position=UDim2.new(0.75,5,0,0);timerTextLabel.BackgroundTransparency=1;timerTextLabel.Font=Enum.Font.Code;timerTextLabel.Text="เวลา: 0.0วิ";timerTextLabel.TextColor3=THEME_COLORS.TextDim;timerTextLabel.TextSize=13;timerTextLabel.TextXAlignment=Enum.TextXAlignment.Right
    local bottomBar = Instance.new("Frame", mainFrame); bottomBar.Name = "BottomBar"; bottomBar.Size = UDim2.new(1,0,0,30); bottomBar.Position = UDim2.new(0,0,1,-30); bottomBar.BackgroundColor3 = THEME_COLORS.Primary; bottomBar.ZIndex = 2
    
    local btnWidth = UDim.new(0.23, -8)
    local btnSpacing = UDim.new(0.02,0)
    local copyAllBtn = createStyledButton(bottomBar,"คัดลอก Log",btnWidth,UDim2.new(0.02,0,0.1,0))
    local clearLogBtn = createStyledButton(bottomBar,"ล้าง Log",btnWidth,UDim2.new(0.02 + btnWidth.Scale + btnSpacing.Scale, 0, 0.1, 0))
    local rescanBtn = createStyledButton(bottomBar,"สแกนใหม่",btnWidth,UDim2.new(0.02 + (btnWidth.Scale + btnSpacing.Scale)*2, 0, 0.1, 0))
    local startRobBtn = createStyledButton(bottomBar,"ปล้นทั้งหมด",btnWidth,UDim2.new(0.02 + (btnWidth.Scale + btnSpacing.Scale)*3, 0, 0.1, 0),THEME_COLORS.Accent,THEME_COLORS.Background)

    local dragging=false;local dI,dS,sPF;titleBar.InputBegan:Connect(function(i)if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragging=true;dS=i.Position;sPF=mainFrame.Position;i.Changed:Connect(function()if i.UserInputState==Enum.UserInputState.End then dragging=false end end)end end);UserInputService.InputChanged:Connect(function(i)if i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch then if dragging and dS then local d=i.Position-dS;mainFrame.Position=UDim2.new(sPF.X.Scale,sPF.X.Offset+d.X,sPF.Y.Scale,sPF.Y.Offset+d.Y)end end end);cB.MouseButton1Click:Connect(function()local ct=TweenService:Create(mainFrame,TweenInfo.new(0.2,Enum.EasingStyle.Quad,Enum.EasingDirection.In),{Size=UDim2.fromScale(0.01,0.01),Position=UDim2.new(0.5,0,0.5,0),Transparency=1});ct:Play();ct.Completed:Wait();screenGui:Destroy();mainFrame=nil;if currentRobberyCoroutine then task.cancel(currentRobberyCoroutine);currentRobberyCoroutine=nil;logOutputWrapper("RobCtrl","หยุดการปล้น (ปิด UI)")end end);local isCV=INITIAL_UI_VISIBLE;local function tCV()isCV=not isCV;outputContainer.Visible=isCV;bottomBar.Visible=isCV;statusBar.Visible=isCV;local tS;if isCV then tS=originalMainFrameSize;mxB.ImageColor3=THEME_COLORS.MaximizeButton;mB.ImageColor3=THEME_COLORS.MinimizeButton else tS=UDim2.new(originalMainFrameSize.X.Scale,originalMainFrameSize.X.Offset,0,titleBar.AbsoluteSize.Y);mxB.ImageColor3=THEME_COLORS.Accent;mB.ImageColor3=THEME_COLORS.Accent end;TweenService:Create(mainFrame,TweenInfo.new(0.2),{Size=tS}):Play()end;mB.MouseButton1Click:Connect(tCV);mxB.MouseButton1Click:Connect(tCV)
    copyAllBtn.MouseButton1Click:Connect(function()local at="-- RyntazHub Explorer Log --\n";for _,e in ipairs(allLoggedMessages)do at=at..e.."\n"end;if copyToClipboard(at)then copyAllBtn.Text="คัดลอกแล้ว!"else copyAllBtn.Text="พลาด!"end;task.wait(1.5);copyAllBtn.Text="คัดลอก Log"end)
    clearLogBtn.MouseButton1Click:Connect(function()allLoggedMessages={};for _,c in ipairs(outputContainer:GetChildren())do if c:IsA("Frame")and(c.Name=="LogEntryContainer"or c.Name=="CategoryHeader"or c.Name=="TempStatusLabel")then c:Destroy()end end;outputContainer.CanvasSize=UDim2.new(0,0,0,0);logOutputWrapper("UI","ล้าง Log ในหน้าต่างแล้ว")end)
    rescanBtn.MouseButton1Click:Connect(function()if RyntazHub.State.IsScanning or RyntazHub.State.IsRobbing then logOutputWrapper("System","มีกระบวนการอื่นทำงานอยู่!"); return end;logOutputWrapper("System","กำลังสแกนเป้าหมายอีกครั้ง...");task.spawn(executeFocusedScanSequence)end)
    startRobBtn.MouseButton1Click:Connect(function()if RyntazHub.State.IsScanning or RyntazHub.State.IsRobbing then logOutputWrapper("System","มีกระบวนการอื่นทำงานอยู่!"); return end;logOutputWrapper("System","เริ่มลำดับการปล้นทั้งหมด...");currentRobberyCoroutine=task.spawn(executeAllRobberiesSequence)end)

    originalMainFramePosition=UDim2.new(0.5,0,0.5,0);TweenService:Create(mainFrame,TweenInfo.new(0.5,Enum.EasingStyle.Elastic,Enum.EasingDirection.Out),{Size=originalMainFrameSize,Position=originalMainFramePosition}):Play()
    if not INITIAL_UI_VISIBLE then task.wait(0.5);toggleContentVisibility()end
end

local function addLogEntryToUI(category,originalMessage,encryptedMessage,encryptionTag)if not(SHOW_UI_OUTPUT and mainFrame and outputContainer)then return end;local timestamp=os.date("[%H:%M:%S] ");local entryContainer=Instance.new("Frame",outputContainer);entryContainer.Name="LogEntryContainer";entryContainer.BackgroundTransparency=1;entryContainer.Size=UDim2.new(1,-6,0,0);entryContainer.AutomaticSize=Enum.AutomaticSize.Y;entryContainer.LayoutOrder=#outputContainer:GetChildren();local logEntryLabel=Instance.new("TextLabel",entryContainer);logEntryLabel.Name="LogEntryLabel";logEntryLabel.Text="<b>"..timestamp.."["..category.."]</b> "..encryptionTag..encryptedMessage;logEntryLabel.RichText=true;logEntryLabel.TextColor3=(category:match("Error")or category:match("Fail"))and THEME.Colors.Error or(category:match("Success"))and THEME.Colors.Success or(category:match("Warning") or category:match("Info")) and THEME.Colors.Warning or THEME.Colors.TextDim;logEntryLabel.Font=Enum.Font.Code;logEntryLabel.TextSize=12;logEntryLabel.TextXAlignment=Enum.TextXAlignment.Left;logEntryLabel.TextWrapped=true;logEntryLabel.Size=UDim2.new(0.82,-5,0,0);logEntryLabel.Position=UDim2.new(0,0,0,0);logEntryLabel.AutomaticSize=Enum.AutomaticSize.Y;logEntryLabel.BackgroundColor3=THEME_COLORS.Primary;logEntryLabel.BackgroundTransparency=0.7;local lc=Instance.new("UICorner",logEntryLabel);lc.CornerRadius=UDim.new(0,3);local cb=createStyledButton(entryContainer,"คัดลอก",UDim2.new(0.15,0,0,20),UDim2.new(0.84,0,0,0),THEME_COLORS.Secondary,THEME_COLORS.Accent);cb.TextSize=11;cb.ZIndex=3;task.wait();local lh=logEntryLabel.AbsoluteSize.Y;entryContainer.Size=UDim2.new(1,-6,0,math.max(22,lh+2));cb.Size=UDim2.new(0.15,0,0,math.max(18,lh));cb.Position=UDim2.new(0.84,0,0.5,-cb.AbsoluteSize.Y/2);cb.MouseButton1Click:Connect(function()if copyToClipboard(originalMessage)then cb.Text="OK!";cb.TextColor3=Color3.fromRGB(0,255,0)else cb.Text="พลาด!";cb.TextColor3=Color3.fromRGB(255,80,80)end;task.wait(1);cb.Text="คัดลอก";cb.TextColor3=THEME_COLORS.Accent end);local th=5;for _,c in ipairs(outputContainer:GetChildren())do if c:IsA("Frame")and(c.Name=="LogEntryContainer"or c.Name=="CategoryHeader"or c.Name=="TempStatusLabel")then th=th+c.AbsoluteSize.Y+outputContainer.UIListLayout.Padding.Offset end end;outputContainer.CanvasSize=UDim2.new(0,0,0,th);if outputContainer.CanvasSize.Y.Offset>outputContainer.AbsoluteSize.Y then outputContainer.CanvasPosition=Vector2.new(0,outputContainer.CanvasSize.Y.Offset-outputContainer.AbsoluteSize.Y)end end
local function addCategoryHeaderToUI(categoryName)if not(SHOW_UI_OUTPUT and mainFrame and outputContainer)then return end;local h=Instance.new("Frame",outputContainer);h.Name="CategoryHeader";h.Size=UDim2.new(1,-6,0,25);h.BackgroundColor3=THEME_COLORS.Secondary;h.LayoutOrder=#outputContainer:GetChildren();local co=Instance.new("UICorner",h);co.CornerRadius=UDim.new(0,3);local t=Instance.new("TextLabel",h);t.Size=UDim2.new(1,-10,1,0);t.Position=UDim2.new(0,5,0,0);t.BackgroundTransparency=1;t.Font=Enum.Font.Michroma;t.Text="สแกน: "..categoryName;t.TextColor3=THEME_COLORS.Accent;t.TextSize=15;t.TextXAlignment=Enum.TextXAlignment.Left;task.wait();local th=5;for _,c in ipairs(outputContainer:GetChildren())do if c:IsA("Frame")and(c.Name=="LogEntryContainer"or c.Name=="CategoryHeader"or c.Name=="TempStatusLabel")then th=th+c.AbsoluteSize.Y+outputContainer.UIListLayout.Padding.Offset end end;outputContainer.CanvasSize=UDim2.new(0,0,0,th)end
local function logOutputWrapper(category,message)local timestamp=os.date("[%H:%M:%S] ");local originalMessage=message;local fullMessageForConsole=timestamp.."["..category.."] "..originalMessage;print(fullMessageForConsole);table.insert(allLoggedMessages,fullMessageForConsole);local encryptedMessage=originalMessage;local encryptionTag="";if UI_OUTPUT_ENCRYPTION_METHOD=="Hex"then local hex="";for i=1,#originalMessage do hex=hex..string.format("%02x",string.byte(originalMessage,i))end;encryptedMessage=hex;encryptionTag="[HEX] "elseif UI_OUTPUT_ENCRYPTION_METHOD=="Base64"then if HttpService and HttpService.EncodeBase64 then encryptedMessage=HttpService:EncodeBase64(originalMessage);encryptionTag="[B64] "else encryptedMessage=originalMessage;encryptionTag="[B64-Fail] "end end;if SHOW_UI_OUTPUT and mainFrame and outputContainer then addLogEntryToUI(category,originalMessage,encryptedMessage,encryptionTag)end end
local function updateStatus(text,overallPercentage)if SHOW_UI_OUTPUT and statusTextLabel and statusTextLabel.Parent then local currentText="สถานะ: "..text;if overallPercentage then currentText=currentText..string.format(" (รวม: %.0f%%)",overallPercentage)end;statusTextLabel.Text=currentText end;print("[StatusUpdate] "..text..(overallPercentage and string.format(" (รวม: %.0f%%)",overallPercentage)or""))end
local function findRemote(parentInst,nameHint,typeHint)typeHint=typeHint or"RemoteEvent";if not parentInst then return nil end;for _,D in ipairs(parentInst:GetDescendants())do if D:IsA(typeHint)and D.Name:lower():match(nameHint:lower())then return D end end;return nil end
local function findPrompt(parentInst,actionHint)if not parentInst then return nil end;for _,D in ipairs(parentInst:GetDescendants())do if D:IsA("ProximityPrompt")then if D.ActionText and D.ActionText:lower():match(actionHint:lower())then return D elseif D.ObjectText and D.ObjectText:lower():match(actionHint:lower())then return D end end end;return nil end

function scanAndPrepareHeistData(heistName, heistConfigEntry)
    local heistFolder = Workspace:FindFirstChild(heistConfigEntry.PathString, true)
    if not heistFolder then logOutputWrapper("ScanError", "ไม่พบ Heist Folder สำหรับ: " .. heistName .. " ที่ Path: " .. heistConfigEntry.PathString); return false end
    logOutputWrapper("HeistScan", "เริ่มสแกนและเตรียมข้อมูลสำหรับ: " .. (heistConfigEntry.DisplayName or heistName))
    ScannedHeistData[heistName] = {LootPoints = {}, Path = heistFolder, Config = heistConfigEntry, DisplayName = heistConfigEntry.DisplayName or heistName}

    for targetIndex, lootTargetConfig in ipairs(heistConfigEntry.LootTargets or {}) do
        local currentSearchBase = heistFolder
        if lootTargetConfig.SearchPath then
            local subPathInstance = heistFolder:FindFirstChild(lootTargetConfig.SearchPath, true)
            if subPathInstance then currentSearchBase = subPathInstance
            else logOutputWrapper("ScanWarning", heistName .. " - ไม่พบ SearchPath: " .. lootTargetConfig.SearchPath .. " ใน " .. heistFolder:GetFullName()); goto next_heist_target_scan_v264 end
        end
        
        local itemsToProcess = {}
        if lootTargetConfig.ItemNameHint then
             for _, child in ipairs(currentSearchBase:GetDescendants()) do 
                if child.Name:lower():match(lootTargetConfig.ItemNameHint:lower()) and (child:IsA("Model") or child:IsA("BasePart")) then table.insert(itemsToProcess, child) end
            end
        else 
            for _, child in ipairs(currentSearchBase:GetChildren()) do if child:IsA("Model") or child:IsA("BasePart") then table.insert(itemsToProcess, child) end end
        end
        
        if #itemsToProcess == 0 then logOutputWrapper("ScanInfo", heistName .. " - ไม่พบ items ที่ตรงกับ Hint/Keywords ใน " .. currentSearchBase:GetFullName() .. " สำหรับ Target: " .. (lootTargetConfig.Name or "Unnamed Target")) end

        for _, itemInstance in ipairs(itemsToProcess) do
            local itemCFrame = (itemInstance:IsA("Model") and itemInstance:GetPivot() or itemInstance.CFrame)
            local lootData = {
                Name = lootTargetConfig.Name or itemInstance.Name, Instance = itemInstance,
                CFrame = itemCFrame * CFrame.new(lootTargetConfig.TeleportOffset or Vector3.new(0,1.5,0)),
                InteractionType = lootTargetConfig.InteractionType,
                FireCount = lootTargetConfig.FireCount or 1,
                RobDelay = lootTargetConfig.RobDelay or 0.1,
                RobDelay_PerFire = lootTargetConfig.DelayBetweenFires, 
                OriginalConfig = lootTargetConfig 
            }
            if lootTargetConfig.InteractionType == "RemoteEvent" then
                if lootTargetConfig.RemoteEventPath then lootData.RobEvent = Workspace:FindFirstChild(lootTargetConfig.RemoteEventPath, true) or currentSearchBase:FindFirstChild(lootTargetConfig.RemoteEventPath, true) or itemInstance:FindFirstChild(lootTargetConfig.RemoteEventPath, true)
                elseif lootTargetConfig.RemoteEventNameHint then lootData.RobEvent = findRemote(itemInstance, lootTargetConfig.RemoteEventNameHint) or findRemote(itemInstance.Parent, lootTargetConfig.RemoteEventNameHint) or findRemote(heistFolder, lootTargetConfig.RemoteEventNameHint) end
                lootData.EventArgsFunc = lootTargetConfig.RemoteEventArgs
                if lootData.RobEvent then logOutputWrapper("LootPointSetup", string.format("%s - ตั้งค่า Loot: %s | Event: %s", heistName, lootData.Name, lootData.RobEvent:GetFullName()))
                else logOutputWrapper("ScanWarning", string.format("%s - ไม่พบ Event สำหรับ Loot: %s (Hint: %s)", heistName, lootData.Name, lootTargetConfig.RemoteEventNameHint or lootTargetConfig.RemoteEventPath or "N/A")) end
            elseif lootTargetConfig.InteractionType == "ProximityPrompt" then
                lootData.ProximityPromptInstance = findPrompt(itemInstance, lootTargetConfig.ProximityPromptActionHint or itemInstance.Name)
                if lootData.ProximityPromptInstance then logOutputWrapper("LootPointSetup", string.format("%s - ตั้งค่า Loot: %s | Prompt: %s (Act: %s)", heistName, lootData.Name, lootData.ProximityPromptInstance:GetFullName(), lootData.ProximityPromptInstance.ActionText or "-")); lootData.HoldDuration = lootTargetConfig.HoldDuration or lootData.ProximityPromptInstance.HoldDuration
                else logOutputWrapper("ScanWarning", string.format("%s - ไม่พบ Prompt สำหรับ Loot: %s (Hint: %s)", heistName, lootData.Name, lootTargetConfig.ProximityPromptActionHint or "N/A")) end
            elseif lootTargetConfig.InteractionType == "Touch" then logOutputWrapper("LootPointSetup", string.format("%s - ตั้งค่า Loot (Touch): %s", heistName, lootData.Name)) end
            if lootData.RobEvent or lootData.ProximityPromptInstance or lootData.InteractionType == "Touch" then table.insert(ScannedHeistData[heistName].LootPoints, lootData) end
        end
        ::next_heist_target_scan_v264::
        task.wait(0.01)
    end
    logOutputWrapper("HeistScan", "สแกน " .. (heistConfigEntry.DisplayName or heistName) .. " เสร็จสิ้น, พบ " .. #ScannedHeistData[heistName].LootPoints .. " จุดปล้น.")
    return true
end

function exploreFocusedPath(rootInstance, rootNameForLog, currentScanIndex, totalScanTasks)
    updateStatus("กำลังสำรวจ: " .. rootNameForLog, (currentScanIndex / totalScanTasks) * 100)
    if SHOW_UI_OUTPUT and mainFrame and outputContainer then addCategoryHeaderToUI(rootNameForLog) end
    local foundItems = {}; local descendants = rootInstance:GetDescendants(); local numDescendants = #descendants; local updateInterval = math.max(1, math.floor(numDescendants / 20))
    for i, descendant in ipairs(descendants) do
        local itemPath = descendant:GetFullName()
        if not foundItems[itemPath] then
            local loggedThisItem = false
            if descendant:IsA("LuaSourceContainer") then local sCP=""; if descendant:IsA("Script")or descendant:IsA("LocalScript")then local s,sr=pcall(function()return descendant.Source end);if s and sr and #sr>0 then sCP="|Code";for _,k in ipairs(SENSITIVE_SCRIPT_KEYWORDS)do if sr:lower():match(k)then sCP=sCP.." [K:"..k.."]";break end end else sCP="|SrcFail/Empty"end end;logOutputWrapper("ScriptFound","Path: "..itemPath.." |T: "..descendant.ClassName..sCP);loggedThisItem=true end
            if descendant:IsA("RemoteEvent")or descendant:IsA("RemoteFunction")then logOutputWrapper("RemoteFound","Path: "..itemPath.." |T: "..descendant.ClassName);loggedThisItem=true end
            if descendant:IsA("ProximityPrompt")then logOutputWrapper("ProximityPromptFound","Path: "..itemPath.." |Obj:"..(descendant.ObjectText or"-").." |Act:"..(descendant.ActionText or"-").." |Hold:"..tostring(descendant.HoldDuration).." |Dist:"..string.format("%.1f",descendant.MaxActivationDistance).." |En:"..tostring(descendant.Enabled));loggedThisItem=true end
            if descendant:IsA("BasePart")and not descendant:IsA("Terrain")then local pI="";local iLP=false;for _,k in ipairs(MINI_ROBBERIES_NAMES_EXTENDED)do if descendant.Name:lower():match(k:lower())then iLP=true;pI=pI.."[K:"..k.."]";break end end;if not iLP then for _,k in ipairs(EXTRA_LOOT_KEYWORDS)do if descendant.Name:lower():match(k:lower())then iLP=true;pI=pI.."[K:"..k.."]";break end end end;if iLP then logOutputWrapper("PotentialLootPart","Path: "..itemPath.." "..pI.." |Pos: "..string.format("%.1f,%.1f,%.1f",descendant.Position.X,descendant.Position.Y,descendant.Position.Z));loggedThisItem=true end;if descendant:FindFirstChildOfClass("TouchTransmitter")then logOutputWrapper("PartWithTouch","Path: "..itemPath.." (Touch)");loggedThisItem=true end;local p=descendant.Parent;if p then for _,cs in ipairs(p:GetChildren())do if cs:IsA("LuaSourceContainer")and(cs.Name:lower():match("touch")or cs.Name:lower():match("interact")or cs.Name:lower():match("click"))then logOutputWrapper("PartAssociatedScript","Part: "..itemPath.." |Scr: "..cs:GetFullName());loggedThisItem=true;break end end end end
            if loggedThisItem then foundItems[itemPath]=true end
        end
        if i % updateInterval == 0 then updateStatus("สแกน "..rootNameForLog..string.format(" (%.0f%%)",(i/numDescendants)*100), (currentScanIndex/totalScanTasks)*100+((i/numDescendants)*(1/totalScanTasks)*100) ); task.wait() end
    end
    updateStatus("สำรวจเสร็จสิ้น: "..rootNameForLog, (currentScanIndex / totalScanTasks) * 100)
end

local function attemptRobSingleLoot(lootData, heistName) if not (Character and Humanoid and HumanoidRootPart and Humanoid.Health > 0) then logOutputWrapper("RobError", "ตัวละครไม่อยู่ในสถานะพร้อมปล้น: " .. lootData.Name); return false end;updateStatus(string.format("กำลังไปที่ %s (%s) ใน %s", lootData.Name, lootData.InteractionType, ScannedHeistData[heistName].DisplayName));local targetCFrame = lootData.CFrame; local distance = (HumanoidRootPart.Position - targetCFrame.Position).Magnitude;local teleportDuration = math.clamp(distance / 250, 0.1, 0.4); local tpSuccess = pcall(function() HumanoidRootPart.CFrame = targetCFrame end); if not tpSuccess then logOutputWrapper("RobError", "Teleport ล้มเหลวสำหรับ "..lootData.Name); return false end; task.wait(0.1); local robSuccessful = false; if lootData.InteractionType == "RemoteEvent" and lootData.RobEvent then logOutputWrapper("RobAction", string.format("[%s] Firing RE: %s for %s", ScannedHeistData[heistName].DisplayName, lootData.RobEvent.Name, lootData.Name)); local argsToFire = {}; if lootData.EventArgsFunc then argsToFire = lootData.EventArgsFunc(lootData.Instance) or {} end; for i = 1, lootData.FireCount or 1 do if not (Character and Humanoid.Health > 0 and currentRobberyCoroutine) then logOutputWrapper("RobInfo","หยุด Fire Event (ตัวละครตาย/หยุดโดยผู้ใช้)"); break end; local s,e = pcall(function() lootData.RobEvent:FireServer(unpack(argsToFire)) end); if not s then logOutputWrapper("RobError", "Error firing "..lootData.Name..": "..tostring(e)) end; task.wait(0.05 + (lootData.RobDelay_PerFire or 0.05) ) end; robSuccessful = true elseif lootData.InteractionType == "ProximityPrompt" and lootData.ProximityPromptInstance then logOutputWrapper("RobAction", string.format("[%s] Triggering PP: %s (Act: %s) for %s", ScannedHeistData[heistName].DisplayName, lootData.ProximityPromptInstance.Name, lootData.ProximityPromptInstance.ActionText, lootData.Name)); if typeof(fireproximityprompt) == "function" then pcall(fireproximityprompt, lootData.ProximityPromptInstance, lootData.HoldDuration or 0); robSuccessful = true else logOutputWrapper("RobError", "Executor ไม่มี fireproximityprompt.") end elseif lootData.InteractionType == "Touch" then logOutputWrapper("RobAction", string.format("[%s] Touch for %s (จำลอง Touch ซับซ้อน)", ScannedHeistData[heistName].DisplayName, lootData.Name)); if typeof(firetouchinterest) == "function" and lootData.Instance:IsA("BasePart") then pcall(firetouchinterest, lootData.Instance, HumanoidRootPart, 0); task.wait(0.05); pcall(firetouchinterest, lootData.Instance, HumanoidRootPart, 1); robSuccessful = true else logOutputWrapper("RobInfo","ไม่สามารถจำลอง Touch หรือ Executor ไม่มี firetouchinterest.") end else logOutputWrapper("RobWarning", string.format("[%s] ไม่พบวิธีการโต้ตอบสำหรับ %s", ScannedHeistData[heistName].DisplayName, lootData.Name)) end; if robSuccessful then logOutputWrapper("RobSuccess", string.format("[%s] โต้ตอบ %s สำเร็จ", ScannedHeistData[heistName].DisplayName, lootData.Name)) else logOutputWrapper("RobFail", string.format("[%s] โต้ตอบ %s ไม่สำเร็จ", ScannedHeistData[heistName].DisplayName, lootData.Name)) end; task.wait((lootData.RobDelay or 0.05) + (lootData.HoldDuration or 0)); return robSuccessful end
function executeFullHeistRobbery(heistName) if not ScannedHeistData[heistName] or not ScannedHeistData[heistName].Path then logOutputWrapper("RobError", "ไม่พบข้อมูล Heist สำหรับ " .. heistName); return false end; updateStatus("เริ่มการปล้น " .. ScannedHeistData[heistName].DisplayName); local config = HEIST_SPECIFIC_CONFIG[heistName]; if config.EntryTeleportCFrame and HumanoidRootPart then logOutputWrapper("ExecuteRob", "[" .. ScannedHeistData[heistName].DisplayName .. "] เทเลพอร์ตไปจุดเริ่มต้น..."); local tpSuccess = pcall(function() HumanoidRootPart.CFrame = config.EntryTeleportCFrame end); if not tpSuccess then logOutputWrapper("RobError", "Teleport ไปจุดเริ่มต้น " .. heistName .. " ล้มเหลว"); return false end; task.wait(0.2) end; local lootPoints = ScannedHeistData[heistName].LootPoints; if #lootPoints == 0 then logOutputWrapper("ExecuteRob", "[" .. ScannedHeistData[heistName].DisplayName .. "] ไม่พบจุด Loot ที่จะปล้น."); return true end; for i, lootData in ipairs(lootPoints) do if not currentRobberyCoroutine then logOutputWrapper("RobInfo", "การปล้น "..heistName.." ถูกหยุดโดยผู้ใช้"); return false end; if not (Character and Humanoid and Humanoid.Health > 0) then logOutputWrapper("ExecuteRob", "[" .. ScannedHeistData[heistName].DisplayName .. "] ตัวละครตาย, หยุดปล้น."); return false end; attemptRobSingleLoot(lootData, heistName); task.wait(0.1) end; logOutputWrapper("ExecuteRob", "--- ลำดับการปล้น " .. ScannedHeistData[heistName].DisplayName .. " เสร็จสิ้น ---"); return true end
local function executeAllRobberiesSequence() startTime = tick(); updateStatus("กำลังเตรียมข้อมูล Heists สำหรับการปล้น...", 0); local allHeistsPrepared = true; for i, heistKey in ipairs(TARGET_HEISTS_TO_ROB) do local config = HEIST_SPECIFIC_CONFIG[heistKey]; if config then if not scanAndPrepareHeistData(heistKey, config) then allHeistsPrepared = false end else MainUI:CreateNotification("Config Error", "ไม่พบ MasterConfig สำหรับ: " .. heistKey, "Error"); allHeistsPrepared = false end; updateStatus("เตรียม " .. (config and config.DisplayName or heistKey) .. " เสร็จสิ้น", (i / #TARGET_HEISTS_TO_ROB) * 100); if i < #TARGET_HEISTS_TO_ROB then task.wait(0.1) end end; if not allHeistsPrepared then MainUI:CreateNotification("ข้อผิดพลาด", "การเตรียมข้อมูลบาง Heist ล้มเหลว", "Error"); RyntazHub.State.IsRobbing = false; currentRobberyCoroutine = nil; return end; if MainUI.UIController and MainUI.UIController.PopulateHeists then MainUI.UIController.PopulateHeists() else liveDebug("Error: MainUI.UIController.PopulateHeists is nil before robbing sequence") end ; updateStatus("เริ่มลำดับการปล้นทั้งหมด...", 0); local totalHeistsToRob = #TARGET_HEISTS_TO_ROB; for i, heistKey in ipairs(TARGET_HEISTS_TO_ROB) do if not currentRobberyCoroutine then break end; local analyzedData = ScannedHeistData[heistKey]; if analyzedData and analyzedData.LootPoints and #analyzedData.LootPoints > 0 then executeFullHeistRobbery(heistKey); local timeout = 0; local maxWaitTime = 120; while RyntazHub.State.IsRobbing and RyntazHub.State.CurrentHeist == heistKey and timeout < maxWaitTime do task.wait(0.1); timeout = timeout + 0.1 end; if RyntazHub.State.IsRobbing and RyntazHub.State.CurrentHeist == heistKey then MainUI:CreateNotification("Timeout", heistKey .. " ใช้เวลานานเกินไป, ถูกหยุด.", "Warning"); if RyntazHub.UI[heistKey.."_StatusLabel"] then RyntazHub.UI[heistKey.."_StatusLabel"].Text = "สถานะ: Timeout"; RyntazHub.UI[heistKey.."_StatusLabel"].TextColor3 = THEME.Colors.Error end; if RyntazHub.UI[heistKey.."_RobButton"] then RyntazHub.UI[heistKey.."_RobButton"].Text = "เริ่มปล้น"; RyntazHub.UI[heistKey.."_RobButton"].Enabled = true end; RyntazHub.State.IsRobbing = false; RyntazHub.State.CurrentHeist = nil; currentRobberyCoroutine = nil; break end else MainUI:CreateNotification("ข้าม", (analyzedData and analyzedData.DisplayName or heistKey) .. " ไม่ได้ถูกเตรียมไว้/ไม่มีขั้นตอน", "Info") end; updateStatus("เสร็จสิ้น " .. (analyzedData and analyzedData.DisplayName or heistKey), (i / totalHeistsToRob) * 100); if i < totalHeistsToRob and currentRobberyCoroutine then task.wait(0.5) end end; if currentRobberyCoroutine then updateStatus("ปล้นทั้งหมดเสร็จสิ้น.", 100); MainUI:CreateNotification("เสร็จสิ้น", "การปล้นตามลำดับทั้งหมดเสร็จสิ้น", "Success") end; RyntazHub.State.IsRobbing = false; currentRobberyCoroutine = nil end
local function executeFocusedScanSequence() startTime = tick(); if SHOW_UI_OUTPUT and RyntazHub.UIHooks and RyntazHub.UIHooks.ScanLogOutput then local children = RyntazHub.UIHooks.ScanLogOutput:GetChildren(); for i = #children, 1, -1 do local child = children[i]; if child.Name == "LogEntry" or child.Name == "CategoryHeader" then child:Destroy() end end; RyntazHub.UIHooks.ScanLogOutput.CanvasSize = UDim2.new(0,0,0,0) end; allLoggedMessages = {}; logOutputWrapper("System", "RyntazHub Explorer V2.6.4 Initialized & Focused Scanning..."); local pathsToScanConfig = {}; local heistsFolder = Workspace:FindFirstChild(HEISTS_BASE_PATH_STRING); if heistsFolder then if #TARGET_HEISTS_IN_WORKSPACE > 0 then for _, heistName in ipairs(TARGET_HEISTS_IN_WORKSPACE) do local specificHeistFolder = heistsFolder:FindFirstChild(heistName); if specificHeistFolder then table.insert(pathsToScanConfig, {instance = specificHeistFolder, name = specificHeistFolder:GetFullName(), isHeist = true, heistNameForConfig = heistName}) else logOutputWrapper("Error", "ไม่พบ Folder Heist: " .. heistName) end end else for _, childHeist in ipairs(heistsFolder:GetChildren()) do if childHeist:IsA("Instance") then table.insert(pathsToScanConfig, {instance = childHeist, name = childHeist:GetFullName(), isHeist = true, heistNameForConfig = childHeist.Name}) end end end else logOutputWrapper("Error", "ไม่พบ Folder Heists หลัก: '" .. HEISTS_BASE_PATH_STRING .. "'") end; if ReplicatedStorage then table.insert(pathsToScanConfig, {instance = ReplicatedStorage, name = "ReplicatedStorage"}) end; local totalScanTasks = #pathsToScanConfig; if totalScanTasks == 0 then updateStatus("ไม่พบ Path ที่จะสแกน", 100); logOutputWrapper("System", "Focused scan finished (No paths)."); RyntazHub.State.IsScanning = false; return end; for i, scanTask in ipairs(pathsToScanConfig) do if scanTask.isHeist then scanAndPrepareHeistData(scanTask.heistNameForConfig, MasterConfig[scanTask.heistNameForConfig] or {}); updateStatus("สแกน Heist: " .. scanTask.name, (i / totalScanTasks) * 100) else exploreFocusedPath(scanTask.instance, scanTask.name, i, totalScanTasks) end; if i < totalScanTasks then task.wait(0.05) end end; updateStatus("การสำรวจ (Focused) ทั้งหมดเสร็จสิ้น.", 100); logOutputWrapper("System", string.format("การสำรวจ (Focused) ทั้งหมดเสร็จสิ้นใน %.2f วินาที.", tick() - startTime)); RyntazHub.State.IsScanning = false; if RyntazHub.UIController and RyntazHub.UIController.PopulateHeists then RyntazHub.UIController.PopulateHeists() else liveDebug("Error: PopulateHeists not available after scan.") end end

task.spawn(function() while true do if SHOW_UI_OUTPUT and mainFrame and mainFrame.Parent and timerTextLabel then if startTime then timerTextLabel.Text = string.format("เวลา: %.1fs", tick() - startTime) else timerTextLabel.Text = "เวลา: --.-s" end end; task.wait(0.1) end end)

local initSuccess, initError = pcall(function() if not waitForCharacter() then error("RyntazHub: ไม่สามารถโหลด Character ได้, สคริปต์หยุดทำงาน") end; if SHOW_UI_OUTPUT then MainUI:Build() else liveDebug("SHOW_UI_OUTPUT is false, no MainUI build.") end end)
if not initSuccess then liveDebug("FATAL ERROR during RyntazHub Initialization: " .. tostring(initError)); local errScreen = Player.PlayerGui:FindFirstChild("RyntazFatalErrorScreen") or Instance.new("ScreenGui", Player.PlayerGui); errScreen.Name = "RyntazFatalErrorScreen"; errScreen.ResetOnSpawn = false; errScreen.DisplayOrder = 20000; local errLabel = errScreen:FindFirstChild("RyntazFatalErrorLabel") or Instance.new("TextLabel", errScreen); errLabel.Name = "RyntazFatalErrorLabel"; errLabel.Size = UDim2.new(1,0,0.2,0); errLabel.Position = UDim2.new(0,0,0,0); errLabel.BackgroundColor3 = Color3.fromRGB(180,0,0); errLabel.BackgroundTransparency = 0.1; errLabel.TextColor3 = Color3.new(1,1,1); errLabel.Font = Enum.Font.Code; errLabel.TextSize = 16; errLabel.TextWrapped = true; errLabel.TextXAlignment = Enum.TextXAlignment.Left; errLabel.ZIndex = 20001; errLabel.Text = "RYNTAZHUB FATAL ERROR:\n" .. tostring(initError) .. "\n\nPlease check your executor console for more details or contact support."
else
    task.spawn(function()
        task.wait(0.2) 
        liveDebug("Attempting initial focused scan...")
        local scanSuccess, scanErr = pcall(RyntazHub.Scanner.FocusedScan)
        if not scanSuccess then
            if MainUI.CreateNotification then MainUI:CreateNotification("Scan Error","การสแกนเบื้องต้นล้มเหลว: "..tostring(scanErr),"Error") end
            if statusTextLabel and statusTextLabel.Parent then statusTextLabel.Text="สถานะ: Scan Error!" end
            liveDebug("ERROR during initial FocusedScan: "..tostring(scanErr))
        else
            if MainUI.CreateNotification then MainUI:CreateNotification("พร้อมใช้งาน","สแกนเบื้องต้นเสร็จสิ้น, UI พร้อมใช้งาน","Success",3) end
            liveDebug("Initial FocusedScan successful.")
        end
    end)
end
