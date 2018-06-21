local ssl = require("ngx.ssl")
local configuration = require("configuration")

local _M = {}

function _M.call()
    local hostname = ssl.server_name()
    print("Setting certificate for host - ", hostname)

    local pem_cert_key = configuration.get_cert_key(hostname)
    if not pem_cert_key then
        ngx.log(ngx.ERR, "Certificate not found for the given hostname: ", hostname)
        return
    end

    -- clear the fallback certificates and private keys
    -- set by the ssl_certificate and ssl_certificate_key
    -- directives above:
    local clear_ok, clear_err = ssl.clear_certs()
    if not clear_ok then
        ngx.log(ngx.ERR, "failed to clear existing (fallback) certificates: ", clear_err)
        return ngx.exit(ngx.ERROR)
    end

    local der_cert, der_cert_err = ssl.cert_pem_to_der(pem_cert_key)
    if not der_cert then
        ngx.log(ngx.ERR, "failed to convert certificate chain from PEM to DER: ", der_cert_err)
        return ngx.exit(ngx.ERROR)
    end

    local set_cert_ok, set_cert_err = ssl.set_der_cert(der_cert)
    if not set_cert_ok then
        ngx.log(ngx.ERR, "failed to set DER cert: ", set_cert_err)
        return ngx.exit(ngx.ERROR)
    end

    local der_priv_key, dev_priv_key_err = ssl.priv_key_pem_to_der(pem_cert_key)
    if not der_priv_key then
        ngx.log(ngx.ERR, "failed to convert private key from PEM to DER: ", dev_priv_key_err)
        return ngx.exit(ngx.ERROR)
    end

    local set_priv_key_ok, set_priv_key_err = ssl.set_der_priv_key(der_priv_key)
    if not set_priv_key_ok then
        ngx.log(ngx.ERR, "failed to set DER private key: ", set_priv_key_err)
        return ngx.exit(ngx.ERROR)
    end
end

return _M