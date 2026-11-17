-- MY CHIIKAWA RESTAURANT - AUTO FISHING HUB V7 (OPTIMIZED)
-- F1 = show/hide hub; X = hide hub; END = stop fishing
-- Config includes independent Anti-AFK toggle and test button.
-- Hub stays loaded when hidden.

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local VIM = game:GetService("VirtualInputManager")
local VirtualUser = game:GetService("VirtualUser")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Stop previous copy when re-executed
local old = playerGui:FindFirstChild("AutoFishing")
if old then old:Destroy() end

local enabled = false
local antiAfkEnabled = false
local afkActions = 0
local pendingAfk = false
local afkSending = false
local tapDelay = 0.08
local shoreDistance = 7
local pond = nil
local phase = "READY"
local lastCastAttempt = 0
local lastHookAttempt = 0
local hookAttempts = 0
local lastTap = 0
local lastMinigame = 0
local lastCastPoint = nil
local textAddedConnection, textRemovingConnection

-- Hub layout
local gui = Instance.new("ScreenGui")
gui.Name = "AutoFishing"
gui.ResetOnSpawn = false
gui.DisplayOrder = 100
gui.Parent = playerGui

local function rounded(obj, pixels)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, pixels)
    corner.Parent = obj
end

local function makeText(kind, parent, text, pos, size)
    local item = Instance.new(kind)
    item.Position = pos
    item.Size = size
    item.Text = text
    item.Font = Enum.Font.GothamBold
    item.TextSize = 14
    item.TextColor3 = Color3.fromRGB(245, 245, 250)
    item.BackgroundTransparency = 1
    item.Parent = parent
    return item
end

local window = Instance.new("Frame")
window.Name = "HubWindow"
window.Size = UDim2.fromOffset(440, 290)
window.Position = UDim2.new(0, 28, 0.5, -145)
window.BackgroundColor3 = Color3.fromRGB(25, 27, 36)
window.Active = true
window.Draggable = true
window.Parent = gui
rounded(window, 12)

local border = Instance.new("UIStroke")
border.Color = Color3.fromRGB(73, 80, 104)
border.Thickness = 1
border.Parent = window

local heading = makeText("TextLabel", window, "CHIIKAWA HUB", UDim2.fromOffset(17, 9), UDim2.fromOffset(260, 30))
heading.TextXAlignment = Enum.TextXAlignment.Left
heading.TextSize = 17

local close = makeText("TextButton", window, "X", UDim2.new(1, -42, 0, 8), UDim2.fromOffset(30, 28))
close.BackgroundTransparency = 0
close.BackgroundColor3 = Color3.fromRGB(165, 50, 65)
rounded(close, 7)

local line = Instance.new("Frame")
line.Position = UDim2.fromOffset(0, 43)
line.Size = UDim2.new(1, 0, 0, 1)
line.BackgroundColor3 = Color3.fromRGB(68, 72, 91)
line.BorderSizePixel = 0
line.Parent = window

local sidebar = Instance.new("Frame")
sidebar.Position = UDim2.fromOffset(10, 53)
sidebar.Size = UDim2.fromOffset(120, 225)
sidebar.BackgroundTransparency = 1
sidebar.Parent = window

local function sideButton(text, y)
    local b = makeText("TextButton", sidebar, text, UDim2.fromOffset(0, y), UDim2.fromOffset(117, 39))
    b.BackgroundTransparency = 0
    b.BackgroundColor3 = Color3.fromRGB(47, 50, 65)
    rounded(b, 8)
    return b
end

local fishingTab = sideButton("Auto Fishing", 0)
local settingsTab = sideButton("Config", 47)
local hint = makeText("TextLabel", sidebar, "F1: Hide / Show\nEND: Stop Fishing", UDim2.fromOffset(4, 157), UDim2.fromOffset(115, 50))
hint.Font = Enum.Font.Gotham
hint.TextSize = 11
hint.TextColor3 = Color3.fromRGB(170, 178, 202)
hint.TextWrapped = true

local function panel()
    local f = Instance.new("Frame")
    f.Position = UDim2.fromOffset(141, 53)
    f.Size = UDim2.fromOffset(286, 225)
    f.BackgroundColor3 = Color3.fromRGB(35, 38, 51)
    f.Parent = window
    rounded(f, 9)
    return f
end

local fishPanel = panel()
local configPanel = panel()
configPanel.Visible = false

local fishTitle = makeText("TextLabel", fishPanel, "AUTO FISHING", UDim2.fromOffset(13, 10), UDim2.fromOffset(255, 27))
fishTitle.TextXAlignment = Enum.TextXAlignment.Left
fishTitle.TextSize = 16

local toggle = makeText("TextButton", fishPanel, "AUTO FISH: OFF", UDim2.fromOffset(14, 47), UDim2.fromOffset(257, 44))
toggle.BackgroundTransparency = 0
toggle.BackgroundColor3 = Color3.fromRGB(170, 45, 45)
rounded(toggle, 9)

local status = makeText("TextLabel", fishPanel, "Status: Stopped", UDim2.fromOffset(14, 105), UDim2.fromOffset(257, 70))
status.Font = Enum.Font.Gotham
status.TextSize = 13
status.TextWrapped = true
status.TextColor3 = Color3.fromRGB(190, 219, 255)

local fishNote = makeText("TextLabel", fishPanel, "Find pond  >  Cast  >  Hook  >  14 taps", UDim2.fromOffset(13, 185), UDim2.fromOffset(260, 22))
fishNote.Font = Enum.Font.Gotham
fishNote.TextSize = 11
fishNote.TextColor3 = Color3.fromRGB(180, 185, 200)

local configTitle = makeText("TextLabel", configPanel, "CONFIG", UDim2.fromOffset(13, 10), UDim2.fromOffset(255, 28))
configTitle.TextXAlignment = Enum.TextXAlignment.Left
configTitle.TextSize = 16

local speedLabel = makeText("TextLabel", configPanel, "Minigame tap delay (seconds):", UDim2.fromOffset(14, 48), UDim2.fromOffset(260, 25))
speedLabel.TextXAlignment = Enum.TextXAlignment.Left
speedLabel.Font = Enum.Font.Gotham
speedLabel.TextSize = 12

local speed = makeText("TextBox", configPanel, "0.08", UDim2.fromOffset(14, 74), UDim2.fromOffset(257, 30))
speed.BackgroundTransparency = 0
speed.BackgroundColor3 = Color3.fromRGB(58, 62, 79)
speed.ClearTextOnFocus = false
rounded(speed, 8)

-- Independent Anti-AFK controls on Config tab
local antiAfkToggle = makeText("TextButton", configPanel, "ANTI-AFK: OFF", UDim2.fromOffset(14, 110), UDim2.fromOffset(257, 37))
antiAfkToggle.BackgroundTransparency = 0
antiAfkToggle.BackgroundColor3 = Color3.fromRGB(170, 45, 45)
rounded(antiAfkToggle, 8)

local afkTestButton = makeText("TextButton", configPanel, "TEST ANTI-AFK", UDim2.fromOffset(14, 153), UDim2.fromOffset(257, 29))
afkTestButton.BackgroundTransparency = 0
afkTestButton.BackgroundColor3 = Color3.fromRGB(67, 90, 122)
afkTestButton.TextSize = 12
rounded(afkTestButton, 7)

local afkStatus = makeText("TextLabel", configPanel, "AFK: Off", UDim2.fromOffset(14, 189), UDim2.fromOffset(257, 27))
afkStatus.Font = Enum.Font.Gotham
afkStatus.TextSize = 11
afkStatus.TextWrapped = true
afkStatus.TextColor3 = Color3.fromRGB(183, 191, 211)

local function selectTab(which)
    fishPanel.Visible = which == "Fishing"
    configPanel.Visible = which == "Config"
    fishingTab.BackgroundColor3 = fishPanel.Visible and Color3.fromRGB(65, 106, 135) or Color3.fromRGB(47, 50, 65)
    settingsTab.BackgroundColor3 = configPanel.Visible and Color3.fromRGB(65, 106, 135) or Color3.fromRGB(47, 50, 65)
end
fishingTab.MouseButton1Click:Connect(function() selectTab("Fishing") end)
settingsTab.MouseButton1Click:Connect(function() selectTab("Config") end)
selectTab("Fishing")

local function setStatus(message)
    local newText = "Status: " .. message
    if status.Text ~= newText then
        status.Text = newText
    end
end

local function updateToggle()
    toggle.Text = enabled and "AUTO FISH: ON" or "AUTO FISH: OFF"
    toggle.BackgroundColor3 = enabled and Color3.fromRGB(35, 155, 75) or Color3.fromRGB(170, 45, 45)
end

local function setEnabled(value)
    enabled = value
    if enabled then
        pond = nil
        phase = "READY"
        lastCastAttempt = 0
        lastHookAttempt = 0
        hookAttempts = 0
        lastMinigame = 0
        setStatus("Finding nearest pond...")
    else
        setStatus("Stopped")
        local char = player.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            local root = char:FindFirstChild("HumanoidRootPart")
            if hum and root then hum:MoveTo(root.Position) end
        end
    end
    updateToggle()
end

toggle.MouseButton1Click:Connect(function() setEnabled(not enabled) end)
close.MouseButton1Click:Connect(function() gui.Enabled = false end)
speed.FocusLost:Connect(function()
    tapDelay = math.clamp(tonumber(speed.Text) or 0.08, 0.04, 0.5)
    speed.Text = tostring(tapDelay)
end)

-- Anti-AFK: sends an input only after Roblox reports the player idle.
-- This does not claim to prove that the server idle timer was reset.
local function updateAntiAfkToggle()
    antiAfkToggle.Text = antiAfkEnabled and "ANTI-AFK: ON" or "ANTI-AFK: OFF"
    antiAfkToggle.BackgroundColor3 = antiAfkEnabled
        and Color3.fromRGB(35, 155, 75)
        or Color3.fromRGB(170, 45, 45)
    if not antiAfkEnabled then
        afkStatus.Text = "AFK: Off"
    elseif afkActions == 0 then
        afkStatus.Text = "AFK: On - awaiting idle (~2 min)"
    else
        afkStatus.Text = "AFK: On - " .. afkActions .. " input(s) sent"
    end
end

local function antiAfkAction()
    if not gui.Parent or not antiAfkEnabled then return false end
    -- Never inject an AFK input during casting, hooking, or the minigame.
    -- When fishing, wait for the explicit WAITING state.
    if enabled and phase ~= "WAITING" then
        pendingAfk = true
        afkStatus.Text = "AFK: queued until safe fishing phase"
        return false
    end
    if afkSending then return false end
    afkSending = true
    pendingAfk = false
    local camera = Workspace.CurrentCamera
    local camCFrame = camera and camera.CFrame or CFrame.new()
    local ok, err = pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new(0, 0), camCFrame)
    end)
    local method = "VirtualUser"

    -- Fallback only if VirtualUser is blocked by the executor.
    if not ok then
        method = "Key fallback"
        ok, err = pcall(function()
            VIM:SendKeyEvent(true, Enum.KeyCode.F15, false, game)
            task.wait(0.06)
            VIM:SendKeyEvent(false, Enum.KeyCode.F15, false, game)
        end)
    end

    if ok then
        afkActions = afkActions + 1
        afkStatus.Text = "AFK: input sent #" .. afkActions .. " (" .. method .. ")"
    else
        afkStatus.Text = "AFK: input blocked - check executor"
        warn("Chiikawa Hub Anti-AFK input failed: " .. tostring(err))
    end
    afkSending = false
    return ok
end

antiAfkToggle.MouseButton1Click:Connect(function()
    antiAfkEnabled = not antiAfkEnabled
    if not antiAfkEnabled then pendingAfk = false end
    updateAntiAfkToggle()
end)

afkTestButton.MouseButton1Click:Connect(function()
    -- Manual test checks whether the input API is available.
    -- Does not prove that Roblox will keep the connection alive.
    afkStatus.Text = "AFK: testing input..."
    if not antiAfkEnabled then
        afkStatus.Text = "AFK: turn Anti-AFK ON to test"
    else
        antiAfkAction()
    end
end)

local idleConnection = player.Idled:Connect(function()
    if antiAfkEnabled and gui.Parent then
        antiAfkAction()
    end
end)

local inputConnection
inputConnection = UIS.InputBegan:Connect(function(input)
    if not gui.Parent then return end
    if input.KeyCode == Enum.KeyCode.F1 then
        gui.Enabled = not gui.Enabled
    elseif input.KeyCode == Enum.KeyCode.End then
        setEnabled(false)
    end
end)
gui.Destroying:Connect(function()
    enabled = false
    antiAfkEnabled = false
    if inputConnection then inputConnection:Disconnect() end
    if idleConnection then idleConnection:Disconnect() end
    if textAddedConnection then textAddedConnection:Disconnect() end
    if textRemovingConnection then textRemovingConnection:Disconnect() end
end)

-- Character and detection
local function characterParts()
    local char = player.Character
    if not char then return nil, nil end
    return char:FindFirstChildOfClass("Humanoid"), char:FindFirstChild("HumanoidRootPart")
end

local function visible(obj)
    local node = obj
    while node and node ~= playerGui do
        if node:IsA("GuiObject") and not node.Visible then return false end
        if node:IsA("ScreenGui") and not node.Enabled then return false end
        node = node.Parent
    end
    return true
end

-- Cache fishing-related text objects instead of rescanning all PlayerGui descendants
-- five times per fishing tick. New UI labels are tracked as they are created.
local textCandidates = {}

local function trackText(obj)
    if (obj:IsA("TextLabel") or obj:IsA("TextButton"))
        and not obj:IsDescendantOf(gui) then
        textCandidates[obj] = true
    end
end

for _, obj in ipairs(playerGui:GetDescendants()) do
    trackText(obj)
end

textAddedConnection = playerGui.DescendantAdded:Connect(trackText)
textRemovingConnection = playerGui.DescendantRemoving:Connect(function(obj)
    textCandidates[obj] = nil
end)

local function readFishingUI()
    local result = {}

    for obj in pairs(textCandidates) do
        if obj.Parent and visible(obj) and obj.AbsoluteSize.X > 2 then
            local content = obj.Text:lower()

            if not result.mini
                and (content:find("tap fast", 1, true)
                    or content:find("/14", 1, true)) then
                result.mini = obj
                result.miniText = content
            end

            if not result.bite
                and (content:find("a bite!", 1, true)
                    or content:find("a fish! tap", 1, true)
                    or content:find("fish! tap", 1, true)) then
                result.bite = obj
            end

            if not result.waiting
                and (content:find("wait for a bite", 1, true)
                    or content:find("nibble", 1, true)
                    or content:find("not yet", 1, true)) then
                result.waiting = obj
            end

            if not result.ready
                and (content:find("tap the water to fish", 1, true)
                    or content:find("tap water to fish", 1, true)) then
                result.ready = obj
            end

            if not result.gone
                and (content:find("it got away", 1, true)
                    or content:find("got away", 1, true)) then
                result.gone = obj
            end
        end
    end

    return result
end

local function mouseClick(x, y)
    if not x or not y then return false end
    return pcall(function()
        VIM:SendMouseButtonEvent(x, y, 0, true, game, 0)
        task.wait(0.025)
        VIM:SendMouseButtonEvent(x, y, 0, false, game, 0)
    end)
end

local function clickCenter(obj)
    if not obj then return false end
    local p, s = obj.AbsolutePosition, obj.AbsoluteSize
    return mouseClick(p.X + s.X / 2, p.Y + s.Y / 2)
end

-- Pond search (Terrain water and water-named Parts)
local function partPond(pos)
    local best, dist = nil, math.huge
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") then
            local n = obj.Name:lower()
            local water = n:find("water", 1, true) or n:find("pond", 1, true) or n:find("lake", 1, true)
            if water and not (player.Character and obj:IsDescendantOf(player.Character)) then
                local d = (obj.Position - pos).Magnitude
                if d < dist then
                    dist = d
                    best = { position = obj.Position, size = obj.Size }
                end
            end
        end
    end
    return best, dist
end

local function terrainPond(pos)
    local terrain = Workspace.Terrain
    local best, dist = nil, math.huge
    local sampleCount = 0
    for x = -200, 200, 24 do
        for z = -200, 200, 24 do
            if not enabled or not gui.Parent then return nil, math.huge end
            sampleCount = sampleCount + 1
            if sampleCount % 24 == 0 then task.wait() end
            local sample = pos + Vector3.new(x, 0, z)
            local region = Region3.new(sample - Vector3.new(2, 24, 2), sample + Vector3.new(2, 12, 2)):ExpandToGrid(4)
            local ok, materials, occupancy = pcall(function()
                return terrain:ReadVoxels(region, 4)
            end)
            if ok and materials then
                local found = false
                for i = 1, #materials do
                    for j = 1, #materials[i] do
                        for k = 1, #materials[i][j] do
                            if materials[i][j][k] == Enum.Material.Water and occupancy[i][j][k] > 0 then
                                found = true
                                break
                            end
                        end
                        if found then break end
                    end
                    if found then break end
                end
                if found then
                    local d = (sample - pos).Magnitude
                    if d < dist then
                        dist = d
                        best = { position = sample }
                    end
                end
            end
        end
    end
    return best, dist
end

local function nearestPond(pos)
    local a = partPond(pos)
    -- Most ponds are named Parts; skip costly terrain sampling when found.
    if a then return a end
    return terrainPond(pos)
end

-- Walking
local function walkToWater(targetPond)
    local hum, root = characterParts()
    if not hum or not root then return false end
    local delta = targetPond.position - root.Position
    local flat = Vector3.new(delta.X, 0, delta.Z)
    if flat.Magnitude <= shoreDistance + 2 then return true end
    local destination = targetPond.position - flat.Unit * shoreDistance
    destination = Vector3.new(destination.X, root.Position.Y, destination.Z)
    hum:MoveTo(destination)
    local started = os.clock()
    while enabled and gui.Parent and os.clock() - started < 12 do
        task.wait(0.2)
        local _, currentRoot = characterParts()
        if not currentRoot then return false end
        if (currentRoot.Position - destination).Magnitude < 4 then
            hum:MoveTo(currentRoot.Position)
            return true
        end
    end
    return false
end

local function clickWater(targetPond)
    local camera = Workspace.CurrentCamera
    if not camera then return false end
    local screen, onScreen = camera:WorldToViewportPoint(targetPond.position)
    if not onScreen then return false end
    lastCastPoint = Vector2.new(screen.X, screen.Y)
    return mouseClick(screen.X, screen.Y)
end

-- Fishing: hook ONLY on real bite, ignore nibbles,
-- finish 14 taps, recast ONLY when prompt says ready.
local function fishStep(targetPond)
    local now = os.clock()
    local ui = readFishingUI()
    local mini, miniText = ui.mini, ui.miniText
    local bite, waiting, ready, gone =
        ui.bite, ui.waiting, ui.ready, ui.gone

    if mini then
        phase = "MINIGAME"
        lastMinigame = now
        hookAttempts = 0
        local count = tonumber((miniText or ""):match("(%d+)%s*/%s*14"))
        if count and count >= 14 then
            setStatus("14/14 complete - finishing...")
            return
        end
        if now - lastTap >= tapDelay then
            setStatus("Tap fast! " .. (count and tostring(count) .. "/14" or ""))
            clickCenter(mini)
            lastTap = os.clock()
        end
        return
    end

    if bite then
        phase = "BITE"
        if now - lastHookAttempt >= 0.32 and hookAttempts < 4 then
            hookAttempts = hookAttempts + 1
            setStatus("Bite! Hook attempt " .. hookAttempts)
            if hookAttempts % 2 == 1 then
                clickCenter(bite)
            elseif lastCastPoint then
                mouseClick(lastCastPoint.X, lastCastPoint.Y)
            else
                clickCenter(bite)
            end
            lastHookAttempt = os.clock()
        end
        return
    end

    if waiting then
        phase = "WAITING"
        hookAttempts = 0
        setStatus("Waiting for a real bite...")
        -- Process any deferred AFK input only during the quiet waiting phase.
        if pendingAfk and antiAfkEnabled then
            task.spawn(antiAfkAction)
        end
        return
    end

    if ready then
        phase = "READY"
        hookAttempts = 0
        if now - lastMinigame < 0.9 then
            setStatus("Finishing catch...")
            return
        end
        if now - lastCastAttempt >= 1.2 then
            setStatus(gone and "Fish escaped - recasting" or "Casting rod...")
            lastCastAttempt = now
            if clickWater(targetPond) then
                phase = "CASTING"
            else
                setStatus("Water off screen - adjust camera")
            end
        else
            setStatus("Waiting for cast to register...")
        end
        return
    end

    if phase == "MINIGAME" then phase = "FINISHING" end
    if phase == "FINISHING" then
        setStatus("Waiting for next cast prompt...")
    elseif phase == "BITE" then
        setStatus("Checking hook result...")
    elseif phase == "CASTING" then
        setStatus("Checking cast result...")
    else
        setStatus("Waiting for fishing prompt...")
    end
end

-- Main loop continues even when the hub is hidden.
task.spawn(function()
    while gui.Parent do
        -- Less work while waiting; quick checks during the timed minigame.
        task.wait(phase == "MINIGAME" and 0.06
            or phase == "WAITING" and 0.15
            or enabled and 0.10
            or 0.30)
        if antiAfkEnabled and pendingAfk and not enabled then
            task.spawn(antiAfkAction)
        end
        if enabled then
            local hum, root = characterParts()
            if not hum or not root then
                setStatus("Waiting for character...")
                task.wait(1)
            else
                if not pond then
                    setStatus("Finding nearest pond...")
                    pond = nearestPond(root.Position)
                    if not pond then
                        setStatus("No pond detected")
                        task.wait(2)
                    end
                end
                if pond and enabled then
                    local delta = pond.position - root.Position
                    local flat = Vector3.new(delta.X, 0, delta.Z).Magnitude
                    if flat > shoreDistance + 5 then
                        setStatus("Walking to pond...")
                        if not walkToWater(pond) then
                            pond = nil
                            setStatus("Retrying pond search...")
                        end
                    else
                        fishStep(pond)
                    end
                end
            end
        end
    end
end)

print("Chiikawa Auto Fishing HUB V7 optimized. F1 toggles hub; Config has Anti-AFK.")