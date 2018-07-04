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
    
    describe("set_pem_cert", function()
        local mock_cert = [[-----BEGIN CERTIFICATE-----
            MIIC2jCCAcICCQCKqS3yQyY7/jANBgkqhkiG9w0BAQsFADAvMRgwFgYDVQQDDA9t
            eW1pbmlrdWJlLmluZm8xEzARBgNVBAoMCkhlbnJ5IFRyYW4wHhcNMTgwNTI1MDMx
            ovMq8H2OrAFRPVaJMeeG+NSdL4hagnPGs7J7vlB/5xET+8aLMaF0YpwUHEhqqovL
            Ie8Aqo2LQ+nKCj3t7ltNsWQ+kOD2B68qQ1edixq5NnWPApAZoXJlWfPW8Aitrgib
            28CEI7lKJxbL5LelLrw=
            -----END CERTIFICATE-----]]

        it("successfully sets the PEM encoded certificate", function()
            spy.on(ssl, "cert_pem_to_der")
            spy.on(ssl, "set_der_cert")
            local set_cert_ok = certificate.set_pem_cert(mock_cert)
            assert.spy(ssl.cert_pem_to_der).was_called_with(mock_cert)
            assert.spy(ssl.set_der_cert).was_called_with(ssl.cert_pem_to_der(mock_cert))
            assert.is_true(set_cert_ok)
        end)
    end)

    describe("set_pem_priv_key", function()
        local mock_priv_key = [[-----BEGIN PRIVATE KEY-----
            MIIC2jCCAcICCQCKqS3yQyY7/jANBgkqhkiG9w0BAQsFADAvMRgwFgYDVQQDDA9t
            HCNchFXZXf+MW9LlSK5xlePU+/9qw7Q6juD9l5XZ8JBWRTbXGuS+ftYHOPHIX23L
            +VkKx36EdFxIsqfAP6auwIEEMeD7AgMBAAEwDQYJKoZIhvcNAQELBQADggEBACOH
            Ie8Aqo2LQ+nKCj3t7ltNsWQ+kOD2B68qQ1edixq5NnWPApAZoXJlWfPW8Aitrgib
            28CEI7lKJxbL5LelLrw=
            -----END PRIVATE KEY-----]]

        it("successfully sets the PEM encoded private key", function()
            spy.on(ssl, "priv_key_pem_to_der")
            spy.on(ssl, "set_der_priv_key")
            local set_priv_key_ok = certificate.set_pem_priv_key(mock_priv_key)
            assert.spy(ssl.priv_key_pem_to_der).was_called_with(mock_priv_key)
            assert.spy(ssl.set_der_priv_key).was_called_with(ssl.priv_key_pem_to_der(mock_priv_key))
            assert.is_true(set_priv_key_ok)
        end)
    end)
end)
