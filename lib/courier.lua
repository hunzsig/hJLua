---@class hcourier 信使
hcourier = {}

---@private
--- 注册hlua框架默认的信使技能，极速做图
hitem.matchAutoSkills = function(whichCourier)
    hevent.pool(whichCourier, hevent_default_actions.courier.defaultSkills, function(tgr)
        cj.TriggerRegisterUnitEvent(tgr, whichCourier, EVENT_UNIT_SPELL_EFFECT)
    end)
end