-- Flow v1.0
-- Co-op admin menusu. Build 42 uyumlu.
-- F7 ile acilir.

Flow = Flow or {}
Flow.state = { godmode = false }

-- ============ GODMODE (tick-bazli) ============
-- setGodMod metodu yok; OnPlayerUpdate'te her tick iyilestirerek simule ediyoruz.
local function godmodeTick(player)
    if not player or not instanceof(player, "IsoPlayer") then return end
    if player:isDead() then return end
    local data = player:getModData()
    if not data or not data.FlowGod then return end
    
    local body = player:getBodyDamage()
    local stats = player:getStats()
    if body then
        body:RestoreToFullHealth()
    end
    if stats then
        stats:reset(CharacterStat.FATIGUE)
        stats:reset(CharacterStat.HUNGER)
        stats:reset(CharacterStat.THIRST)
        stats:reset(CharacterStat.ENDURANCE)
    end
    -- Olmesine izin verme (can 1.0 yap)
    if body then
        local health = body:getHealth()
        if health > 0 and health < 0.9 then
            player:setHealth(1.0)
        end
    end
end

Events.OnPlayerUpdate.Add(godmodeTick)

local function doToggleGodmode(enabled)
    local player = getPlayer()
    if not player then return end
    local data = player:getModData()
    data.FlowGod = enabled
end

-- ============ YARA / ENFEKSIYON IYILESTIR ============
local function doHealInjuries()
    local player = getPlayer()
    if not player then return end
    local bodyDmg = player:getBodyDamage()
    local visual = player:getHumanVisual()
    
    if bodyDmg then
        bodyDmg:RestoreToFullHealth()
        -- Enfeksiyon
        bodyDmg:setInfected(false)
        bodyDmg:setInfectionLevel(0)
        
        -- Vucut parcalarini sifirla
        local parts = bodyDmg:getBodyParts()
        if parts then
            for i = 0, parts:size() - 1 do
                local bp = parts:get(i)
                if bp then
                    bp:setStiffness(0)
                end
            end
        end
    end
    
    -- Kir ve kan
    if visual then
        pcall(function() visual:removeDirt() end)
        pcall(function() visual:removeBlood() end)
    end
    
    -- Hastalik
    local stats = player:getStats()
    if stats then
        stats:set(CharacterStat.SICKNESS, 0)
        stats:set(CharacterStat.PAIN, 0)
    end
    
    player:resetModel()
    pcall(function() player:resetModelNextFrame() end)
    player:Say("Iyilestim!")
end

-- ============ ACLIK / SUSUZLUK ============
local function doHungerThirst()
    local player = getPlayer()
    if not player then return end
    local stats = player:getStats()
    if stats then
        stats:set(CharacterStat.HUNGER, 0)
        stats:set(CharacterStat.THIRST, 0)
    end
    player:Say("Karnim tok, susuzlugum gecti.")
end

-- ============ YORGUNLUK / STRES / PANIK ============
local function doFatigueStress()
    local player = getPlayer()
    if not player then return end
    local stats = player:getStats()
    if stats then
        stats:set(CharacterStat.FATIGUE, 0)
        stats:set(CharacterStat.ENDURANCE, 1)
        stats:set(CharacterStat.STRESS, 0)
        stats:set(CharacterStat.PANIC, 0)
        stats:set(CharacterStat.BOREDOM, 0)
        stats:set(CharacterStat.ANGER, 0)
        stats:set(CharacterStat.MORALE, 100)
        stats:set(CharacterStat.SANITY, 1)
    end
    player:Say("Kafam rahat.")
end

-- ============ SKILL XP ============
local function doAddSkillLevel(skillName, targetLevel)
    local player = getPlayer()
    if not player then return end
    
    local ok, perk = pcall(function() return Perks.FromString(skillName) end)
    if not ok or not perk then
        player:Say("Skill bulunamadi: " .. tostring(skillName))
        return
    end
    
    -- Onceki level'i sifirla
    pcall(function() player:level0(perk) end)
    pcall(function() player:getXp():setXPToLevel(perk, 0) end)
    
    -- Istenen seviyeye cikar
    if targetLevel and targetLevel > 0 then
        for _ = 1, targetLevel do
            pcall(function() player:LevelPerk(perk, false) end)
        end
        pcall(function() player:getXp():setXPToLevel(perk, targetLevel) end)
    end
    player:Say("Skill ayarlandi: " .. skillName .. " -> " .. tostring(targetLevel))
end

-- ============ UI ============
local FlowPanel = ISPanel:derive("FlowPanel")

function FlowPanel:createChildren()
    ISPanel.createChildren(self)
    local y = 10
    local btnH = 25
    local btnW = self.width - 20
    local spacing = 30
    
    self.titleLabel = ISLabel:new(10, y, 20, "Flow", 1, 1, 1, 1, UIFont.Medium, true)
    self.titleLabel:initialise()
    self:addChild(self.titleLabel)
    y = y + spacing + 5
    
    self.godmodeBtn = ISButton:new(10, y, btnW, btnH, "Godmode: OFF", self, self.onGodmode)
    self.godmodeBtn:initialise()
    self:addChild(self.godmodeBtn)
    y = y + spacing
    
    self.healBtn = ISButton:new(10, y, btnW, btnH, "Yara ve Enfeksiyonlari Iyilestir", self, self.onHeal)
    self.healBtn:initialise()
    self:addChild(self.healBtn)
    y = y + spacing
    
    self.hungerBtn = ISButton:new(10, y, btnW, btnH, "Aclik ve Susuzlugu Gider", self, self.onHunger)
    self.hungerBtn:initialise()
    self:addChild(self.hungerBtn)
    y = y + spacing
    
    self.fatigueBtn = ISButton:new(10, y, btnW, btnH, "Yorgunluk/Stres/Panik Gider", self, self.onFatigue)
    self.fatigueBtn:initialise()
    self:addChild(self.fatigueBtn)
    y = y + spacing
    
    self.xpBtn = ISButton:new(10, y, btnW, btnH, "Skill Seviye Ayarla", self, self.onXp)
    self.xpBtn:initialise()
    self:addChild(self.xpBtn)
    y = y + spacing + 10
    
    self.closeBtn = ISButton:new(10, y, btnW, btnH, "Kapat", self, self.onClose)
    self.closeBtn:initialise()
    self:addChild(self.closeBtn)
    
    self:setHeight(y + btnH + 15)
end

function FlowPanel:onGodmode()
    Flow.state.godmode = not Flow.state.godmode
    doToggleGodmode(Flow.state.godmode)
    self.godmodeBtn:setTitle("Godmode: " .. (Flow.state.godmode and "ON" or "OFF"))
end

function FlowPanel:onHeal() doHealInjuries() end
function FlowPanel:onHunger() doHungerThirst() end
function FlowPanel:onFatigue() doFatigueStress() end

function FlowPanel:onXp()
    local modal = ISTextBox:new(
        getCore():getScreenWidth() / 2 - 200,
        getCore():getScreenHeight() / 2 - 75,
        400, 150,
        "Skill adi ve seviye (ornek: Strength,10 veya Axe,5). Skill isimleri: Fitness, Strength, Aiming, Reloading, Axe, LongBlade, ShortBlade, Maintenance, Carpentry, Cooking, Farming, Doctor, Electricity, Metalworking, Mechanics, Tailoring, Fishing, Trapping, PlantScavenging, Sprinting, Lightfooted, Nimble, Sneaking",
        "Strength,10",
        nil,
        function(_, button, param)
            if button.internal == "OK" then
                local input = button.parent.entry:getText()
                local name, levelStr = input:match("([^,]+),%s*(%d+)")
                if not name then
                    name = input:match("([^,]+)")
                    levelStr = "10"
                end
                if name then
                    name = name:gsub("^%s*(.-)%s*$", "%1")  -- trim
                    local lv = tonumber(levelStr) or 10
                    if lv < 0 then lv = 0 end
                    if lv > 10 then lv = 10 end
                    doAddSkillLevel(name, lv)
                end
            end
        end
    )
    modal:initialise()
    modal:addToUIManager()
end

function FlowPanel:onClose()
    self:setVisible(false)
    self:removeFromUIManager()
    Flow.panel = nil
end

function FlowPanel:new(x, y)
    local o = ISPanel:new(x, y, 280, 260)
    setmetatable(o, self)
    self.__index = self
    o.backgroundColor = {r=0, g=0, b=0, a=0.85}
    o.borderColor = {r=0.4, g=0.4, b=0.4, a=1}
    o.moveWithMouse = true
    return o
end

local function onKeyPressed(key)
    if key == Keyboard.KEY_F7 then
        if Flow.panel and Flow.panel:isVisible() then
            Flow.panel:onClose()
        else
            local x = getCore():getScreenWidth() / 2 - 140
            local y = 100
            Flow.panel = FlowPanel:new(x, y)
            Flow.panel:initialise()
            Flow.panel:addToUIManager()
        end
    end
end

Events.OnKeyPressed.Add(onKeyPressed)

local function onGameStart()
    local player = getSpecificPlayer(0)
    if player then
        player:Say("Flow yuklendi. F7 ile ac.")
    end
end

Events.OnGameStart.Add(onGameStart)
