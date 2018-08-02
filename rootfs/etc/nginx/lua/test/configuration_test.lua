_G._TEST = true
local cjson = require("cjson")

function get_mocked_ngx_env()
    local _ngx = {}
    setmetatable(_ngx, {__index = _G.ngx})

    _ngx.status = 100
    _ngx.var = {}
    _ngx.req = {
        read_body = function() end,
        get_body_file = function() end,
    }
    return _ngx
end

local unmocked_ngx = _G.ngx
local configuration = require("configuration")

describe("Configuration", function()
    before_each(function()
        _G.ngx = get_mocked_ngx_env()
    end)

    after_each(function()
        _G.ngx = unmocked_ngx
    end)

    describe("handle_servers()", function()
        it("should not accept non POST methods", function()
            ngx.var.request_method = "GET"
            
            local s = spy.on(ngx, "print")
            assert.has_no.errors(configuration.handle_servers)
            assert.spy(s).was_called_with("Only POST requests are allowed!")
            assert.same(ngx.status, ngx.HTTP_BAD_REQUEST)
        end)

        it("should ignore servers that don't have hostname or pemCertKey set", function()
            ngx.var.request_method = "POST"
            local mock_servers = cjson.encode({
                {
                    hostname = "hostname",
                    sslCert = {}
                },
                {
                    sslCert = {
                        pemCertKey = "pemCertKey"
                    }
                }
            })
            ngx.req.get_body_data = function() return mock_servers end

            local s = spy.on(ngx, "log")
            assert.has_no.errors(configuration.handle_servers)
            assert.spy(s).was_called_with(ngx.WARN, "hostname or pemCertKey are not present")
            assert.same(ngx.status, ngx.HTTP_CREATED)
        end)

        it("should successfully update certificates and keys for each host", function()
            ngx.var.request_method = "POST"
            local mock_servers = cjson.encode({
                {
                    hostname = "hostname",
                    sslCert = {
                        pemCertKey = "pemCertKey"
                    }
                }
            })
            ngx.req.get_body_data = function() return mock_servers end

            assert.has_no.errors(configuration.handle_servers)
            assert.same(ngx.status, ngx.HTTP_CREATED)
        end)

        it("should log an err and set status to Internal Server Error when a certificate cannot be set", function()
            ngx.var.request_method = "POST"
            ngx.shared.certificate_data.safe_set = function(self, data) return false, "error" end
            local mock_servers = cjson.encode({
                {
                    hostname = "hostname",
                    sslCert = {
                        pemCertKey = "pemCertKey"
                    }
                }
            })
            ngx.req.get_body_data = function() return mock_servers end

            local s = spy.on(ngx, "log")
            assert.has_no.errors(configuration.handle_servers)
            assert.spy(s).was_called_with(ngx.ERR, "error setting certificate for hostname: error\n")
            assert.same(ngx.status, ngx.HTTP_INTERNAL_SERVER_ERROR)
        end)

        it("should log an err and set status to Internal Server Error when shared dictionary is full", function()
            ngx.var.request_method = "POST"
            ngx.shared.certificate_data.safe_set = function(self, data) return false, "no memory" end
            local mock_servers = cjson.encode({
                {
                    hostname = "hostname",
                    sslCert = {
                        pemCertKey = "pemCertKey"
                    }
                }
            })
            ngx.req.get_body_data = function() return mock_servers end

            local s = spy.on(ngx, "log")
            assert.has_no.errors(configuration.handle_servers)
            assert.spy(s).was_called_with(ngx.ERR, "no memory in certificate_data dictionary")
            assert.same(ngx.status, ngx.HTTP_INTERNAL_SERVER_ERROR)
        end)
    end)
end)
