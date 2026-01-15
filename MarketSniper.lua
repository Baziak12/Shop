MarketSniper = {}
MarketSniper.LoopID = nil
MarketSniper.IsRunning = false

MarketSniper.Config = {
    ExchangeRate = 200,
    Items = {},

    PriorityPositions = {
        { x = 2233, y = 2475, z = 7 },
        { x = 2236, y = 2478, z = 7 },
        { x = 2242, y = 2478, z = 7 },
        { x = 2239, y = 2481, z = 7 },
        { x = 2233, y = 2481, z = 7 },
        { x = 2236, y = 2484, z = 7 },
        { x = 2242, y = 2484, z = 7 },
        { x = 2233, y = 2487, z = 7 },
        { x = 2236, y = 2490, z = 7 },
        { x = 2242, y = 2490, z = 7 },
        { x = 2239, y = 2493, z = 7 },
        { x = 2233, y = 2493, z = 7 },
        { x = 2236, y = 2496, z = 7 },
        { x = 2242, y = 2496, z = 7 },
        { x = 2233, y = 2499, z = 7 },
        { x = 2236, y = 2502, z = 7 },
        { x = 2242, y = 2502, z = 7 },
        { x = 2233, y = 2505, z = 7 },
        { x = 2239, y = 2505, z = 7 },
        { x = 2227, y = 2505, z = 7 },
        { x = 2221, y = 2505, z = 7 },
        { x = 2224, y = 2502, z = 7 },
        { x = 2218, y = 2502, z = 7 },
        { x = 2227, y = 2499, z = 7 },
        { x = 2224, y = 2496, z = 7 },
        { x = 2218, y = 2496, z = 7 },
        { x = 2221, y = 2493, z = 7 },
        { x = 2227, y = 2493, z = 7 },
        { x = 2224, y = 2490, z = 7 },
        { x = 2218, y = 2490, z = 7 },
        { x = 2227, y = 2487, z = 7 },
        { x = 2224, y = 2484, z = 7 },
        { x = 2218, y = 2484, z = 7 },
        { x = 2221, y = 2481, z = 7 },
        { x = 2227, y = 2481, z = 7 },
        { x = 2224, y = 2478, z = 7 },
        { x = 2218, y = 2478, z = 7 },
        { x = 2227, y = 2475, z = 7 }
    },

    ScanInterval = 200,
    ActionDelay = 500,
    SearchRadius = 30,
    BlacklistTime = 120000,
    SafeMode = true,
    TestBuyMode = false
}

MarketSniper.State = {
    BlacklistedPlayers = {},
    CurrentTargetName = nil,
    Opening = false,
    LastMoveTime = 0,
    CurrentPriorityIndex = 1,
    IsPaused = false
}

function MarketSniper.log(msg, type)
    local prefix = "[MarketSniper] "
    if type == "SUCCESS" or type == "WARN" then
        if pwarning then pwarning(prefix .. msg) else print(prefix .. "!!! " .. msg .. " !!!") end
    elseif type == "ERROR" then
        if perror then perror(prefix .. msg) else print(prefix .. "ERR: " .. msg) end
    else
        print(prefix .. msg)
    end
end

function MarketSniper.saveConfig()
    if not storage.MarketSniper then storage.MarketSniper = {} end
    storage.MarketSniper.Items = MarketSniper.Config.Items
end

function MarketSniper.loadConfig()
    if not storage.MarketSniper or not storage.MarketSniper.Items then
        storage.MarketSniper = { Items = {} }
        MarketSniper.log("No saved items found. Add items via config UI.", "INFO")
    end
    MarketSniper.Config.Items = storage.MarketSniper.Items
end
MarketSniper.UI = {
    Window = nil,
    ItemList = nil,
    NameInput = nil,
    GIInput = nil,
    SPInput = nil
}

function MarketSniper.refreshItemList()
    if not MarketSniper.UI.ItemList then return end
    MarketSniper.UI.ItemList:destroyChildren()

    local names = {}
    for name, _ in pairs(MarketSniper.Config.Items) do
        table.insert(names, name)
    end
    table.sort(names)

    for _, name in ipairs(names) do
        local limits = MarketSniper.Config.Items[name]
        local label = UI.createWidget('MarketSniperItem', MarketSniper.UI.ItemList)

        local gi = limits.GI or "-"
        local sp = limits.SP or "-"

        label:setText(name .. " | GI: " .. gi .. " | SP: " .. sp)
        label.marketSniperName = name

        label.onClick = function(widget)
            MarketSniper.UI.NameInput:setText(name)
            MarketSniper.UI.GIInput:setText(limits.GI or "")
            MarketSniper.UI.SPInput:setText(limits.SP or "")
            MarketSniper.log("Selected: " .. name, "INFO")
        end
    end
end

function MarketSniper.createUI()
    if MarketSniper.UI.Window then return end

    MarketSniper.UI.Window = g_ui.createWidget('MarketSniperConfigWindow', g_ui.getRootWidget())
    MarketSniper.UI.Window:hide()

    MarketSniper.UI.Window.ok = function(self)
        self:hide()
    end

    MarketSniper.UI.ItemList = MarketSniper.UI.Window:recursiveGetChildById('itemList')
    MarketSniper.UI.NameInput = MarketSniper.UI.Window:recursiveGetChildById('txtName')
    MarketSniper.UI.GIInput = MarketSniper.UI.Window:recursiveGetChildById('txtGI')
    MarketSniper.UI.SPInput = MarketSniper.UI.Window:recursiveGetChildById('txtSP')

    local btnAdd = MarketSniper.UI.Window:recursiveGetChildById('btnAdd')
    btnAdd.onClick = function()
        local name = MarketSniper.UI.NameInput:getText()
        local gi = tonumber(MarketSniper.UI.GIInput:getText())
        local sp = tonumber(MarketSniper.UI.SPInput:getText())

        if name and name ~= "" then
            MarketSniper.Config.Items[name] = { GI = gi, SP = sp }
            MarketSniper.saveConfig()
            MarketSniper.refreshItemList()
            MarketSniper.log("Updated/Added item: " .. name, "SUCCESS")

            MarketSniper.UI.NameInput:setText("")
            MarketSniper.UI.GIInput:setText("")
            MarketSniper.UI.SPInput:setText("")
        else
            MarketSniper.log("Invalid item name!", "ERROR")
        end
    end

    local btnRemove = MarketSniper.UI.Window:recursiveGetChildById('btnRemove')
    btnRemove.onClick = function()
        local name = MarketSniper.UI.NameInput:getText()

        if (not name or name == "") and MarketSniper.UI.ItemList then
            local focused = MarketSniper.UI.ItemList:getFocusedChild()
            if focused and focused.marketSniperName then
                name = focused.marketSniperName
            end
        end

        if name and MarketSniper.Config.Items[name] then
            MarketSniper.Config.Items[name] = nil
            MarketSniper.saveConfig()
            MarketSniper.refreshItemList()
            MarketSniper.log("Removed item: " .. name, "SUCCESS")

            MarketSniper.UI.NameInput:setText("")
            MarketSniper.UI.GIInput:setText("")
            MarketSniper.UI.SPInput:setText("")
        else
            MarketSniper.log("Cannot remove: Item not found or no name selected (" .. tostring(name) .. ")", "ERROR")
        end
    end

    local btnClose = MarketSniper.UI.Window:recursiveGetChildById('btnClose')
    btnClose.onClick = function()
        MarketSniper.closePopup(MarketSniper.UI.Window)
    end
end

function MarketSniper.toggleConfig()
    if not MarketSniper.UI.Window then
        MarketSniper.createUI()
    end

    if MarketSniper.UI.Window:isVisible() then
        MarketSniper.closePopup(MarketSniper.UI.Window)
    else
        MarketSniper.UI.Window:show()
        MarketSniper.UI.Window:raise()
        MarketSniper.UI.Window:focus()
        MarketSniper.refreshItemList()
    end
end

function MarketSniper.getWidgetCenter(widget)
    local x = widget:getX()
    local y = widget:getY()
    local w = widget:getWidth()
    local h = widget:getHeight()
    return { x = x + (w/2), y = y + (h/2) }
end

function MarketSniper.closePopup(window)
    if not window or not window:isVisible() then 
        return false 
    end

    if window.ok then
        local status, err = pcall(function() window:ok() end)
        if status then
            MarketSniper.log("Closed window using :ok()", "INFO")
            return true
        else
            MarketSniper.log("Failed to call :ok() - " .. tostring(err), "WARN")
        end
    end

    local okBtn = window:recursiveGetChildById("ok")
               or window:recursiveGetChildById("okButton")
               or window:recursiveGetChildById("confirm")
               or window:recursiveGetChildById("close")
               or window:recursiveGetChildById("closeButton")

    if okBtn and okBtn.onClick then
        local status, err = pcall(function() okBtn.onClick() end)
        if status then
            MarketSniper.log("Closed window using button onClick", "INFO")
            return true
        else
            MarketSniper.log("Failed to click button - " .. tostring(err), "WARN")
        end
    end

    local status, err = pcall(function() window:destroy() end)
    if status then
        MarketSniper.log("Closed window using :destroy()", "INFO")
        return true
    else
        MarketSniper.log("Failed to destroy window - " .. tostring(err), "ERROR")
        return false
    end
end
function MarketSniper.rightClickPacket(creature)
    if modules and modules.game_interface then
        local mockPoint = {x = 500, y = 300}
        local mapPos = creature:getPosition()

        modules.game_interface.processMouseAction(
            mockPoint,
            2,
            mapPos,
            creature,
            creature,
            creature,
            creature,
            false
        )
    end
end


function MarketSniper.closeResultPopup()
    local root = g_ui.getRootWidget()
    local children = root:getChildren()

    for i = #children, 1, -1 do
        local child = children[i]

        if child:isVisible() then
            local okBtn = child:recursiveGetChildById("ok")
                       or child:recursiveGetChildById("okButton")
                       or child:recursiveGetChildById("buttonOk")
                       or child:recursiveGetChildById("buttonOK")

            if not okBtn then
                local function findButtonByText(widget)
                    for _, sub in ipairs(widget:getChildren()) do
                        if sub:getClassName() == "UIButton" or sub:getClassName() == "Button" then
                            local text = sub:getText()
                            if text then
                                local lower = text:lower()
                                if lower == "ok" or lower == "close" or lower == "yes" then
                                    return sub
                                end
                            end
                        end
                        local res = findButtonByText(sub)
                        if res then return res end
                    end
                    return nil
                end

                okBtn = findButtonByText(child)
            end

            if okBtn then
                MarketSniper.log("Error Popup Detected -> Closing.", "WARN")

                if MarketSniper.closePopup(child) then
                    if MarketSniper.purchaseQueue and #MarketSniper.purchaseQueue > 0 then
                        local idx = MarketSniper.currentPurchaseIndex or 1
                        MarketSniper.log("Purchase failed for item [" .. idx .. "/" .. #MarketSniper.purchaseQueue .. "]. Skipping.", "WARN")

                        schedule(500, function()
                            if not MarketSniper.IsRunning then return end
                            MarketSniper.currentPurchaseIndex = idx + 1
                            MarketSniper.processPurchaseQueue()
                        end)
                    else
                        if MarketSniper.State.CurrentTargetName then
                            local name = MarketSniper.State.CurrentTargetName
                            MarketSniper.State.BlacklistedPlayers[name] = true

                            schedule(MarketSniper.Config.BlacklistTime, function()
                                MarketSniper.State.BlacklistedPlayers[name] = nil
                            end)

                            MarketSniper.State.CurrentTargetName = nil
                        end

                        schedule(500, function()
                            if not MarketSniper.IsRunning then return end

                            local shopWin = root:recursiveGetChildById("amountWindow")
                            if shopWin and shopWin:isVisible() then
                                MarketSniper.closePopup(shopWin)
                            end

                            schedule(300, function()
                                if not MarketSniper.IsRunning then return end
                                MarketSniper.State.Opening = false
                                MarketSniper.process()
                            end)
                        end)
                    end

                    break
                end
            end
        end
    end
end


function MarketSniper.finalizePurchase()
    local root = g_ui.getRootWidget()
    local targetWin = nil

    for _, child in ipairs(root:getChildren()) do
        local text = child:getText()
        if text and string.find(text, "Buying") and child:isVisible() then
            targetWin = child
            break
        end
    end

    if not targetWin then return false end

    local slider = targetWin:recursiveGetChildById("value")
    if slider then
        local maxVal = slider:getMaximum()
        if maxVal > 1 then
            slider:setValue(maxVal)
        end
    end

    local buyBtn = targetWin:recursiveGetChildById("confirm")
    if buyBtn and buyBtn.onClick then
        schedule(200, function()
            if not MarketSniper.IsRunning then return end
            MarketSniper.log("CONFIRMING PURCHASE!", "WARN")
            buyBtn.onClick()

            schedule(600, MarketSniper.closeResultPopup)
            schedule(1200, MarketSniper.closeResultPopup)
        end)

        return true
    end

    MarketSniper.log("CRITICAL: Buy button not found!", "ERROR")
    return false
end


function MarketSniper.buySlot(slotWidget)
    MarketSniper.log("Selecting Item...", "INFO")
    if not slotWidget then return end

    local children = slotWidget:getChildren()
    local clicked = false

    for _, child in ipairs(children) do
        if child.onDoubleClick then
            local pos = MarketSniper.getWidgetCenter(child)
            pcall(function() child:onDoubleClick(pos) end)
            clicked = true
            break
        end
    end

    if clicked then
        schedule(400, MarketSniper.finalizePurchase)

        schedule(800, function()
            if not MarketSniper.IsRunning then return end

            local root = g_ui.getRootWidget()
            local found = false

            for _, child in ipairs(root:getChildren()) do
                if child:getText() and string.find(child:getText(), "Buying") and child:isVisible() then
                    found = true
                    break
                end
            end

            if found then MarketSniper.finalizePurchase() end
        end)
    else
        MarketSniper.log("ERROR: Slot not clickable!", "ERROR")
    end
end


function MarketSniper.closeWindow(window)
    if not window then return end

    MarketSniper.closePopup(window)

    if MarketSniper.State.CurrentTargetName then
        local name = MarketSniper.State.CurrentTargetName
        MarketSniper.State.BlacklistedPlayers[name] = true

        schedule(MarketSniper.Config.BlacklistTime, function()
            MarketSniper.State.BlacklistedPlayers[name] = nil
        end)

        MarketSniper.State.CurrentTargetName = nil
    end
end
function MarketSniper.scanCurrentWindow()
    local root = g_ui.getRootWidget()
    local amountWindow = root:recursiveGetChildById("amountWindow")
    if not amountWindow then return false end

    local itemsToBuy = {}
    local itemsFound = 0
    local shopLog = ""

    for i = 1, 10 do
        local slotId = "slot" .. i
        local slot = amountWindow:recursiveGetChildById(slotId)

        if slot and slot:isVisible() then
            local nameWidget = slot:recursiveGetChildById("name")
            local priceWidget = slot:recursiveGetChildById("price")

            if nameWidget and priceWidget then
                local name = nameWidget:getText()
                local priceText = priceWidget:getText()

                local detectedCurrency = "UNKNOWN"
                if priceWidget.getColor then
                    local c = priceWidget:getColor()
                    local r_val = math.floor(c.r * 255)
                    if r_val > 62000 then detectedCurrency = "GI" else detectedCurrency = "SP" end
                end

                if name and name ~= "" then
                    local price = nil
                    if priceText then priceText = string.gsub(priceText, ",", "") end
                    local match = string.match(priceText, "each:%s*(%d+)")
                    if match then price = tonumber(match) end

                    if price then
                        itemsFound = itemsFound + 1
                        shopLog = shopLog .. "[" .. name .. ": " .. price .. detectedCurrency .. "] "

                        if MarketSniper.Config.TestBuyMode then
                            MarketSniper.log("[TEST] Buying: " .. name .. " @ " .. price .. detectedCurrency, "WARN")
                            MarketSniper.buySlot(slot)
                            return true
                        end

                        local itemConfig = MarketSniper.Config.Items[name]
                        if itemConfig then
                            if type(itemConfig) == "number" then
                                itemConfig = { GI = itemConfig }
                            end

                            local shouldBuy = false
                            local reason = ""
                            local rate = MarketSniper.Config.ExchangeRate

                            if itemConfig[detectedCurrency] and price <= itemConfig[detectedCurrency] then
                                shouldBuy = true
                                reason = "Limit: " .. itemConfig[detectedCurrency] .. detectedCurrency
                            end

                            if not shouldBuy then
                                if detectedCurrency == "GI" and itemConfig.SP then
                                    local eqSP = price / rate
                                    if eqSP <= itemConfig.SP then
                                        shouldBuy = true
                                        reason = "Calc: " .. string.format("%.1f", eqSP) .. " SP (Cheap GI!)"
                                    end
                                elseif detectedCurrency == "SP" and itemConfig.GI then
                                    local eqGI = price * rate
                                    if eqGI <= itemConfig.GI then
                                        shouldBuy = true
                                        reason = "Calc: " .. eqGI .. " GI (Cheap SP!)"
                                    end
                                end
                            end

                            if shouldBuy then
                                MarketSniper.log(">>> DEAL! " .. name .. " | " .. price .. detectedCurrency .. " | " .. reason .. " <<<", "SUCCESS")
                                table.insert(itemsToBuy, {
                                    slot = slot,
                                    name = name,
                                    price = price,
                                    currency = detectedCurrency,
                                    reason = reason
                                })
                            end
                        end
                    end
                end
            end
        end
    end

    if #itemsToBuy > 0 then
        if MarketSniper.Config.SafeMode then
            for i, item in ipairs(itemsToBuy) do
                MarketSniper.log("(SafeMode) Would buy [" .. i .. "/" .. #itemsToBuy .. "]: " .. item.name, "WARN")
            end
            MarketSniper.closeWindow(amountWindow)
        else
            MarketSniper.log("Found " .. #itemsToBuy .. " items to buy. Starting purchases...", "SUCCESS")
            MarketSniper.purchaseQueue = itemsToBuy
            MarketSniper.currentPurchaseIndex = 1
            MarketSniper.processPurchaseQueue()
            return true
        end
    else
        if itemsFound > 0 then
            MarketSniper.log("Scanned: " .. shopLog, "INFO")
            MarketSniper.log("No deals found. Closing.", "INFO")
        else
            MarketSniper.log("Shop is empty. Closing.", "INFO")
        end
        MarketSniper.closeWindow(amountWindow)
    end

    return true
end



function MarketSniper.processPurchaseQueue()
    if not MarketSniper.IsRunning then return end

    if not MarketSniper.purchaseQueue or #MarketSniper.purchaseQueue == 0 then
        MarketSniper.log("Purchase queue empty. Closing shop.", "INFO")

        local root = g_ui.getRootWidget()
        local amountWindow = root:recursiveGetChildById("amountWindow")
        if amountWindow then
            MarketSniper.closeWindow(amountWindow)
        end

        return
    end

    local currentIndex = MarketSniper.currentPurchaseIndex or 1

    if currentIndex > #MarketSniper.purchaseQueue then
        MarketSniper.log("All purchases completed (" .. (#MarketSniper.purchaseQueue) .. " items). Closing shop.", "SUCCESS")

        local root = g_ui.getRootWidget()
        local amountWindow = root:recursiveGetChildById("amountWindow")
        if amountWindow then
            MarketSniper.closeWindow(amountWindow)
        end

        MarketSniper.purchaseQueue = nil
        MarketSniper.currentPurchaseIndex = nil
        return
    end

    local item = MarketSniper.purchaseQueue[currentIndex]
    MarketSniper.log("Purchasing [" .. currentIndex .. "/" .. #MarketSniper.purchaseQueue .. "]: " .. item.name .. " @ " .. item.price .. item.currency, "WARN")

    MarketSniper.buySlot(item.slot)

    schedule(2500, function()
        if not MarketSniper.IsRunning then return end
        MarketSniper.currentPurchaseIndex = currentIndex + 1
        MarketSniper.processPurchaseQueue()
    end)
end
function MarketSniper.tryOpenShop(creature)
    local name = creature:getName()

    local function finish(success)
        MarketSniper.State.Opening = false

        if not success then
            MarketSniper.log("Failed to open: " .. name .. " (Timeout) -> skipping this shop position.", "ERROR")

            -- blacklist gracza
            MarketSniper.State.BlacklistedPlayers[name] = true
            schedule(MarketSniper.Config.BlacklistTime, function()
                MarketSniper.State.BlacklistedPlayers[name] = nil
            end)

            MarketSniper.State.CurrentTargetName = nil

            -- PRZECHODZIMY DO KOLEJNEJ POZYCJI
            MarketSniper.State.CurrentPriorityIndex = MarketSniper.State.CurrentPriorityIndex + 1

            -- jeśli to był ostatni sklep → pauza
            if MarketSniper.State.CurrentPriorityIndex > #MarketSniper.Config.PriorityPositions then
                MarketSniper.log("Zakończono pełny cykl sklepów (timeout). Odpoczynek 5 minut.", "INFO")

                MarketSniper.State.CurrentPriorityIndex = 1
                MarketSniper.State.IsPaused = true

                schedule(5 * 60 * 1000, function()
                    if MarketSniper.IsRunning then
                        MarketSniper.State.IsPaused = false
                        MarketSniper.log("Wznawiam patrol sklepów.", "INFO")
                        MarketSniper.process()
                    end
                end)

                return
            end

            -- kontynuujemy patrol
            MarketSniper.process()
        else
            -- okno się otworzyło → wracamy do process()
            MarketSniper.process()
        end
    end

    local function checkWindow()
        if not MarketSniper.IsRunning then return end

        local root = g_ui.getRootWidget()
        local win = root:recursiveGetChildById("amountWindow")

        if win and win:isVisible() then
            finish(true)
        else
            finish(false)
        end
    end

    MarketSniper.log("Opening Shop: " .. name, "WARN")
    MarketSniper.rightClickPacket(creature)

    schedule(2000, checkWindow)
end


-- porównywanie pozycji
local function positionsEqual(a, b)
    return a.x == b.x and a.y == b.y and a.z == b.z
end
function MarketSniper.process()
    if not MarketSniper.IsRunning then return end

    -- jeśli trwa pauza → nic nie rób
    if MarketSniper.State.IsPaused then
        return
    end

    local root = g_ui.getRootWidget()
    local amountWindow = root:recursiveGetChildById("amountWindow")
    local isWindowOpen = amountWindow and amountWindow:isVisible()

    --------------------------------------------------------------------
    -- 1. Jeśli okno sklepu jest otwarte → skanujemy i przechodzimy dalej
    --------------------------------------------------------------------
    if isWindowOpen then
        MarketSniper.scanCurrentWindow()

        -- przechodzimy do kolejnej pozycji
        MarketSniper.State.CurrentPriorityIndex = MarketSniper.State.CurrentPriorityIndex + 1

        -- jeśli to był ostatni sklep → pauza 5 minut
        if MarketSniper.State.CurrentPriorityIndex > #MarketSniper.Config.PriorityPositions then
            MarketSniper.log("Zakończono pełny cykl sklepów. Odpoczynek 5 minut.", "INFO")

            MarketSniper.State.CurrentPriorityIndex = 1
            MarketSniper.State.IsPaused = true

            schedule(5 * 60 * 1000, function()
                if MarketSniper.IsRunning then
                    MarketSniper.State.IsPaused = false
                    MarketSniper.log("Wznawiam patrol sklepów.", "INFO")
                    MarketSniper.process()
                end
            end)

            return
        end

        -- kontynuujemy patrol
        MarketSniper.LoopID = schedule(MarketSniper.Config.ScanInterval, MarketSniper.process)
        return
    end

    --------------------------------------------------------------------
    -- 2. Jeśli okno nie jest otwarte → szukamy shopkeepera na pozycji
    --------------------------------------------------------------------
    local player = g_game.getLocalPlayer()
    if not player then return end

    if player:isWalking() then
        MarketSniper.LoopID = schedule(MarketSniper.Config.ScanInterval, MarketSniper.process)
        return
    end

    local specs = g_map.getSpectators(player:getPosition(), false)
    local prioList = MarketSniper.Config.PriorityPositions
    local idx = MarketSniper.State.CurrentPriorityIndex

    -- sanity check
    if idx < 1 or idx > #prioList then
        idx = 1
        MarketSniper.State.CurrentPriorityIndex = 1
    end

    local targetPos = prioList[idx]
    local bestSpec = nil

    --------------------------------------------------------------------
    -- 3. Szukamy shopkeepera stojącego dokładnie na tej pozycji
    --------------------------------------------------------------------
    for _, spec in ipairs(specs) do
        if spec ~= player and spec:isPlayer() then
            local pos = spec:getPosition()

            if positionsEqual(pos, targetPos) then
                local tile = g_map.getTile(pos)
                local isShop = false

                if tile then
                    for _, thing in ipairs(tile:getThings()) do
                        if thing:isItem() and thing:getId() == 10145 then
                            isShop = true
                            break
                        end
                    end
                end

                if isShop then
                    bestSpec = spec
                    break
                end
            end
        end
    end

    --------------------------------------------------------------------
    -- 4. Jeśli nie ma shopkeepera → skip pozycji
    --------------------------------------------------------------------
    if not bestSpec then
        MarketSniper.State.CurrentPriorityIndex = idx + 1

        if MarketSniper.State.CurrentPriorityIndex > #prioList then
            MarketSniper.log("Zakończono pełny cykl sklepów. Odpoczynek 5 minut.", "INFO")

            MarketSniper.State.CurrentPriorityIndex = 1
            MarketSniper.State.IsPaused = true

            schedule(5 * 60 * 1000, function()
                if MarketSniper.IsRunning then
                    MarketSniper.State.IsPaused = false
                    MarketSniper.log("Wznawiam patrol sklepów.", "INFO")
                    MarketSniper.process()
                end
            end)

            return
        end

        MarketSniper.LoopID = schedule(MarketSniper.Config.ScanInterval, MarketSniper.process)
        return
    end

    --------------------------------------------------------------------
    -- 5. Mamy shopkeepera → podchodzimy i otwieramy sklep
    --------------------------------------------------------------------
    local name = bestSpec:getName()
    MarketSniper.State.CurrentTargetName = name

    local pPos = player:getPosition()
    local tPos = bestSpec:getPosition()
    local dist = math.max(math.abs(pPos.x - tPos.x), math.abs(pPos.y - tPos.y))

    if dist > 1 then
        local now = os.clock() * 1000

        if (not player:isAutoWalking()) or (now - MarketSniper.State.LastMoveTime > 1500) then
            if CaveBot and CaveBot.walkTo then
                CaveBot.walkTo(tPos, 20, { ignoreNonPathable = true, precision = 1 })
            else
                g_game.autoWalk(tPos)
            end

            MarketSniper.State.LastMoveTime = now
        end
    else
        if not MarketSniper.State.Opening then
            if g_game.stop then g_game.stop() end

            MarketSniper.State.Opening = true
            MarketSniper.tryOpenShop(bestSpec)
        end

        return
    end

    MarketSniper.LoopID = schedule(MarketSniper.Config.ScanInterval, MarketSniper.process)
end
function MarketSniper.toggle()
    if MarketSniper.IsRunning then
        MarketSniper.IsRunning = false
        MarketSniper.State.IsPaused = false

        if MarketSniper.LoopID then
            removeEvent(MarketSniper.LoopID)
        end

        MarketSniper.log("STOPPED", "ERROR")
    else
        MarketSniper.IsRunning = true
        MarketSniper.State.IsPaused = false

        MarketSniper.log("STARTED (SafeMode: " .. tostring(MarketSniper.Config.SafeMode) .. ")", "WARN")
        MarketSniper.process()
    end
end


-- PRZYCISK W TOPMENU
if not MarketSniper.Button then
    MarketSniper.Button = modules.client_topmenu.getButton('marketSniperBtn')

    if not MarketSniper.Button then
        MarketSniper.Button = modules.client_topmenu.addLeftGameButton(
            'marketSniperBtn',
            'Sniper',
            '/images/topbuttons/shop',
            function() MarketSniper.toggle() end
        )
    end
end


-- OBSŁUGA KLIKNIĘĆ W PRZYCISK
MarketSniper.Button.onMouseRelease = function(widget, mousePos, mouseButton)
    local L_MouseLeft = 1
    local L_MouseRight = 2

    if mouseButton == L_MouseRight then
        MarketSniper.toggleConfig()
        return true
    elseif mouseButton == L_MouseLeft then
        MarketSniper.toggle()
        return true
    end
end


-- ŁADOWANIE KONFIGU
MarketSniper.loadConfig()

MarketSniper.log("Script V16.1 Loaded. (Priority Shops + Skip + Timeout Skip + 5min Pause)", "SUCCESS")

return MarketSniper


