--[[
Script สำรวจ Heists และ ReplicatedStorage - V2.6.3 (Streamlined)
(ฐานจาก V2.6 ที่ผู้ใช้ยืนยันว่ารันได้ ปรับปรุง UI/UX, Progress, Timer, Animation,
และเน้นการสแกนเฉพาะ Workspace.Heists และ ReplicatedStorage)

เป้าหมาย: ค้นหา Scripts, ProximityPrompts, Remotes และ Parts ที่อาจเกี่ยวข้องกับการปล้น
แล้วแสดง Path ของสิ่งที่ค้นพบ พร้อมปุ่มคัดลอก

ข้อควรระวัง: สคริปต์นี้มีวัตถุประสงค์เพื่อการทดสอบและปรับปรุงความปลอดภัยเท่านั้น
]]

local Player = game:GetService("Players").LocalPlayer
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- ตัดการ GetService ที่ไม่ได้ใช้ออก
-- local Lighting = game:GetService("Lighting")
-- local StarterGui = game:GetService("StarterGui")
-- local ServerScriptService = pcall(function() return game:GetService("ServerScriptService") end) and game:GetService("ServerScriptService") or nil

-- ================= CONFIGURATION =================
local HEISTS_BASE_PATH_STRING = "Heists"
-- TARGET_HEISTS จะใช้ในการวนลูปสแกน Heist ย่อยๆ ถ้า HeistsFolder ถูกพบ
local TARGET_HEISTS_IN_WORKSPACE = {"Bank", "Casino", "JewelryStore"}

local SHOW_UI_OUTPUT = true
local UI_OUTPUT_ENCRYPTION_METHOD = "None" -- "None", "Hex", "Base64"
local INITIAL_UI_VISIBLE = true

local EXTRA_LOOT_KEYWORDS = {"moneybag", "goldbar", "artifact", "valuable", "contraband", "keycard", "access", "vault", "safe", "computer", "terminal", "loot", "item", "collectible"}
local MINI_ROBBERIES_NAMES_EXTENDED = {
    "Cash", "CashRegister", "DiamondBox", "Laptop", "Phone", "Luggage", "ATM", "TV", "Safe",
    "Briefcase", "MoneyStack", "GoldStack", "Computer", "Terminal"
}
local SENSITIVE_SCRIPT_KEYWORDS = {"admin", "exploit", "hack", "remote", "event", "fire", "invoke", "money", "cash", "rob", "heist", "security", "bypass", "kill", "fly", "speed", "esp", "trigger", "pcall", "require", "network", "signal"}


-- ================= THEME & UI SETTINGS (เหมือน V2.6) =================
local THEME_COLORS = {
    Background = Color3.fromRGB(18, 20, 23), Primary = Color3.fromRGB(25, 28, 33),
    Secondary = Color3.fromRGB(35, 40, 50), Accent = Color3.fromRGB(0, 255, 120),
    Text = Color3.fromRGB(210, 215, 220), TextDim = Color3.fromRGB(130, 135, 140),
    ButtonHover = Color3.fromRGB(50, 55, 70), CloseButton = Color3.fromRGB(255, 95, 86),
    MinimizeButton = Color3.fromRGB(255, 189, 46), MaximizeButton = Color3.fromRGB(40, 200, 65)
}

-- ================= UI ELEMENTS & FUNCTIONS (เหมือน V2.6) =================
local mainFrame
local outputContainer
local titleBar
local statusBar
local statusTextLabel
local timerTextLabel
local allLoggedMessages = {}
local isMinimized = not INITIAL_UI_VISIBLE
local originalMainFrameSize = UDim2.new(0.6, 0, 0.75, 0)
local originalMainFramePosition

local startTime

local function copyToClipboard(textToCopy)
    local success = false; local message = ""
    if typeof(setclipboard) == "function" then
        pcall(function() setclipboard(textToCopy); success = true end)
        message = success and "[Clipboard] Copied." or "[Clipboard] Failed to copy."
    elseif typeof(writefile) == "function" then
        pcall(function() writefile("ryntaz_explorer_clipboard.txt", textToCopy); success = true end)
        message = success and "[Clipboard] Saved to ryntaz_explorer_clipboard.txt." or "[Clipboard] Failed to save file."
    else message = "[Clipboard] No copy/writefile function." end
    print(message)
    if SHOW_UI_OUTPUT and mainFrame and outputContainer then
        local tempLabel = outputContainer:FindFirstChild("TempStatusLabel") or Instance.new("TextLabel", outputContainer)
        tempLabel.Name = "TempStatusLabel"; tempLabel.Size = UDim2.new(1, -10, 0, 20)
        tempLabel.BackgroundColor3 = THEME_COLORS.Accent; tempLabel.TextColor3 = THEME_COLORS.Background
        tempLabel.Font = Enum.Font.SourceSansSemibold; tempLabel.TextSize = 14
        tempLabel.LayoutOrder = -1000; tempLabel.ZIndex = 100; tempLabel.Text = message; tempLabel.Visible = true
        task.delay(2, function() if tempLabel and tempLabel.Parent then tempLabel.Visible = false end end)
    end
    return success
end

local function createStyledButton(parent, text, size, position, colorOverride, textColorOverride)
    local button = Instance.new("TextButton", parent); button.Text = text; button.Size = size; button.Position = position
    button.BackgroundColor3 = colorOverride or THEME_COLORS.Secondary
    button.TextColor3 = textColorOverride or THEME_COLORS.Text
    button.Font = Enum.Font.SourceSansSemibold; button.TextSize = 14; button.ClipsDescendants = true
    local corner = Instance.new("UICorner", button); corner.CornerRadius = UDim.new(0, 4)
    button.MouseEnter:Connect(function() TweenService:Create(button, TweenInfo.new(0.1), {BackgroundColor3 = THEME_COLORS.ButtonHover}):Play() end)
    button.MouseLeave:Connect(function() TweenService:Create(button, TweenInfo.new(0.1), {BackgroundColor3 = colorOverride or THEME_COLORS.Secondary}):Play() end)
    return button
end

local function introAnimationV2(parentGui)
    local introFrame = Instance.new("Frame", parentGui); introFrame.Name = "IntroAnimationV2"
    introFrame.Size = UDim2.new(1, 0, 1, 0); introFrame.Position = UDim2.new(0, 0, 0, 0)
    introFrame.BackgroundTransparency = 1; introFrame.ZIndex = 2000

    local textLabel = Instance.new("TextLabel", introFrame)
    textLabel.Name = "RyntazHubText"; textLabel.Size = UDim2.new(0.8, 0, 0.3, 0)
    textLabel.Position = UDim2.new(0.5, 0, 0.5, 0); textLabel.AnchorPoint = Vector2.new(0.5, 0.5)
    textLabel.BackgroundTransparency = 1; textLabel.Font = Enum.Font.Michroma
    textLabel.Text = ""; textLabel.TextColor3 = THEME_COLORS.Accent; textLabel.TextScaled = true
    textLabel.TextStrokeTransparency = 0.3; textLabel.TextStrokeColor3 = Color3.fromRGB(10,10,10)

    local fullText = "Ryntaz Hub"; local typeDuration = 0.8; local stayDuration = 0.7; local fadeOutDuration = 0.5
    textLabel.TextTransparency = 0
    for i = 1, #fullText do textLabel.Text = string.sub(fullText, 1, i); task.wait(typeDuration / #fullText) end
    task.wait(stayDuration)
    TweenService:Create(textLabel, TweenInfo.new(fadeOutDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {TextTransparency = 1, TextStrokeTransparency = 1}):Play()
    task.delay(fadeOutDuration + 0.1, function() if introFrame and introFrame.Parent then introFrame:Destroy() end end)
end

local function createMainUI()
    if mainFrame and mainFrame.Parent then return end
    local screenGui = Instance.new("ScreenGui", Player:WaitForChild("PlayerGui"))
    screenGui.Name = "RyntazHub_Explorer_V2_6_3"
    screenGui.ResetOnSpawn = false; screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling; screenGui.DisplayOrder = 999
    
    introAnimationV2(screenGui); task.wait(1.6)

    mainFrame = Instance.new("Frame", screenGui); mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.fromScale(0.01,0.01); mainFrame.Position = UDim2.new(0.5,0,0.5,0)
    mainFrame.AnchorPoint = Vector2.new(0.5, 0.5); mainFrame.BackgroundColor3 = THEME_COLORS.Background
    mainFrame.BorderSizePixel = 1; mainFrame.BorderColor3 = THEME_COLORS.Accent; mainFrame.ClipsDescendants = true
    local frameCorner = Instance.new("UICorner", mainFrame); frameCorner.CornerRadius = UDim.new(0, 6)

    titleBar = Instance.new("Frame", mainFrame); titleBar.Name = "TitleBar"
    titleBar.Size = UDim2.new(1,0,0,30); titleBar.BackgroundColor3 = THEME_COLORS.Primary
    titleBar.BorderSizePixel = 0; titleBar.ZIndex = 3
    local titleText = Instance.new("TextLabel", titleBar); titleText.Name = "TitleText"
    titleText.Size = UDim2.new(1,-80,1,0); titleText.Position = UDim2.new(0.5,0,0.5,0)
    titleText.AnchorPoint = Vector2.new(0.5,0.5); titleText.BackgroundTransparency = 1
    titleText.Font = Enum.Font.Michroma; titleText.Text = "RyntazHub :: Focused Explorer"
    titleText.TextColor3 = THEME_COLORS.Accent; titleText.TextSize = 15; titleText.TextXAlignment = Enum.TextXAlignment.Center

    local buttonSize = UDim2.new(0,12,0,12); local btnY = 0.5; local btnYOffset = -6
    local closeBtn = Instance.new("ImageButton",titleBar);closeBtn.Name="Close";closeBtn.Size=buttonSize;closeBtn.Position=UDim2.new(0,10,btnY,btnYOffset);closeBtn.Image="rbxassetid://13516625";closeBtn.ImageColor3=THEME_COLORS.CloseButton;closeBtn.BackgroundTransparency=1;closeBtn.ZIndex=4
    local minBtn = Instance.new("ImageButton",titleBar);minBtn.Name="Minimize";minBtn.Size=buttonSize;minBtn.Position=UDim2.new(0,30,btnY,btnYOffset);minBtn.Image="rbxassetid://13516625";minBtn.ImageColor3=THEME_COLORS.MinimizeButton;minBtn.BackgroundTransparency=1;minBtn.ZIndex=4
    local maxBtn = Instance.new("ImageButton",titleBar);maxBtn.Name="Maximize";maxBtn.Size=buttonSize;maxBtn.Position=UDim2.new(0,50,btnY,btnYOffset);maxBtn.Image="rbxassetid://13516625";maxBtn.ImageColor3=THEME_COLORS.MaximizeButton;maxBtn.BackgroundTransparency=1;maxBtn.ZIndex=4

    outputContainer = Instance.new("ScrollingFrame", mainFrame); outputContainer.Name = "OutputContainer"
    outputContainer.Size = UDim2.new(1,-10,1,-95); outputContainer.Position = UDim2.new(0,5,0,30)
    outputContainer.BackgroundColor3 = Color3.fromRGB(22,24,27); outputContainer.BorderSizePixel = 1; outputContainer.BorderColor3 = THEME_COLORS.Secondary
    outputContainer.CanvasSize = UDim2.new(0,0,0,0); outputContainer.ScrollBarImageColor3 = THEME_COLORS.Accent
    outputContainer.ScrollBarThickness = 8; outputContainer.ZIndex = 1; local oc = Instance.new("UICorner",outputContainer); oc.CornerRadius = UDim.new(0,4)
    local listLayout = Instance.new("UIListLayout", outputContainer); listLayout.Padding = UDim.new(0,2); listLayout.SortOrder = Enum.SortOrder.LayoutOrder; listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left; listLayout.FillDirection = Enum.FillDirection.Vertical

    statusBar = Instance.new("Frame", mainFrame); statusBar.Name = "StatusBar"; statusBar.Size = UDim2.new(1,-10,0,25)
    statusBar.Position = UDim2.new(0,5,1,-60); statusBar.BackgroundColor3 = THEME_COLORS.Primary; statusBar.BackgroundTransparency = 0.5; statusBar.ZIndex = 2; local sc = Instance.new("UICorner",statusBar); sc.CornerRadius = UDim.new(0,3)
    statusTextLabel = Instance.new("TextLabel", statusBar); statusTextLabel.Name = "StatusText"; statusTextLabel.Size = UDim2.new(0.75,-5,1,0); statusTextLabel.Position = UDim2.new(0,5,0,0); statusTextLabel.BackgroundTransparency = 1; statusTextLabel.Font = Enum.Font.Code; statusTextLabel.Text = "Status: Idle"; statusTextLabel.TextColor3 = THEME_COLORS.TextDim; statusTextLabel.TextSize = 12; statusTextLabel.TextXAlignment = Enum.TextXAlignment.Left
    timerTextLabel = Instance.new("TextLabel", statusBar); timerTextLabel.Name = "TimerText"; timerTextLabel.Size = UDim2.new(0.25,-5,1,0); timerTextLabel.Position = UDim2.new(0.75,5,0,0); timerTextLabel.BackgroundTransparency = 1; timerTextLabel.Font = Enum.Font.Code; timerTextLabel.Text = "Time: 0.0s"; timerTextLabel.TextColor3 = THEME_COLORS.TextDim; timerTextLabel.TextSize = 12; timerTextLabel.TextXAlignment = Enum.TextXAlignment.Right

    local bottomBar = Instance.new("Frame", mainFrame); bottomBar.Name = "BottomBar"; bottomBar.Size = UDim2.new(1,0,0,30); bottomBar.Position = UDim2.new(0,0,1,-30); bottomBar.BackgroundColor3 = THEME_COLORS.Primary; bottomBar.ZIndex = 2
    local copyAllBtn = createStyledButton(bottomBar,"Copy All Logs",UDim2.new(0.45, -10, 0.8, 0),UDim2.new(0.02, 0, 0.1, 0))
    local clearLogBtn = createStyledButton(bottomBar,"Clear Logs",UDim2.new(0.45, -10, 0.8, 0),UDim2.new(0.53, 0, 0.1, 0))
    -- ปุ่ม Rescan จะเรียก executeFocusedScanSequence
    -- ปุ่ม Start All Robs จะถูกตัดออกไปก่อนในเวอร์ชันนี้ เพื่อเน้นการสแกน

    local dragging = false; local dragInput, dragStart, startPositionFrame
    titleBar.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = true; dragStart = input.Position; startPositionFrame = mainFrame.Position; input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end) end end)
    UserInputService.InputChanged:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then if dragging and dragStart then local delta = input.Position - dragStart; mainFrame.Position = UDim2.new(startPositionFrame.X.Scale, startPositionFrame.X.Offset + delta.X, startPositionFrame.Y.Scale, startPositionFrame.Y.Offset + delta.Y) end end end)
    closeBtn.MouseButton1Click:Connect(function() local ct = TweenService:Create(mainFrame,TweenInfo.new(0.2,Enum.EasingStyle.Quad,Enum.EasingDirection.In),{Size=UDim2.fromScale(0.01,0.01),Position=UDim2.new(0.5,0,0.5,0),Transparency=1}); ct:Play(); ct.Completed:Wait(); screenGui:Destroy(); mainFrame=nil end)
    local isContentVisible = INITIAL_UI_VISIBLE; local function toggleContentVisibility() isContentVisible = not isContentVisible; outputContainer.Visible = isContentVisible; bottomBar.Visible = isContentVisible; statusBar.Visible = isContentVisible; local ts; if isContentVisible then ts = originalMainFrameSize; maxBtn.ImageColor3 = THEME_COLORS.MaximizeButton; minBtn.ImageColor3 = THEME_COLORS.MinimizeButton else ts = UDim2.new(originalMainFrameSize.X.Scale,originalMainFrameSize.X.Offset,0,titleBar.AbsoluteSize.Y); maxBtn.ImageColor3 = THEME_COLORS.Accent; minBtn.ImageColor3 = THEME_COLORS.Accent end; TweenService:Create(mainFrame,TweenInfo.new(0.2),{Size=ts}):Play() end
    minBtn.MouseButton1Click:Connect(toggleContentVisibility); maxBtn.MouseButton1Click:Connect(toggleContentVisibility)
    copyAllBtn.MouseButton1Click:Connect(function() local at = "-- RyntazHub Explorer Log --\n"; for _,e in ipairs(allLoggedMessages)do at=at..e.."\n"end; if copyToClipboard(at)then copyAllBtn.Text="Copied!"else copyAllBtn.Text="Fail!"end; task.wait(1.5);copyAllBtn.Text="Copy All Logs"end)
    clearLogBtn.MouseButton1Click:Connect(function() allLoggedMessages={}; for _,c in ipairs(outputContainer:GetChildren())do if c:IsA("Frame")and(c.Name=="LogEntryContainer"or c.Name=="CategoryHeader"or c.Name=="TempStatusLabel")then c:Destroy()end end; outputContainer.CanvasSize=UDim2.new(0,0,0,0); logOutputWrapper("UI","Logs Cleared.")end)
    -- rescanBtn จะถูกเพิ่มทีหลัง เมื่อ executeFocusedScanSequence พร้อม
    
    originalMainFramePosition = UDim2.new(0.5,0,0.5,0); TweenService:Create(mainFrame,TweenInfo.new(0.5,Enum.EasingStyle.Elastic,Enum.EasingDirection.Out),{Size=originalMainFrameSize,Position=originalMainFramePosition}):Play()
    if not INITIAL_UI_VISIBLE then task.wait(0.5); toggleContentVisibility() end
end

local function addLogEntryToUI(category,originalMessage,encryptedMessage,encryptionTag) if not(SHOW_UI_OUTPUT and mainFrame and outputContainer)then return end;local timestamp=os.date("[%H:%M:%S] ");local entryContainer=Instance.new("Frame",outputContainer);entryContainer.Name="LogEntryContainer";entryContainer.BackgroundTransparency=1;entryContainer.Size=UDim2.new(1,-6,0,0);entryContainer.AutomaticSize=Enum.AutomaticSize.Y;entryContainer.LayoutOrder=#outputContainer:GetChildren();local logEntryLabel=Instance.new("TextLabel",entryContainer);logEntryLabel.Name="LogEntryLabel";logEntryLabel.Text="<b>"..timestamp.."["..category.."]</b> "..encryptionTag..encryptedMessage;logEntryLabel.RichText=true;logEntryLabel.TextColor3=THEME_COLORS.Text;logEntryLabel.Font=Enum.Font.Code;logEntryLabel.TextSize=13;logEntryLabel.TextXAlignment=Enum.TextXAlignment.Left;logEntryLabel.TextWrapped=true;logEntryLabel.Size=UDim2.new(0.82,-5,0,0);logEntryLabel.Position=UDim2.new(0,0,0,0);logEntryLabel.AutomaticSize=Enum.AutomaticSize.Y;logEntryLabel.BackgroundColor3=THEME_COLORS.Primary;logEntryLabel.BackgroundTransparency=0.6;local lc=Instance.new("UICorner",logEntryLabel);lc.CornerRadius=UDim.new(0,3);local cb=createStyledButton(entryContainer,"COPY",UDim2.new(0.15,0,0,20),UDim2.new(0.84,0,0,0),THEME_COLORS.Secondary,THEME_COLORS.Accent);cb.TextSize=11;cb.ZIndex=3;task.wait();local lh=logEntryLabel.AbsoluteSize.Y;entryContainer.Size=UDim2.new(1,-6,0,math.max(22,lh+2));cb.Size=UDim2.new(0.15,0,0,math.max(18,lh));cb.Position=UDim2.new(0.84,0,0.5,-cb.AbsoluteSize.Y/2);cb.MouseButton1Click:Connect(function()if copyToClipboard(originalMessage)then cb.Text="OK";cb.TextColor3=Color3.fromRGB(0,255,0)else cb.Text="ERR";cb.TextColor3=Color3.fromRGB(255,80,80)end;task.wait(1);cb.Text="COPY";cb.TextColor3=THEME_COLORS.Accent end);local th=5;for _,c in ipairs(outputContainer:GetChildren())do if c:IsA("Frame")and(c.Name=="LogEntryContainer"or c.Name=="CategoryHeader"or c.Name=="TempStatusLabel")then th=th+c.AbsoluteSize.Y+outputContainer.UIListLayout.Padding.Offset end end;outputContainer.CanvasSize=UDim2.new(0,0,0,th);if outputContainer.CanvasSize.Y.Offset>outputContainer.AbsoluteSize.Y then outputContainer.CanvasPosition=Vector2.new(0,outputContainer.CanvasSize.Y.Offset-outputContainer.AbsoluteSize.Y)end end
local function addCategoryHeaderToUI(categoryName)if not(SHOW_UI_OUTPUT and mainFrame and outputContainer)then return end;local h=Instance.new("Frame",outputContainer);h.Name="CategoryHeader";h.Size=UDim2.new(1,-6,0,25);h.BackgroundColor3=THEME_COLORS.Secondary;h.LayoutOrder=#outputContainer:GetChildren();local co=Instance.new("UICorner",h);co.CornerRadius=UDim.new(0,3);local t=Instance.new("TextLabel",h);t.Size=UDim2.new(1,-10,1,0);t.Position=UDim2.new(0,5,0,0);t.BackgroundTransparency=1;t.Font=Enum.Font.Michroma;t.Text="SCANNING: "..categoryName;t.TextColor3=THEME_COLORS.Accent;t.TextSize=15;t.TextXAlignment=Enum.TextXAlignment.Left;task.wait();local th=5;for _,c in ipairs(outputContainer:GetChildren())do if c:IsA("Frame")and(c.Name=="LogEntryContainer"or c.Name=="CategoryHeader"or c.Name=="TempStatusLabel")then th=th+c.AbsoluteSize.Y+outputContainer.UIListLayout.Padding.Offset end end;outputContainer.CanvasSize=UDim2.new(0,0,0,th)end
local function logOutputWrapper(category,message)local timestamp=os.date("[%H:%M:%S] ");local originalMessage=message;local fullMessageForConsole=timestamp.."["..category.."] "..originalMessage;print(fullMessageForConsole);table.insert(allLoggedMessages,fullMessageForConsole);local encryptedMessage=originalMessage;local encryptionTag="";if UI_OUTPUT_ENCRYPTION_METHOD=="Hex"then local hex="";for i=1,#originalMessage do hex=hex..string.format("%02x",string.byte(originalMessage,i))end;encryptedMessage=hex;encryptionTag="[HEX] "elseif UI_OUTPUT_ENCRYPTION_METHOD=="Base64"then if HttpService and HttpService.EncodeBase64 then encryptedMessage=HttpService:EncodeBase64(originalMessage);encryptionTag="[B64] "else encryptedMessage=originalMessage;encryptionTag="[B64-Fail] "end end;if SHOW_UI_OUTPUT and mainFrame and outputContainer then addLogEntryToUI(category,originalMessage,encryptedMessage,encryptionTag)end end

local function updateStatus(text, overallPercentage)
    if SHOW_UI_OUTPUT and statusTextLabel and statusTextLabel.Parent then
        local currentText = "Status: " .. text
        if overallPercentage then currentText = currentText .. string.format(" (Overall: %.0f%%)", overallPercentage) end
        statusTextLabel.Text = currentText
    end
    print("[StatusUpdate] " .. text .. (overallPercentage and string.format(" (Overall: %.0f%%)", overallPercentage) or ""))
end

function exploreFocusedPath(rootInstance, rootNameForLog, currentScanIndex, totalScanTasks)
    updateStatus("กำลังสำรวจ: " .. rootNameForLog, (currentScanIndex / totalScanTasks) * 100)
    if SHOW_UI_OUTPUT and mainFrame and outputContainer and not outputContainer:FindFirstChild("CategoryHeader_"..rootNameForLog:gsub("[^%w]","")) then
        addCategoryHeaderToUI(rootNameForLog)
    end

    local foundItems = {}
    local descendants = rootInstance:GetDescendants()
    local numDescendants = #descendants
    local updateInterval = math.max(1, math.floor(numDescendants / 15)) -- อัปเดต Progress บ่อยขึ้นเล็กน้อย

    for i, descendant in ipairs(descendants) do
        local itemPath = descendant:GetFullName()
        if not foundItems[itemPath] then
            local loggedThisItem = false
            if descendant:IsA("LuaSourceContainer") then
                local sCP=""; if descendant:IsA("Script")or descendant:IsA("LocalScript")then local s,sr=pcall(function()return descendant.Source end);if s and sr and #sr>0 then sCP="|Code";for _,k in ipairs(SENSITIVE_SCRIPT_KEYWORDS)do if sr:lower():match(k)then sCP=sCP.." [K:"..k.."]";break end end else sCP="|SrcFail/Empty"end end
                logOutputWrapper("ScriptFound","Path: "..itemPath.." |T: "..descendant.ClassName..sCP);loggedThisItem=true
            end
            if descendant:IsA("RemoteEvent")or descendant:IsA("RemoteFunction")then logOutputWrapper("RemoteFound","Path: "..itemPath.." |T: "..descendant.ClassName);loggedThisItem=true end
            if descendant:IsA("ProximityPrompt")then logOutputWrapper("ProximityPromptFound","Path: "..itemPath.." |Obj:"..(descendant.ObjectText or"-").." |Act:"..(descendant.ActionText or"-").." |Hold:"..tostring(descendant.HoldDuration).." |Dist:"..string.format("%.1f",descendant.MaxActivationDistance).." |En:"..tostring(descendant.Enabled));loggedThisItem=true end
            if descendant:IsA("BasePart")and not descendant:IsA("Terrain")then
                local pI="";local iLP=false
                for _,k in ipairs(MINI_ROBBERIES_NAMES_EXTENDED)do if descendant.Name:lower():match(k:lower())then iLP=true;pI=pI.."[K:"..k.."]";break end end
                if not iLP then for _,k in ipairs(EXTRA_LOOT_KEYWORDS)do if descendant.Name:lower():match(k:lower())then iLP=true;pI=pI.."[K:"..k.."]";break end end end
                if iLP then logOutputWrapper("PotentialLootPart","Path: "..itemPath.." "..pI.." |Pos: "..string.format("%.1f,%.1f,%.1f",descendant.Position.X,descendant.Position.Y,descendant.Position.Z));loggedThisItem=true end
                if descendant:FindFirstChildOfClass("TouchTransmitter")then logOutputWrapper("PartWithTouch","Path: "..itemPath.." (Touch)");loggedThisItem=true end
                local p=descendant.Parent;if p then for _,cs in ipairs(p:GetChildren())do if cs:IsA("LuaSourceContainer")and(cs.Name:lower():match("touch")or cs.Name:lower():match("interact")or cs.Name:lower():match("click"))then logOutputWrapper("PartAssociatedScript","Part: "..itemPath.." |Scr: "..cs:GetFullName());loggedThisItem=true;break end end end
            end
            if loggedThisItem then foundItems[itemPath]=true end
        end
        if i % updateInterval == 0 then
            updateStatus("สแกน "..rootNameForLog..string.format(" (%.0f%%)",(i/numDescendants)*100), (currentScanIndex/totalScanTasks)*100+((i/numDescendants)*(1/totalScanTasks)*100) )
            task.wait()
        end
    end
    updateStatus("สำรวจเสร็จสิ้น: "..rootNameForLog, (currentScanIndex / totalScanTasks) * 100)
end

local function executeFocusedScanSequence()
    startTime = tick()
    if SHOW_UI_OUTPUT and outputContainer then
        local children = outputContainer:GetChildren()
        for i = #children, 1, -1 do local child = children[i]
            if child.Name == "LogEntryContainer" or child.Name == "CategoryHeader" or child.Name == "TempStatusLabel" then child:Destroy() end
        end
        allLoggedMessages = {}; outputContainer.CanvasSize = UDim2.new(0,0,0,0)
    end

    logOutputWrapper("System", "RyntazHub Explorer V2.6.1 Initialized & Focused Scanning...")
    
    local pathsToScanConfig = {}
    local heistsFolder = Workspace:FindFirstChild(HEISTS_BASE_PATH_STRING)
    if heistsFolder then
        if #TARGET_HEISTS_IN_WORKSPACE > 0 then
            for _, heistName in ipairs(TARGET_HEISTS_IN_WORKSPACE) do
                local specificHeistFolder = heistsFolder:FindFirstChild(heistName)
                if specificHeistFolder then table.insert(pathsToScanConfig, {instance = specificHeistFolder, name = specificHeistFolder:GetFullName()})
                else logOutputWrapper("Error", "ไม่พบ Folder Heist: " .. heistName .. " ใน " .. heistsFolder:GetFullName()) end
            end
        else
            logOutputWrapper("Info", "ไม่ได้ระบุ TARGET_HEISTS_IN_WORKSPACE, สแกน Children ของ " .. heistsFolder:GetFullName())
            for _, childHeist in ipairs(heistsFolder:GetChildren()) do
                if childHeist:IsA("Instance") then table.insert(pathsToScanConfig, {instance = childHeist, name = childHeist:GetFullName()}) end
            end
        end
    else logOutputWrapper("Error", "ไม่พบ Folder Heists หลัก: '" .. HEISTS_BASE_PATH_STRING .. "' ใน Workspace.") end

    if ReplicatedStorage then table.insert(pathsToScanConfig, {instance = ReplicatedStorage, name = "ReplicatedStorage"}) end
    
    local totalScanTasks = #pathsToScanConfig
    if totalScanTasks == 0 then updateStatus("ไม่พบ Path ที่จะสแกน", 100); logOutputWrapper("System", "Focused scan finished (No paths)."); return end

    for i, scanTask in ipairs(pathsToScanConfig) do
        exploreFocusedPath(scanTask.instance, scanTask.name, i, totalScanTasks)
        if i < totalScanTasks then task.wait(0.05) end
    end
    updateStatus("การสำรวจ (Focused) ทั้งหมดเสร็จสิ้น.", 100)
    logOutputWrapper("System", string.format("การสำรวจ (Focused) ทั้งหมดเสร็จสิ้นใน %.2f วินาที.", tick() - startTime))
end

task.spawn(function()
    while true do
        if SHOW_UI_OUTPUT and mainFrame and mainFrame.Parent and timerTextLabel then
            if startTime then timerTextLabel.Text = string.format("Time: %.1fs", tick() - startTime)
            else timerTextLabel.Text = "Time: --.-s" end
        end; task.wait(0.1)
    end
end)

if SHOW_UI_OUTPUT then
    local uiSuccess, uiErr = pcall(createMainUI)
    if not uiSuccess then
        if typeof(earlyDebug) == "function" then earlyDebug("ERROR createMainUI: "..tostring(uiErr))
        else print("FATAL ERROR creating UI, and earlyDebug is not available: "..tostring(uiErr)) end
    end
else
    if typeof(earlyDebug) == "function" then earlyDebug("SHOW_UI_OUTPUT is false.")
    else print("SHOW_UI_OUTPUT is false, no UI will be created.") end
end

task.spawn(function()
    task.wait(0.2) -- ให้ UI มีโอกาสสร้างเสร็จก่อนเริ่มสแกน
    local scanSuccess, scanErr = pcall(executeFocusedScanSequence)
    if not scanSuccess then
        if typeof(earlyDebug) == "function" then earlyDebug("ERROR executeFocusedScanSequence: "..tostring(scanErr)) end
        logOutputWrapper("SystemError", "Scan Error: " .. tostring(scanErr))
    else
        logOutputWrapper("System", "สแกน (Focused) เสร็จสิ้น.")
    end
end)
