function dprint()
    if (string.len(dmsg) >1) then
        print(dmsg)
        dmsg = ""
      end
end


-- percentage must be 0~1
function expPercent(percentage, exp)
    return percentage^(1/exp)
end


function anaPercent(anaVal)
    if (xbc==nil or not btEnabled or math.abs(anaVal) < anaDeadZone) then
        return 0
    end
    -- anaVal=-32767~0~+32767
    -- anaDeadZone ~=~ 3000~3500
    -- Minimal push stick ~=~ 10000
    local anaMax = 32767
    local anaMin = anaDeadZone
    local positive = 1
    local anaValAbs=math.abs(anaVal)
    if (anaValAbs ~= anaVal) then
        positive = -1
    end
    local anaPercentAbs = (anaValAbs-anaMin)/(anaMax-anaMin)
    local anaPercentVal = positive*expPercent(anaPercentAbs, anaSensitivityExp)
    return anaPercentVal
end


-- XZY Movement: Left/Right, Forward/Back, Up/Down
-- Y Rotate
function anaMoveRotate(anaValX, anaValZ, anaValY, anaValRY)
    local anaPercentX=anaPercent(anaValX)
    local anaPercentZ=anaPercent(anaValZ)
    local anaPercentY=anaPercent(anaValY)
    local anaPercentRY=anaPercent(anaValRY)
    
    local abs=math.abs
    -- any axis movement
    if (abs(anaPercentX)+abs(anaPercentY)+abs(anaPercentZ)+abs(anaPercentRY) == 0) then
        return
    end
    
    eular=getEular()
    anaMovePlane(anaPercentX*anaMoveFactor, anaPercentZ*anaMoveFactor)
    anaMoveElev(anaPercentY*anaMoveFactor)
    anaRotate(anaPercentRY*anaRotateFactor)
end

function anaMoveElev(move)
    -- Word Y: up+, down-
    if (move == 0) then return end
    writeDouble(posYAddr, readDouble(posYAddr)+move)
end

function anaMovePlane(moveX, moveZ)
    -- Word X: rigt=+, back=-
    -- Word Z: forwad=-, back=+
    if (moveX == 0) and (moveZ == 0) then return end

    local moveDist = math.sqrt(moveX^2+moveZ^2)
    local moveAngle = math.deg(math.atan(-moveX/moveZ))
    if (moveZ <  0) then
        moveAngle = moveAngle + 180
    end
    -- Would XYZ always changed by reseting the view
    -- So the initial eular.y should by ignore, 
    -- It needs to remeber the value or count the total rotation after the view is reseted.
    -- Monitor other mem addr which affected by reset may help, but still has some issue.
    -- The best way should be move along the realtime HMD direction.
    
    -- No need to add original eular.y
    local eularRst = getEularRst()
    local targetAngle = (eular.y - eularRst.y  + moveAngle)%360
    --local targetAngle = moveAngle
    
    local dX = -moveDist * math.sin(math.rad(targetAngle))
    local dZ = -moveDist * math.cos(math.rad(targetAngle))
    local targetX = readDouble(posXAddr) + dX
    local targetZ = readDouble(posZAddr) + dZ
    --print (">>> rstAngle:"..eularRst.y.." ,fwdAngle:"..eular.y..", moveAngle:"..moveAngle..", targetAngle:"..targetAngle..", Dist:"..moveDist..", mX:"..moveX..", mZ:"..moveZ..", dX:"..dX..", dZ:"..dZ)
    writeDouble(posXAddr, targetX)
    writeDouble(posZAddr, targetZ)
end

-- Y Rotate
function anaRotate(rotAngle)
    -- Rest Vew: In Game=Oculus Rest View, Changes World XYZ. Front = 0 degree angle
    -- rotQy: Changes virtual screen viewing direction (BOTH VR and Monitor), doesnot change World XYZ. HMD angle clockwise
    -- rotQyHMD: Changes VR HEAD direction to follow viewing change, doesnot change World XYZ. HMD angle anticlockwise. (opposite with rotQy)
    -- compare to the value of rotQy--
    -- Turn the Headset to the right and reset, rotQy is +90, and world turns.
    -- Increase rotQy by 90=180, the World XYZ doesnot reset.
    -- The Heaset doesnot really changed its direction, but the game think we are turning head to the right
    -- So the Virtual window turn to Left and shows the 'LEFT side'
    -- rotQyHMD turns the virtual window back to in front of the face, but this doesnot changes the view in virtual window.
    -- So the rotQy value for HEAD set is clockwise, for virtual window view is anticlockwise.
    if (rotAngle == 0) then return end
    local ey = (eular.y-rotAngle) % 360
    local q=eulerToQuat(newE(0,ey,0))
    -- Monitor and HMD use differnt rotation addresses --
    writeDouble(rotQyAddr, q.y)
    writeDouble(rotQyHMDAddr, -q.y)
    writeDouble(rotQwAddr, q.w)
    writeDouble(rotQwHMDAddr, q.w)
    
    -- fix rotation center
    -- There some left/rigt drift with the rotaion, 
    -- accourding to the HMD distance to the Oculus reset point
    -- No proper method to fix this.
    --anaMovePlane(-rotAngle/1000*1, -rotAngle/1000*1)
    
    
end

-- create Quaternion table --
function newQ(x,y,z,w)
    local q={}
    q.x=x
    q.y=y
    q.z=z
    q.w=w
    return q
end
-- create Eular table --
function newE(x,y,z)
    local e={}
    e.x=x
    e.y=y
    e.z=z
    return e
end

-- Convert Quaternion to Eular angles --
function quatToEular(q)
    local e={} -- Eular angles
	local n = q.x * q.x + q.y * q.y + q.z * q.z + q.w * q.w
	n = 1 / math.sqrt(n)

	local x = q.x * n
	local y = q.y * n
	local z = q.z * n
	local w = q.w * n

	local check = 2 * (-y * z + w * x)

    local rad2Deg=math.rad2Deg
    local atan2=math.atan2
    local asin=math.asin
    if check < -0.999999 then
        e.x=-90
        e.y=-atan2(2 * (x * z - w * y), 1 - 2 * (y * y + z * z)) * rad2Deg
        e.z=0
    elseif (check > 0.999999) then
        e.x=90
        e.y=-atan2(2 * (x * z - w * y), 1 - 2 * (y * y + z * z)) * rad2Deg
        e.z=0
    else
        e.x=asin(check) * rad2Deg
        e.y=atan2(2 * (x * z + w * y), 1 - 2 * (x * x + y * y)) * rad2Deg
        e.z=atan2(2 * (x * y + w * z), 1 - 2 * (x * x + z * z)) * rad2Deg
    end
    return e
end

-- Convert Eular angles to Quaternion --
function eulerToQuat(e)
    local q = {}

	e.x = e.x * 0.5 * math.deg2Rad
    e.y = e.y * 0.5 * math.deg2Rad
    e.z = e.z * 0.5 * math.deg2Rad

	local sinX = math.sin(e.x)
    local cosX = math.cos(e.x)
    local sinY = math.sin(e.y)
    local cosY = math.cos(e.y)
    local sinZ = math.sin(e.z)
    local cosZ = math.cos(e.z)

    q.w = cosY * cosX * cosZ + sinY * sinX * sinZ
    q.x = cosY * sinX * cosZ + sinY * cosX * sinZ
    q.y = sinY * cosX * cosZ - cosY * sinX * sinZ
    q.z = cosY * cosX * sinZ - sinY * sinX * cosZ

	return q
end


function xbcButtonDown(btn)
    if (not xbcButtonStat[btn]) then
        print("> "..btn.." DOWN")
        xbcButtonStat[btn]=true
    end
end
function xbcButtonUp(btn)
    xbcButtonStat[btn]=false
        print("> "..btn.." UP")
end

-- Calculate Orientation Angle --
function getEular() -- Orientation of current forward
    local eular=quatToEular(newQ(0,readDouble(rotQyAddr),0,readDouble(rotQwAddr)))
    --eular=quatToEular(newQ(0,readDouble(rotQyHMDAddr),0,readDouble(rotQwHMDAddr)))
    return eular
end
function getEularHMD() -- Orientation in HMD
    local eular=quatToEular(newQ(0,readDouble(rotQyHMDAddr),0,readDouble(rotQwHMDAddr)))
    return eular
end
function getEularRst() -- Orientation of the reset view
    local eular=quatToEular(newQ(0,readDouble(rotQyRstAddr),0,readDouble(rotQwRstAddr)))
    return eular
end

-- timer function --
function xbcGetState()
    local btn
    
    -- Read Xbox Controller state
    xbc = getXBox360ControllerState();
    if (xbc==nil) then
       return
    end

        -- stop vibration --
    if (vibStart>0) and (os.clock()-vibStart > vibDuration) then
        vibStart=0
        setXBox360ControllerVibration(xbc.ControllerID, 0, 0)
    end

    btn="GAMEPAD_LEFT_SHOULDER"
    if (xbc[btn]) then
         xbcButtonDown(btn)
    else
        -- BTN released, do something
        if (xbcButtonStat[btn]) then
            xbcButtonUp(btn)
            btEnabled= not btEnabled
            --Vibration when enabled
            if (btEnabled) then
               vibStart=os.clock()
               setXBox360ControllerVibration(xbc.ControllerID, 35535, 0)
            end
        end
    end

    btn="GAMEPAD_RIGHT_SHOULDER"
    if (xbc[btn]) then
        xbcButtonDown(btn)
    else
        -- BTN released, do something
        if (xbcButtonStat[btn]) then
            xbcButtonUp(btn)
            -- Change speed factors
            if (anaFactorSel==1) then
                anaFactorSelFwd=1
            elseif  (anaFactorSel==#anaMoveFactors) then
                anaFactorSelFwd=-1
            end
            -- bi-direction
            --anaFactorSel = anaFactorSel + anaFactorSelFwd
            -- single direction
            anaFactorSel = (anaFactorSel % #anaMoveFactors)+1
            anaMoveFactor = anaMoveFactors[anaFactorSel]
            anaRotateFactor = anaRotateFactors[anaFactorSel]
            --Vibration when back to def factor
            if (anaFactorSel==#anaMoveFactors) then
               vibStart=os.clock()
               setXBox360ControllerVibration(xbc.ControllerID, 0, 65535)
            end
        end
    end

    --Move and Rotate with Analog Sticks
    -- parameters analog axis for: Move X, Move Z, Move Y, Roate Y (Y is up/down)
    -- XZY Movement: Left/Right, Forward/Back, Up/Down
    -- Rotate: Left/Right
    if (controlStyle == 1) then --CS style
        anaMoveRotate(xbc.ThumbLeftX, xbc.ThumbLeftY, xbc.ThumbRightY, xbc.ThumbRightX)
    elseif (controlStyle == 2) then --Racing style
        anaMoveRotate(xbc.ThumbRightX, xbc.ThumbRightY, xbc.ThumbLeftY, xbc.ThumbLeftX)
    else -- Space Fighter Style
        anaMoveRotate(xbc.ThumbLeftX, xbc.ThumbRightY, xbc.ThumbLeftY, xbc.ThumbRightX)
    end
end


function debugDisp()

    sec=sec+1
    local msg = ""
    local xbcMsg = ""
    local xbcConnStr = ""
    if (xbc==nil) then
        xbcConnStr="NOT Connected"
    else
        xbcConnStr="OK"
        -- XBC Analog Stick range: XY -32767~32767, dz range 1017~2329
        xbcMsg =          " - LX:"..xbc.ThumbLeftX..", LY:"..xbc.ThumbLeftY
        xbcMsg = xbcMsg..", RX:"..xbc.ThumbRightX..", RY:"..xbc.ThumbRightY
        xbcMsg = xbcMsg..", %= LX:"..anaPercent(xbc.ThumbLeftX)
        xbcMsg = xbcMsg..   ", LY:"..anaPercent(xbc.ThumbLeftY)
        xbcMsg = xbcMsg..   ", RX:"..anaPercent(xbc.ThumbRightX)
        xbcMsg = xbcMsg..   ", RY:"..anaPercent(xbc.ThumbRightY)
    end
    msg = "v5, sec:"..sec..", XBC:"..xbcConnStr..", Enabled: "..tostring(btEnabled)
    msg = msg..xbcMsg
    if (eular == nil) then
        eular=getEular()
    end
    local e=getEular()
    msg = msg..nl.."Angle X:"..e.x.." ,Y:"..e.y.." ,Z:"..e.z.." ,Fac Sel:"..anaFactorSel..", Move:"..anaMoveFactor..", Rotate:"..anaRotateFactor
    --print(msg)
    --dprint()
end

function infoUpdate()

    if (xbc==nil) then
        f.t_xbcConnected.checked=false
    else
        f.t_xbcConnected.checked=true
        -- XBC Analog Stick range: XY -32767~32767, dz range 1017~2329
        xbcMsg =          " - LX:"..xbc.ThumbLeftX..", LY:"..xbc.ThumbLeftY
        xbcMsg = xbcMsg..", RX:"..xbc.ThumbRightX..", RY:"..xbc.ThumbRightY
        xbcMsg = xbcMsg..", %= LX:"..anaPercent(xbc.ThumbLeftX)
        xbcMsg = xbcMsg..   ", LY:"..anaPercent(xbc.ThumbLeftY)
        xbcMsg = xbcMsg..   ", RX:"..anaPercent(xbc.ThumbRightX)
        xbcMsg = xbcMsg..   ", RY:"..anaPercent(xbc.ThumbRightY)
    end
    f.t_hackEnabled.checked = btEnabled

    local posX = readDouble(posXAddr)
    local posY = readDouble(posYAddr)
    local posZ = readDouble(posZAddr)
    local posXrst = readDouble(posXRstAddr)
    local posYrst = readDouble(posYRstAddr)
    local posZrst = readDouble(posZRstAddr)
    --
    local mapPosX = readFloat(mapPosXAddr)
    local mapPosY = readFloat(mapPosYAddr)
    local mapPosZ = readFloat(mapPosZAddr)
    local mapRelX = readFloat(mapRelXAddr)
    local mapRelY = readFloat(mapRelYAddr)
    local mapRelZ = readFloat(mapRelZAddr)
    --
    local dtX = (posX-posXrst)
    local dtY = (posY-posYrst)
    local dtZ = (posZ-posZrst)
    --
    local chaX = readFloat(chaXAddr)
    local chaY = readFloat(chaYAddr)
    local chaZ = readFloat(chaZAddr)
    
    f.e_hmdX.text = posX
    f.e_hmdZ.text = posZ
    f.e_hmdY.text = posY
    f.e_cenX.text = posXrst
    f.e_cenZ.text = posZrst
    f.e_cenY.text = posYrst
    f.e_dtX.text = dtX
    f.e_dtZ.text = dtZ
    f.e_dtY.text = dtY
    f.e_mapX.text = mapPosX
    f.e_mapZ.text = mapPosZ
    f.e_mapY.text = mapPosY
    f.e_relX.text = mapRelX
    f.e_relZ.text = mapRelZ
    f.e_relY.text = mapRelY
    f.e_chaX.text = chaX
    f.e_chaZ.text = chaZ
    f.e_chaY.text = chaY
    -- calc --
    f.b_cal1.caption ="Rel/Dt"
    f.e_cal1a.text = (mapRelX+35.57421875)/dtX
    f.e_cal1b.text = (mapRelZ-38.003841400146)/dtZ
    f.e_cal1c.text = (mapRelY+49.963916778564)/dtY
    f.b_cal3.caption ="Rel-init"
    f.e_cal13a.text = (mapRelX+35.57421875)/dtX
    f.e_cal13b.text = (mapRelZ-38.003841400146)/dtZ
    f.e_cal13c.text = (mapRelY+49.963916778564)/dtY
    f.b_cal2.caption ="Rel/pos"
    f.e_cal2a.text = mapRelX/posX
    f.e_cal2b.text = mapRelZ/posZ
    f.e_cal2c.text = mapRelY/posY
    
-- Orientation -
    f.e_hmdQy.text = readDouble(rotQyAddr)
    f.e_hmdQw.text = readDouble(rotQwAddr)
    if (eular == nil) then
        eular=getEular()
    end
    local e=getEular()
    local eRst=getEularRst()
    if (e.y ~= nil) then
        f.e_hmdAngle.text = e.y
        f.e_hmdAngleRst.text = eRst.y
    end
    --msg = msg..nl.."Angle X:"..e.x.." ,Y:"..e.y.." ,Z:"..e.z.." ,Fac Sel:"..anaFactorSel..", Move:"..anaMoveFactor..", Rotate:"..anaRotateFactor

    f.e_t1.text = readFloat(mapRelXAddr)
    if (chaX ~= nil) and (chaX ~= 0) then
        f.e_t2.text = mapRelX/chaX
    end

    
end
function timerStart()
    timer_setEnabled(t1,true)
    timer_setEnabled(t2,true)
    timer_setEnabled(t3,true)
end

function timerStop()
    timer_setEnabled(t1,false)
    timer_setEnabled(t2,false)
    timer_setEnabled(t3,false)
    --t1.destroy()
    --t2.destroy()
    --t3.destroy()
    print("Stopped")
end
function timer1_tick(timer) 
    --debugDisp()
    if DoneState == true then
        timer.destroy()
    end
end
function timer2_tick(timer) 
    xbcGetState()
    if DoneState == true then
        timer.destroy()
    end
end
function timer3_tick(timer) 
    infoUpdate()
    if DoneState == true then
        timer.destroy()
    end
end

function FormClose(sender)
    timerStop()
    return caHide --Possible options: caHide, caFree, caMinimize, caNone
end
math.deg2Rad = math.pi / 180
math.rad2Deg = 180 / math.pi


PROCESS_NAME = 'LandfallClient-Win64-Shipping.exe'
getAutoAttachList().add(PROCESS_NAME)

-- Parameters --

-- timer is inaccure --
--interval/10sec should triggered/ real triggered
--100ms :100  - 91
--50ms  :200  - 163
--20ms  :500  - 322
--10ms  :1000 - 637
--5ms   :2000 - 651
t2_interval = 10 -- input timer

autoStart=true
btEnabled=true
-- Control Style
-- 1: CS style: Left hand walk/strafe, right hand turn/elev
-- 2: Racing style: Left hand turn/elev, right hand drift/gas
-- 3: Space Fighter Style: Left hand 3D strafe, right hand turn/throttle
controlStyle =1
anaSensitivityExp = 1/3
anaFactorSel = 1 -- 1 based table
anaFactorSelFwd=1
anaMoveFactors = {0.05, 0.15, 5}
anaRotateFactors = {2, 3, 5}
anaDeadZone = 3000
vibDuration = 0.2 --secs

---
xbc = nil
sec = 0
eular={}
xbcButtonStat={}
anaMoveFactor = anaMoveFactors[anaFactorSel]
anaRotateFactor = anaRotateFactors[anaFactorSel]
vibStart = 0 -- os.clock time
--
nl="\r\n"
--


print("Press F3 to Start, F4 to stop")
-- Y=up, Z=front
-- Angle: forward=0, clockwise
--Memory Address
posXAddr = "[\"LibOVRRT64_1.dll\" + 0030A060] +660"
posYAddr = "[\"LibOVRRT64_1.dll\" + 0030A060] +668"
posZAddr = "[\"LibOVRRT64_1.dll\" + 0030A060] +670"
rotQyAddr = "[\"LibOVRRT64_1.dll\" + 0030A060] +648" -- View rotation (both Monitor and HMD)
rotQwAddr = "[\"LibOVRRT64_1.dll\" + 0030A060] +658"
rotQyHMDAddr = "[\"LibOVRRT64_1.dll\" + 0030A060] +680" -- HMD Rotation
rotQwHMDAddr = "[\"LibOVRRT64_1.dll\" + 0030A060] +690"
posXRstAddr = "[\"LibOVRRT64_1.dll\" + 0030A060] +5f0"
posYRstAddr = "[\"LibOVRRT64_1.dll\" + 0030A060] +5f8"
posZRstAddr = "[\"LibOVRRT64_1.dll\" + 0030A060] +600"
rotQyRstAddr = "[\"LibOVRRT64_1.dll\" + 0030A060] +5d8" -- Forward direction (only affected by reset view)
rotQwRstAddr = "[\"LibOVRRT64_1.dll\" + 0030A060] +620"
-- Map postion
mapPosZAddr = "[[[\"LandfallClient-Win64-Shipping.exe\"+02E00EC0]+0]+C8] +0"
mapPosXAddr = "[[[\"LandfallClient-Win64-Shipping.exe\"+02E00EC0]+0]+C8] +4"
mapPosYAddr = "[[[\"LandfallClient-Win64-Shipping.exe\"+02E00EC0]+0]+C8] +8"
mapRelZAddr = "[[[[[\"LandfallClient-Win64-Shipping.exe\"+02DFF670]+8]+278]+58]+390] +1E0"
mapRelXAddr = "[[[[[\"LandfallClient-Win64-Shipping.exe\"+02DFF670]+8]+278]+58]+390] +1E4"
mapRelYAddr = "[[[[[\"LandfallClient-Win64-Shipping.exe\"+02DFF670]+8]+278]+58]+390] +1E8"
-- Character
chaZAddr = "[[[[\"LandfallClient-Win64-Shipping.exe\"+03091A50]+30]+400]+3E8] +1A0"
chaXAddr = "[[[[\"LandfallClient-Win64-Shipping.exe\"+03091A50]+30]+400]+3E8] +1A4"
chaYAddr = "[[[[\"LandfallClient-Win64-Shipping.exe\"+03091A50]+30]+400]+3E8] +1A8"

--print(readFloat(0x1eca16d3084))
--print(readFloat(0x1eca16d3094))


--t1=createTimer(getMainForm(), true) --message output
--t2=createTimer(getMainForm(), true) -- fast timer
t1=createTimer(f, true) --message output
t2=createTimer(f, true) -- fast timer
t3=createTimer(f, true) -- form update
timer_setInterval(t1, 1000)
timer_onTimer(t1, timer1_tick)
timer_setInterval(t2, t2_interval)
timer_onTimer(t2, timer2_tick)
timer_setInterval(t3, 500)
timer_onTimer(t3, timer3_tick)
createHotkey(pressStart, VK_SCROLL)
createHotkey(pressStop, VK_PAUSE)
print("------")

f=UDF1
f.show()
--f.CEEdit1.text = tree.items[0].text
--f.CEEdit2.text = tree.items[3].text
--dhmd=f.CEPanel1.CEGroupBx1
d={}
d.hmd={}
d.hmd.x=f.CEEdit1
d.hmd.x="1111"
infoUpdate()





