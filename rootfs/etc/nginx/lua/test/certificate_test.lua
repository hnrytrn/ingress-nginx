package.path = "./rootfs/etc/nginx/lua/?.lua;./rootfs/etc/nginx/lua/test/mocks/?.lua;" .. package.path
_G._TEST = true

local _ngx = {
  shared = {},
  log = function(...) end,
}
_G.ngx = _ngx

describe("Certificate", function()
    local certificate = require("certificate")
    local ssl = require("ngx.ssl")
    
    describe("set_pem_cert_key", function()
        local mock_cert_key = [[-----BEGIN CERTIFICATE-----
            MIIC2jCCAcICCQCKqS3yQyY7/jANBgkqhkiG9w0BAQsFADAvMRgwFgYDVQQDDA9t
            eW1pbmlrdWJlLmluZm8xEzARBgNVBAoMCkhlbnJ5IFRyYW4wHhcNMTgwNTI1MDMx
            ovMq8H2OrAFRPVaJMeeG+NSdL4hagnPGs7J7vlB/5xET+8aLMaF0YpwUHEhqqovL
            Ie8Aqo2LQ+nKCj3t7ltNsWQ+kOD2B68qQ1edixq5NnWPApAZoXJlWfPW8Aitrgib
            28CEI7lKJxbL5LelLrw=
            -----END CERTIFICATE-----
            -----BEGIN PRIVATE KEY-----
            MIIC2jCCAcICCQCKqS3yQyY7/jANBgkqhkiG9w0BAQsFADAvMRgwFgYDVQQDDA9t
            HCNchFXZXf+MW9LlSK5xlePU+/9qw7Q6juD9l5XZ8JBWRTbXGuS+ftYHOPHIX23L
            +VkKx36EdFxIsqfAP6auwIEEMeD7AgMBAAEwDQYJKoZIhvcNAQELBQADggEBACOH
            Ie8Aqo2LQ+nKCj3t7ltNsWQ+kOD2B68qQ1edixq5NnWPApAZoXJlWfPW8Aitrgib
            28CEI7lKJxbL5LelLrw=
            -----END PRIVATE KEY-----]]

        it("successfully sets the PEM encoded certificate and private key", function()
            spy.on(ssl, "cert_pem_to_der")
            spy.on(ssl, "set_der_cert")
            spy.on(ssl, "priv_key_pem_to_der")
            spy.on(ssl, "set_der_priv_key")
            
            local set_cert_key_err = certificate.set_pem_cert_key(mock_cert_key)
            assert.spy(ssl.cert_pem_to_der).was_called_with(mock_cert_key)
            assert.spy(ssl.set_der_cert).was_called_with(ssl.cert_pem_to_der(mock_cert_key))
            assert.spy(ssl.priv_key_pem_to_der).was_called_with(mock_cert_key)
            assert.spy(ssl.set_der_priv_key).was_called_with(ssl.priv_key_pem_to_der(mock_cert_key))
            assert.is_not_truthy(set_cert_key_err)
        end)
    end)
end)
