local function update_request(txn, path, action, query, query_table)
  if not query then query = "" end

  txn.http.req_set_path(txn.http, path)
  txn.http.req_set_query(txn.http, "action=" .. action .. "&" .. query)

  -- I don't succeed to rewrite body to send json instead of query...
  -- txn.http.req_set_header(txn.http, "nabaztamp", ztampId)
  -- txn.http.req_set_header(txn.http, "Content-Type", "application/json")
end

local function nabaztag_request_rewrite(txn, dst_path)

  txn:Alert("START")
  txn:Alert(txn.f:path())
  txn:Alert(txn.sf:req_body())

  -- Path of the Home Assistant hook to where forward requests
  if not dst_path then
    dst_path = "/api/webhook/nabaztag"
    txn:Alert("Nab : No dst_path received, will use the default one : ".. dst_path )
  end

  -- Read initial path to detect event type
  local init_path = txn.f:path()
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
    --local ears_left = string.sub(data, string.find(data, "left=", 37) + 5, string.find(data, "&", 37) -1 )
    --local ears_right = string.sub(data, string.find(data, "right=", 37)+6)
    local ears_left = string.sub(init_body, string.find(init_body, "left=") + 5, string.find(init_body, "&") -1 )
    local ears_right = string.sub(init_body, string.find(init_body, "right=")+6)
    update_request(txn, dst_path, event_type, "left=" .. ears_left .. "&right=" .. ears_right)
  
  -- ZTAMP RFID -- /local/vl/hooks/rfid.php tag=0123456789abcdef
  elseif event_type == 'rfid' then
    local ztampId = string.sub(init_body ,-16)
    update_request(txn, dst_path, event_type, "nabaztamp=" .. ztampId)
        
  -- EVENT TYPE is SOUND RECORD -- /local/vl/hooks/record.php
  elseif event_type == 'record' then
    txn:Alert("Nab : RECORD NOT IMPLEMENTED")

  else
    txn:Alert("Nab : Can't define action : " .. event_type)
    txn:set_var('req.blocked', true)
  end
end

core.register_action('nabaztag_url_rewrite', {"tcp-req", "http-req"}, nabaztag_request_rewrite, 1)
