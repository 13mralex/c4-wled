require "json"
JSON=(loadstring(json.JSON_LIBRARY_CHUNK))()

do	--Globals
	OPC = OPC or {}
	EC = EC or {}
	RFP = RFP or {}
	WLED = {}
	DeviceID = nil
	PersistData["Scenes"] = PersistData["Scenes"] or {}
end

function dbg (strDebugText, ...)
     if (Properties["Debug Mode"] == 'On') then
		DEBUGPRINT = true
	end

	if (DEBUGPRINT) then print (os.date ('%x %X : ')..(strDebugText or ''), ...) end
end

function OnDriverInit()

     --C4:AddVariable("PRESET_LEVEL",0,"NUMBER",false,true)
	--C4:AddVariable("CLICK_RATE_UP",0,"NUMBER",false,true)
	--C4:AddVariable("CLICK_RATE_DOWN",0,"NUMBER",false,true)

end

function OnDriverLateInit()

     dbg("On driver late init...")
	
	DeviceID = C4:GetDeviceID()
	ProxyID = C4:GetProxyDevicesById(DeviceID)

     WLED.GetDeviceInfo()

end

function ConversionScale(level)

     level = tonumber(level)
     level = (level/100)*255
     level = math.floor(level)
	return level

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

function RFP.BUTTON_ACTION(tParams)

     buttonId = tonumber(tParams["BUTTON_ID"])
	buttonAction = tonumber(tParams["ACTION"])
	
	--dbg("button id: "..buttonId)
	--dbg("button action: "..buttonAction)

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

function OPC.Primary_Host_Address(value)
     dbg("Host address changed to "..value)
	WLED.GetDeviceInfo()

end

function WLED.GetURL(uri,source)

     baseUrl = Properties["Primary Host Address"]
	url = baseUrl..uri
	
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

function WLED.PostURL(uri,data,source)

     baseUrl = Properties["Primary Host Address"]
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
     WLED.GetURL("/json/info","GetDeviceInfo")
end

function WLED.PopulateDeviceInfo(response)
    
    data = JSON:decode(response)
    
    C4:UpdateProperty("Name", data["name"])
    C4:UpdateProperty("WLED Version", data["ver"])
    C4:UpdateProperty("Chip Type", data["arch"])
    
    C4:RenameDevice(ProxyID, data["name"])
    
    C4:SendToProxy(5001, "ONLINE_CHANGED", {STATE=true})

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
	
	C4:SendToProxy(5001,"LIGHT_BRIGHTNESS_CHANGING",dataToSend)

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
	
	x = tParams["LIGHT_COLOR_TARGET_X"]
	y = tParams["LIGHT_COLOR_TARGET_Y"]
	
	mode = tonumber(tParams["LIGHT_COLOR_TARGET_MODE"])
	rate = tParams["RATE"]
	
	currentLevel = C4:GetVariable(ProxyID, 1001)
	
	
	if (mode == 0) then
	
	    r,g,b = C4:ColorXYtoRGB (x, y)
	    
	    SetStr = "/win&R="..r.."&G="..g.."&B="..b.."&TT="..rate
	    
	    dbg("Setting color to "..r..","..g..","..b.." over "..rate.."ms")
	
     else
	    k = C4:ColorXYtoCCT (x, y)
	    
	    SetStr = "/win&LY="..k.."&TT="..rate
	    
	    dbg("Setting temperature to "..k.." over "..rate.."ms")
	    
     end
	
	WLED.GetURL(SetStr,"SetColor")
	
	dataToSend = {

	   LIGHT_COLOR_CURRENT_X = x,
	   LIGHT_COLOR_CURRENT_Y = y,
	   LIGHT_COLOR_CURRENT_COLOR_MODE = mode

    }

	
	C4:SendToProxy(5001,"LIGHT_COLOR_CHANGED",dataToSend)

end