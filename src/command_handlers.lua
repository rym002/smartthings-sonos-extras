local log = require "log"
local upnp_services = require "upnp_services"

local command_handlers = {}

function command_handlers.switch_on(driver, device, command)
    upnp_services.set_eq(device, command)
end

-- callback to handle an `off` capability command
function command_handlers.switch_off(driver, device, command)
    upnp_services.set_eq(device, command)
end

function command_handlers.refresh(driver, device)
    upnp_services.refresh_components(device)
end

return command_handlers
