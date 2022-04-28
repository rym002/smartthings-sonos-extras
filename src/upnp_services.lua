local log = require "log"
local capabilities = require "st.capabilities"
local upnp = require "UPnP"
local socket = require "cosock.socket"
local tree = require "xmlhandler.tree"
local xml2lua = require "xml2lua"

local upnp_services = {}

upnp_services.service_id = "urn:upnp-org:serviceId:RenderingControl"
upnp_services.searchtarget = 'urn:schemas-upnp-org:device:MediaRenderer:1'

local switchMapping = {
    ['0'] = capabilities.switch.switch.off(),
    ['1'] = capabilities.switch.switch.on()
}

local commandMapping = {
    ['off'] = 0,
    ['on'] = 1
}
local function emit_switch_capability_event(name, device, value)
    local event = switchMapping[value]
    if event then
        local component = device.profile.components[name]
        device:emit_component_event(component, event)
    else
        log.error('Missing event')
    end
end

local eq_types = {
    ['DialogLevel'] = {
        eventEmitter = emit_switch_capability_event
    },
    ['NightMode'] = {
        eventEmitter = emit_switch_capability_event
    },
    ['SurroundMode'] = {
        eventEmitter = emit_switch_capability_event
    }
}

function upnp_services.log_table(v)
    for key, value in pairs(v) do
        local t = type(value)
        if t == "string" or t == "boolean" then
            log.debug(string.format("%s : %s", key, value))
        elseif t == "nil" then
            log.debug(string.format("%s : nil", key))
        elseif t == "table" then
            log.debug(string.format("%s : start", key))
            upnp_services.log_table(value)
            log.debug(string.format("%s : end", key))
        else
            log.debug(string.format("%s : type: %s", key, t))
        end
    end
end

function upnp_services.get_eq(device, eqType)
    local upnpdev = device:get_field("upnpdevice")
    if upnpdev then
        local cmd = {
            action = 'GetEQ',
            arguments = {
                ['InstanceID'] = 0,
                ['EQType'] = eqType
            }
        }
        local status, response = upnpdev:command(upnp_services.service_id, cmd)
        if status == 'OK' then
            local value = response.GetEQ.CurrentValue
            eq_types[eqType].eventEmitter(eqType, device, value)
        else
            log.error('get_eq status:' .. status)
        end
    else
        log.error("Missing upnpdevice")
    end
end

function upnp_services.set_eq(device, command)
    local eqType = command.component
    local value = commandMapping[command.command]
    local upnpdev = device:get_field("upnpdevice")
    if upnpdev then
        local cmd = {
            action = 'SetEQ',
            arguments = {
                ['InstanceID'] = 0,
                ['EQType'] = eqType,
                ['DesiredValue'] = value
            }
        }
        local status, response = upnpdev:command(upnp_services.service_id, cmd)
        if status == 'OK' then
            for key, value in pairs(response) do
                log.info(key)
            end
        else
            log.error('get_eq status:' .. status)
        end
    else
        log.error("Missing upnpdevice")
    end
end

function upnp_services.refresh_components(device)
    for k, _ in pairs(eq_types) do
        upnp_services.get_eq(device, k)
    end
end

function upnp_services.discover_device(device)
    local upnpdev
    local waittime = 1 -- initially try for a quick response since it's a known device

    -- NOTE: a specific search target must include prefix (eg 'uuid:') for SSDP searches                                        
    while waittime <= 3 do
        upnp.discover(upnp_services.searchtarget, waittime, function(devobj)
            if device.device_network_id == devobj.uuid then
                upnpdev = devobj
            end
        end)
        if upnpdev then
            return upnpdev
        end
        waittime = waittime + 1
        if waittime <= 3 then
            socket.sleep(2)
        end
    end
    return nil
end

function upnp_services.event_callback(device, sid, sequence, propertylist)
    local res = tree:new()
    local parser = xml2lua.parser(res)
    parser:parse(propertylist.LastChange)
    for k, v in pairs(eq_types) do
        local eqChange = res.root.Event.InstanceID[k]
        if eqChange then
            local value = eqChange._attr.val
            log.debug(string.format('event key: %s value: %s', k, value))
            v.eventEmitter(k, device, value)
        else
            log.error(string.format('eq change not found for %s', k))
        end
    end
end

return upnp_services
