local log = require "log"
local upnp = require "UPnP"
local cosock = require "cosock" -- cosock used only for sleep timers in this module
local socket = require "cosock.socket"
local upnp_services = require "upnp_services"
local discovery = {}

local profiles = {
    ["S9"] = "sonos-extras",
    ["S14"] = "sonos-extras"
}

local newly_added = {}

function discovery.handler(driver, opts, should_continue)
    local known_devices = {}
    local found_devices = {}

    local device_list = driver:get_devices()
    for _, device in ipairs(device_list) do
        local id = device.device_network_id
        known_devices[id] = true
    end

    local waitTime = 3
    local repeat_count = 3
    while should_continue() and (repeat_count > 0) do
        log.info("request " .. ((repeat_count * -1) + 4) .. " searchtarget " .. upnp_services.searchtarget)
        upnp.discover(upnp_services.searchtarget, waitTime, function(upnpdev)
            local id = upnpdev.uuid
            if not known_devices[id] and not found_devices[id] then
                found_devices[id] = true
                local modelNumber = upnpdev:devinfo().modelNumber
                local devprofile = profiles[modelNumber]
                if devprofile then
                    local create_device_msg = {
                        type = "LAN",
                        device_network_id = id,
                        label = upnpdev:devinfo().friendlyName,
                        profile = devprofile,
                        manufacturer = upnpdev:devinfo().manufacturer,
                        model = modelNumber,
                        vendor_provided_label = upnpdev:devinfo().modelName
                    }

                    assert(driver:try_create_device(create_device_msg), "failed to create device record")
                    newly_added[id] = upnpdev
                end
            end
        end)

        repeat_count = repeat_count - 1

        if repeat_count > 0 then
            socket.sleep(2) -- avoid creating network storms
        end
    end
    log.info("Driver is exiting discovery")
end

function discovery.popNewlyAdded(id)
    log.info("Popping: " .. id)
    local ret = newly_added[id]
    newly_added[id] = nil
    return ret
end

return discovery
