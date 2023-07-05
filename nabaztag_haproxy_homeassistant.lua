
--[[
  This function build the body to send to HomeAssistant
--]]
local function update_request(txn, path, action, query)
  if not query then query = "" end

  txn.http.req_set_path(txn.http, path)
  txn.http.req_set_query(txn.http, "action=" .. action .. "&" .. query)

  -- I don't succeed to rewrite body, which could have allowed to send json instead of url query...
  -- txn.http.req_set_header(txn.http, "nabaztamp", ztampId)
  -- txn.http.req_set_header(txn.http, "Content-Type", "application/json")

  txn.http.req_set_body(txn.http, "action=" .. action .. "&" .. query)
end

--[[
  This function is the one to call from HAProxy and SHOULD receive an argument to define the HomeAssistant webhook URL.
  This function MUST be called on 
  If no path is given, then the default one is use and MUST be defined in HomeAssistant : "/api/webhook/nabaztag"
  The requests will be sent to domain:port of the original request, on which the path is added.
  Example 1 : Click
  - Original request sent by the Nabaztag : http://myhomeassistantinstance.fr/local/vl/hooks/click.php
  - rewritten URL : http://myhomeassistantinstance.fr/api/webhook/nabaztag?action=click
  Example 2 : Action on a ear of the rabbit
  - Original request sent by the Nabaztag : http://myhomeassistantinstance.fr/local/vl/hooks/ears.php
  - rewritten URL : http://myhomeassistantinstance.fr/api/webhook/nabaztag?action=ears&left=10&right=4
  Example 3 : Scan a ztamp
  - Original request sent by the Nabaztag : http://myhomeassistantinstance.fr/local/vl/hooks/rfid.php
  - rewritten URL : http://myhomeassistantinstance.fr/api/webhook/nabaztag?action=rfid&tag=0123456789ABCDEF
--]]
local function nabaztag_request_rewrite(txn, dst_path)
  txn:Info("NAB : Start")
  txn:Debug(txn.f:path())
  txn:Debug(txn.sf:req_body())

  -- Path of the Home Assistant hook to where forward requests
  if not dst_path then
    dst_path = "/api/webhook/nabaztag"
    txn:Warning("Nab : No dst_path received, will use the default one : ".. dst_path )
  end

  -- Read initial path to detect event type
  local init_path = txn.f:path()
  txn:Debug(string.sub(init_path, 1, 10))

  if init_path == "/local/vl/bc.jsp" then
    txn:Info("NAB : get firmware request, pass through.")
  elseif init_path == "/local/vl/config" then
    txn:Info("NAB : get file request (voices, sounds, ...), pass through.")
  elseif string.sub(init_path, 1, 10) == "/local/vl/" then
    txn:Info("NAB : get event request (click, dblclick, ear, rfid, ...), will transform the request.")
    local init_body = txn.sf:req_body()

    --local data = txn.req.dup(txn.req)
    --local event_type = string.sub(data, 22, string.find(data, ".php", 22) -1 )
    local event_type = string.sub(init_path, 17, - 5)
  
    -- BUTTON CLICK -- /local/vl/hooks/click.php time=22631262
    if event_type == 'click' then update_request(txn, dst_path, event_type)
    
    -- BUTTON DOUBLE CLICK -- /local/vl/hooks/dblclick.php time=22631262
    elseif event_type == 'dblclick' then update_request(txn, dst_path, event_type)
    
    -- EAR MOVEMENT -- /local/vl/hooks/ears.php left=0&right=13
    elseif event_type == 'ears' then
      local ears_left = string.sub(init_body, string.find(init_body, "left=") + 5, string.find(init_body, "&") -1 )
      local ears_right = string.sub(init_body, string.find(init_body, "right=")+6)
      update_request(txn, dst_path, event_type, "left=" .. ears_left .. "&right=" .. ears_right)
    
    -- ZTAMP RFID -- /local/vl/hooks/rfid.php tag=0123456789abcdef
    elseif event_type == 'rfid' then
      local ztampId = string.sub(init_body ,-16)
      update_request(txn, dst_path, event_type, "nabaztamp=" .. ztampId)
          
    -- EVENT TYPE is SOUND RECORD -- /local/vl/hooks/record.php
    elseif event_type == 'record' then
      txn:Warning("Nab : RECORD NOT IMPLEMENTED")
  
    else
      txn:Warning("Nab : Can't define action : " .. event_type)
      txn:set_var('req.blocked', true)
    end

  else
    txn:Warning("NAB : no action for this path : "..init_path)
  end

end

core.register_action('nabaztag_url_rewrite', {"tcp-req", "http-req"}, nabaztag_request_rewrite, 1)
