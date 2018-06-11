local json = require("cjson")

-- this is the Lua representation of Configuration struct in internal/ingress/types.go
local configuration_data = ngx.shared.configuration_data

local _M = {
  nameservers = {}
}

function _M.get_backends_data()
  return configuration_data:get("backends")
end

local function fetch_request_body()
  ngx.req.read_body()
  local body = ngx.req.get_body_data()

  if not body then
    -- request body might've been written to tmp file if body > client_body_buffer_size
    local file_name = ngx.req.get_body_file()
    local file = io.open(file_name, "rb")

    if not file then
      return nil
    end

    body = file:read("*all")
    file:close()
  end

  return body
end

-- Returns the certificate for a given host
function _M.get_cert(hostname)
  local servers_data = configuration_data:get("servers")
  local ok, servers = pcall(json.decode, servers_data)
  if not ok then
    ngx.log(ngx.ERR,  "could not parse servers: " .. tostring(servers))
    return
  end

  for _, server in pairs(servers) do
    if server.Hostname == hostname and server.SSLCertificate then
      return server.SSLCertificate
    end
  end

  ngx.log(ngx.ERR, string.format("Certificate for %s not found", hostname))
  return
end

local function handle_server_request()
  if ngx.var.request_method ~= "POST" then
    ngx.status = ngx.HTTP_BAD_REQUEST
    ngx.print("Only POST requests are allowed!")
    return
  end

  local servers = fetch_request_body()
  if not servers then
    ngx.log(ngx.ERR, "certificate dynamic-configuration: unable to read valid request body")
    ngx.status = ngx.HTTP_BAD_REQUEST
    return
  end

  local success, err = configuration_data:set("servers", servers)
  if not success then
    ngx.log(ngx.ERR, "certificate dynamic-configuration: error setting servers: " .. tostring(err))
    ngx.status = ngx.HTTP_BAD_REQUEST
    return
  end

  ngx.status = ngx.HTTP_CREATED
  return
end

function _M.call()
  if ngx.var.request_method ~= "POST" and ngx.var.request_method ~= "GET" then
    ngx.status = ngx.HTTP_BAD_REQUEST
    ngx.print("Only POST and GET requests are allowed!")
    return
  end

  if ngx.var.request_uri == "/configuration/servers" then
    handle_server_request()
    return
  end

  if ngx.var.request_uri ~= "/configuration/backends" then
    ngx.status = ngx.HTTP_NOT_FOUND
    ngx.print("Not found!")
    return
  end

  if ngx.var.request_method == "GET" then
    ngx.status = ngx.HTTP_OK
    ngx.print(_M.get_backends_data())
    return
  end

  local backends = fetch_request_body()
  if not backends then
    ngx.log(ngx.ERR, "dynamic-configuration: unable to read valid request body")
    ngx.status = ngx.HTTP_BAD_REQUEST
    return
  end

  local success, err = configuration_data:set("backends", backends)
  if not success then
    ngx.log(ngx.ERR, "dynamic-configuration: error updating configuration: " .. tostring(err))
    ngx.status = ngx.HTTP_BAD_REQUEST
    return
  end

  ngx.status = ngx.HTTP_CREATED
end

return _M
