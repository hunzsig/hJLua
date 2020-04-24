---@class hhero
hhero = {
    player_allow_qty = {}, -- 玩家最大单位数量,默认1
    player_current_qty = {}, -- 玩家当前单位数量,默认0
    player_heros = {}, -- 玩家当前英雄
    build_token = hslk_global.unit_hero_tavern_token,
    build_params = {
        id = hslk_global.unit_hero_tavern,
        x = 0, y = 0,
        distance = 128.0,
        per_row = 2,
        allow_qty = 11,
    },
    hero_born_params = {
        x = 0, y = 0,
        effect = nil,
    }
}

---@private
hhero.init = function()
    for i = 1, bj_MAX_PLAYER_SLOTS, 1 do
        local p = cj.Player(i - 1)
        hhero.player_allow_qty[p] = 1
        hhero.player_current_qty[p] = 0
        hhero.player_heros[p] = {}
    end
end

--- 设置英雄之前的等级
---@protected
---@param u userdata
---@param lv number
hhero.setPrevLevel = function(u, lv)
    if (hRuntime.hero[u] == nil) then
        hRuntime.hero[u] = {}
    end
    hRuntime.hero[u].prevLevel = lv
end
--- 获取英雄之前的等级
---@protected
---@param u userdata
---@return number
hhero.getPrevLevel = function(u)
    if (hRuntime.hero[u] == nil) then
        hRuntime.hero[u] = {}
    end
    return hRuntime.hero[u].prevLevel or 0
end

--- 获取英雄当前等级
---@param u userdata
---@return number
hhero.getCurLevel = function(u)
    return cj.GetHeroLevel(u) or 1
end
--- 设置英雄当前的等级
---@paramu userdata
---@param newLevel number
---@param showEffect boolean
hhero.setCurLevel = function(u, newLevel, showEffect)
    if (type(showEffect) ~= "boolean") then
        showEffect = false
    end
    local oldLevel = cj.GetHeroLevel(u)
    if (newLevel > oldLevel) then
        cj.SetHeroLevel(u, newLevel, showEffect)
    elseif (newLevel < oldLevel) then
        cj.UnitStripHeroLevel(u, oldLevel - newLevel)
    else
        return
    end
    hhero.setPrevLevel(u, newLevel)
end

--- 获取英雄的类型（STR AGI INT）需要注册
---@param u userdata
---@return string STR|AGI|INT
hhero.getHeroType = function(u)
    return hslk_global.heroesKV[cj.GetUnitTypeId(u)].Primary
end

--- 获取英雄的类型文本
---@param u userdata
---@return string 力量|敏捷|智力
hhero.getHeroTypeLabel = function(u)
    return CONST_HERO_PRIMARY[hhero.getHeroType(u)]
end

--- 设定酒馆参数
hhero.setBuildParams = function(x, y, distance, per_row, allow_qty)
    hhero.build_params.x = x
    hhero.build_params.y = y
    hhero.build_params.distance = distance
    hhero.build_params.per_row = per_row
    hhero.build_params.allow_qty = allow_qty
end
-- 设定英雄创建参数
hhero.setHeroBornParams = function(x, y)
    hhero.hero_born_params.x = x
    hhero.hero_born_params.y = y
end

--- 设置玩家最大英雄数量,支持1 - 7
--- 超过7会有很多魔兽原生问题，例如英雄不会复活，左侧图标无法查看等
---@param whichPlayer userdata
---@param max number
hhero.setPlayerAllowQty = function(whichPlayer, max)
    if (max < 1) then
        max = 1
    end
    if (max > 7) then
        max = 7
    end
    heros.player_allow_qty[whichPlayer] = max
end
--- 获取玩家最大英雄数量
---@param whichPlayer userdata
---@return number
hhero.getPlayerAllowQty = function(whichPlayer)
    return heros.player_allow_qty[whichPlayer]
end

--- 添加一个英雄给玩家
---@private
---@param whichPlayer userdata
---@param sItem userdata
---@param type string
hhero.addPlayerUnit = function(whichPlayer, sItem, type)
    if (sItem ~= nil) then
        hhero.player_current_qty[whichPlayer] = hhero.player_current_qty[whichPlayer] + 1
        local u
        if (type == "click") then
            -- 点击方式
            u = sItem
            hRuntime.heroBuildSelection[u].canSelect = false
            cj.SetUnitOwner(u, whichPlayer, true)
            cj.SetUnitPosition(u, hhero.hero_born_params.x, hhero.hero_born_params.y)
            cj.PauseUnit(u, false)
        elseif (type == "tavern") then
            -- 酒馆方式(单位ID)
            u = hunit.create(
                {
                    whichPlayer = whichPlayer,
                    unitId = sItem,
                    x = hhero.hero_born_params.x,
                    y = hhero.hero_born_params.y
                }
            )
            if (hhero.player_current_qty[whichPlayer] >= hhero.player_allow_qty[whichPlayer]) then
                hmessage.echo("您选择了 " .. "|cffffff80" .. cj.GetUnitName(u) .. "|r,已挑选完毕", whichPlayer)
            else
                hmessage.echo(
                    "您选择了 |cffffff80" .. cj.GetUnitName(u) .. "|r,还要选 " ..
                        math.floor(hhero.player_allow_qty[whichPlayer] - hhero.player_current_qty[whichPlayer])
                        .. " 个",
                    whichPlayer
                )
            end
        end
        if (u == nil) then
            hmessage.echo("hhero.addPlayerUnit类型错误", whichPlayer)
            return
        end
        table.insert(hhero.player_heros[whichPlayer], u)
        hhero.setIsHero(u, true)
        hunit.setInvulnerable(u, false)
        -- 触发英雄被选择事件(全局)
        hevent.triggerEvent(
            "global",
            CONST_EVENT.pickHero,
            {
                triggerPlayer = whichPlayer,
                triggerUnit = u
            }
        )
    end
end
--- 删除一个英雄单位对玩家
---@private
---@param whichPlayer userdata
---@param u userdata
---@param type string
hhero.removePlayerUnit = function(whichPlayer, u, type)
    table.delete(u, hhero.player_heros[whichPlayer])
    hhero.player_current_qty[whichPlayer] = hhero.player_current_qty[whichPlayer] - 1
    if (type == "click") then
        -- 点击方式
        local heroId = cj.GetUnitTypeId(u)
        local x = hRuntime.heroBuildSelection[u].x
        local y = hRuntime.heroBuildSelection[u].y
        hRuntime.heroBuildSelection[u] = nil
        hunit.del(u)
        local u_new = hunit.create(
            {
                whichPlayer = cj.Player(PLAYER_NEUTRAL_PASSIVE),
                unitId = heroId,
                x = x,
                y = y,
                isPause = true
            }
        )
        hRuntime.heroBuildSelection[u_new] = {
            x = x,
            x = y,
            canChoose = true
        }
    elseif (type == "tavern") then
        -- 酒馆方式
        local heroId = cj.GetUnitTypeId(u)
        local itemId = hRuntime.heroBuildSelection[heroId].itemId
        local tavern = hRuntime.heroBuildSelection[heroId].tavern
        hunit.del(u)
        cj.AddItemToStock(tavern, itemId, 1, 1)
    end
end

--- 设置一个单位是否拥有英雄判定(请勿重复设置)
--- 当设置[一般单位]为[英雄]时，框架自动屏幕，[力量|敏捷|智力]等不属于一般单位的属性，以避免引起崩溃报错
--- 设定后 his.hero 方法会认为单位为英雄，同时属性系统也会认定它为英雄
---@param u userdata
---@param flag boolean
hhero.setIsHero = function(u, flag)
    flag = flag or false
    his.set(u, "isHero", flag)
    if (flag == true and his.get(u, "isHeroInit") == false) then
        his.set(u, "isHeroInit", true)
        hhero.setPrevLevel(u, 1)
        hevent.pool(u, hevent_default_actions.hero.levelUp, function(tgr)
            cj.TriggerRegisterUnitEvent(tgr, u, EVENT_UNIT_HERO_LEVEL)
        end)
    end
end

-- 构建选择单位给玩家（clickQty 击）
hhero.buildClick = function(during, clickQty)
    if (during <= 20) then
        print_err("建立点击选英雄模式必须设定during大于20秒")
        return
    end
    if (clickQty == nil or clickQty <= 1) then
        clickQty = 2
    end
    during = during + 1
    -- build
    local randomChooseAbleList = {}
    local totalRow = 1
    local rowNowQty = 0
    local x = 0
    local y = 0
    for _, v in ipairs(hslk_global.heroes) do
        local heroId = v.heroID
        if (heroId > 0) then
            if (rowNowQty >= hhero.build_params.per_row) then
                rowNowQty = 0
                totalRow = totalRow + 1
                x = hhero.build_params.x
                y = y - hhero.build_params.distance
            else
                x = hhero.build_params.x + rowNowQty * hhero.build_params.distance
            end
            local u = hunit.create(
                {
                    whichPlayer = cj.Player(PLAYER_NEUTRAL_PASSIVE),
                    unitId = heroId,
                    x = x,
                    y = y,
                    during = during,
                    isInvulnerable = true,
                    isPause = true
                }
            )
            hRuntime.heroBuildSelection[u] = {
                x = x,
                x = y,
                canChoose = true
            }
            table.insert(randomChooseAbleList, u)
            rowNowQty = rowNowQty + 1
        end
    end
    -- evt
    local tgr_random = cj.CreateTrigger()
    local tgr_repick = cj.CreateTrigger()
    cj.TriggerAddAction(
        tgr_random,
        function()
            local p = cj.GetTriggerPlayer()
            if (hhero.player_current_qty[p] >= hhero.player_allow_qty[p]) then
                hmessage.echo("|cffffff80你已经选够了|r", p)
                return
            end
            local txt = ""
            local qty = 0
            while (true) do
                local u = table.random(randomChooseAbleList)
                table.delete(u, randomChooseAbleList)
                txt = txt .. " " .. cj.GetUnitName(u)
                hhero.addPlayerUnit(p, u, "click")
                hhero.player_current_qty[p] = hhero.player_current_qty[p] + 1
                qty = qty + 1
                if (hhero.player_current_qty[p] >= hhero.player_allow_qty[p]) then
                    break
                end
            end
            hmessage.echo00(
                "已为您 |cffffff80random|r 选择了 " .. "|cffffff80" .. math.floor(qty) .. "|r 个单位：|cffffff80" .. txt .. "|r",
                0,
                p
            )
        end
    )
    cj.TriggerAddAction(
        tgr_repick,
        function()
            local p = cj.GetTriggerPlayer()
            if (hhero.player_current_qty[p] <= 0) then
                hmessage.echo("|cffffff80你还没有选过任何单位|r", p)
                return
            end
            local qty = #hhero.player_heros
            for _, v in ipairs(hhero.player_heros[p]) do
                hhero.removePlayerUnit(p, v, "click")
                table.insert(randomChooseAbleList, v)
            end
            hhero.player_heros[p] = {}
            hhero.player_current_qty[p] = 0
            hcamera.toXY(p, 0, hhero.build_params.x, hhero.build_params.y)
            hmessage.echo("已为您 |cffffff80repick|r 了 " .. "|cffffff80" .. qty .. "|r 个单位", p)
        end
    )
    -- token
    for i = 1, bj_MAX_PLAYER_SLOTS, 1 do
        local p = cj.Player(i - 1)
        local u = hunit.create(
            {
                whichPlayer = p,
                unitId = hhero.build_token,
                x = hhero.build_params.x + hhero.build_params.per_row * 0.5 * hhero.build_params.distance,
                y = hhero.build_params.y - totalRow * 0.5 * hhero.build_params.distance,
                during = during,
                isInvulnerable = true,
                isPause = true
            }
        )
        hunit.del(u, during)
        cj.TriggerRegisterPlayerChatEvent(tgr_random, p, "-random", true)
        cj.TriggerRegisterPlayerChatEvent(tgr_repick, p, "-repick", true)
        local tgr_click = hevent.onSelection(
            p,
            clickQty,
            function(data)
                local p = data.triggerPlayer
                local u = data.triggerUnit
                if (hRuntime.heroBuildSelection[u] == nil) then
                    return
                end
                if (hRuntime.heroBuildSelection[u].canSelect == false) then
                    return
                end
                if (cj.GetOwningPlayer(u) ~= cj.Player(PLAYER_NEUTRAL_PASSIVE)) then
                    return
                end
                if (hhero.player_current_qty[p] >= hhero.player_allow_qty[p]) then
                    hmessage.echo("|cffffff80你已经选够了|r", p)
                    return
                end
                table.delete(u, randomChooseAbleList)
                hhero.addPlayerUnit(p, u, "click")
                if (hhero.player_current_qty[p] >= hhero.player_allow_qty[p]) then
                    hmessage.echo("您选择了 " .. "|cffffff80" .. cj.GetUnitName(u) .. "|r,已挑选完毕", p)
                else
                    hmessage.echo("您选择了 |cffffff80" .. cj.GetUnitName(u) .. "|r,还要选 " ..
                        math.floor(hhero.player_allow_qty[p] - hhero.player_current_qty[p]) .. " 个", p
                    )
                end
            end
        )
        htime.setTimeout(
            during - 0.5,
            function(t)
                htime.delTimer(t)
                hevent.deleteEvent(p, CONST_EVENT.selection .. "#" .. clickQty, tgr_click)
            end
        )
    end
    -- 还剩10秒给个选英雄提示
    htime.setTimeout(
        during - 10.0,
        function(t)
            local x1 = hhero.build_params.x + hhero.build_params.per_row * 0.5 * hhero.build_params.distance
            local y1 = hhero.build_params.y - totalRow * 0.5 * hhero.build_params.distance
            htime.delTimer(t)
            cj.DisableTrigger(tgr_repick)
            cj.DestroyTrigger(tgr_repick)
            hmessage.echo("还剩 10 秒，还未选择的玩家尽快啦～")
            cj.PingMinimapEx(x1, y1, 1.00, 254, 0, 0, true)
        end
    )
    -- 一定时间后clear
    htime.setTimeout(
        during - 0.5,
        function(t)
            htime.delTimer(t)
            cj.DisableTrigger(tgr_random)
            cj.DestroyTrigger(tgr_random)
        end,
        "选择英雄"
    )
    -- 转移玩家镜头
    hcamera.toXY(nil, 0, hhero.build_params.x, hhero.build_params.y)
end

-- 构建选择单位给玩家（商店物品）
hhero.buildTavern = function(during)
    if (during <= 20) then
        print_err("建立酒馆选英雄模式必须设定during大于20秒")
        return
    end
    during = during + 1
    local randomChooseAbleList = {}
    -- evt
    local tgr_sell = cj.CreateTrigger()
    local tgr_random = cj.CreateTrigger()
    local tgr_repick = cj.CreateTrigger()
    cj.TriggerAddAction(
        tgr_sell,
        function()
            local it = cj.GetSoldItem()
            local itemId = cj.GetItemTypeId(it)
            local p = cj.GetOwningPlayer(cj.GetBuyingUnit())
            local unitId = hRuntime.heroBuildSelection[itemId].unitId
            local tavern = hRuntime.heroBuildSelection[itemId].tavern
            if (unitId == nil or tavern == nil) then
                print_err("hhero.buildTavern-tgr_sell=nil")
                return
            end
            if (hhero.player_current_qty[p] >= hhero.player_allow_qty[p]) then
                hmessage.echo("|cffffff80你已经选够了|r", p)
                hitem.del(it, 0)
                cj.AddItemToStock(tavern, itemId, 1, 1)
                return
            end
            hhero.player_current_qty[p] = hhero.player_current_qty[p] + 1
            cj.RemoveItemFromStock(tavern, itemId)
            table.delete(itemId, randomChooseAbleList)
            hhero.addPlayerUnit(p, unitId, "tavern")
        end
    )
    cj.TriggerAddAction(
        tgr_random,
        function()
            local p = cj.GetTriggerPlayer()
            if (hhero.player_current_qty[p] >= hhero.player_allow_qty[p]) then
                hmessage.echo("|cffffff80你已经选够了|r", p)
                return
            end
            local txt = ""
            local qty = 0
            while (true) do
                local itemId = table.random(randomChooseAbleList)
                table.delete(itemId, randomChooseAbleList)
                local unitId = hRuntime.heroBuildSelection[itemId].unitId
                local tavern = hRuntime.heroBuildSelection[itemId].tavern
                if (unitId == nil or tavern == nil) then
                    print_err("hhero.buildTavern-tgr_random=nil")
                    return
                end
                txt = txt .. " " .. hslk_global.heroesKV[unitId].Name
                hhero.addPlayerUnit(p, unitId, "tavern")
                hhero.player_current_qty[p] = hhero.player_current_qty[p] + 1
                qty = qty + 1
                if (hhero.player_current_qty[p] >= hhero.player_allow_qty[p]) then
                    break
                end
            end
            hmessage.echo00(
                p,
                "已为您 |cffffff80random|r 选择了 " .. "|cffffff80" .. math.floor(qty) .. "|r 个单位：|cffffff80" .. txt .. "|r",
                0
            )
        end
    )
    cj.TriggerAddAction(
        tgr_repick,
        function()
            local p = cj.GetTriggerPlayer()
            if (hhero.player_current_qty[p] <= 0) then
                hmessage.echo00(p, "|cffffff80你还没有选过任何单位|r", 0)
                return
            end
            local qty = #hhero.player_heros
            for _, v in ipairs(hhero.player_heros[p]) do
                local heroId = cj.GetUnitTypeId(v)
                hhero.removePlayerUnit(p, v, "tavern")
                table.insert(randomChooseAbleList, hRuntime.heroBuildSelection[heroId].itemId)
            end
            hhero.player_heros[p] = {}
            hhero.player_current_qty[p] = 0
            hcamera.toXY(p, 0, hhero.build_params.x, hhero.build_params.y)
            hmessage.echo00(p, "已为您 |cffffff80repick|r 了 " .. "|cffffff80" .. qty .. "|r 个单位", 0)
        end
    )
    -- build
    local totalRow = 1
    local rowNowQty = 0
    local x = 0
    local y = hhero.build_params.y
    local tavern
    local tavernNowQty = {}
    for k, v in ipairs(hslk_global.heroesItems) do
        local itemId = v.itemID
        local heroId = v.heroID
        if (itemID > 0 and heroId > 0) then
            if (tavern == nil or tavernNowQty[tavern] == nil or tavernNowQty[tavern] >= hhero.build_params.allow_qty) then
                tavernNowQty[tavern] = 0
                if (rowNowQty >= hhero.build_params.per_row) then
                    rowNowQty = 0
                    totalRow = totalRow + 1
                    x = hhero.build_params.x
                    y = y - hhero.build_params.distance
                else
                    x = hhero.build_params.x + rowNowQty * hhero.build_params.distance
                end
                tavern = hunit.create(
                    {
                        whichPlayer = cj.Player(PLAYER_NEUTRAL_PASSIVE),
                        unitId = hhero.build_params.id,
                        x = x,
                        y = y,
                        during = during
                    }
                )
                cj.SetItemTypeSlots(tavern, hhero.build_params.allow_qty)
                cj.TriggerRegisterUnitEvent(tgr_sell, tavern, EVENT_UNIT_SELL_ITEM)
                rowNowQty = rowNowQty + 1
            end
            tavernNowQty[tavern] = tavernNowQty[tavern] + 1
            cj.AddItemToStock(tavern, itemId, 1, 1)
            hRuntime.heroBuildSelection[itemId] = {
                heroId = heroId,
                tavern = tavern
            }
            hRuntime.heroBuildSelection[heroId] = {
                itemId = itemId,
                tavern = tavern
            }
            table.insert(randomChooseAbleList, itemId)
        end
    end
    -- token
    for i = 1, bj_MAX_PLAYER_SLOTS, 1 do
        local p = cj.Player(i - 1)
        local u = hunit.create(
            {
                whichPlayer = p,
                unitId = hhero.build_token,
                x = hhero.build_params.x + hhero.build_params.per_row * 0.5 * hhero.build_params.distance,
                y = hhero.build_params.y - totalRow * 0.5 * hhero.build_params.distance,
                isPause = true
            }
        )
        hunit.del(u, during)
        cj.TriggerRegisterPlayerChatEvent(tgr_random, p, "-random", true)
        cj.TriggerRegisterPlayerChatEvent(tgr_repick, p, "-repick", true)
    end
    -- 还剩10秒给个选英雄提示
    htime.setTimeout(
        during - 10.0,
        function(t)
            local x1 = hhero.build_params.x + hhero.build_params.per_row * 0.5 * hhero.build_params.distance
            local y1 = hhero.build_params.y - totalRow * 0.5 * hhero.build_params.distance
            htime.delTimer(t)
            cj.DisableTrigger(tgr_repick)
            cj.DestroyTrigger(tgr_repick)
            hmessage.echo("还剩 10 秒，还未选择的玩家尽快啦～")
            cj.PingMinimapEx(x1, y1, 1.00, 254, 0, 0, true)
        end
    )
    -- 一定时间后clear
    htime.setTimeout(
        during - 0.5,
        function(t)
            htime.delTimer(t)
            cj.DisableTrigger(tgr_random)
            cj.DestroyTrigger(tgr_random)
            cj.DisableTrigger(tgr_sell)
            cj.DestroyTrigger(tgr_sell)
        end,
        "选择英雄"
    )
    -- 转移玩家镜头
    hcamera.toXY(nil, 0, hhero.build_params.x, hhero.build_params.y)
end
