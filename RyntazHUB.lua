-- AutoRob (Super Simplified) - V5.1 (UI Parent Fix)
-- เน้นการปล้น, เทเลพอร์ต, และ Server Hop (ถ้าต้องการ) - UI น้อยที่สุด

local Player = game:GetService("Players").LocalPlayer
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui") -- ยังคง GetService ไว้เผื่อกรณีอื่น แต่จะใช้ PlayerGui เป็นหลัก

local Character
local Humanoid
local HumanoidRootPart
local currentRobberyCoroutine = nil
local isRobbingGlobally = false

local function waitForCharacter()
    print("[AutoRob V5.1] Waiting for character...")
    local attempts = 0
    repeat
        attempts = attempts + 1
        if Player and Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") and Player.Character:FindFirstChildOfClass("Humanoid") then
            Character = Player.Character
            Humanoid = Character:FindFirstChildOfClass("Humanoid")
            RootPart = Character:FindFirstChild("HumanoidRootPart")
            if Humanoid and RootPart then
                print("[AutoRob V5.1] Character found.")
                return true
            end
        end
        task.wait(0.3)
    until attempts > 60
    print("[AutoRob V5.1] ERROR: Character not found after timeout.")
    return false
end

Player.CharacterAdded:Connect(function(newChar)
    Character = newChar
    Humanoid = newChar:WaitForChild("Humanoid", 15)
    RootPart = newChar:WaitForChild("HumanoidRootPart", 15)
    print("[AutoRob V5.1] Character respawned/added.")
    if isRobbingGlobally then
        print("[AutoRob V5.1] Character died during robbery. Sequence may need manual restart or will attempt next heist if applicable.")
        -- For simplicity, stopping current coroutine if it exists.
        if currentRobberyCoroutine then
            task.cancel(currentRobberyCoroutine)
            currentRobberyCoroutine = nil
            isRobbingGlobally = false
            print("[AutoRob V5.1] Active robbery coroutine cancelled due to character death.")
        end
    end
end)

local HEISTS_BASE_PATH_STRING = "Workspace.Heists"
local TARGET_HEISTS_TO_ROB_SEQUENCE = {"JewelryStore", "Bank", "Casino"}

local HEIST_SPECIFIC_CONFIG = {
    JewelryStore = {
        DisplayName = "ร้านเพชร", PathString = HEISTS_BASE_PATH_STRING .. ".JewelryStore", EntryTeleportCFrame = nil,
        RobberyActions = {{ Name = "เก็บเครื่องเพชร", ActionType = "IterateAndFireEvent", ItemContainerPath = "EssentialParts.JewelryBoxes", RemoteEventPath = "EssentialParts.JewelryBoxes.JewelryManager.Event", EventArgsFunc = function(lootInstance) return {lootInstance} end, FireCountPerItem = 2, TeleportOffsetPerItem = Vector3.new(0, 1.8, 1.8), DelayBetweenItems = 0.15, DelayBetweenFires = 0.1 }}
    },
    Bank = {
        DisplayName = "ธนาคาร", PathString = HEISTS_BASE_PATH_STRING .. ".Bank", EntryTeleportCFrame = CFrame.new(730, 108, 565),
        RobberyActions = {{ Name = "เปิดประตูห้องมั่นคง", ActionType = "Touch", TargetPath = "EssentialParts.VaultDoor.Touch", TeleportOffset = Vector3.new(0, 0, -2.2), RobDelayAfter = 1.5 }, { Name = "เก็บเงิน CashStack", ActionType = "IterateAndFindInteract", ItemContainerPath = "Interior.CashStack.Model", ItemNameHint = "Cash", InteractionHint = {Type="RemoteEvent", NameHint="CollectCash", Args=function(item) return {item, 1000} end}, TeleportOffset = Vector3.new(0,0.5,0), DelayBetweenItems = 0.2, FireCountPerItem = 1 }, { Name = "เก็บเงิน Model Cash", ActionType = "IterateAndFindInteract", ItemContainerPath = "Interior.Model", ItemNameHint = "Cash", InteractionHint = {Type="RemoteEvent", NameHint="CollectMoney", Args=function(item) return {item, 500} end}, TeleportOffset = Vector3.new(0,0.5,0), DelayBetweenItems = 0.2, FireCountPerItem = 1 }}
    },
    Casino = {
        DisplayName = "คาสิโน", PathString = HEISTS_BASE_PATH_STRING .. ".Casino", EntryTeleportCFrame = CFrame.new(1690, 30, 525),
        RobberyActions = {{ Name = "แฮ็กคอมพิวเตอร์", ActionType = "ProximityPrompt", TargetPath = "Interior.HackComputer.HackComputer", ProximityPromptActionHint = "Hack", HoldDuration = 2.0, TeleportOffset = Vector3.new(0,1,-1.8), RobDelayAfter = 1.0 }, { Name = "เก็บเงิน CashGiver", ActionType = "IterateAndFindInteract", ItemContainerPath = "EssentialParts.CasinoDoor", ItemNameHint = "CashGiver", InteractionHint = {Type="RemoteEvent", NameHint="GiveCash", Args=function(item) return {} end}, TeleportOffset = Vector3.new(0,0.5,0), DelayBetweenItems = 0.2, FireCountPerItem = 1 }, { Name = "เก็บเงินใน Interior", ActionType = "IterateAndFindInteract", ItemContainerPath = "Interior", ItemNameHint = "Cash", InteractionHint = {Type="RemoteEvent", NameHint="CollectCasinoCash", Args=function(item) return {item} end}, TeleportOffset = Vector3.new(0,0.5,0), DelayBetweenItems = 0.2, FireCountPerItem = 1 }}
    }
}

local function findInstance(pathStringOrInstance, childPath) local root=nil;if type(pathStringOrInstance)=="string"then local current=game;for component in pathStringOrInstance:gmatch("([^%.]+)")do if current then current=current:FindFirstChild(component)else return nil end end;root=current elseif typeof(pathStringOrInstance)=="Instance"then root=pathStringOrInstance end;if not root then return nil end;return childPath and root:FindFirstChild(childPath,true)or root end
local function teleportTo(targetCFrame)if not RootPart then print("[Teleport] RootPart is nil.");return false end;local s,e=pcall(function()RootPart.CFrame=targetCFrame end);if not s then print("[Teleport] Failed:",e);return false end;RunService.Stepped:Wait();return true end
local function findRemote(parentInst,nameHint,typeHint)typeHint=typeHint or"RemoteEvent";if not parentInst then return nil end;for _,D in ipairs(parentInst:GetDescendants())do if D:IsA(typeHint)and D.Name:lower():match(nameHint:lower())then return D end end;return nil end
local function findPrompt(parentInst,actionHint)if not parentInst then return nil end;for _,D in ipairs(parentInst:GetDescendants())do if D:IsA("ProximityPrompt")then if D.ActionText and D.ActionText:lower():match(actionHint:lower())then return D elseif D.ObjectText and D.ObjectText:lower():match(actionHint:lower())then return D end end end;return nil end

local function attemptSingleRobberyAction(actionConfig, heistFolder)
    if not(Character and Humanoid and Humanoid.Health > 0) then print("[Robbery] Character dead or missing."); return false end
    print(string.format("  [Action] %s", actionConfig.Name))
    local targetInstance; if actionConfig.TargetPath then targetInstance = findInstance(heistFolder, actionConfig.TargetPath); if not targetInstance then print("    [Error] TargetPath not found: " .. actionConfig.TargetPath); return false end end
    local robSuccessful = false
    if not teleportTo((targetInstance and (targetInstance:IsA("Model") and targetInstance:GetPivot() or targetInstance.CFrame) or heistFolder:GetPivot()) * CFrame.new(actionConfig.TeleportOffset or Vector3.new())) then return false end
    if actionConfig.ActionType == "Touch" and targetInstance then if typeof(firetouchinterest) == "function" and targetInstance:IsA("BasePart") then print("    Firing touch interest for:", targetInstance.Name); pcall(firetouchinterest, targetInstance, RootPart, 0); task.wait(0.05); pcall(firetouchinterest, targetInstance, RootPart, 1); robSuccessful = true else print("    firetouchinterest not available or target not BasePart.") end
    elseif actionConfig.ActionType == "ProximityPrompt" and targetInstance then local prompt = findPrompt(targetInstance, actionConfig.ProximityPromptActionHint or targetInstance.Name); if prompt then if typeof(fireproximityprompt) == "function" then print(string.format("    Firing PP: %s (Hold: %.1fs)", prompt.ActionText or prompt.ObjectText or "Unknown", actionConfig.HoldDuration or 0)); pcall(fireproximityprompt, prompt, actionConfig.HoldDuration or 0); robSuccessful = true else print("    fireproximityprompt not available.") end else print("    ProximityPrompt not found for:", targetInstance.Name, "Hint:", actionConfig.ProximityPromptActionHint) end
    elseif (actionConfig.ActionType == "RemoteEvent" or actionConfig.ActionType == "IterateAndFireEvent") then local itemsToProcess = {}; local remoteEventInstance; local searchBaseForItems = actionConfig.ItemContainerPath and findInstance(heistFolder, actionConfig.ItemContainerPath) or heistFolder; if not searchBaseForItems then print("    [Error] ItemContainerPath not found: " .. (actionConfig.ItemContainerPath or "N/A")); return false end; if actionConfig.ActionType == "IterateAndFireEvent" then if actionConfig.ItemQuery then itemsToProcess = actionConfig.ItemQuery(searchBaseForItems) else for _,child in ipairs(searchBaseForItems:GetChildren()) do if (child:IsA("Model") or child:IsA("BasePart")) and (not actionConfig.ItemNameHint or child.Name:lower():match(actionConfig.ItemNameHint:lower())) then table.insert(itemsToProcess, child) end end end else if targetInstance then table.insert(itemsToProcess, targetInstance) else print("    [Error] TargetPath needed for SingleEvent."); return false end end; if #itemsToProcess == 0 then print("    No items found for: " .. actionConfig.Name); return true end; if actionConfig.RemoteEventPath then remoteEventInstance = findInstance(Workspace, actionConfig.RemoteEventPath) or findInstance(searchBaseForItems, actionConfig.RemoteEventPath) elseif actionConfig.RemoteEventNameHint then remoteEventInstance = findRemote(itemsToProcess[1], actionConfig.RemoteEventNameHint) or findRemote(itemsToProcess[1].Parent, actionConfig.RemoteEventNameHint) or findRemote(heistFolder, actionConfig.RemoteEventNameHint) end; if not remoteEventInstance or not remoteEventInstance:IsA("RemoteEvent") then print("    [Error] RemoteEvent not found for action:", actionConfig.Name, "(Path/Hint:", actionConfig.RemoteEventPath or actionConfig.RemoteEventNameHint or "N/A", ")"); return false end; for i, itemInst in ipairs(itemsToProcess) do if not (Character and Humanoid.Health > 0 and currentRobberyCoroutine) then print("    Robbery sequence interrupted."); return false end; if not teleportTo((itemInst:IsA("Model") and itemInst:GetPivot() or itemInst.CFrame) * CFrame.new(actionConfig.TeleportOffsetPerItem or actionConfig.TeleportOffset or Vector3.new())) then return false end; local argsToFire = {}; if actionConfig.EventArgsFunc then argsToFire = actionConfig.EventArgsFunc(itemInst) or {} end; print(string.format("    Firing RE: %s for %s (Item %d/%d)", remoteEventInstance.Name, itemInst.Name, i, #itemsToProcess)); for fc = 1, actionConfig.FireCountPerItem or 1 do if not (Character and Humanoid.Health > 0 and currentRobberyCoroutine) then print("    Robbery interrupted during fire loop."); return false end; local s,e = pcall(function() remoteEventInstance:FireServer(unpack(argsToFire)) end); if not s then print("      Error firing event: "..tostring(e)) end; task.wait(actionConfig.DelayBetweenFires or 0.05) end; robSuccessful = true; if #itemsToProcess > 1 and i < #itemsToProcess then task.wait(actionConfig.DelayBetweenItems or 0.1) end end
    end; if robSuccessful then print(string.format("    Action '%s' completed.", actionConfig.Name)) else print(string.format("    Action '%s' failed or no interaction method.", actionConfig.Name)) end; if actionConfig.RobDelayAfter then task.wait(actionConfig.RobDelayAfter) end; return robSuccessful end
function executeFullHeistRobbery(heistName) local config = HEIST_SPECIFIC_CONFIG[heistName]; if not config then print("[Heist] No config for: " .. heistName); return false end; local heistFolder = findInstance(config.PathString); if not heistFolder then print("[Heist] Heist folder not found: " .. config.PathString); return false end; print(string.format("--- Starting Heist: %s ---", config.DisplayName)); if config.EntryTeleportCFrame and RootPart then if not teleportTo(config.EntryTeleportCFrame) then return false end; task.wait(0.3) end; for i, actionConfig in ipairs(config.RobberyActions or {}) do if not currentRobberyCoroutine then print("[Heist] Robbery sequence cancelled by user."); return false end; if not (Character and Humanoid and Humanoid.Health > 0) then print("[Heist] Character died, stopping heist: " .. config.DisplayName); return false end; if not attemptSingleRobberyAction(actionConfig, heistFolder) then print(string.format("[Heist] Action '%s' in %s failed. Stopping this heist.", actionConfig.Name, config.DisplayName)); return false end; task.wait(0.2) end; print(string.format("--- Heist: %s - Sequence Completed ---", config.DisplayName)); return true end
local function ServerHop()print("[ServerHop] Attempting...");local s,e=pcall(function()local S={};local R=HttpService:RequestAsync({Url="https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?sortOrder=Desc&limit=100&excludeFullGames=true",Method="GET"});if not R or not R.Success or not R.Body then print("[ServerHop] Fail get list:",R and R.Body or "No resp");return end;local B=HttpService:JSONDecode(R.Body);if B and B.data then for _,v in next,B.data do if type(v)=="table"and tonumber(v.playing)and tonumber(v.maxPlayers)and v.playing<v.maxPlayers and v.id~=game.JobId then table.insert(S,1,v.id)end end end;print("[ServerHop] Found",#S,"servers.");if #S>0 then TeleportService:TeleportToPlaceInstance(game.PlaceId,S[math.random(1,#S)],Player)else print("[ServerHop] No other servers.");if #Player:GetPlayers()<=1 then Player:Kick("Rejoining...");task.wait(1);TeleportService:Teleport(game.PlaceId,Player)else TeleportService:TeleportToPlaceInstance(game.PlaceId,game.JobId,Player)end end end);if not s then print("[ServerHop] PcallFail:",e);TeleportService:TeleportToPlaceInstance(game.PlaceId,game.JobId,Player)end end
function executeAllRobberiesAndHop()if isRobbingGlobally then print("[AutoRob] Sequence already running.");return end;isRobbingGlobally=true;currentRobberyCoroutine=coroutine.running();print("--- Starting Full Auto-Robbery Sequence (V5.1) ---");local oST=tick();for i,hN in ipairs(ROB_ORDER)do if not currentRobberyCoroutine then print("[AutoRob] Full sequence cancelled.");break end;if not(Character and Humanoid and Humanoid.Health>0)then print("[AutoRob] Character died, stopping sequence.");break end;print(string.format("[AutoRob] Preparing: %s (%d/%d)",HEIST_SPECIFIC_CONFIG[hN]and HEIST_SPECIFIC_CONFIG[hN].DisplayName or hN,i,#ROB_ORDER));if not executeFullHeistRobbery(hN)then print(string.format("[AutoRob] Heist %s failed/interrupted.",HEIST_SPECIFIC_CONFIG[hN]and HEIST_SPECIFIC_CONFIG[hN].DisplayName or hN))end;if i<#ROB_ORDER and currentRobberyCoroutine then local wT=math.random(2,5);print(string.format("[AutoRob] Waiting %.1fs...",wT));local wD=0;while wD<wT and currentRobberyCoroutine do task.wait(0.1);wD=wD+0.1 end end end;if currentRobberyCoroutine then print(string.format("--- Sequence Completed in %.2fs. Server Hopping. ---",tick()-oST));ServerHop()end;isRobbingGlobally=false;currentRobberyCoroutine=nil end
local function createControlUI()
    if CoreGui:FindFirstChild("RyntazAutoRobV5_Control") then CoreGui:FindFirstChild("RyntazAutoRobV5_Control"):Destroy() end
    
    local playerGui = Player:WaitForChild("PlayerGui") -- รอ PlayerGui ให้พร้อม
    if not playerGui then print("[UI Error] PlayerGui not found!"); return end

    local screenGui = Instance.new("ScreenGui", playerGui)
    screenGui.Name = "RyntazAutoRobV5_Control"
    screenGui.ResetOnSpawn = false; screenGui.DisplayOrder = 1000; screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    local main = Instance.new("Frame", screenGui)
    main.Size = UDim2.new(0, 220, 0, 80); main.Position = UDim2.new(0.01, 0, 0.5, -40)
    main.BackgroundColor3 = Color3.fromRGB(25,25,30); main.BorderColor3 = Color3.fromRGB(0,200,100); main.BorderSizePixel = 1
    local c=Instance.new("UICorner",main);c.CornerRadius=UDim.new(0,5);local l=Instance.new("UIListLayout",main);l.Padding=UDim.new(0,5);l.HorizontalAlignment=Enum.HorizontalAlignment.Center;l.VerticalAlignment=Enum.VerticalAlignment.Center;l.SortOrder=Enum.SortOrder.LayoutOrder

    local title = Instance.new("TextLabel",main);title.Name="Title";title.LayoutOrder=1;title.Size=UDim2.new(1,-10,0,20);title.Text="Ryntaz AutoRob V5.1";title.TextColor3=Color3.fromRGB(0,255,120);title.Font=Enum.Font.Michroma;title.TextSize=12;title.BackgroundTransparency=1
    local startButton = createStyledButton(main,"เริ่มปล้นทั้งหมด",UDim2.new(0.9,0,0,25),UDim2.new(),Color3.fromRGB(0,150,80),Color3.new(1,1,1),12);startButton.LayoutOrder=2
    startButton.MouseButton1Click:Connect(function()if not isRobbingGlobally then task.spawn(executeAllRobberiesAndHop)else print("[ARob] In progress.")end end)
    local stopButton = createStyledButton(main,"หยุดปล้น",UDim2.new(0.9,0,0,25),UDim2.new(),Color3.fromRGB(180,50,50),Color3.new(1,1,1),12);stopButton.LayoutOrder=3
    stopButton.MouseButton1Click:Connect(function()if currentRobberyCoroutine then isRobbingGlobally=false;task.cancel(currentRobberyCoroutine);currentRobberyCoroutine=nil;print("[ARob] Stopped by user.")else print("[ARob] Nothing to stop.")end end)
end

if waitForCharacter() then
    pcall(createControlUI) -- ใส่ pcall เพื่อป้องกัน Error หยุดทั้งสคริปต์
    local autoStartRobbery = true 
    if autoStartRobbery then
        print("[AutoRob V5.1] Auto-start. Waiting 3s...")
        task.wait(3)
        if not isRobbingGlobally then task.spawn(executeAllRobberiesAndHop) end
    else
        print("[AutoRob V5.1] Auto-start disabled. Click button or call executeAllRobberiesAndHop()")
    end
else
    print("[AutoRob V5.1] Script terminated: Character not loaded.")
end
