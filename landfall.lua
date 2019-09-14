function dprint()
    if (string.len(dmsg) >1) then
        print(dmsg)
        dmsg = ""
      end
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


-- Calculate angles of baseOffsets --
function getEularBase()
    local eular=quatToEular(newQ(mBaseRot.x ,mBaseRot.y, mBaseRot.z, mBaseRot.w))
    return eular
end
function getEularParent()
    local eular=quatToEular(newQ(readFloat(mapParentRotXAddr), readFloat(mapParentRotYAddr), readFloat(mapParentRotZAddr), readFloat(mapParentRotWAddr)))
    return eular
end

-- Calculate angles of libOVR --
function getEularOvr()
    local eular=quatToEular(newQ(0,readDouble(rotQyAddr),0,readDouble(rotQwAddr)))
    return eular
end
-- Calculate angles of libOVR reseting view --
function getEularOvrRst() -- Orientation of the reset view
    local eular=quatToEular(newQ(0,readDouble(rotQyRstAddr),0,readDouble(rotQwRstAddr)))
    return eular
end

function getWorldScale()
    local ws=readFloat(WorldToMetersScaleWhileInFrameAddr)
    if (ws == nil) then
       ws = worldScale
    end
    return ws
end

function vectorRotate2D(x, z, angle)
    local rad=math.rad(angle)
    local sin=math.sin
    local cos=math.cos
    local d={}
    d.x = x*cos(rad)-z*sin(rad)
    d.z = x*sin(rad)+z*cos(rad)
    return d
end

function rotateWithParentY(inAngle)
    return (inAngle-eularParent.y)%360
end

-- Convert liner to exp curve
-- percentage must be 0~1
function expPercent(percentage, exp)
    return percentage^(1/exp)
end

function anaPercent(anaVal)
    if ((not checkXbcReady()) or math.abs(anaVal) < anaDeadZone) then
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


-- New method using Origin/BaseOffsets
-- XZY Movement: Left/Right, Forward/Back, Up/Down
-- Y Rotate
function anaAdvTransfrom(anaValX, anaValZ, anaValY, anaValRY)
    local anaPercentX=anaPercent(anaValX)
    local anaPercentZ=anaPercent(anaValZ)
    local anaPercentY=anaPercent(anaValY)
    local anaPercentRY=anaPercent(anaValRY)

    local abs=math.abs
    -- any axis movement
    if (abs(anaPercentX)+abs(anaPercentY)+abs(anaPercentZ)+abs(anaPercentRY) == 0) then
        return
    end

    eularBase=getEularBase()
    if (camMode==CAM_MODE_FREE) then
        anaAdvMovePlane(anaPercentX*anaMoveFactor, anaPercentZ*anaMoveFactor)
        anaAdvMoveElev(anaPercentY*anaMoveFactor)
        anaAdvRotate(anaPercentRY*anaRotateFactor)
    elseif (camMode==CAM_MODE_FOLLOW) then
        -- Slowly rotate Cam when charactor walk/aim to left or right
        anaAdvRotate(anaPercentRY*anaRotateFactor*followCamModeRotateFactor)
    end
end

-- Old method using LibOVR
-- XZY Movement: Left/Right, Forward/Back, Up/Down
-- Y Rotate
function anaTransfrom(anaValX, anaValZ, anaValY, anaValRY)
    local anaPercentX=anaPercent(anaValX)
    local anaPercentZ=anaPercent(anaValZ)
    local anaPercentY=anaPercent(anaValY)
    local anaPercentRY=anaPercent(anaValRY)
    
    local abs=math.abs
    -- any axis movement
    if (abs(anaPercentX)+abs(anaPercentY)+abs(anaPercentZ)+abs(anaPercentRY) == 0) then
        return
    end
    
    eularOvr=getEularOvr()
    anaMovePlane(anaPercentX*anaMoveFactor, anaPercentZ*anaMoveFactor)
    anaMoveElev(anaPercentY*anaMoveFactor)
    anaRotate(anaPercentRY*anaRotateFactor)
end

-- New method using Origin/BaseOffsets
function anaAdvMovePlane(moveX, moveZ)
    -- Word X: rigt=+, back=-
    -- Word Z: forwad=-, back=+
    if (moveX == 0) and (moveZ == 0) then return end

    if (camMode==CAM_MODE_FREE) then
        -- Map corrdinate always changed by reseting the view
        -- The orign offset is the same with Map coordinate
        -- Just Need to calculate vectors from the base angle
        local angle=rotateWithParentY(eularBase.y)
        local d=vectorRotate2D(moveX, moveZ, angle)
        -- changes Offset Origin to move
        local targetX, targetZ
        targetX = readFloat(offOrgXAddr) + d.x *worldScale
        targetZ = readFloat(offOrgZAddr) + d.z *worldScale
        writeFloat(offOrgXAddr, targetX)
        writeFloat(offOrgZAddr, targetZ)
    end
end

-- Old method using LibOVR
function anaMovePlane(moveX, moveZ)
    -- Word X: rigt=+, back=-
    -- Word Z: forwad=-, back=+
    if (moveX == 0) and (moveZ == 0) then return end

    -- Map corrdinate always changed by reseting the view
    -- So the OVR reset(calibration) angle should by remove to get the correct related angle
    local eularRst = getEularOvrRst()
    local d=vectorRotate2D(moveX, moveZ, eularOvr.y-eularRst.y)
    local targetX = readDouble(posXAddr) + d.x
    local targetZ = readDouble(posZAddr) + d.z
    writeDouble(posXAddr, targetX)
    writeDouble(posZAddr, targetZ)
end

function anaAdvMoveElev(move)
    -- Word Y: up+, down-
    if (move == 0) then return end
    mBasePos.y=mBasePos.y-move
    writeFloat(basePosYAddr, mBasePos.y)
end

function anaMoveElev(move)
    -- Word Y: up+, down-
    if (move == 0) then return end
    writeDouble(posYAddr, readDouble(posYAddr)-move)
end

-- New method using Origin/BaseOffsets
-- Y Rotate
function anaAdvRotate(rotAngle)

    if (rotAngle == 0) then return end
    local ez = eularBase.z
    local ey = (eularBase.y-rotAngle) % 360
    local ex = eularBase.x
    mBaseRot=eulerToQuat(newE(ez,ey,ex))

    writeFloat(baseRotZAddr, mBaseRot.z)
    writeFloat(baseRotYAddr, mBaseRot.y)
    writeFloat(baseRotXAddr, mBaseRot.x)
    writeFloat(baseRotWAddr, mBaseRot.w)
end

-- Old method using LibOVR
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
    local ey = (eularOvr.y-rotAngle) % 360
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

function followCharacter()
    local mapChaZ=readFloat(mapChaZAddr)
    local mapChaX=readFloat(mapChaXAddr)
    local mapChaY=readFloat(mapChaYAddr)
    if (mapChaZ == nil) then
        resetCamMode()
        return
    end
    -- move offset origin to charatoer location
    local newOffOrgX=mapChaX-readFloat(mapParentXAddr)+followCamOriginFix.x
    local newOffOrgZ=mapChaZ-readFloat(mapParentZAddr)+followCamOriginFix.z
    -- There is no OffOrgY property, only XZ
    writeFloat(offOrgXAddr, newOffOrgX)
    writeFloat(offOrgZAddr, newOffOrgZ)
    -- Question: Let followCharacter() update height?
end
function distance3D(dx, dz, dy)
    local xzDist = math.sqrt(dx^2+dz^2)
    return math.sqrt(xzDist^2+dz^2)
end

function followCamAcitve()
    -- set basePos (the offset distance from cam to charactor)
    -- calculate the distance between character to current position
    local d={}
    local abs=math.abs
    d.x = readFloat(mapParentXAddr)+readFloat(offOrgXAddr)-readFloat(mapChaXAddr)
    d.z = readFloat(mapParentZAddr)+readFloat(offOrgZAddr)-readFloat(mapChaZAddr)
    d.y = readFloat(mapParentYAddr)-mBasePos.y*worldScale-readFloat(mapChaYAddr)
    if (not followCamReset) then
        local angle=rotateWithParentY(eularBase.y)
        local r=vectorRotate2D(d.x, d.z, -angle)
        --print("followCAM switch: d.x:"..d.x..", d.z:"..d.z..", r.x:"..r.x..", r.z"..r.z)
        mBasePos.x =  -r.x/worldScale
        mBasePos.z =  -r.z/worldScale
        writeFloat(basePosXAddr, mBasePos.x)
        writeFloat(basePosZAddr, mBasePos.z)
    else
        --print("followCAM reset")
        -- When cam position is too far
        -- Reset followCAM to default distance
        mBasePos.x =  0/worldScale
        mBasePos.z =  followCamResetDistanceXZ/worldScale
        -- basePosY is calulated from parent origin
        mBasePos.y = -(readFloat(mapChaYAddr)-readFloat(mapParentYAddr)+followCamResetHeight)/worldScale
        followCamReset=false
        writeFloat(basePosXAddr, mBasePos.x)
        writeFloat(basePosZAddr, mBasePos.z)
        writeFloat(basePosYAddr, mBasePos.y)
        -- Question: keep view angle?
    end
    -- Move the offset origin to the character , This is also updated by timer repeatedly
    followCharacter()
end
function followCamDeactive()
    -- move the origin from charactor back to free cam pos
    -- reset basePos
    local d={}
    d.x=mBasePos.x
    d.z=mBasePos.z
    local angle=rotateWithParentY(eularBase.y)
    local r=vectorRotate2D(d.x, d.z, angle)
    local newOffOrgX=readFloat(offOrgXAddr)-followCamOriginFix.x-r.x*worldScale
    local newOffOrgZ=readFloat(offOrgZAddr)-followCamOriginFix.z-r.z*worldScale
    --print("deactive: dx:"..d.x..", dz:"..d.z..", rx:"..r.x..", .z"..r.z)
    mBasePos.x=0
    mBasePos.z=0
    -- no need to reset Y position, it always use basePos to move in both mode
    writeFloat(offOrgXAddr, newOffOrgX)
    writeFloat(offOrgZAddr, newOffOrgZ)
    writeFloat(basePosXAddr, mBasePos.x)
    writeFloat(basePosZAddr, mBasePos.z)
end
function freeCamActive()
    xinputBlockToggle(true)
end
function freeCamDeactive()
    xinputBlockToggle(false)
end

function switchCamMode(newMode)
    if (not checkGameReady()) then
        return
    end
    updateWorldData()
    eularBase=getEularBase()
    if (newMode==CAM_MODE_FREE) then
        -- check last mode
        if (camMode==CAM_MODE_FREE) then
            newMode=CAM_MODE_NONE
            freeCamDeactive()
        elseif (camMode == CAM_MODE_FOLLOW) then
            followCamDeactive()
            freeCamActive()
        else
            freeCamActive()
        end
    elseif (newMode==CAM_MODE_FOLLOW) then
        if (not checkCharacterReady()) then
            newMode=camMode --don't switch if no character
        else
            if (camMode==CAM_MODE_FREE) then
                freeCamDeactive()
                followCamAcitve()
            elseif (camMode == CAM_MODE_FOLLOW and (not followCamReset)) then
                newMode=CAM_MODE_NONE
                followCamDeactive()
            else
                followCamAcitve()
            end 
        end
    else
        if (camMode==CAM_MODE_FREE) then
            freeCamActive()
        elseif (camMode == CAM_MODE_FOLLOW) then
            followCamAcitve()
        end
    end

    camMode=newMode
end

function resetCamMode()
    -- Reset position when the game excuting Re-calibrate
    writeFloat(offOrgXAddr, 0)
    writeFloat(offOrgZAddr, 0)
    mBasePos.x=0
    mBasePos.z=0
    mBasePos.y=0
    mBaseRot.x=0
    mBaseRot.z=0
    mBaseRot.y=0
    mBaseRot.w=1
    if (camMode==CAM_MODE_FREE) then
        freeCamDeactive()
    end
    camMode=CAM_MODE_NONE
end

function setSpeed()
    if (worldScale == 100) then
        anaMoveFactor = anaMoveFactorsHanger[anaFactorSel]
        anaRotateFactor = anaRotateFactorsHanger[anaFactorSel]
    else
        anaMoveFactor = anaMoveFactors[anaFactorSel]
        anaRotateFactor = anaRotateFactors[anaFactorSel]
    end
end

function increaseSpeed()
    -- Increase speed
    anaFactorSel = anaFactorSel + 1
    if (anaFactorSel > #anaMoveFactors) then
        anaFactorSel = #anaMoveFactors
    end
    setSpeed()
end

function decreaseSpeed()
    -- Decrease speed
    anaFactorSel = anaFactorSel - 1
    if (anaFactorSel < 1) then
        anaFactorSel = 1
    end
    setSpeed()
end

function on_GAMEPAD_LEFT_SHOULDER_released(btn)
    decreaseSpeed()
end
function on_GAMEPAD_RIGHT_SHOULDER_released(btn)
    increaseSpeed()
end
function on_GAMEPAD_DPAD_UP_released(btn)
end
function on_GAMEPAD_DPAD_DOWN_released(btn)
end
function on_GAMEPAD_DPAD_LEFT_released(btn)
end
function on_GAMEPAD_DPAD_RIGHT_released(btn)
end
function on_GAMEPAD_BACK_released(btn)
    resetCamMode()
end
function on_GAMEPAD_LEFT_THUMB_released(btn)
    switchCamMode(CAM_MODE_FOLLOW)
end
function on_GAMEPAD_LEFT_THUMB_hold(btn)
    followCamReset=true
    switchCamMode(CAM_MODE_FOLLOW)
end
function on_GAMEPAD_RIGHT_THUMB_released(btn)
    switchCamMode(CAM_MODE_FREE)
end

function xbcCheckButtons()
    local idx, btn
    -- check button status
    for btn, pressed in pairs(xbc) do
        -- Only checks buttons, skip analog stick and other info
        local btnInitialStr="GAMEPAD_"
        if (string.sub(btn, 0,string.len(btnInitialStr))==btnInitialStr) and (pressed) then
            -- button pressed
            -- Register a botton state
            if (xbcButtonStat[btn]==nil or xbcButtonStat[btn]==0) then
                --print("> "..btn.." DOWN")
                xbcButtonStat[btn]=1
            else
                --button hold
                if (xbcButtonStat[btn] ~= -1) then
                    xbcButtonStat[btn]=xbcButtonStat[btn]+1
                    if (xbcButtonStat[btn] >= buttonHoldThreshold) then
                        --print("> "..btn.." HOLD")
                        xbcButtonStat[btn]=-1
                        -- Call button function if exist
                        local btnFuncName= "on_"..btn.."_hold"
                        if (_G[btnFuncName] ~= nil) then
                            _G[btnFuncName](btn)
                        else
                            btnFuncName= "on_"..btn.."_released"
                            if (_G[btnFuncName] ~= nil) then
                                _G[btnFuncName](btn)
                            end
    
                        end
                    end
                end
            end
        else
            -- BTN released, do something
            if (xbcButtonStat[btn] and xbcButtonStat[btn]>0) then
                -- UnRegister a botton state
                --print("> "..btn.." UP")

                -- Call button function if exist
                local btnFuncName= "on_"..btn.."_released"
                if (_G[btnFuncName] ~= nil) then
                    _G[btnFuncName](btn)
                end
            end
            xbcButtonStat[btn]=0
        end
    end
end 


-- Timer updates --
function xbcGetState()
    -- Read Xbox Controller state
    xbc = getXBox360ControllerState();
    if (not (checkXbcReady() or checkGameReady())) then
       return
    end

   
    -- stop vibration --
    if (vibStart>0) and (os.clock()-vibStart > vibDuration) then
        vibStart=0
        setXBox360ControllerVibration(xbc.ControllerID, 0, 0)
    end

    xbcCheckButtons()


    --Move and Rotate with Analog Sticks
    -- parameters analog axis for: Move X, Move Z, Move Y, Roate Y (Y is up/down)
    -- XZY Movement: Left/Right, Forward/Back, Up/Down
    -- Rotate: Left/Right
    -- Original method: Use libOvr calibration data
    -- New method: Use Origin/BaseOffest in Settings
    if (controlStyle == 1) then --CS style
        --anaTransfrom(xbc.ThumbLeftX, xbc.ThumbLeftY, xbc.ThumbRightY, xbc.ThumbRightX)
        anaAdvTransfrom(xbc.ThumbLeftX, xbc.ThumbLeftY, xbc.ThumbRightY, xbc.ThumbRightX)
    elseif (controlStyle == 2) then --Racing style
        --anaTransfrom(xbc.ThumbRightX, xbc.ThumbRightY, xbc.ThumbLeftY, xbc.ThumbLeftX)
        anaAdvTransfrom(xbc.ThumbRightX, xbc.ThumbRightY, xbc.ThumbLeftY, xbc.ThumbLeftX)
    else -- Space Fighter Style
        --anaTransfrom(xbc.ThumbLeftX, xbc.ThumbRightY, xbc.ThumbLeftY, xbc.ThumbRightX)
        anaAdvTransfrom(xbc.ThumbLeftX, xbc.ThumbRightY, xbc.ThumbLeftY, xbc.ThumbRightX)
    end
end

function uiEnHackClicked(sender)
    hackToggle(sender.checked)
end
function uiEnCheatClicked(sender)
    cheatToggle(sender.checked)
end
function uiEnHelpClicked(sender)
    helpToggle(sender.checked)
end
function uiEnDebugClicked(sender)
    debugToggle(sender.checked)
end
function uiFormClose(sender)
    hackStop()
    return caHide --Possible options: caHide, caFree, caMinimize, caNone
end

function hackToggle(en)
    enHack=en
    updataHackButtonCaption()
    if (en) then
        hackStart()
    else
        hackStop()
    end
end

function updataHackButtonCaption()
    local str
    if (enHack) then
        if (status.gameExe) then
            str="Running"
        else
            str="Waiting"
        end
    else
        str="Suspended"
    end
    f.enHack.caption=str
end

function uiToggle(mode)
    if (mode=="help") then
        f.enDebug.checked = false
        f.p_debugInfo.visible = false
        f.p_help.visible = true
        f.height = 400
    elseif (mode=="debug") then
        f.enHelp.checked = false
        f.p_help.visible = false
        f.p_debugInfo.visible = true
        f.height = 700
    else
        f.height = 200
        f.p_debugInfo.visible = false
        f.p_help.visible = false
    end
end

function helpToggle(en)
    if (en) then
        uiToggle("help")
    else
        uiToggle("normal")
    end
end

function debugToggle(en)
    enDebug=en
    if (en) then
        uiToggle("debug")
    else
        uiToggle("normal")
    end
end

function xinputBlockToggle(en)
    mrXinputAxisBlock.Active=en
end

function cheatToggle(en)
    enCheat=en
    cheatAAToggle(en)
end

function cheatAAToggle(en)
    if (not enCheat) then
        en=false
    end
    --mrHealth.Active=en
    --mrSP.Active=en
end

function cheatUpdate()
    if (not (enCheat and checkCheatUpdateReady())) then
        return
    end
    cheatUpdateNum("Health", "Float", 3000)
    cheatUpdateNum("SPTimer", "Float", -200)
    cheatUpdateNum("Grenade", "Bytes", 3)
end

function cheatUpdateNum(cheatName, type, value) 
    local addr="cheat"..cheatName.."Addr"
    _G["write"..type](_G[addr], value)
end


function initHotkey()
    if (enDebug) then
        createHotkey(hackStart, VK_SCROLL)
        createHotkey(hackStop, VK_PAUSE)
    end
end


function hackStart()
    timerStart()
    cheatAAToggle(true)
end

function hackStop()
    xinputBlockToggle(false)
    cheatAAToggle(false)
    timerStop()
    resetUI()
end


function timerStart()
    --t1=createTimer(getMainForm(), true) --message output
    timerRunning=true
    t1=createTimer(f, true) --message output
    t2=createTimer(f, true) -- fast timer
    t3=createTimer(f, true) -- form update
    t4=createTimer(f, true) -- cheat value update
    timer_setInterval(t1, 1000)
    timer_setInterval(t2, t2_interval)
    timer_setInterval(t3, 100)
    timer_setInterval(t4, 500)
    timer_onTimer(t1, timer1_tick)
    timer_onTimer(t2, timer2_tick)
    timer_onTimer(t3, timer3_tick)
    timer_onTimer(t4, timer4_tick)
--    timer_setEnabled(t1,true)
--    timer_setEnabled(t2,true)
--    timer_setEnabled(t3,true)
--    timer_setEnabled(t4,true)
    print("Started")
end

function timerStop()
    timerRunning=false
    print("Stopped")
end
function timer1_tick(timer)  -- 1 second timer
    updateDebugData()
    timerCheckDestroy(timer)
end
function timer2_tick(timer)  --fastest timer
    xbcGetState()
    if (camMode==CAM_MODE_FOLLOW) then
        followCharacter()
    end
    timerCheckDestroy(timer)
end
function timer3_tick(timer) -- 0.1 second timer
    updateUI()
    timerCheckDestroy(timer)
end
function timer4_tick(timer) -- 0.5 second timer
    updateStatus()
    updateWorldData()
    setSpeed()
    cheatUpdate()
    timerCheckDestroy(timer)
end

function timerCheckDestroy(timer)
    if (not timerRunning) then
        print("Timer "..tostring(timer).." destroyed.")
        timer.destroy()
    end
end

function checkGameReady()
    return status.gameExe and checkSceneReady()
end
function checkGameExe()
    if (not enHack) then
        status.gameExe=false
        return status.gameExe
    end

    -- getProcessIDFromProcessName(PROCESS_NAME) causes high CPU loading
    -- Check game scence first
    if (checkSceneReady()) then -- Process already opened, no need to check process id
        status.gameExe=true
    else
        gameExeDectectionSec=gameExeDectectionSec+1
        if (gameExeDectectionSec>=3*1000/500) then --slowdown the check interval when game not running
            gameExeDectectionSec=0
            if (getProcessIDFromProcessName(PROCESS_NAME) ~= nil) then
                if (not status.gameExe) then -- prevent process opened but scence not loaded yet
                    openProcess(PROCESS_NAME)
                end
                status.gameExe=true
            else
                status.gameExe=false
            end
        end
    end
    return status.gameExe
end
function checkSceneReady()
    -- check Scence loaded
    return readDouble(basePosZAddr) ~= nil
end
function checkXbcReady()
    return xbc ~= nil
end
function checkCharacterReady()
    return readFloat(mapChaXAddr) ~= nil
end
function checkCheatUpdateReady()
    return readFloat(cheatHealthAddr) ~= nil
end

function updateWorldData()
    if(checkGameReady()) then
        worldScale=getWorldScale()
        eularParent=getEularParent()
    end
end

-- slowly update status
function updateStatus()
    if (enHack) then
        status.gameExe = checkGameExe()
        status.scence = checkSceneReady()
        status.xbc = checkXbcReady()
        status.character = checkCharacterReady()
    end
end
function initUI()
    f.caption = hackName.." ( v"..version.." )"
    f.enHack.checked=enHack
    f.enCheat.checked=enCheat
    f.enDebug.checked=enDebug
    f.enDebug.visible=enDebug
    debugToggle(enDebug)
end

function resetUI()
    status.gameExe = false
    status.scence = false
    status.xbc = false
    status.character = false
    updateUI()
end

function updateUI()
    -- Status
    f.statusGameExe.checked=status.gameExe
    updataHackButtonCaption()
    f.statusXbc.checked = status.xbc
    f.statusScene.checked=status.scence
    if (not status.scence) then
        f.statusScene.caption = "No Scence"
    else
        if (worldScale>100) then
            f.statusScene.caption = "Map"
        else
            f.statusScene.caption = "Hanger"
        end
    end
    f.statusCharacter.checked=status.character
    if (not status.character) then
        f.statusCharacter.caption="No Character"
    else
        f.statusCharacter.caption="Character"
    end
    -- Info
    f.infoCamMode.text = camModeNames[camMode]
    f.infoSpeed.text = "Speed: "..anaFactorSel.." / "..#anaMoveFactors --.." ("..anaMoveFactor.." )"
end


function updateDebugData()
    local o
    if (not enDebug) or (not checkGameReady()) then return end

    local e=eularBase
    local ep=eularParent

    o="o1"
    f[o].caption = "Qw"
    f[o..'a'].text = ""
    f[o..'b'].text = ""
    f[o..'c'].text = readFloat(baseRotWAddr)
    o="o2"
    f[o].caption = "Qxzy"
    f[o..'a'].text = readFloat(baseRotXAddr)
    f[o..'b'].text = readFloat(baseRotZAddr)
    f[o..'c'].text = readFloat(baseRotYddr)
    o="o3"
    f[o].caption = "Angle"
    f[o..'a'].text = e.x
    f[o..'b'].text = e.z
    f[o..'c'].text = e.y
    o="o4"
    f[o].caption = "pAngle"
    f[o..'a'].text = ep.x
    f[o..'b'].text = ep.z
    f[o..'c'].text = ep.y

    o="p1"
    f[o].caption ="Parent"
    f[o..'a'].text = readFloat(mapParentXAddr)
    f[o..'b'].text = readFloat(mapParentZAddr)
    f[o..'c'].text = readFloat(mapParentYAddr)

    o="p2"
    f[o].caption ="Origin off"
    f[o..'a'].text = readFloat(offOrgXAddr)
    f[o..'b'].text = readFloat(offOrgZAddr)
    f[o..'c'].text = ""

    o="p3"
    f[o].caption ="Origin map"
    f[o..'a'].text = readFloat(mapParentXAddr)+readFloat(offOrgXAddr)
    f[o..'b'].text = readFloat(mapParentZAddr)+readFloat(offOrgZAddr)
    f[o..'c'].text = ""

    o="p4"
    f[o].caption ="Cam map"
    f[o..'a'].text = readFloat(mapCamXAddr)
    f[o..'b'].text = readFloat(mapCamZAddr)
    f[o..'c'].text = readFloat(mapCamYAddr)

    if (checkCharacterReady()) then
        o="p5"
        f[o].caption ="Cha diff"
        f[o..'a'].text = readFloat(mapParentXAddr)+readFloat(offOrgXAddr)-readFloat(mapChaXAddr)
        f[o..'b'].text = readFloat(mapParentZAddr)+readFloat(offOrgZAddr)-readFloat(mapChaZAddr)
        f[o..'c'].text = readFloat(mapParentYAddr)-readFloat(basePosYAddr)*worldScale-readFloat(mapChaYAddr)
    end

    o="p6"
    f[o].caption ="RbasePos *ws"
    local r=vectorRotate2D(readFloat(basePosXAddr), readFloat(basePosZAddr), e.y)
    f[o..'a'].text = r.x *worldScale
    f[o..'b'].text = r.z *worldScale

    o="p7"
    f[o].caption ="basePos *ws"
    f[o..'a'].text = readFloat(basePosXAddr)*worldScale
    f[o..'b'].text = readFloat(basePosZAddr)*worldScale
    f[o..'c'].text = readFloat(basePosYAddr)*worldScale

    o="p8"
    f[o].caption ="World Scale"
    f[o..'a'].text = worldScale
    
end
-- Follow mode: Compare camera Relative to match character's Relative
-- newRelative = new Delta OvrPos *worldScale + origin Fix
-- origin fix = relative -(deltaOvrPos*worldScale)
function relOriginFix(currDtOvrPos, currRelative)
    return currRelative-(currDtOvrPos*worldScale)
end
function getRelative (currOvrPos, newOvrPos, currRelative)
    --newMapPos = newDtOvrPos*worldScale+relOriginFix(currRelative, currDtOvrPos)
    --newMapPos = newDtOvrPos*worldScale+currRelative-(currDtOvrPos*worldScale)
    --newMapPos = (newDtOvrPos-currDtOvrPos)*worldScale+currRelative
    newRelative = (newOvrPos-currOvrPos)*worldScale+currRelative
    return newMapPos
end
function getOvrPos(currOvrPos, currRelative, newRelative)
    local newOvrPos = currOvrPos+(newRelative-currRelative)/worldScale
    return newOvrPos 
end



-- definations --
math.deg2Rad = math.pi / 180
math.rad2Deg = 180 / math.pi
nl="\r\n"
f=UDF1
camModeNames={"Default Camera", "Free Camera", "Follow Camera"}
CAM_MODE_NONE=1
CAM_MODE_FREE=2
CAM_MODE_FOLLOW=3
camMode=CAM_MODE_NONE -- Need to be defined at first time for camera switching


-- Settings --
PROCESS_NAME = 'LandfallClient-Win64-Shipping.exe'
-- (timer is inaccure)
-- real trigger per second:
-- 100ms :9.1/10
-- 50ms  :16.3/20
-- 20ms  :32.2/50
-- 10ms  :63.7/100
-- 5ms   :65.1/2000
t2_interval = 10 -- input timer
-- Control Style (not used now)
-- 1: CS style: Left hand walk/strafe, right hand turn/elev
-- 2: Racing style: Left hand turn/elev, right hand drift/gas
-- 3: Space Fighter Style: Left hand 3D strafe, right hand turn/throttle
controlStyle =1
-- move/rotate speed
anaMoveFactors = {0.002, 0.006, 0.018, 0.054, 0.152}
anaRotateFactors = {0.8, 1.2, 1.8, 2.5, 3}
-- move/rotate speed in hanger
anaMoveFactorsHanger = {0.01, 0.03, 0.2, 1.2, 10}
anaRotateFactorsHanger = {1, 2, 3, 4, 5}
-- default speed selection
anaFactorSel = 2
-- follow mode rotation multiplier
followCamModeRotateFactor=1
-- input
anaSensitivityExp = 1/3
anaDeadZone = 3000
vibDuration = 0.2 --secs
-- button hold seconds --
buttonHoldThreshold=0.3*(1000/t2_interval)
-- Position fix
followCamOriginFix = {}
followCamOriginFix.x = 0 -- Monitor displays left eye position, shout check this in HMD
followCamOriginFix.z = 0
-- Default follow cam distance
followCamResetDistanceXZ = 1800
followCamResetHeight = 1800
-- enable/disable --
enHack = true
enCheat = false
enDebug = true
-- software info
hackName= "Landfall Camera hack"
version = "1.0"





---- Globals ----
xbc = nil
xbcButtonStat={}
eularBase = {["x"]=0,["y"]=0,["z"]=0}
eularParent={["x"]=0,["y"]=0,["z"]=0}
eularOvr =  {["x"]=0,["y"]=0,["z"]=0}
anaMoveFactor=0
anaRotateFactor=0
worldScale = 100
followCamReset=false
vibStart = 0 -- os.clock time
timerRunning = false
gameExeDectectionSec=0

-- Game view reset will clear all base data
-- Remember them will be useful if we don't want reset view changes current position
mBasePos={}
mBasePos.x=0
mBasePos.z=0
mBasePos.y=0
mBaseRot={}
mBaseRot.x=0
mBaseRot.z=0
mBaseRot.y=0
mBaseRot.w=1
-- Non-realtime status
status = {}
status.gameExe = false
status.xbc = false
status.scence = false
status.character = false

---- Memory Records ----
-- PositionOffset (offOrg): 
--                 Offset distance to HMD Origin,
--                 The coodinate system is alway the same with Map, not effected by rotation.
--                 The scale is also the same with the Map. (but counting from HMD Origin.)
--                 This changes the HMD position, and also the rotation center of the 'BaseOrientation'
--                 This doesnot effect the 'ComponentToWorld.Trans' / 'Relative' in CamComponent Object
--                 Only 2 axis X & Z are provided, no Y axis.
-- BaseOffset: This also moves the HMD position, and the coodinate system follows 'BaseOrientation'
--             But too bad this does not move the rotation center together.
-- BaseOrientation: This Rotaion feels much better than the quaternion in libOVR, true rotaion around center point.
--                  And this also provides 3 axis rotation.
-- LibOVR Orientation: The rotation center always follows HMD, not effectd by PositionOffset or BaseOffset
--                     But the rotaion feels strange, 
--                     and it is affected by the distance of HMD and the Oculus initial calibration origin.
-- Direction
-- BaseOffset.Z (FW- BK+) / BaseOffset.X (L+ R-) / BaseOffset.Y (Up- Dn+)
-- BaseOrientation.Z (-CW) / BaseOrientation.X (-Dn) / BaseOrientation.Y (L+ R-) / BaseOrientation

-- LibOVR
posXAddr = "[[[[[\"LandfallClient-Win64-Shipping.exe\"+02FDA368]+0]+38]+650]+150]+660"
posYAddr = "[[[[[\"LandfallClient-Win64-Shipping.exe\"+02FDA368]+0]+38]+650]+150]+668"
posZAddr = "[[[[[\"LandfallClient-Win64-Shipping.exe\"+02FDA368]+0]+38]+650]+150]+670"
rotQyAddr = "[[[[[\"LandfallClient-Win64-Shipping.exe\"+02FDA368]+0]+38]+650]+150]+648" -- View rotation (both Monitor and HMD)
rotQwAddr = "[[[[[\"LandfallClient-Win64-Shipping.exe\"+02FDA368]+0]+38]+650]+150]+658"
rotQyHMDAddr = "[[[[[\"LandfallClient-Win64-Shipping.exe\"+02FDA368]+0]+38]+650]+150]+680" -- HMD Rotation
rotQwHMDAddr = "[[[[[\"LandfallClient-Win64-Shipping.exe\"+02FDA368]+0]+38]+650]+150]+690"
posXRstAddr = "[[[[[\"LandfallClient-Win64-Shipping.exe\"+02FDA368]+0]+38]+650]+150]+5f0"
posYRstAddr = "[[[[[\"LandfallClient-Win64-Shipping.exe\"+02FDA368]+0]+38]+650]+150]+5f8"
posZRstAddr = "[[[[[\"LandfallClient-Win64-Shipping.exe\"+02FDA368]+0]+38]+650]+150]+600"
rotQyRstAddr = "[[[[[\"LandfallClient-Win64-Shipping.exe\"+02FDA368]+0]+38]+650]+150]+5d8" -- Forward direction (only affected by reset view)
rotQwRstAddr = "[[[[[\"LandfallClient-Win64-Shipping.exe\"+02FDA368]+0]+38]+650]+150]+620"
currHeadposXAdrr="[[[[[\"LandfallClient-Win64-Shipping.exe\"+02FDA368]+0]+38]+650]+150]+720"
-- Map postion --
-- the old one, not sure belong to which object
mapPosZAddr = "[[[\"LandfallClient-Win64-Shipping.exe\"+02E00EC0]+0]+C8] +0"
mapPosXAddr = "[[[\"LandfallClient-Win64-Shipping.exe\"+02E00EC0]+0]+C8] +4"
mapPosYAddr = "[[[\"LandfallClient-Win64-Shipping.exe\"+02E00EC0]+0]+C8] +8"
-- CameraComponent Object
mapCamZAddr = "[[[[[\"LandfallClient-Win64-Shipping.exe\"+02DFF670]+8]+278]+58]+390] +1A0"
mapCamXAddr = "[[[[[\"LandfallClient-Win64-Shipping.exe\"+02DFF670]+8]+278]+58]+390] +1A4"
mapCamYAddr = "[[[[[\"LandfallClient-Win64-Shipping.exe\"+02DFF670]+8]+278]+58]+390] +1A8"
mapRelZAddr = "[[[[[\"LandfallClient-Win64-Shipping.exe\"+02DFF670]+8]+278]+58]+390] +1E0"
mapRelXAddr = "[[[[[\"LandfallClient-Win64-Shipping.exe\"+02DFF670]+8]+278]+58]+390] +1E4"
mapRelYAddr = "[[[[[\"LandfallClient-Win64-Shipping.exe\"+02DFF670]+8]+278]+58]+390] +1E8"
-- Character CameraComponent Object
mapChaZAddr = "[[[[\"LandfallClient-Win64-Shipping.exe\"+03091A50]+30]+400]+3E8] +1A0"
mapChaXAddr = "[[[[\"LandfallClient-Win64-Shipping.exe\"+03091A50]+30]+400]+3E8] +1A4"
mapChaYAddr = "[[[[\"LandfallClient-Win64-Shipping.exe\"+03091A50]+30]+400]+3E8] +1A8"
-- FOculusHMD Object
FOculusHMDObjBase= "[[[\"LandfallClient-Win64-Shipping.exe\"+02DD70D8]+8]+8] +0"
mapParentRotZAddr= "[[[\"LandfallClient-Win64-Shipping.exe\"+02DD70D8]+8]+8] +40"
mapParentRotXAddr= "[[[\"LandfallClient-Win64-Shipping.exe\"+02DD70D8]+8]+8] +44"
mapParentRotYAddr= "[[[\"LandfallClient-Win64-Shipping.exe\"+02DD70D8]+8]+8] +48"
mapParentRotWAddr= "[[[\"LandfallClient-Win64-Shipping.exe\"+02DD70D8]+8]+8] +4C"
mapParentZAddr= "[[[\"LandfallClient-Win64-Shipping.exe\"+02DD70D8]+8]+8] +50"
mapParentXAddr= "[[[\"LandfallClient-Win64-Shipping.exe\"+02DD70D8]+8]+8] +54"
mapParentYAddr= "[[[\"LandfallClient-Win64-Shipping.exe\"+02DD70D8]+8]+8] +58"
-- FOculusHMD Settings
FOculusHMDObjSettingsBase= "[[[[\"LandfallClient-Win64-Shipping.exe\"+02DD70D8]+8]+8]+A8]+0"
basePosZAddr = "[[[[\"LandfallClient-Win64-Shipping.exe\"+02DD70D8]+8]+8]+A8]+70"
basePosXAddr = "[[[[\"LandfallClient-Win64-Shipping.exe\"+02DD70D8]+8]+8]+A8]+74"
basePosYAddr = "[[[[\"LandfallClient-Win64-Shipping.exe\"+02DD70D8]+8]+8]+A8]+78"
baseRotZAddr = "[[[[\"LandfallClient-Win64-Shipping.exe\"+02DD70D8]+8]+8]+A8]+80"
baseRotXAddr = "[[[[\"LandfallClient-Win64-Shipping.exe\"+02DD70D8]+8]+8]+A8]+84"
baseRotYAddr = "[[[[\"LandfallClient-Win64-Shipping.exe\"+02DD70D8]+8]+8]+A8]+88"
baseRotWAddr = "[[[[\"LandfallClient-Win64-Shipping.exe\"+02DD70D8]+8]+8]+A8]+8C"
-- Camera origin offset to the parent
offOrgZAddr = "[[[[\"LandfallClient-Win64-Shipping.exe\"+02DD70D8]+8]+8]+A8]+D0"
offOrgXAddr = "[[[[\"LandfallClient-Win64-Shipping.exe\"+02DD70D8]+8]+8]+A8]+D4"

FOculusHMDObjFrameBase= "[[[[\"LandfallClient-Win64-Shipping.exe\"+02DD70D8]+8]+8]+B8]+0"
WorldToMetersScaleWhileInFrameAddr= "[[[[\"LandfallClient-Win64-Shipping.exe\"+02DD70D8]+8]+8]+B8]+B8"

-- Cheat ptrs --
cheatHealthAddr =  "[[[[\"LandfallClient-Win64-Shipping.exe\"+03091A50]+30]+390]+7C8]+178"
cheatSPTimerAddr = "[[[[[\"LandfallClient-Win64-Shipping.exe\"+03091A50]+30]+390]+310]+90]+F8"
cheatGrenadeAddr = "[[[[[\"LandfallClient-Win64-Shipping.exe\"+03091A50]+30]+3A8]+658]+78]+AE1"

-- AA --
mrXinputAxisBlock=getAddressList().getMemoryRecordByDescription('Xinput Axis Block')
mrHealth=getAddressList().getMemoryRecordByDescription('Health AA')
mrSP=getAddressList().getMemoryRecordByDescription('SP timer AA')

initHotkey()
initUI()
f.show()
updateUI()
updateDebugData()
hackToggle(enHack)

print("------")
print("Press ScrLk to Start, Pause to stop")




