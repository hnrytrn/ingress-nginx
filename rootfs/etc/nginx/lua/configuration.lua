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

-- Returns the certificate and key for a given host
function _M.get_cert_key(hostname)
  return configuration_data:get(hostname)
end

local function handle_cert_request()
  if ngx.var.request_method ~= "POST" then
    ngx.status = ngx.HTTP_BAD_REQUEST
    ngx.print("Only POST requests are allowed!")
    return
  end

  local raw_certs = fetch_request_body()

  local ok, certs = pcall(json.decode, raw_certs)
  if not ok then
    ngx.log(ngx.ERR,  "could not parse certificate: " .. tostring(certs))
    return
  end

  if not certs then
    ngx.log(ngx.ERR, "certificate dynamic-configuration: unable to read valid request body")
    ngx.status = ngx.HTTP_BAD_REQUEST
    return
  end

  local err_buf = {}
  -- Update certificates and private keys for each host
  for _, cert in pairs(certs) do
    if cert.hostname and cert.sslCert.pemCertKey then
      local success, err = configuration_data:set(cert.hostname, cert.sslCert.pemCertKey)
      if not success then
        err_buf[#err_buf + 1] = string.format("certificate dynamic-configuration: " ..
          "error setting certificate for %s: %s\n", cert.hostname, tostring(err))
      end
    else
      ngx.log(ngx.WARN, "certificate dynamic-configuration: hostname and pemCertKey are not present")
    end
  end

  if table.getn(err_buf) > 0 then
    ngx.log(ngx.ERR, table.concat(err_buf))
    ngx.status = ngx.HTTP_INTERNAL_SERVER_ERROR
    return
  end

  ngx.status = ngx.HTTP_CREATED
end

function _M.call()
  if ngx.var.request_method ~= "POST" and ngx.var.request_method ~= "GET" then
    ngx.status = ngx.HTTP_BAD_REQUEST
    ngx.print("Only POST and GET requests are allowed!")
    return
  end

  if ngx.var.request_uri == "/configuration/servers" then
    handle_cert_request()
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
