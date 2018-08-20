local certificate = require("certificate")
local unmocked_ngx = _G.ngx

describe("Certificate", function()
  describe("call", function()
    local ssl = require("ngx.ssl")
    local match = require("luassert.match")

    ssl.server_name = function() return "hostname", nil end
    ssl.clear_certs = function() return true, "" end
    ssl.cert_pem_to_der = function(cert) return cert ~= "" and cert, "" or nil, "error" end
    ssl.set_der_cert = function(cert) return true, "" end
    ssl.priv_key_pem_to_der = function(priv_key) return priv_key, "" end
    ssl.set_der_priv_key = function(priv_key) return true, "" end

    it("does not clear fallback certificates and logs error message when host is not in dictionary", function()
      spy.on(ngx, "log")
      spy.on(ssl, "clear_certs")
      spy.on(ssl, "set_der_cert")
      spy.on(ssl, "set_der_priv_key")
      
      assert.has_no.errors(certificate.call)
      assert.spy(ngx.log).was_called_with(ngx.ERR, "Certificate not found for the given hostname: hostname")
      assert.spy(ssl.clear_certs).was_not_called()
      assert.spy(ssl.set_der_cert).was_not_called()
      assert.spy(ssl.set_der_priv_key).was_not_called()
    end)

    it("successfully sets SSL certificate and key when hostname is found in dictionary", function()
      local _ = match._
      local fake_pem_cert_key = "fake_pem_cert_key"
      ngx.shared.certificate_data:set("hostname", fake_pem_cert_key)
      
      spy.on(ngx, "log")
      spy.on(ssl, "set_der_cert")
      spy.on(ssl, "set_der_priv_key")
      
      assert.has_no.errors(certificate.call)
      assert.spy(ngx.log).was_not_called_with(ngx.ERR, _)
      assert.spy(ssl.set_der_cert).was_called()
      assert.spy(ssl.set_der_priv_key).was_called_with(fake_pem_cert_key)
    end)

    it("logs error message when certificate in dictionary is empty", function()
      ngx.shared.certificate_data:set("hostname", "")

      spy.on(ngx, "log")
      spy.on(ssl, "set_der_cert")
      spy.on(ssl, "set_der_priv_key")

      assert.has_no.errors(certificate.call)
      assert.spy(ngx.log).was_called_with(ngx.ERR, "failed to convert certificate chain from PEM to DER: error")
      assert.spy(ssl.set_der_cert).was_not_called()
      assert.spy(ssl.set_der_priv_key).was_not_called()
    end)

    it("does not clear fallback certificates and logs error message when hostname could not be fetched", function()
      ssl.server_name = function() return nil, "error" end

      spy.on(ngx, "log")
      spy.on(ssl, "clear_certs")
      spy.on(ssl, "set_der_cert")
      spy.on(ssl, "set_der_priv_key")

      assert.has_no.errors(certificate.call)
      assert.spy(ngx.log).was_called_with(ngx.ERR, "Error getting the hostname: error")
      assert.spy(ssl.clear_certs).was_not_called()
      assert.spy(ssl.set_der_cert).was_not_called()
      assert.spy(ssl.set_der_priv_key).was_not_called()
    end)
  end)
end)
