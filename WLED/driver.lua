JSON = require ('drivers-common-public.module.json')
WebSocket = require ('drivers-common-public.module.websocket')

do	--Globals
	OPC = OPC or {}
	EC = EC or {}
	RFP = RFP or {}
	WLED = {}
	DeviceID = nil
	PersistData["Scenes"] = PersistData["Scenes"] or {}
	DeviceProperty = "Device Address "
	MaxDevices = 10
	NumDevices = tonumber(Properties["Number of Additional Devices"])
	RetryCount = 0
	MaxRetries = 5
	ReconnectTimer = nil
	effects = {}
	effectsRev = {}
	EFFECT_SELECT = {}
	info = {}
end

function dbg (strDebugText, ...)
    if (Properties["Debug Mode"] == 'On') then
		DEBUGPRINT = true
	end

	if (DEBUGPRINT) then print (os.date ('%x %X : ')..(strDebugText or ''), ...) end
end

function OnDriverInit()
	C4:SendToProxy(5001, "ONLINE_CHANGED", {STATE=false})
	
	UpdateAdditionalDevices()

	if (Properties["Communication Mode"] == "Websocket") then
		ConnectWebsocket()
	end
end

function OnDriverLateInit()
    dbg("On driver late init...")
	
	DeviceID = C4:GetDeviceID()
	ProxyID = C4:GetProxyDevicesById(DeviceID)

	if (Properties["Communication Mode"] == "HTTP") then
		WLED.ConnectionState(true)
	end

	WLED.GetDeviceInfo()
end

function ConversionScale(level)
    level = tonumber(level)
    level = (level/100)*255
    level = math.floor(level)
	return level
end

function ConversionScale100(level)
    level = tonumber(level)
    level = (level/255)*100
    level = math.floor(level)
	return level
end

function UpdateAdditionalDevices()
	NumDevices = tonumber(Properties["Number of Additional Devices"])
	for i = 1,MaxDevices,1 do
	    if (i <= NumDevices) then
		   C4:SetPropertyAttribs(DeviceProperty..i, 0)
	    else
		   C4:SetPropertyAttribs(DeviceProperty..i, 1)
		end
    end
end

function ConnectWebsocket()

     wsURL = "ws://"..Properties["Primary Device Address"].."/ws"
	
	--PersistData["WLEDSocket"] = PersistData["WLEDSocket"] or "none"
	
     if (PersistData["WLEDSocket"]) then
		PersistData["WLEDSocket"]:delete ()
	end
	PersistData["WLEDSocket"] = WebSocket:new (wsURL)

	local pm = function (self, data)
		dbg ('WS Message Received: ' .. data)
		WLED.WSDataReceived(data)
	end

	PersistData["WLEDSocket"]:SetProcessMessageFunction (pm)

	local est = function (self)
		dbg ('ws connection established')
		WLED.ConnectionState(true)
	end

	local offline = function (self)
		dbg ('ws connection established')
		WLED.ConnectionState(false)
	end

	PersistData["WLEDSocket"]:SetEstablishedFunction (est)
	PersistData["WLEDSocket"]:SetOfflineFunction (offline)

	local closed = function (self)
		dbg ('ws connection closed by remote host')
		WLED.ConnectionState(false)
	end

	PersistData["WLEDSocket"]:SetClosedByRemoteFunction (closed)

	PersistData["WLEDSocket"]:Start ()

end

function ReceivedFromProxy (idBinding, strCommand, tParams)
	strCommand = strCommand or ''
	tParams = tParams or {}
	local args = {}
	if (tParams.ARGS) then
		local parsedArgs = C4:ParseXml(tParams.ARGS)
		for _, v in pairs(parsedArgs.ChildNodes) do
			args[v.Attributes.name] = v.Value
		end
		tParams.ARGS = nil
	end
	if (DEBUGPRINT) then
		local output = {"--- ReceivedFromProxy: "..idBinding, strCommand, "----PARAMS----"}
		for k, v in pairs(tParams) do table.insert(output, tostring(k).." = "..tostring(v)) end
		table.insert(output, "-----ARGS-----")
		for k, v in pairs(args) do table.insert(output, tostring(k).." = "..tostring(v)) end
		table.insert(output, "---")
		print (table.concat(output, "\r\n"))
	end
     local success, ret
	--strProperty = string.gsub (strProperty, '%s+', '_')
	if (RFP and RFP [strCommand] and type (RFP [strCommand]) == 'function') then
		success, ret = pcall (RFP [strCommand], tParams)
	end
	if (success == true) then
		return (ret)
	elseif (success == false) then
		print ('ReceivedFromProxy Lua error: ', strCommand, ret)
	end
end

function RFP.RAMP_TO_LEVEL(tParams)
    level = tParams["LEVEL"]
	time = tParams["TIME"]

    dbg("Ramping to "..level.." over "..time.."ms")
	
	WLED.SetLevel(level,time)
end

function RFP.SET_LEVEL(tParams)
    level = tParams["LEVEL"] 
	time = tParams["TIME"] or 0

    dbg("Setting level to "..level.." over "..time.."ms")
	
	WLED.SetLevel(level,time)
end

function RFP.ON()
    WLED.Power("on")
end

function RFP.OFF()
    WLED.Power("off")
end

function RFP.BUTTON_ACTION(tParams)
    buttonId = tonumber(tParams["BUTTON_ID"])
	buttonAction = tonumber(tParams["ACTION"])

    if (buttonId == 0) then -- Top
		if (buttonAction == 1) then -- Press
			WLED.Power("on")
		elseif (buttonAction == 0) then -- Release
		end
	elseif (buttonId == 1) then -- Bottom
		if (buttonAction == 1) then -- Press
			WLED.Power("off")
		elseif (buttonAction == 0) then -- Release
		end
	elseif (buttonId == 2) then -- Toggle
	   	if (buttonAction == 1) then -- Press
			WLED.Power("toggle")
		elseif (buttonAction == 0) then -- Release
		end
	end
end

function RFP.DO_CLICK(tParams, idBinding)
	if (idBinding == 300) then -- Top
		WLED.Power("on")
   	elseif (idBinding == 301) then -- Toggle
		WLED.Power("toggle")
	elseif (idBinding == 303) then -- Bottom
		WLED.Power("off")
	end
end

function RFP.SET_PRESET_LEVEL(tParams)
	PersistData["PRESET_LEVEL"] = tParams["LEVEL"]
end

function RFP.SET_CLICK_RATE_UP(tParams)
    PersistData["CLICK_RATE_UP"] = tParams["RATE"]
end

function RFP.SET_CLICK_RATE_DOWN(tParams)
    PersistData["CLICK_RATE_DOWN"] = tParams["RATE"]
end

function RFP.SET_COLOR_TARGET(tParams)
	WLED.SetColor(tParams)
end

function RFP.PUSH_SCENE(tParams)
    SceneID = tonumber(tParams["SCENE_ID"])
    PersistData["Scenes"][SceneID] = tParams
end

function RFP.ACTIVATE_SCENE(tParams)
    SceneID = tParams["SCENE_ID"]

    elements = PersistData["Scenes"][tonumber(SceneID)]["ELEMENTS"]
	elements = C4:ParseXml(elements)
	
	data = {}
	
	for k,v in pairs(elements.ChildNodes) do
	    data[v["Name"]] = v["Value"]
    end
	
	if (data["brightnessEnabled"] == "True") then
	 
	   dbg("Brightness mode enabled")
	   
	   WLED.SetLevel(data["brightness"],data["brightnessRate"])

    end
	
    if (data["colorEnabled"] == "True") then
	
	   dbg("Color mode enabled")
	   colorData = {}
	   colorData["LIGHT_COLOR_TARGET_X"] = data["colorX"]
	   colorData["LIGHT_COLOR_TARGET_Y"] = data["colorY"]
	   colorData["LIGHT_COLOR_TARGET_MODE"] = data["colorMode"]
	   colorData["RATE"] = data["colorRate"]
	   
	   WLED.SetColor(colorData)
	
    end
end

function ExecuteCommand (strCommand, tParams)
	tParams = tParams or {}
    if (DEBUGPRINT) then
        local output = {"--- ExecuteCommand", strCommand, "----PARAMS----"}
        for k, v in pairs(tParams) do
            table.insert(output, tostring(k).." = "..tostring(v))
        end
        table.insert(output, "---")
        print (table.concat(output, "\r\n"))
    end
    if (strCommand == "LUA_ACTION") then
        if (tParams.ACTION) then
            strCommand = tParams.ACTION
            tParams.ACTION = nil
        end
    end
    local success, ret
    strCommand = string.gsub(strCommand, "%s+", "_")
    if (EC and EC[strCommand] and type(EC[strCommand]) == "function") then
        success, ret = pcall(EC[strCommand], tParams)
    end
    if (success == true) then
        return (ret)
    elseif (success == false) then
        print ("ExecuteCommand Lua error: ", strCommand, ret)
    end
end

function EC.refresh_device()
    dbg("Refreshing Device")
    WLED.GetDeviceInfo()
	if (Properties["Communication Mode"] == "Websocket") then
		ConnectWebsocket()
	end
end

function EC.reboot_devices()
    WLED.GetURL("/win&RB","reboot")
end

function EC.Set_Effect(tParams)
	WLED.SetEffect(tParams["Effect"])
end

function EC.Set_Preset(tParams)
	WLED.SetPreset(tParams["Preset ID"])
end

function OnPropertyChanged (strProperty)
	local value = Properties [strProperty]
	if (value == nil) then
		value = ''
	end
	if (DEBUGPRINT) then
		local output = {"--- OnPropertyChanged: "..strProperty, value}
		print (output)
	end
	local success, ret
	strProperty = string.gsub (strProperty, '%s+', '_')
	if (OPC and OPC [strProperty] and type (OPC [strProperty]) == 'function') then
		success, ret = pcall (OPC [strProperty], value)
	end
	
	dbg("Property "..strProperty.." changed to "..value)
	
	if (success == true) then
		return (ret)
	elseif (success == false) then
		print ('OnPropertyChanged Lua error: ', strProperty, ret)
	end
end

function OPC.Debug_Mode (value)
	if (DEBUGPRINT) then
		DEBUGPRINT = false
	end
	if (value == 'On') then
		DEBUGPRINT = true
	end
end

function OPC.Primary_Device_Address(value)
    dbg("Device address changed to "..value)
	WLED.GetDeviceInfo()
	if (Properties["Communication Mode"] == "Websocket") then
		ConnectWebsocket()
	end
end

function OPC.Number_of_Additional_Devices(value)
    UpdateAdditionalDevices()
end

function WLED.GetURL(uri,source)

    urls = {}
	
	table.insert(urls,Properties["Primary Device Address"]..uri)

	if (source ~= "GetDeviceInfo") then -- Only update primary device values
	    for i = 1,NumDevices,1 do
			url = Properties[DeviceProperty..i]..uri
		  	table.insert(urls,url)
	    end
    end
	
	for i,url in pairs(urls) do
	
	    dbg ("---Get URL---")
	    dbg ("URL: "..url)
	    C4:urlGet(url, {}, false,
		    function(ticketId, strData, responseCode, tHeaders, strError)
			    if (strError == nil) then
				    strData = strData or ''
				    responseCode = responseCode or 0
				    tHeaders = tHeaders or {}
				    if (responseCode == 0) then
					    print("FAILED retrieving: "..url.." Error: "..strError)
				    end
				    if (strData == "") then
					    print("FAILED -- No Data returned")
				    end
				    if (responseCode == 200) then
					    dbg ("SUCCESS retrieving: "..url.." Response: "..strData)
					    
					    if (source == "GetDeviceInfo") then
						  WLED.PopulateDeviceInfo(strData)
					    end
					    
				    end
			    else
				    print("C4:urlGet() failed: "..strError)
			    end
		    end
	    )
	
	end

end

function WLED.PostURL(uri,data,source)

    baseUrl = Properties["Primary Device Address"]
	url = baseUrl..uri
	
	dbg ("---Get URL---")
	dbg ("URL: "..url)
	dbg ("Posting data: "..data)
	C4:urlPost(url, data, {["Content-Type"] = "text/json"})
	
	function ReceivedAsync(ticketId, strData, responseCode, tHeaders, strError)
			if (strError == nil) then
				strData = strData or ''
				responseCode = responseCode or 0
				tHeaders = tHeaders or {}
				if (responseCode == 0) then
					print("FAILED retrieving: "..url.." Error: "..strError)
				end
				if (strData == "") then
					print("FAILED -- No Data returned")
				end
				if (responseCode == 200) then
					dbg ("SUCCESS retrieving: "..url.." Response: "..strData)
					
					if (source == "GetDeviceInfo") then
					   WLED.PopulateDeviceInfo(strData)
				     end
					
					
					
				end
			else
				print("C4:urlPost() failed: "..strError)
			end
     end

end

function WLED.GetDeviceInfo()
    WLED.GetURL("/json","GetDeviceInfo")
end

function WLED.PopulateDeviceInfo(response)
    
    data = JSON:decode(response)

	state = data["state"]
	info = data["info"]
	effects = data["effects"]
	palettes = data["palettes"]

	--Update Properties
    
    C4:UpdateProperty("Name", info["name"])
    C4:UpdateProperty("WLED Version", info["ver"])
    C4:UpdateProperty("Chip Type", info["arch"])
    
    if (Properties["Auto Name Driver"] == "On") then
	   C4:RenameDevice(ProxyID, info["name"])
    end


	--Update Effects

	--Reverse list
	effectsRev = {}
	for index,name in orderedPairs(effects) do
		effectsRev[name] = index-1
	end

	local effectList = ""

	for effectIndex, effectName in orderedPairs(effects) do
		effectList = effectList..effectName..","
	end

	effectList = effectList:sub(1, -2)

	C4:UpdatePropertyList("Default Effect", effectList)
    
    DynamicCapabilities = {}
    
    -- leds["lc"]
    -- 0	None. Indicates a segment that does not have a bus within its range, e.g. because it is not active.
    -- 1	Supports RGB
    -- 2	Supports white channel only
    -- 3	Supports RGBW
    -- 4	Supports CCT only, no white channel (unused)
    -- 5	Supports CCT + RGB, no white channel (unused)
    -- 6	Supports CCT (including white channel)
    -- 7	Supports CCT (including white channel) + RGB

    -- leds["cct"]
    -- 0	Segment supports RGB color
    -- 1	Segment supports white channel
    -- 2	Segment supports color temperature
    -- 3-7	Reserved (expect any value)
    
    -- leds["wv"]
    -- bool  Displays white channel slider (v10.0+)
    
    
    --Still want the Color Temp slider in UI for RGB simulated color temp
    
    --if (leds["lc"] >= 4) then
	--   DynamicCapabilities["supports_color_correlated_temperature"] = true
    --else
	 --  DynamicCapabilities["supports_color_correlated_temperature"] = false
    --end
	    
    --C4:SendToProxy(5001, "DYANAMIC_CAPABILITIES_CHANGED", DynamicCapabilities)
    --C4:SendToProxy(5001, "ONLINE_CHANGED", {STATE=true})

end

function EffectSelection(currentValue)

	for k,v in pairs(EFFECT_SELECT) do EFFECT_SELECT[k] = nil end -- clear table!
	for effectIndex, effectName in orderedPairs(effects) do
		table.insert(EFFECT_SELECT, { text = effectName, value = effectIndex })
	end

	return EFFECT_SELECT

end

function WLED.SetEffect(fx)
	SetStr = "/win&FX="..fx
	WLED.GetURL(SetStr,"SetEffect")
	dbg("Setting effect to "..effects[tonumber(fx)])
end

function WLED.SetPreset(id)
	SetStr = "/win&PL="..id
	WLED.GetURL(SetStr,"SetPreset")
	dbg("Setting preset to "..id)
end

function WLED.SetLevel(level,time)

    scaledLevel = ConversionScale(level)
	currentLevel = C4:GetVariable(ProxyID, 1001)
	
	SetStr = "/win&A="..scaledLevel.."&TT="..time
	
	WLED.GetURL(SetStr,"SetLevel")
	
	dataToSend = {
	    LIGHT_BRIGHTNESS_CURRENT = currentLevel,
	    LIGHT_BRIGHTNESS_TARGET = level,
	    RATE = time
	}
	
	dbg("Setting level to "..level.." over "..time.."ms")
	
	if (Properties["Communication Mode"] == "HTTP") then
	    brightnessData = {
		  LIGHT_BRIGHTNESS_CURRENT = level,
		  RATE = time
	    }
	    C4:SendToProxy(5001,"LIGHT_BRIGHTNESS_CHANGED",brightnessData)
	else
	    brightnessData = {
		   LIGHT_BRIGHTNESS_CURRENT = currentLevel,
		   LIGHT_BRIGHTNESS_TARGET = level,
		   RATE = time
	    }
	    C4:SendToProxy(5001,"LIGHT_BRIGHTNESS_CHANGING",brightnessData)
     end

end

function WLED.Power(state)
    dbg("Setting WLED power to "..state)

    currentState = tonumber(C4:GetVariable(ProxyID, 1000))
	
    rateUp = PersistData["CLICK_RATE_UP"]
	rateDown = PersistData["CLICK_RATE_DOWN"]
	--rateHold = C4:GetVariable(ProxyID, 1004)
	
	defaultLevel = C4:GetVariable(ProxyID, 1006)

    if (state == "on") then
		WLED.SetLevel(defaultLevel,rateUp)
	elseif (state == "off") then
		WLED.SetLevel(0,rateDown)
	elseif (state == "toggle") then
		dbg("Current state: "..currentState)
	   	if (currentState ~= 0) then
			WLED.SetLevel(0,rateDown)
	   	else
			WLED.SetLevel(defaultLevel,rateUp)
	   	end
	end
end

function WLED.SetColor(tParams)
	
	x1 = tParams["LIGHT_COLOR_TARGET_X"]
	y1 = tParams["LIGHT_COLOR_TARGET_Y"]
	
	mode = tonumber(tParams["LIGHT_COLOR_TARGET_MODE"])
	rate = tParams["RATE"] or tParams["LIGHT_COLOR_TARGET_RATE"]
	
	currentLevel = C4:GetVariable(ProxyID, 1001)
	
    temp = tonumber(Properties["White Color Temperature"])
	
	fx = effectsRev[Properties["Default Effect"]]
	
    -- leds["lc"]
    -- 0	None. Indicates a segment that does not have a bus within its range, e.g. because it is not active.
    -- 1	Supports RGB
    -- 2	Supports white channel only
    -- 3	Supports RGBW
    -- 4	Supports CCT only, no white channel (unused)
    -- 5	Supports CCT + RGB, no white channel (unused)
    -- 6	Supports CCT (including white channel)
    -- 7	Supports CCT (including white channel) + RGB

    -- leds["cct"]
    -- 0	Segment supports RGB color
    -- 1	Segment supports white channel
    -- 2	Segment supports color temperature
    -- 3-7	Reserved (expect any value)
    
    -- leds["wv"]
    -- bool  Displays white channel slider (v10.0+)
	
    
    --Check for CCT, if not suppored then go back to RGB
    
    leds = info["leds"]
    
    if (leds["lc"]) then
	    if (leds["lc"] >= 4) then
			modeNew = 1
	    else
			modeNew = 0	
	    end
    else
	    modeNew = 0
    end
	
	
	if (modeNew == 0) then
	
	    --Only use white channel if CCT isn't supported, but the default while K value is selected
	    --This sets RGB to 0 and W to 255 for accurate color
	    k = C4:ColorXYtoCCT (x1, y1)
	    k = tonumber(k)
	    if (mode == 1 and temp == k and leds["lc"] == 3) then
			dbg("Color temp called, k: "..k)
			dbg("Default white color was set. Using only white channel.")
	    	SetStr = "/win&TT="..rate.."&R=0&G=0&B=0&W=255&FX="..fx
	    else
			c2 = Properties["Color Palette 2"]
			c3 = Properties["Color Palette 3"]

			r1,g1,b1 = C4:ColorXYtoRGB(x1,y1)
			r2,g2,b2 = c2:match("([^,]+),([^,]+),([^,]+)")
			r3,g3,b3 = c3:match("([^,]+),([^,]+),([^,]+)")

			c1 = rgb_to_hex(r1,g1,b1)
			c2 = rgb_to_hex(r2,g2,b2)
			c3 = rgb_to_hex(r3,g3,b3)
			
			SetStr = "/win&TT="..rate.."&CL=h"..c1.."&C2=h"..c2.."&C3=h"..c3.."&FX="..fx
			
			dbg("Setting color to "..r1..","..g1..","..b1.." over "..rate.."ms")
		end
	
    else
	    --k = C4:ColorXYtoCCT (x, y)
	    SetStr = "/win&LY="..k.."&TT="..rate
		dbg("Setting temperature to "..k.." over "..rate.."ms")
    end
	
	WLED.GetURL(SetStr,"SetColor")
	
	dataToSend = {
	   LIGHT_COLOR_CURRENT_X = x1,
	   LIGHT_COLOR_CURRENT_Y = y1,
	   LIGHT_COLOR_CURRENT_COLOR_MODE = mode,
	   RATE = rate
    }

	
	if (Properties["Communication Mode"] == "HTTP") then
		C4:SendToProxy(5001,"LIGHT_COLOR_CHANGED",dataToSend)
	else
		C4:SendToProxy(5001,"LIGHT_COLOR_CHANGING",dataToSend)
	end

end

function WLED.ConnectionState(connected)

	if (connected) then
		C4:UpdateProperty("Websocket State", "Connected")
		C4:SendToProxy(5001, "ONLINE_CHANGED", {STATE=true})
		RetryCount = 0
		dbg("WS reports online state")
	else
		C4:UpdateProperty("Websocket State", "Disconnected")
		C4:SendToProxy(5001, "ONLINE_CHANGED", {STATE=false})
		dbg("WS reports offline state")
	end

	if (not connected and ReconnectTimer == nil) then
		dbg("Starting reconnect timer.")
		ReconnectTimer = C4:SetTimer(10000,WLED.AttemptReconnect,true)
	end

end

function WLED.AttemptReconnect()
	RetryCount = RetryCount + 1

	local state = Properties["Websocket State"]

	if (RetryCount > MaxRetries) then
		ReconnectTimer:Cancel()
		ReconnectTimer = nil
		dbg("Stopping reconnection: Max retry count reached")
		C4:UpdateProperty("Websocket State", "Disconnected: Max reconnect attempts reached")
	elseif (state == "Connected") then
		ReconnectTimer:Cancel()
		ReconnectTimer = nil
		dbg("Stopping reconnection: Connection has been restored.")
	else
		local str = "Reconnect attempt #"..RetryCount
		dbg(str)
		C4:UpdateProperty("Websocket State", str)
		ConnectWebsocket()
	end

end

function WLED.WSDataReceived(data)
    
    data = JSON:decode(data)

	if (data["state"]["on"]) then
	   	brightness = data["state"]["bri"]
	   	brightness = ConversionScale100(brightness)
    else
		brightness = 0
    end
	
	mainseg = data["state"]["mainseg"] + 1
	
	basecolor = data["state"]["seg"][mainseg]["col"][1]
	
	r = basecolor[1]
	g = basecolor[2]
    b = basecolor[3]
	
	if (basecolor[4]) then
		w = basecolor[4]
    end
	
	if (w > 0) then
		x,y = C4:ColorCCTtoXY(tonumber(Properties["White Color Temperature"]))
	else
	   x,y = C4:ColorRGBtoXY(r, g, b)
	end
	
	brightnessData = {
		LIGHT_BRIGHTNESS_CURRENT = brightness
    }
	
    colorData = {
	   	LIGHT_COLOR_CURRENT_X = x,
	   	LIGHT_COLOR_CURRENT_Y = y,
    }
    
    C4:SendToProxy(5001,"LIGHT_BRIGHTNESS_CHANGED",brightnessData)
	C4:SendToProxy(5001,"LIGHT_COLOR_CHANGED",colorData)
end

function rgb_to_hex(r, g, b)
    --%02x: 0 means replace " "s with "0"s, 2 is width, x means hex
	return string.format("%02x%02x%02x", 
		math.floor(r),
		math.floor(g),
		math.floor(b))
end

function __genOrderedIndex(t)
    local orderedIndex = {}
    for key in pairs(t) do
        table.insert( orderedIndex, key )
    end
    table.sort( orderedIndex, cmp_multitype )
    return orderedIndex
end

function orderedNext(t, state)
    local key = nil
    if state == nil then
        t.__orderedIndex = __genOrderedIndex( t )
        key = t.__orderedIndex[1]
    else
        for i = 1,table.getn(t.__orderedIndex) do
            if t.__orderedIndex[i] == state then
                key = t.__orderedIndex[i+1]
            end
        end
    end

    if key then
        return key, t[key]
    end

    t.__orderedIndex = nil
    return
end

function orderedPairs(t)
    return orderedNext, t, nil
end