local log = require "log"
local discovery = require "discovery"
local upnp_services = require "upnp_services"
local lifecycle = {}
local upnp = require "UPnP"

lifecycle.SUBSCRIBETIME = 86400


local function subscribe_device(device)

    local upnpdev = device:get_field('upnpdevice')

    local response = upnpdev:subscribe(upnp_services.service_id, upnp_services.event_callback, lifecycle.SUBSCRIBETIME, nil)

    if response ~= nil then
        upnp_services.log_table(response)
        device:set_field("upnp_sid", response.sid)
        return response
    end
end

local function status_changed_callback(device)
    local upnpdev = device:get_field("upnpdevice")
    local sid = device:get_field("upnp_sid")

    if upnpdev.online then

        log.info("Device is back online")
        device:online()
        if sid then
            subscribe_device(device)
        end

    else
        log.info("Device has gone offline")
        device:offline()
        if sid then
            upnpdev:cancel_resubscribe(sid)
        end
    end
end

local function startup(driver, device, upnpdev)
    if upnpdev then
        upnpdev:init(driver, device)
        upnpdev:monitor(status_changed_callback)
        subscribe_device(device)
    end
    device:online()
end
function lifecycle.device_added(driver, device)
    log.info("device_added")
    local id = device.device_network_id
    local upnpdev = discovery.popNewlyAdded(id)
    startup(driver, device, upnpdev)
end

function lifecycle.device_removed(driver, device)
    log.info("device_removed")
    log.info("<" .. device.id .. "> removed")

    local upnpdev = device:get_field("upnpdevice")

    -- Clean up any outstanding event subscriptions

    local sid = device:get_field("upnp_sid")
    if sid ~= nil then
        upnpdev:unsubscribe(sid)
        upnpdev:cancel_resubscribe(sid)
        device:set_field("upnp_sid", nil)
    end

    -- stop monitoring & allow for later re-discovery 
    upnpdev:forget()
end

function lifecycle.device_init(driver, device)
    log.info("device_init")
    local upnpdev = device:get_field("upnpdevice")

    if upnpdev == nil then -- if nil, then this handler was called to initialize an existing device (eg driver reinstall)
        upnpdev = upnp_services.discover_device(device)
        if not upnpdev then
            log.warn("<" .. device.id .. "> not found on network")
            device:offline()
            return
        else
            -- Perform startup tasks for the device
            startup(driver, device, upnpdev)
        end
    else
        -- nothing else needs to be done if device metadata already available (already handled in device_added)
    end
end

function lifecycle.resubscribe_all(driver)

    local device_list = driver:get_devices()

    for _, device in ipairs(device_list) do

        -- Determine if there is a subscription for this device
        local sid = device:get_field("upnp_sid")
        if sid then

            local upnpdev = device:get_field("upnpdevice")
            local name = upnpdev:devinfo().friendlyName

            -- Resubscribe only if the device is online
            if upnpdev.online then
                upnpdev:unsubscribe(sid)
                device:set_field("upnp_sid", nil)
                log.info(string.format("Re-subscribing to %s", name))
                subscribe_device(device)
            else
                log.warn(string.format("%s is offline, can't re-subscribe now", name))
            end
        end
    end

end
function lifecycle.lan_info_changed_handler(driver, hub_ipv4)

    if driver.listen_ip == nil or hub_ipv4 ~= driver.listen_ip then

        -- reset device monitoring and subscription event server
        upnp.reset(driver)
        -- renew all subscriptions
        lifecycle.resubscribe_all(driver)
    end
end

return lifecycle
