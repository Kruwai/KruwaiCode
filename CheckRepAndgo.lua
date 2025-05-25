-- RyntazHub - V2.6.5 (Enhanced AutoRob Core)
-- (ฐานจาก V2.6.3 เพิ่มระบบ AutoRob ที่สมบูรณ์ขึ้น)

local Player = game:GetService("Players").LocalPlayer
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Character, Humanoid, RootPart
local function waitForCharacter()
    print("[RyntazHub V2.6.5] Waiting for character...")
    local attempts = 0
    repeat attempts = attempts + 1
        if Player and Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") and Player.Character:FindFirstChildOfClass("Humanoid") then
            Character = Player.Character; Humanoid = Character:FindFirstChildOfClass("Humanoid"); RootPart = Character:FindFirstChild("HumanoidRootPart")
            if Humanoid and RootPart then print("[RyntazHub V2.6.5] Character found."); return true end
        end; task.wait(0.3)
    until attempts > 60
    print("[RyntazHub V2.6.5] ERROR: Character not found after timeout."); return false
end

if not waitForCharacter() then print("RyntazHub ERROR: Character not loaded, script will not fully initialize."); return end
Player.CharacterAdded:Connect(function(newChar) Character=newChar; Humanoid=newChar:WaitForChild("Humanoid",15); RootPart=newChar:WaitForChild("HumanoidRootPart",15); print("[RyntazHub V2.6.5] Character respawned.") end)

-- ================= CONFIGURATION =================
local HEISTS_BASE_PATH_STRING = "Heists"
local TARGET_HEISTS_IN_WORKSPACE_FOR_SCAN = {"Bank", "Casino", "JewelryStore"}
local TARGET_HEISTS_TO_ROB_SEQUENCE = {"JewelryStore", "Bank", "Casino"}

local AutoHeistSettings = {
    teleportSpeedFactor = 150, -- (ตัวหาร) ค่าน้อยลง = เร็วขึ้น (เช่น 100 จะเร็วกว่า 200)
    interactionDelay = 0.2, -- Delay พื้นฐานระหว่างการโต้ตอบ
    autoLootEnabled = true, -- (ยังไม่ได้ใช้ใน Logic นี้โดยตรง แต่เตรียมไว้)
    safeMode = false, -- ถ้า true อาจจะเพิ่ม Delay หรือการตรวจสอบมากขึ้น (ยังไม่ Implement)
    stopOnError = true -- หยุดการปล้นทั้งหมดถ้า Heist ใด Heist หนึ่งล้มเหลว
}

-- (HEIST_SPECIFIC_CONFIG จาก V5.3 สามารถนำมาใช้เป็นฐานได้ แต่คุณต้องปรับปรุงอย่างละเอียด)
local HEIST_SPECIFIC_CONFIG = {
    JewelryStore = {
        DisplayName = "ร้านเพชร", PathString = Workspace.Heists.JewelryStore, -- ใช้ Instance โดยตรง
        EntryTeleportCFrame = CFrame.new(-82.8, 85.5, 807.5),
        RobberyActions = {
            { Name = "เก็บเครื่องเพชร", ActionType = "IterateAndFireEvent",
              ItemContainerPath = "EssentialParts.JewelryBoxes",
              RemoteEventPath = "EssentialParts.JewelryBoxes.JewelryManager.Event",
              EventArgsFunc = function(lootInstance) return {lootInstance} end, FireCountPerItem = 2,
              TeleportOffsetPerItem = Vector3.new(0,1.8,1.8), DelayBetweenItems = 0.1, DelayBetweenFires = 0.05, RobDelayAfter = 0.2 }
        }
    },
    Bank = {
        DisplayName = "ธนาคาร", PathString = Workspace.Heists.Bank,
        EntryTeleportCFrame = CFrame.new(730, 108, 565),
        RobberyActions = {
            { Name = "เปิดประตูห้องมั่นคง", ActionType = "Touch", TargetPath = "EssentialParts.VaultDoor.Touch", TeleportOffset = Vector3.new(0,0,-2.2), RobDelayAfter = 2.0 },
            { Name = "เก็บเงิน CashStack", ActionType = "IterateAndFindInteract", ItemContainerPath = "Interior.CashStack.Model", ItemNameHint = "Cash", InteractionHint = {Type="RemoteEvent", NameHint="CollectCash", Args=function(item) return {item, 1000} end}, TeleportOffset = Vector3.new(0,0.5,0), DelayBetweenItems = 0.2, FireCountPerItem = 1, RobDelayAfter = 0.3 },
            { Name = "เก็บเงิน Model Cash", ActionType = "IterateAndFindInteract", ItemContainerPath = "Interior.Model", ItemNameHint = "Cash", InteractionHint = {Type="RemoteEvent", NameHint="CollectMoney", Args=function(item) return {item, 500} end}, TeleportOffset = Vector3.new(0,0.5,0), DelayBetweenItems = 0.2, FireCountPerItem = 1, RobDelayAfter = 0.3 }
        }
    },
    Casino = {
        DisplayName = "คาสิโน", PathString = Workspace.Heists.Casino,
        EntryTeleportCFrame = CFrame.new(1690, 30, 525),
        RobberyActions = {
            { Name = "แฮ็กคอมพิวเตอร์", ActionType = "ProximityPrompt", TargetPath = "Interior.HackComputer.HackComputer", ProximityPromptActionHint = "Hack", HoldDuration = 2.5, TeleportOffset = Vector3.new(0,1,-1.8), RobDelayAfter = 1.5 },
            { Name = "เก็บเงินห้องนิรภัย", ActionType = "IterateAndFindInteract", ItemContainerPath = "Interior.Vault", ItemNameHint = "Cash", InteractionHint = {Type="RemoteEvent", NameHint="TakeVaultCash", Args=function(item) return {item} end}, TeleportOffset = Vector3.new(0,0.5,0), DelayBetweenItems = 0.3, FireCountPerItem = 1, RobDelayAfter = 0.3 }
        }
    }
}

-- ================= THEME & UI (จาก V2.6.3 แต่ปรับปุ่ม) =================
local THEME_COLORS = { Background = Color3.fromRGB(18,20,23), Primary = Color3.fromRGB(25,28,33), Secondary = Color3.fromRGB(35,40,50), Accent = Color3.fromRGB(0,255,120), Text = Color3.fromRGB(210,215,220), TextDim = Color3.fromRGB(130,135,140), ButtonHover = Color3.fromRGB(50,55,70), CloseButton = Color3.fromRGB(255,95,86), MinimizeButton = Color3.fromRGB(255,189,46), MaximizeButton = Color3.fromRGB(40,200,65)}
local mainFrame, outputContainer, titleBar, statusBar, statusTextLabel, timerTextLabel; local allLoggedMessages = {}; local isMinimized = not INITIAL_UI_VISIBLE; local originalMainFrameSize = UDim2.new(0.45,0,0.35,0); local startTime; local currentRobberyCoroutine = nil
local function copyToClipboard(textToCopy) local s,m=pcall(function()if typeof(setclipboard)=="function"then setclipboard(textToCopy);return true end;if typeof(writefile)=="function"then writefile("ryntaz_clipboard.txt",textToCopy);return true end;return false end);print(s and(m and"[Clipboard] Copied/Saved."or"[Clipboard] Failed.")or"[Clipboard] No function.");if statusTextLabel and statusTextLabel.Parent then local oS=statusTextLabel.Text;statusTextLabel.Text=s and(m and"Clipboard: OK"or"Clipboard: FAIL")or"Clipboard: N/A";task.delay(2,function()if statusTextLabel and statusTextLabel.Parent then statusTextLabel.Text=oS end end)end;return m end
local function createStyledButton(parent,text,size,pos,color,textColor,fontSize)local b=Instance.new("TextButton",parent);b.Text=text;b.Size=size;b.Position=pos;b.BackgroundColor3=color or THEME_COLORS.Secondary;b.TextColor3=textColor or THEME_COLORS.Text;b.Font=Enum.Font.SourceSansSemibold;b.TextSize=fontSize or 14;b.ClipsDescendants=true;local c=Instance.new("UICorner",b);c.CornerRadius=UDim.new(0,4);b.MouseEnter:Connect(function()TweenService:Create(b,TweenInfo.new(0.1),{BackgroundColor3=THEME_COLORS.ButtonHover}):Play()end);b.MouseLeave:Connect(function()TweenService:Create(b,TweenInfo.new(0.1),{BackgroundColor3=color or THEME_COLORS.Secondary}):Play()end);return b end
local function introAnimationV2(parentGui) local iF=Instance.new("Frame",parentGui);iF.Name="Intro";iF.Size=UDim2.new(1,0,1,0);iF.BackgroundTransparency=1;iF.ZIndex=2000;local tL=Instance.new("TextLabel",iF);tL.Name="RText";tL.Size=UDim2.new(0,0,0,0);tL.Position=UDim2.new(0.5,0,0.5,0);tL.AnchorPoint=Vector2.new(0.5,0.5);tL.Font=Enum.Font.Michroma;tL.Text="";tL.TextColor3=THEME_COLORS.Accent;tL.TextScaled=false;tL.TextSize=1;tL.TextTransparency=1;tL.Rotation=-10;local fT="Ryntaz Hub";local tD=0.6;local sD=0.5;local fD=0.3;TweenService:Create(tL,TweenInfo.new(tD,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{TextSize=70,TextTransparency=0,Rotation=0,Size=UDim2.new(0.5,0,0.15,0)}):Play();for i=1,#fT do tL.Text=string.sub(fT,1,i);task.wait(tD/#fT*0.6)end;task.wait(sD);TweenService:Create(tL,TweenInfo.new(fD,Enum.EasingStyle.Quad,Enum.EasingDirection.In),{TextTransparency=1,Rotation=5,Position=UDim2.new(0.5,0,0.45,0)}):Play();task.delay(fD+0.1,function()if iF and iF.Parent then iF:Destroy()end end)end
local function logOutputWrapper(category,message) local ts=os.date("[%H:%M:%S] ");local oM=message;local fMFC=ts.."["..category.."] "..oM;print(fMFC);table.insert(allLoggedMessages,fMFC);if SHOW_UI_OUTPUT and mainFrame and outputContainer then local entry=Instance.new("TextLabel",outputContainer);entry.Name="Log";entry.Text=ts.."<b>["..category.."]</b> "..message;entry.RichText=true;entry.TextColor3=(category:match("Error")or category:match("Fail"))and Color3.fromRGB(255,100,100)or(category:match("Success"))and Color3.fromRGB(100,255,100)or THEME_COLORS.TextDim;entry.Font=Enum.Font.Code;entry.TextSize=12;entry.TextXAlignment=Enum.TextXAlignment.Left;entry.TextWrapped=true;entry.Size=UDim2.new(1,-8,0,0);entry.AutomaticSize=Enum.AutomaticSize.Y;entry.BackgroundColor3=THEME_COLORS.Primary;entry.BackgroundTransparency=0.7;local co=Instance.new("UICorner",entry);co.CornerRadius=UDim.new(0,2);local th=5;for _,c in ipairs(outputContainer:GetChildren())do if c:IsA("TextLabel")then th=th+c.AbsoluteSize.Y+outputContainer.UIListLayout.Padding.Offset end end;outputContainer.CanvasSize=UDim2.new(0,0,0,th);if outputContainer.CanvasSize.Y.Offset>outputContainer.AbsoluteSize.Y then outputContainer.CanvasPosition=Vector2.new(0,outputContainer.CanvasSize.Y.Offset-outputContainer.AbsoluteSize.Y)end end end
local function updateStatus(text,overallPercentage)if SHOW_UI_OUTPUT and statusTextLabel and statusTextLabel.Parent then local currentText="สถานะ: "..text;if overallPercentage then currentText=currentText..string.format(" (รวม: %.0f%%)",overallPercentage)end;statusTextLabel.Text=currentText end;print("[StatusUpdate] "..text..(overallPercentage and string.format(" (Overall: %.0f%%)",overallPercentage)or""))end
local function createMainUI_V2_6_5()
    if mainFrame and mainFrame.Parent then return end
    local screenGui=Instance.new("ScreenGui",Player:WaitForChild("PlayerGui"));screenGui.Name="RyntazHub_V2_6_5";screenGui.ResetOnSpawn=false;screenGui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;screenGui.DisplayOrder=999
    introAnimationV2(screenGui);task.wait(1.4)
    mainFrame=Instance.new("Frame",screenGui);mainFrame.Name="MainFrame";mainFrame.Size=UDim2.fromScale(0.01,0.01);mainFrame.Position=UDim2.new(0.5,0,0.5,0);mainFrame.AnchorPoint=Vector2.new(0.5,0.5);mainFrame.BackgroundColor3=THEME_COLORS.Background;mainFrame.BorderSizePixel=1;mainFrame.BorderColor3=THEME_COLORS.Accent;mainFrame.ClipsDescendants=true;local fc=Instance.new("UICorner",mainFrame);fc.CornerRadius=UDim.new(0,6)
    titleBar=Instance.new("Frame",mainFrame);titleBar.Name="TitleBar";titleBar.Size=UDim2.new(1,0,0,30);titleBar.BackgroundColor3=THEME_COLORS.Primary;titleBar.BorderSizePixel=0;titleBar.ZIndex=3
    local titleText=Instance.new("TextLabel",titleBar);titleText.Name="TitleText";titleText.Size=UDim2.new(1,-80,1,0);titleText.Position=UDim2.new(0.5,0,0.5,0);titleText.AnchorPoint=Vector2.new(0.5,0.5);titleText.BackgroundTransparency=1;titleText.Font=Enum.Font.Michroma;titleText.Text="RyntazHub :: AutoRob V5.3";titleText.TextColor3=THEME_COLORS.Accent;titleText.TextSize=14;titleText.TextXAlignment=Enum.TextXAlignment.Center
    local btnS=UDim2.new(0,12,0,12);local btnY=0.5;local btnYO=-6;local cB=Instance.new("ImageButton",titleBar);cB.Name="Close";cB.Size=btnS;cB.Position=UDim2.new(0,10,btnY,btnYO);cB.Image="rbxassetid://13516625";cB.ImageColor3=THEME_COLORS.CloseButton;cB.BackgroundTransparency=1;cB.ZIndex=4;local mB=Instance.new("ImageButton",titleBar);mB.Name="Minimize";mB.Size=btnS;mB.Position=UDim2.new(0,30,btnY,btnYO);mB.Image="rbxassetid://13516625";mB.ImageColor3=THEME_COLORS.MinimizeButton;mB.BackgroundTransparency=1;mB.ZIndex=4
    outputContainer=Instance.new("ScrollingFrame",mainFrame);outputContainer.Name="OutputContainer";outputContainer.Size=UDim2.new(1,-10,1,-95);outputContainer.Position=UDim2.new(0,5,0,30);outputContainer.BackgroundColor3=Color3.fromRGB(22,24,27);outputContainer.BorderSizePixel=1;outputContainer.BorderColor3=THEME_COLORS.Secondary;outputContainer.CanvasSize=UDim2.new(0,0,0,0);outputContainer.ScrollBarImageColor3=THEME_COLORS.Accent;outputContainer.ScrollBarThickness=6;outputContainer.ZIndex=1;local oc=Instance.new("UICorner",outputContainer);oc.CornerRadius=UDim.new(0,4);local listLayout=Instance.new("UIListLayout",outputContainer);listLayout.Padding=UDim.new(0,2);listLayout.SortOrder=Enum.SortOrder.LayoutOrder;listLayout.HorizontalAlignment=Enum.HorizontalAlignment.Left;listLayout.FillDirection=Enum.FillDirection.Vertical
    statusBar=Instance.new("Frame",mainFrame);statusBar.Name="StatusBar";statusBar.Size=UDim2.new(1,-10,0,25);statusBar.Position=UDim2.new(0,5,1,-60);statusBar.BackgroundColor3=THEME_COLORS.Primary;statusBar.BackgroundTransparency=0.5;statusBar.ZIndex=2;local sc=Instance.new("UICorner",statusBar);sc.CornerRadius=UDim.new(0,3)
    statusTextLabel=Instance.new("TextLabel",statusBar);statusTextLabel.Name="StatusText";statusTextLabel.Size=UDim2.new(0.75,-5,1,0);statusTextLabel.Position=UDim2.new(0,5,0,0);statusTextLabel.BackgroundTransparency=1;statusTextLabel.Font=Enum.Font.Code;statusTextLabel.Text="สถานะ: ว่าง";statusTextLabel.TextColor3=THEME_COLORS.TextDim;statusTextLabel.TextSize=12;statusTextLabel.TextXAlignment=Enum.TextXAlignment.Left
    timerTextLabel=Instance.new("TextLabel",statusBar);timerTextLabel.Name="TimerText";timerTextLabel.Size=UDim2.new(0.25,-5,1,0);timerTextLabel.Position=UDim2.new(0.75,5,0,0);timerTextLabel.BackgroundTransparency=1;timerTextLabel.Font=Enum.Font.Code;timerTextLabel.Text="เวลา: 0.0วิ";timerTextLabel.TextColor3=THEME_COLORS.TextDim;timerTextLabel.TextSize=12;timerTextLabel.TextXAlignment=Enum.TextXAlignment.Right
    local bottomBar=Instance.new("Frame",mainFrame);bottomBar.Name="BottomBar";bottomBar.Size=UDim2.new(1,0,0,30);bottomBar.Position=UDim2.new(0,0,1,-30);bottomBar.BackgroundColor3=THEME_COLORS.Primary;bottomBar.ZIndex=2
    local startAllBtn=createStyledButton(bottomBar,"เริ่มปล้นทั้งหมด",UDim2.new(0.45,-10,0.8,0),UDim2.new(0.025,0,0.1,0),THEME_COLORS.Accent,THEME_COLORS.Background)
    local stopBtn=createStyledButton(bottomBar,"หยุดปล้น",UDim2.new(0.45,-10,0.8,0),UDim2.new(0.525,0,0.1,0),THEME_COLORS.Error,THEME_COLORS.Text)
    local dragging=false;local dI,dS,sPF;titleBar.InputBegan:Connect(function(i)if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragging=true;dS=i.Position;sPF=mainFrame.Position;i.Changed:Connect(function()if i.UserInputState==Enum.UserInputState.End then dragging=false end end)end end);UserInputService.InputChanged:Connect(function(i)if i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch then if dragging and dS then local d=i.Position-dS;mainFrame.Position=UDim2.new(sPF.X.Scale,sPF.X.Offset+d.X,sPF.Y.Scale,sPF.Y.Offset+d.Y)end end end);cB.MouseButton1Click:Connect(function()local ct=TweenService:Create(mainFrame,TweenInfo.new(0.2),{Size=UDim2.fromScale(0.01,0.01),Position=UDim2.new(0.5,0,0.5,0),Transparency=1});ct:Play();ct.Completed:Wait();screenGui:Destroy();mainFrame=nil;if currentRobberyCoroutine then task.cancel(currentRobberyCoroutine);currentRobberyCoroutine=nil;isRobbingGlobally=false;logOutputWrapper("RobCtrl","หยุด (ปิด UI)")end end);local isCV=INITIAL_UI_VISIBLE;local function tCV()isCV=not isCV;outputContainer.Visible=isCV;bottomBar.Visible=isCV;statusBar.Visible=isCV;local tS;if isCV then tS=originalMainFrameSize;mB.ImageColor3=THEME_COLORS.MinimizeButton else tS=UDim2.new(originalMainFrameSize.X.Scale,originalMainFrameSize.X.Offset,0,titleBar.AbsoluteSize.Y);mB.ImageColor3=THEME_COLORS.Accent end;TweenService:Create(mainFrame,TweenInfo.new(0.2),{Size=tS}):Play()end;mB.MouseButton1Click:Connect(tCV);mxB.MouseButton1Click:Connect(tCV)
    startAllBtn.MouseButton1Click:Connect(function()if isRobbingGlobally then logOutputWrapper("RobCtrl","การปล้นกำลังทำงานอยู่...");return end;logOutputWrapper("System","เริ่มลำดับการปล้นทั้งหมด...");task.spawn(executeAllRobberiesAndHop)end)
    stopBtn.MouseButton1Click:Connect(function()if currentRobberyCoroutine then isRobbingGlobally=false;task.cancel(currentRobberyCoroutine);currentRobberyCoroutine=nil;logOutputWrapper("RobCtrl","หยุดการปล้นตามคำสั่งแล้ว");updateStatus("หยุดปล้นแล้ว",0)else logOutputWrapper("RobCtrl","ไม่มีการปล้นที่กำลังทำงานอยู่")end end)
    originalMainFramePosition=UDim2.new(0.5,0,0.5,0);TweenService:Create(mainFrame,TweenInfo.new(0.5,Enum.EasingStyle.Elastic,Enum.EasingDirection.Out),{Size=originalMainFrameSize,Position=originalMainFramePosition}):Play();if not INITIAL_UI_VISIBLE then task.wait(0.5);tCV()end
end

local function executeAllRobberiesAndHop()
    if isRobbingGlobally then print("[AutoRob] Sequence already running."); return end
    isRobbingGlobally = true; currentRobberyCoroutine = coroutine.running()
    print("--- Starting Full Auto-Robbery Sequence (V5.3) ---"); local overallStartTime = tick(); startTime = overallStartTime
    updateStatus("เริ่มลำดับการปล้นทั้งหมด...", 0)
    for i, heistName in ipairs(TARGET_HEISTS_TO_ROB_SEQUENCE) do
        if not currentRobberyCoroutine then print("[AutoRob] Full sequence cancelled by stopRobbery."); break end
        if not (Character and Humanoid and Humanoid.Health > 0) then print("[AutoRob] Character died, stopping sequence."); break end
        
        local heistConfig = HEIST_SPECIFIC_CONFIG[heistName]
        if heistConfig then
            logOutputWrapper("Sequence", string.format("เริ่มปล้น: %s (%d/%d)", heistConfig.DisplayName or heistName, i, #TARGET_HEISTS_TO_ROB_SEQUENCE))
            updateStatus(string.format("กำลังปล้น: %s", heistConfig.DisplayName or heistName), (i-1)/#TARGET_HEISTS_TO_ROB_SEQUENCE * 100)
            local robSuccess = executeFullHeistRobbery(heistName)
            if not robSuccess then
                logOutputWrapper("SequenceError", string.format("การปล้น %s ล้มเหลวหรือถูกขัดจังหวะ.", heistConfig.DisplayName or heistName))
                if AutoHeistSettings.stopOnError then print("[AutoRob] หยุดการปล้นทั้งหมดเนื่องจาก Heist ก่อนหน้าล้มเหลว."); break end
            end
        else logOutputWrapper("SequenceWarning", "ไม่พบ Config สำหรับ Heist key: " .. heistName) end
        
        if i < #TARGET_HEISTS_TO_ROB_SEQUENCE and currentRobberyCoroutine then
            local waitTime = math.random(2, 4) + (AutoHeistSettings.interactionDelay * 5)
            updateStatus(string.format("รอ %.1fวินาที ก่อนปล้นที่ต่อไป...", waitTime), i / #TARGET_HEISTS_TO_ROB_SEQUENCE * 100)
            local waited = 0; while waited < waitTime and currentRobberyCoroutine do task.wait(0.1); waited = waited + 0.1 end
        end
    end
    if currentRobberyCoroutine then
        updateStatus("ปล้นทั้งหมดเสร็จสิ้น. กำลัง Server Hop...", 100)
        logOutputWrapper("System", string.format("ลำดับการปล้นทั้งหมดเสร็จสิ้นใน %.2f วินาที. กำลังเริ่ม Server Hop.", tick() - overallStartTime))
        ServerHop()
    end
    isRobbingGlobally = false; currentRobberyCoroutine = nil
end

task.spawn(function()while true do if mainFrame and mainFrame.Parent and timerTextLabel then if startTime then timerTextLabel.Text=string.format("เวลา: %.1fs",tick()-startTime)else timerTextLabel.Text="เวลา: --.-s"end end;task.wait(0.1)end end)

if waitForCharacter() then
    pcall(createMainUI_V2_6_5) -- เปลี่ยนชื่อฟังก์ชันให้ไม่ซ้ำ
    local autoStartRobbery = true 
    if autoStartRobbery then
        logOutputWrapper("System", "[AutoRob V5.3] Auto-start. รอ 3 วินาที...")
        task.wait(3)
        if not isRobbingGlobally then task.spawn(executeAllRobberiesAndHop) end
    else
        logOutputWrapper("System", "[AutoRob V5.3] Auto-start ปิดอยู่. คลิกปุ่ม 'เริ่มปล้นทั้งหมด' หรือเรียก executeAllRobberiesAndHop() จาก Console")
    end
else
    logOutputWrapper("SystemError", "[AutoRob V5.3] สคริปต์หยุดทำงาน: ไม่สามารถโหลด Character ได้")
end
