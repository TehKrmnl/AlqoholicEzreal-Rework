if myHero.charName ~= "Ezreal" then return end 	

require "DamageLib"
require "Collision"

local myHero = _G.myHero

local LocalGetTickCount         = GetTickCount
local LocalVector		= Vector
local LocalCallbackAdd		= Callback.Add
local LocalCallbackDel		= Callback.Del
local LocalDrawLine		= Draw.Line
local LocalDrawColor		= Draw.Color
local LocalDrawCircle		= Draw.Circle
local LocalCastSpell            = Control.CastSpell
local LocalControlMove          = Control.Move
local LocalControlIsKeyDown	= Control.IsKeyDown
local LocalControlKeyUp  	= Control.KeyUp
local LocalControlKeyDown	= Control.KeyDown
local LocalGameCanUseSpell	= Game.CanUseSpell
local LocalGameHeroCount 	= Game.HeroCount
local LocalGameHero 		= Game.Hero
local LocalGameMinionCount 	= Game.MinionCount
local LocalGameMinion 		= Game.Minion
local ITEM_1			= ITEM_1
local ITEM_2			= ITEM_2
local ITEM_3			= ITEM_3
local ITEM_4			= ITEM_4
local ITEM_5			= ITEM_5
local ITEM_6			= ITEM_6
local ITEM_7			= ITEM_7
local _Q			= _Q
local _W			= _W
local _E			= _E
local _R		        = _R
local READY 		        = READY
local LocalTableInsert          = table.insert
local LocalTableSort            = table.sort
local LocalTableRemove          = table.remove;
local tonumber		        = tonumber
local ipairs		        = ipairs
local pairs		        = pairs

local Menu, Q, Q2, W, E, R

local Mode = function()
        if _G.SDK then
        	if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
                        return "Combo"
                elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] then
                        return "Harass"
                elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LANECLEARS] then
                        return "LaneClear"
                elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_JUNGLECLEAR] then
                        return "LaneClear"
                elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LASTHIT] then
                        return "LastHit"
                elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_FLEE] then
                        return "Flee"
                end
        elseif _G.Orbwalker then
        	if GOS:GetMode() == "Clear" then
        		return "LaneClear"
        	else
        	        return GOS:GetMode()
        	end
        end
        return ""
end

local LastMove = 0
local Move = function(pos)
	if LastMove + 250 <= LocalGetTickCount() then
		LocalControlMove(pos)
	        LastMove = LocalGetTickCount()
        end
end

local GetTarget = function(range)
        local orb
        if _G.SDK then
        	orb = _G.SDK.TargetSelector:GetTarget(range, _G.SDK.DAMAGE_TYPE_PHYSICAL, myHero.pos)
        elseif _G.Orbwalker then
        	orb = GOS:GetTarget(range, "AD")
        end
        return orb
end

local ValidTarget =  function(unit, range)
	local range = type(range) == "number" and range or math.huge
	return unit and unit.team ~= myHero.team and unit.valid and unit.distance <= range and not unit.dead and unit.isTargetable and unit.visible
end

local GetEnemyHeroes = function()
        local result = {}
	for i = 1, LocalGameHeroCount() do
		local Hero = LocalGameHero(i)
		if Hero.isEnemy then
			LocalTableInsert(result, Hero)
		end
	end
	return result
end

local GetMinions = function(range)
        local result = {}
	for i = 1, LocalGameMinionCount() do
		local minion = LocalGameMinion(i)
		if minion and ValidTarget(minion, range) and minion.isEnemy and minion.team ~= 300 then
			LocalTableInsert(result, minion)
		end
	end
	return result
end

local GetJungleMinions = function(range)
        local result = {}
	for i = 1, LocalGameMinionCount() do
		local minion = LocalGameMinion(i)
		if minion and ValidTarget(minion, range) and minion.team == 300 then
			LocalTableInsert (result, minion)
		end
	end
	return result
end

local GetDistanceSqr = function(Pos1, Pos2)
	local Pos2 = Pos2 or myHero.pos
	local dx = Pos1.x - Pos2.x
	local dz = (Pos1.z or Pos1.y) - (Pos2.z or Pos2.y)
	return dx^2 + dz^2
end

local GetDistance = function(Pos1, Pos2)
	return math.sqrt(GetDistanceSqr(Pos1, Pos2))
end

local GetPercentHP = function(unit)
        return 100 * unit.health / unit.maxHealth
end

local GetPercentMP = function(unit)
        return 100 * unit.mana / unit.maxMana
end

local HealthPrediction = function(unit, time)
        local orb
        if _G.SDK then
        	orb = _G.SDK.HealthPrediction:GetPrediction(unit, time)
        elseif _G.Orbwalker then
        	orb = GOS:HP_Pred(unit, time)
        end
        return orb
end

local VectorPointProjectionOnLineSegment = function(v1, v2, v)
	local cx, cy, ax, ay, bx, by = v.x, (v.z or v.y), v1.x, (v1.z or v1.y), v2.x, (v2.z or v2.y)
        local rL = ((cx - ax) * (bx - ax) + (cy - ay) * (by - ay)) / ((bx - ax) ^ 2 + (by - ay) ^ 2)
        local pointLine = { x = ax + rL * (bx - ax), y = ay + rL * (by - ay) }
        local rS = rL < 0 and 0 or (rL > 1 and 1 or rL)
        local isOnSegment = rS == rL
        local pointSegment = isOnSegment and pointLine or {x = ax + rS * (bx - ax), y = ay + rS * (by - ay)}
	return pointSegment, pointLine, isOnSegment
end

local EnemyMinionsOnLine = function(sp, ep, width)
        local c = 0
        for i, minion in pairs(GetMinions()) do
        	if minion and not minion.dead and minion.isEnemy then
        		local pointSegment, pointLine, isOnSegment = VectorPointProjectionOnLineSegment(sp, ep, minion.pos)
        		if isOnSegment and GetDistanceSqr(pointSegment, minion.pos) < (width + minion.boundingRadius)^2 and GetDistanceSqr(sp, ep) > GetDistanceSqr(sp, minion.pos) then
				c = c + 1
			end
        	end
        end
        return c
end

local GetBestLinearFarmPos = function(range, width)
	local pos, hit = nil, 0
	for i, minion in pairs(GetMinions()) do
		if minion and not minion.dead and minion.isEnemy then
			local EP = myHero.pos:Extended(minion.pos, range)
			local C = EnemyMinionsOnLine(myHero.pos, EP, width)
			if C > hit then
				hit = C
				pos = minion.pos
			end
		end
	end
	return pos, hit
end

local CircleCircleIntersection = function(c1, c2, r1, r2) 
        local D = GetDistance(c1, c2)
        if D > r1 + r2 or D <= math.abs(r1 - r2) then return nil end 
        local A = (r1 * r2 - r2 * r1 + D * D) / (2 * D) 
        local H = math.sqrt(r1 * r1 - A * A)
        local Direction = (c2 - c1):Normalized() 
        local PA = c1 + A * Direction 
        local S1 = PA + H * Direction:Perpendicular() 
        local S2 = PA - H * Direction:Perpendicular() 
        return S1, S2 
end

local ClosestToMouse = function(p1, p2) 
        if GetDistance(mousePos, p1) > GetDistance(mousePos, p2) then return p2 else return p1 end
end

local DrawLine3D = function(x1, y1, z1, x2, y2, z2, width, color)
	local xyz_1 = LocalVector(x1, y1, z1):To2D()
	local xyz_2 = LocalVector(x2, y2, z2):To2D()
	LocalDrawLine(xyz_2.x, xyz_2.y, xyz_1.x, xyz_1.y, width or 1, color or LocalDrawColor(255, 255, 255, 255))
end

local DrawRectangleOutline = function(startPos, endPos, width, color, ex)     
        local c1 = startPos+Vector(Vector(endPos)-startPos):Perpendicular():Normalized()*width     
        local c2 = startPos+Vector(Vector(endPos)-startPos):Perpendicular2():Normalized()*width     
        local c3 = endPos+Vector(Vector(startPos)-endPos):Perpendicular():Normalized()*width     
        local c4 = endPos+Vector(Vector(startPos)-endPos):Perpendicular2():Normalized()*width     
        DrawLine3D(c1.x,c1.y,c1.z,c2.x,c2.y,c2.z,math.ceil(width/ex),color)     
        DrawLine3D(c2.x,c2.y,c2.z,c3.x,c3.y,c3.z,math.ceil(width/ex),color)     
        DrawLine3D(c3.x,c3.y,c3.z,c4.x,c4.y,c4.z,math.ceil(width/ex),color)     
        DrawLine3D(c1.x,c1.y,c1.z,c4.x,c4.y,c4.z,math.ceil(width/ex),color) 
end 

local DrawTriangle = function(vector3, color, thickness, size, rot, speed, yShift, yLevel) 	
        if not vector3 then vector3 = LocalVector(myHero.pos) end 	
        if not color then color = LocalDrawColor(255, 255, 255, 255) end 	
        if not thickness then thickness = 3 end 	
        if not size then size = 75 end 	
        if not speed then speed = 1 else speed = 1-speed end
        vector3.y = vector3.y + yShift + (rot * yLevel) 
        local a2v = function(a, m) m = m or 1 return math.cos(a) * m, math.sin(a) * m end
        local RX1, RZ1 = a2v((rot*speed), size) 	
        local RX2, RZ2 = a2v((rot*speed) + math.pi*0.33333, size) 	
        local RX3, RZ3 = a2v((rot*speed) + math.pi*0.66666, size) 	
        local PX1 = vector3.x + RX1 	
        local PZ1 = vector3.z + RZ1 	
        local PX2 = vector3.x + RX2 	
        local PZ2 = vector3.z + RZ2 	
        local PX3 = vector3.x + RX3 	
        local PZ3 = vector3.z + RZ3 	
        local PXT1 = vector3.x - (PX1 - vector3.x) 	
        local PZT1 = vector3.z - (PZ1 - vector3.z) 	
        local PXT3 = vector3.x - (PX3 - vector3.x) 	
        local PZT3 = vector3.z - (PZ3 - vector3.z)  	
        DrawLine3D(PXT1, vector3.y, PZT1, PXT3, vector3.y, PZT3, thickness, color) 	
        DrawLine3D(PXT3, vector3.y, PZT3, PX2, vector3.y, PZ2, thickness, color) 	
        DrawLine3D(PX2, vector3.y, PZ2, PXT1, vector3.y, PZT1, thickness, color) 
end

local Mode = function()
require("MapPositionGOS")

-- Menu
Menu = MenuElement({type = MENU, id = "AlqoholicEzreal (Reworked by Krmnl) (Reworked by Krmnl)", name = "Alqohol - AlqoholicEzreal (Reworked by Krmnl)", lefticon="https://cdn.discordapp.com/emojis/249237025754972171.png"})

-- [[Keys]]
Menu:MenuElement({type = MENU, id = "Key", name = "Key Settings"})
Menu.Key:MenuElement({id = "ComboKey", name = "Combo Key", key = 32})
Menu.Key:MenuElement({id = "HarassKey", name = "Harass Key", key = 67})
Menu.Key:MenuElement({id = "FarmKey", name = "Farm Key", key = 86})
Menu.Key:MenuElement({id = "LastHitKey", name = "Last Hit Key", key = 88})

-- [[Combo]]
Menu:MenuElement({type = MENU, id = "Combo", name = "Combo Settings"})
Menu.Combo:MenuElement({id = "ComboQ", name = "Use Q", value = true})
Menu.Combo:MenuElement({id = "ComboW", name = "Use W", value = true})
Menu.Combo:MenuElement({id = "ComboR", name = "Use R - DISABLED FOR THE MOMENT", value = true})

-- [[Harass]]
Menu:MenuElement({type = MENU, id = "Harass", name = "Harass Settings"})
Menu.Harass:MenuElement({id = "HarassQ", name = "Use Q", value = true})
Menu.Harass:MenuElement({id = "HarassW", name = "Use W", value = true})
Menu.Harass:MenuElement({id = "HarassMana", name = "Min. Mana", value = 40, min = 0, max = 100})

-- [[Farm]]
Menu:MenuElement({type = MENU, id = "Farm", name = "Farm Settings"})
Menu.Farm:MenuElement({id = "FarmSpells", name = "Farm Spells", value = true})
Menu.Farm:MenuElement({id = "FarmQ", name = "Use Q", value = true})
Menu.Farm:MenuElement({id = "FarmMana", name = "Min. Mana", value = 40, min = 0, max = 100})

-- [[LastHit]]
Menu:MenuElement({type = MENU, id = "LastHit", name = "Last Hit Settings - WORK IN PROGRESS"})
Menu.LastHit:MenuElement({id = "LastHitQ", name = "Use Q", value = true})
Menu.LastHit:MenuElement({id = "LastHitMana", name = "Min. Mana", value = 40, min = 0, max = 100})

-- [[Misc]]
Menu:MenuElement({type = MENU, id = "Misc", name = "Misc Settings"})
Menu.Misc:MenuElement({id = "MaxRange", name = "Max Range Limiter", value = 0.9, min = 0.5, max = 1, step = 0.01})
Menu.Misc:MenuElement({type = SPACE, id = "ToolTip", name = "eg. X = 0.80 (Q.Range = (1150 * 0.80) = 920)"})
Menu:MenuElement({type = MENU, name = "Auto Level Up",  id = "lvlup"})
        Menu.lvlup:MenuElement({name = "Use Auto Level Up", id = "Use", value = true})
        Menu.lvlup:MenuElement({name = "Don't Use At 1 Lvl", id = "flvl", value = true})
        Menu.lvlup:MenuElement({name = "Sequence Order", id = "Order", drop = {"Recomended for Ezreal", "Q > E > Q", "W > Q > R","Q > E > Q","E > R > E","E > W > W", "R > W > W"}})
-- [[Draw]]
Menu:MenuElement({type = MENU, id = "Draw", name = "Drawing Settings"})
Menu.Draw:MenuElement({id = "DrawQ", name = "Draw Q", value = true})
Menu.Draw:MenuElement({id = "DrawW", name = "Draw W", value = true})
Menu.Draw:MenuElement({id = "DrawR", name = "Draw R", value = true})
Menu.Draw:MenuElement({id = "DrawTarget", name = "Draw Target", value = true})


-- [Checks]
-- GetTarget - Returns target
function GetTarget(targetRange)
	local result
	for i = 1,Game.HeroCount()  do
		local hero = Game.Hero(i)
		if isValidTarget(hero, targetRange) and hero.team ~= myHero.team then
      		result = hero
      		break
		end
	end
	return result
end

function GetFarmTarget(minionRange)
	local getFarmTarget
	for j = 1,Game.MinionCount()	do
		local minion = Game.Minion(j)
		if isValidTarget(minion, minionRange) and minion.team ~= myHero.team then
      		getFarmTarget = minion
      		break
		end
	end
	return getFarmTarget
end


-- [Events]
-- OnUpdate
Callback.Add('Tick',function()

	if Menu.Key.ComboKey:Value()  then
		if isReady(_Q) and Menu.Combo.ComboQ:Value() then
			local qTarget = GetTarget(Q.Range * Menu.Misc.MaxRange:Value())
			if qTarget and qTarget:GetCollision(Q.Radius, Q.Speed, Q.Delay) == 0 then
				local qPos = qTarget:GetPrediction(Q.Speed, Q.Delay)
				Control.CastSpell(HK_Q, qPos)
			end
		end
		if isReady(_W) and Menu.Combo.ComboW:Value() then
			local wTarget = GetTarget(W.Range * Menu.Misc.MaxRange:Value())
			if wTarget then
				local wPos = wTarget:GetPrediction(W.Speed, W.Delay)
				Control.CastSpell(HK_W, wPos)
			end
		end
		-- if isReady(_R) and Menu.Combo.ComboR:Value() then
		-- 	local rTarget = GetTarget(R.Range)
		-- 	if rTarget then
		-- 		local rPos = rTarget:GetPrediction(R.Speed, R.Delay)
		-- 		if true or true then
		-- 			Control.CastSpell(HK_R, rPos)
		-- 		end
		-- 	end
		-- end
	end

	if Menu.Key.HarassKey:Value() and (myHero.mana/myHero.maxMana >= Menu.Harass.HarassMana:Value()/100) then
		if isReady(_Q) and Menu.Harass.HarassQ:Value() then
			local qTarget = GetTarget(Q.Range * Menu.Misc.MaxRange:Value())
			if qTarget and qTarget:GetCollision(Q.Radius, Q.Speed, Q.Delay) == 0 then
				local qPos = qTarget:GetPrediction(Q.Speed, Q.Delay)
				Control.CastSpell(HK_Q, qPos)
			end
		end
		if isReady(_W) and Menu.Harass.HarassW:Value() then
			local wTarget = GetTarget(W.Range * Menu.Misc.MaxRange:Value())
			if wTarget then
				local wPos = wTarget:GetPrediction(W.Speed, W.Delay)
				Control.CastSpell(HK_W, wPos)
			end
		end
	end

	if Menu.Key.FarmKey:Value() and Menu.Farm.FarmSpells:Value() and (myHero.mana/myHero.maxMana >= Menu.Farm.FarmMana:Value()/100) then
		if isReady(_Q) and Menu.Farm.FarmQ:Value() then
			local qMinion = GetFarmTarget(Q.Range * Menu.Misc.MaxRange:Value())
			if qMinion then
				local qMinPos = qMinion:GetPrediction(Q.Speed, Q.Delay)
				Control.CastSpell(HK_Q, qMinPos)
			end
		end
	end

end)

-- OnLoad
Callback.Add('Load',function()
    Menu:MenuElement({name = " ", drop = {"Script Info"}})
    Menu:MenuElement({name = "Script Version", drop = {"1.0"}})
    Menu:MenuElement({name = "League Version", drop = {"7.8"}})
    Menu:MenuElement({name = "Author", drop = {"Alqohol (Krmnl Rework)"}})
end)

-- OnDraw
function OnDraw()
	if myHero.dead then return end

	if Menu.Draw.DrawQ:Value()	then
		Draw.Circle(myHero.pos,Q.Range * Menu.Misc.MaxRange:Value(),1,Draw.Color(255, 255, 255, 255))
	end
	if Menu.Draw.DrawW:Value()	then
		Draw.Circle(myHero.pos,W.Range * Menu.Misc.MaxRange:Value(),1,Draw.Color(255, 255, 255, 255))
	end
	if Menu.Draw.DrawR:Value()	then
		Draw.Circle(myHero.pos,R.Range * Menu.Misc.MaxRange:Value(),1,Draw.Color(255, 255, 255, 255))
	end

    if Menu.Draw.DrawTarget:Value() then
	    local drawTarget = GetTarget(Q.Range)
	    if drawTarget then
		    Draw.Circle(drawTarget.pos,80,3,Draw.Color(255, 255, 0, 0))
	    end
    end
end


-- isReady - Returns bool
function isReady(slot)
	return (myHero:GetSpellData(slot).currentCd == 0) and (myHero:GetSpellData(spellSlot).mana < myHero.mana) and (myHero:GetSpellData(slot).level >= 1) -- Thanks MeoBeo
end

-- isValidTarget - Returns bool
function isValidTarget(obj, spellRange)
	return obj ~= nil and obj.valid and obj.visible and not obj.dead and obj.isTargetable and obj.distance <= spellRange

print("AlqoholicEzreal (Reworked by Krmnl) - Loaded | Current orbwalker: "..CurrentOrbName()) 


end
