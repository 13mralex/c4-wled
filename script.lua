function OnDriverInit()
     print("Driver init...")
	
     C4:AddVariable("DIMMER_LEVEL", "0", "INT")
     C4:AddVariable("RED_LEVEL", "0", "INT")
     C4:AddVariable("GREEN_LEVEL", "0", "INT")
     C4:AddVariable("BLUE_LEVEL", "0", "INT")
     C4:AddVariable("WHITE_LEVEL", "0", "INT")
	C4:AddVariable("EFFECT", "0", "INT")
	C4:AddVariable("UPDATE", "0", "BOOL")
	sceneCollection = PersistData["sceneCollection"] or {}
     flashCollection = PersistData["flashCollection"] or {}
     elementCounter = 0
     currentScene = 0
     executeElementTimer = 0
	
     print("Variables added...")
	C4:SendToProxy(5001, "ONLINE_CHANGED", {STATE=true})
	print("Driver online...")
end


function ReceivedFromProxy(idBinding, strCommand, tParams)

  if (strCommand == "ON") then
    powerCmd("on")
  end
  if (strCommand == "OFF") then
    powerCmd("off")
  end
  if (strCommand == "TOGGLE") then
    if (dimmer == "0") then
	       powerCmd("on")
	     else
		  powerCmd("off")
    end
  end

    if (strCommand == "PUSH_SCENE") then
            for k,v in pairs(tParams) do
                print(k .. ": " .. v)
            end
            local sceneNum = tParams["SCENE_ID"]
            local elements = tParams["ELEMENTS"]
            local flash = tParams["FLASH"]
            print("scene_id" .. sceneNum)
            print("elements: " .. tParams["ELEMENTS"])
            local elementTable = collect(elements)

            local scene = {}

            for i=1,#elementTable do
                local t = {}
                t["Delay"] = elementTable[i][1][1]
                t["Rate"] = elementTable[i][2][1]
                t["Level"] = elementTable[i][3][1]
                table.insert(scene,t)
            end
                sceneCollection[sceneNum] = scene

                flashCollection[sceneNum] = flash

                PersistData["sceneCollection"] = sceneCollection
                PersistData["flashCollection"] = flashCollection
        elseif (strCommand == "REMOVE_SCENE") then
            local sceneNum = tParams["SCENE_ID"]
            print("scene_id: " .. sceneNum)

            sceneCollection[sceneNum] = nil

            flashCollection[sceneNum] = nil

            PersistData["sceneCollection"] = sceneCollection
            PersistData["flashCollection"] = flashCollection

        elseif (strCommand == "ACTIVATE_SCENE") then
            local sceneNum = tParams["SCENE_ID"]
		  --rPrint(tParams, 1000, "ACTIVATE_SCENE")
            --for k,v in pairs(tParams) do
            --    dbg(k .. ": " .. v)
            --end
            currentScene = sceneNum
            elementCounter = 0
            playScene()
  end
  
  if (strCommand == "GET_CONNECTED_STATE") then
    C4:SendToProxy(5001, "ONLINE_CHANGED", {STATE=true})
    return
  end
  
  if (strCommand == "SET_LEVEL") then
    print("Light level changed...")
    dimmer = tParams["LEVEL"]
    SetColor = Properties["Default Color"]
    SetColor1 = {}
    local counter = 0
    for i in SetColor:gmatch('[^,%s]+') do
	   counter = counter + 1
	   SetColor1[counter] = i
    end

    SetColorR = SetColor1[1]
    SetColorG = SetColor1[2]
    SetColorB = SetColor1[3]
    
    C4:SetVariable("DIMMER_LEVEL", (dimmer*255)/100)
    C4:SetVariable("RED_LEVEL", SetColorR)
    C4:SetVariable("GREEN_LEVEL", SetColorG)
    C4:SetVariable("BLUE_LEVEL", SetColorB)
    C4:SetVariable("WHITE_LEVEL", Properties["Default White Value"])
    C4:SetVariable("EFFECT", Properties["Default Effect"])
    setColor()
  end
  
  if (strCommand == "RAMP_TO_LEVEL") then
    rampState = true
    dimmer = tParams["LEVEL"]
    rampRate = tonumber(tParams["TIME"])
    SetColor = Properties["Default Color"]
    SetColor1 = {}
    local counter = 0
    for i in SetColor:gmatch('[^,%s]+') do
	   counter = counter + 1
	   SetColor1[counter] = i
    end
    
    print("Light level changed, ramping to "..dimmer.." over the course of "..rampRate.." milliseconds...")
    
    if (rampRate > 65000) then
	   print("Ramp rate reached max. Capping at 65,000ms")
	   rampRate = 65000
    end

    SetColorR = SetColor1[1]
    SetColorG = SetColor1[2]
    SetColorB = SetColor1[3]

    C4:SetVariable("DIMMER_LEVEL", (dimmer*255)/100)
    C4:SetVariable("RED_LEVEL", SetColorR)
    C4:SetVariable("GREEN_LEVEL", SetColorG)
    C4:SetVariable("BLUE_LEVEL", SetColorB)
    C4:SetVariable("WHITE_LEVEL", Properties["Default White Value"])
    C4:SetVariable("EFFECT", Properties["Default Effect"])
    setColor()
  end
  
  if (strCommand == "BUTTON_ACTION") then
    local action = tParams["ACTION"]
    local id = tParams["BUTTON_ID"]
    print("Button action: "..action)
    print("Button ID: "..id)
    
      if (id == "0") then
	   if (action == "2") then
	     powerCmd("on")
	   end
	 end
	 if (id == "1") then
	   if (action == "2") then
	     powerCmd("off")
	   end
	 end
	 if (id == "2") then
	   if (action == "2") then
	     if (dimmer == "0") then
	       powerCmd("on")
	     else
		  powerCmd("off")
	     end
	   end
	 end
  end
  
  
  print("Proxy command: "..strCommand)
  for k,v in pairs(tParams) do
	   print(k .. ": " .. v)
  end

  
-- The rest of your ReceivedFromProxy code goes here...

end

function powerCmd(cmd)

ipAddr1 = Properties["IP Address 1"]
ipAddr2 = Properties["IP Address 2"]
ipAddr3 = Properties["IP Address 3"]
ipAddr4 = Properties["IP Address 4"]
ipAddr5 = Properties["IP Address 5"]

print("Setting Dimmer Command: "..cmd)

rampState = false

if (cmd == "off") then
    dimmerVal = "0"
end    

if (cmd == "on") then

    print("Light level changed...")
    
    rampRate = 500
    
    SetColor = Properties["Default Color"]
    SetColor1 = {}
    local counter = 0
    for i in SetColor:gmatch('[^,%s]+') do
	   counter = counter + 1
	   SetColor1[counter] = i
    end

    SetColorR = SetColor1[1]
    SetColorG = SetColor1[2]
    SetColorB = SetColor1[3]

    C4:SetVariable("DIMMER_LEVEL", "255")
    C4:SetVariable("RED_LEVEL", SetColorR)
    C4:SetVariable("GREEN_LEVEL", SetColorG)
    C4:SetVariable("BLUE_LEVEL", SetColorB)
    C4:SetVariable("WHITE_LEVEL", Properties["Default White Value"])
    C4:SetVariable("EFFECT", Properties["Default Effect"])

    dimmerVal = "255"
end

dimmer =  Variables["DIMMER_LEVEL"]

dimmer100 = (dimmer*100)/255
C4:SendToProxy(5001, "LIGHT_LEVEL", dimmer100)

urlCall1 = ipAddr1.."/win&T="..dimmerVal.."&TT="..rampRate
urlCall2 = ipAddr2.."/win&T="..dimmerVal.."&TT="..rampRate
urlCall3 = ipAddr3.."/win&T="..dimmerVal.."&TT="..rampRate
urlCall4 = ipAddr4.."/win&T="..dimmerVal.."&TT="..rampRate
urlCall5 = ipAddr5.."/win&T="..dimmerVal.."&TT="..rampRate

C4:urlGet(urlCall1, {}, false,
    function(ticketId, strData, responseCode, tHeaders, strError)
	   if (strError == nil) then
		  print("URL Call succeeded")
	   else
		  print("C4:urlGet() failed: " .. strError)
	   end
    end
)

C4:urlGet(urlCall2, {}, false,
    function(ticketId, strData, responseCode, tHeaders, strError)
	   if (strError == nil) then
		  print("URL Call succeeded")
	   else
		  print("C4:urlGet() failed: " .. strError)
	   end
    end
)

C4:urlGet(urlCall3, {}, false,
    function(ticketId, strData, responseCode, tHeaders, strError)
	   if (strError == nil) then
		  print("URL Call succeeded")
	   else
		  print("C4:urlGet() failed: " .. strError)
	   end
    end
)

C4:urlGet(urlCall4, {}, false,
    function(ticketId, strData, responseCode, tHeaders, strError)
	   if (strError == nil) then
		  print("URL Call succeeded")
	   else
		  print("C4:urlGet() failed: " .. strError)
	   end
    end
)

C4:urlGet(urlCall5, {}, false,
    function(ticketId, strData, responseCode, tHeaders, strError)
	   if (strError == nil) then
		  print("URL Call succeeded")
	   else
		  print("C4:urlGet() failed: " .. strError)
	   end
    end
)

C4:SetVariable("DIMMER_LEVEL", "0")

end

function setColor()

ipAddr1 = Properties["IP Address 1"]
ipAddr2 = Properties["IP Address 2"]
ipAddr3 = Properties["IP Address 3"]
ipAddr4 = Properties["IP Address 4"]
ipAddr5 = Properties["IP Address 5"]
red =  Variables["RED_LEVEL"]
green =  Variables["GREEN_LEVEL"]
blue =  Variables["BLUE_LEVEL"]
white =  Variables["WHITE_LEVEL"]
effect = Variables["EFFECT"]
dimmer =  Variables["DIMMER_LEVEL"]


if (dimmer == "0") then

  print("Dimmer is 0, handing to power function")
  powerCmd("off")
  return
  
end

rampState = false

dimmer100 = (dimmer*100)/255

C4:SendToProxy(5001, "LIGHT_LEVEL", dimmer100)

print("Sent to proxy: "..dimmer100)

print("Setting Color: ".."d: "..dimmer.." RGB: "..red..","..green..","..blue..","..white)

urlCall1 = ipAddr1.."/win&A="..dimmer.."&R="..red.."&G="..green.."&B="..blue.."&W="..white.."&FX="..effect.."&TT="..rampRate
urlCall2 = ipAddr2.."/win&A="..dimmer.."&R="..red.."&G="..green.."&B="..blue.."&W="..white.."&FX="..effect.."&TT="..rampRate
urlCall3 = ipAddr3.."/win&A="..dimmer.."&R="..red.."&G="..green.."&B="..blue.."&W="..white.."&FX="..effect.."&TT="..rampRate
urlCall4 = ipAddr4.."/win&A="..dimmer.."&R="..red.."&G="..green.."&B="..blue.."&W="..white.."&FX="..effect.."&TT="..rampRate
urlCall5 = ipAddr5.."/win&A="..dimmer.."&R="..red.."&G="..green.."&B="..blue.."&W="..white.."&FX="..effect.."&TT="..rampRate



C4:urlGet(urlCall1, {}, false,
    function(ticketId, strData, responseCode, tHeaders, strError)
	   if (strError == nil) then
		  print("URL Call succeeded")
	   else
		  print("C4:urlGet() failed: " .. strError)
	   end
    end
)

C4:urlGet(urlCall2, {}, false,
    function(ticketId, strData, responseCode, tHeaders, strError)
	   if (strError == nil) then
		  print("URL Call succeeded")
	   else
		  print("C4:urlGet() failed: " .. strError)
	   end
    end
)

C4:urlGet(urlCall3, {}, false,
    function(ticketId, strData, responseCode, tHeaders, strError)
	   if (strError == nil) then
		  print("URL Call succeeded")
	   else
		  print("C4:urlGet() failed: " .. strError)
	   end
    end
)

C4:urlGet(urlCall4, {}, false,
    function(ticketId, strData, responseCode, tHeaders, strError)
	   if (strError == nil) then
		  print("URL Call succeeded")
	   else
		  print("C4:urlGet() failed: " .. strError)
	   end
    end
)

C4:urlGet(urlCall5, {}, false,
    function(ticketId, strData, responseCode, tHeaders, strError)
	   if (strError == nil) then
		  print("URL Call succeeded")
	   else
		  print("C4:urlGet() failed: " .. strError)
	   end
    end
)

C4:SetVariable("DIMMER_LEVEL", "0")
C4:SetVariable("RED_LEVEL", "0")
C4:SetVariable("GREEN_LEVEL", "0")
C4:SetVariable("BLUE_LEVEL", "0")
C4:SetVariable("WHITE_LEVEL", "0")

end

function setPreset(id)
ipAddr1 = Properties["IP Address 1"]
ipAddr2 = Properties["IP Address 2"]
ipAddr3 = Properties["IP Address 3"]
ipAddr4 = Properties["IP Address 4"]
ipAddr5 = Properties["IP Address 5"]

urlCall1 = ipAddr1.."/win&PL="..id
urlCall2 = ipAddr2.."/win&PL="..id
urlCall3 = ipAddr3.."/win&PL="..id
urlCall4 = ipAddr4.."/win&PL="..id
urlCall5 = ipAddr5.."/win&PL="..id

print("Preset URL: "..urlCall1)

C4:urlGet(urlCall1, {}, false,
    function(ticketId, strData, responseCode, tHeaders, strError)
	   if (strError == nil) then
		  print("URL Call succeeded")
	   else
		  print("C4:urlGet() failed: " .. strError)
	   end
    end
)

C4:urlGet(urlCall2, {}, false,
    function(ticketId, strData, responseCode, tHeaders, strError)
	   if (strError == nil) then
		  print("URL Call succeeded")
	   else
		  print("C4:urlGet() failed: " .. strError)
	   end
    end
)

C4:urlGet(urlCall3, {}, false,
    function(ticketId, strData, responseCode, tHeaders, strError)
	   if (strError == nil) then
		  print("URL Call succeeded")
	   else
		  print("C4:urlGet() failed: " .. strError)
	   end
    end
)

C4:urlGet(urlCall4, {}, false,
    function(ticketId, strData, responseCode, tHeaders, strError)
	   if (strError == nil) then
		  print("URL Call succeeded")
	   else
		  print("C4:urlGet() failed: " .. strError)
	   end
    end
)

C4:urlGet(urlCall5, {}, false,
    function(ticketId, strData, responseCode, tHeaders, strError)
	   if (strError == nil) then
		  print("URL Call succeeded")
	   else
		  print("C4:urlGet() failed: " .. strError)
	   end
    end
)

end

function OnVariableChanged(strName)
print(strName.." variable updated, new value "..Variables[strName])
if (Variables["UPDATE"] == "1") then
    print("update true")
    setColor()
    C4:SetVariable("UPDATE", "0")
    print("update set back to false")
end
end


function ExecuteCommand(strCommand, tParams)
--print("ExecuteCommand function called with : " .. strCommand)
 if (tParams == nil) then
   if (strCommand =="GET_PROPERTIES") then
     GET_PROPERTIES()
   else
     --print ("From ExecuteCommand Function - Unutilized command: " .. strCommand)
   end
 end
 
 if (strCommand == "Set Color") then
    print("Set Color Command...")
    
    SetColor = tParams["RGB"]
    SetColor1 = {}
    local counter = 0
    for i in SetColor:gmatch('[^,%s]+') do
	   counter = counter + 1
	   SetColor1[counter] = i
    end

    SetColorR = SetColor1[1]
    SetColorG = SetColor1[2]
    SetColorB = SetColor1[3]
    SetWhite = tParams["White"]
    SetDimmer = tParams["Dimmer"]
    
    print("R: "..SetColorR.." G: "..SetColorG.." B: "..SetColorB.." White: "..SetWhite.." Dimmer: "..SetDimmer)
    
    C4:SetVariable("DIMMER_LEVEL", SetDimmer)
    C4:SetVariable("RED_LEVEL", SetColorR)
    C4:SetVariable("GREEN_LEVEL", SetColorG)
    C4:SetVariable("BLUE_LEVEL", SetColorB)
    C4:SetVariable("WHITE_LEVEL", SetWhite)
    
    setColor()
    
 end
 
 if (strCommand == "Set Effect") then
    print("Set effect...")
    C4:SetVariable("EFFECT", tParams["Effect Index"])
    C4:SetVariable("DIMMER_LEVEL", "255")
    print("Effect: "..tParams["Effect Index"])
    setColor()
 end
 
 if (strCommand == "Set Preset") then
    print("Setting preset"..tParams["Preset ID"].."...")
    setPreset(tParams["Preset ID"])
 end
 
 if (strCommand == "LUA_ACTION") then
   if tParams ~= nil then
     for cmd,cmdv in pairs(tParams) do 
       --print (cmd,cmdv)
       if cmd == "ACTION" then
         if cmdv == "helloworld" then
	      C4:SendToProxy(5001, "ONLINE_CHANGED", {STATE=true})
           print("Hello world, online")
	    elseif cmdv == "fullwhite" then
	      setColor()
         else
           --print("From ExecuteCommand Function - Undefined Action")
           --print("Key: " .. cmd .. "  Value: " .. cmdv)
         end
       else
         --print("From ExecuteCommand Function - Undefined Command")
         --print("Key: " .. cmd .. "  Value: " .. cmdv)
       end
     end
   end
 end
end

function playScene()
    print("Playing Scene...")
    if (elementCounter ~= 0) then
        local t = {}
        dimmer = sceneCollection[tostring(currentScene)][elementCounter]["Level"]
        rampRate = tonumber(sceneCollection[tostring(currentScene)][elementCounter]["Rate"])
        rampState = true
	   SetColor = Properties["Default Color"]
	   SetColor1 = {}
	   local counter = 0
	   for i in SetColor:gmatch('[^,%s]+') do
		  counter = counter + 1
		  SetColor1[counter] = i
	   end
	   
	   print("Light level changed, ramping to "..dimmer.." over the course of "..rampRate.." milliseconds...")
	   
	   if (rampRate > 65000) then
		  print("Ramp rate reached max. Capping at 65,000ms")
		  rampRate = 65000
	   end

	   SetColorR = SetColor1[1]
	   SetColorG = SetColor1[2]
	   SetColorB = SetColor1[3]

	   C4:SetVariable("DIMMER_LEVEL", (dimmer*255)/100)
	   C4:SetVariable("RED_LEVEL", SetColorR)
	   C4:SetVariable("GREEN_LEVEL", SetColorG)
	   C4:SetVariable("BLUE_LEVEL", SetColorB)
	   C4:SetVariable("WHITE_LEVEL", Properties["Default White Value"])
	   C4:SetVariable("EFFECT", Properties["Default Effect"])
	   setColor()
    end
    elementCounter = elementCounter + 1
    print(elementCounter)

    if (elementCounter > #sceneCollection[tostring(currentScene)] and flashCollection[tostring(currentScene)] == "1") then
        elementCounter = 1
    end

    if (elementCounter <= #sceneCollection[tostring(currentScene)]) then
        local timeInterval = sceneCollection[tostring(currentScene)][elementCounter]["Delay"] or -1
        executeElementTimer = C4:KillTimer(executeElementTimer)
        executeElementTimer = C4:AddTimer(timeInterval, "MILLISECONDS")
    else
        print("end of scene")
    end
end

function collect(s)
  local stack = {}
  local top = {}
  table.insert(stack, top)
  local ni,c,label,xarg, empty
  local i, j = 1, 1
  while true do
    ni,j,c,label,xarg, empty = string.find(s, "<(%/?)([%w:]+)(.-)(%/?)>", i)
    if not ni then break end
    local text = string.sub(s, i, ni-1)
    if not string.find(text, "^%s*$") then
      table.insert(top, text)
    end
    if empty == "/" then  -- empty element tag
      table.insert(top, {label=label, xarg=parseargs(xarg), empty=1})
    elseif c == "" then   -- start tag
      top = {label=label, xarg=parseargs(xarg)}
      table.insert(stack, top)   -- new level
    else  -- end tag
      local toclose = table.remove(stack)  -- remove top
      top = stack[#stack]
      if #stack < 1 then
        print("nothing to close with "..label)
      end
      if toclose.label ~= label then
        print("trying to close "..toclose.label.." with "..label)
      end
      table.insert(top, toclose)
    end
    i = j+1
  end
  local text = string.sub(s, i)
  if not string.find(text, "^%s*$") then
    table.insert(stack[#stack], text)
  end
  if #stack > 1 then
    print("unclosed "..stack[#stack].label)
  end
  return stack[1]
end

function parseargs(s)
  local arg = {}
  string.gsub(s, "(%w+)=([\"'])(.-)%2", function (w, _, a)
    arg[w] = a
  end)
  return arg
end

function OnTimerExpired(idTimer)
    if (idTimer == g_DebugTimer) then
        print("Turning Debug Mode Off (timer expired)")
        C4:UpdateProperty("Debug Mode", "Off")
    elseif (idTimer == executeElementTimer) then
        playScene()
    end
    --C4:KillTimer(idTimer)
end
