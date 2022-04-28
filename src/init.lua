local discovery = require "discovery"
local capabilities = require "st.capabilities"
local Driver = require "st.driver"
local lifecycle = require "lifecycle"
local command_handlers = require "command_handlers"

local sonos_driver = Driver("Sonos Extras", {
    discovery = discovery.handler,
    lifecycle_handlers = {
        added = lifecycle.device_added,
        init = lifecycle.device_init,
        removed = lifecycle.device_removed,
        deleted = lifecycle.device_removed
    },
    lan_info_changed_handler = lifecycle.lan_info_changed_handler,
    capability_handlers = {
        [capabilities.switch.ID] = {
            [capabilities.switch.commands.on.NAME] = command_handlers.switch_on,
            [capabilities.switch.commands.off.NAME] = command_handlers.switch_off
        },
        [capabilities.refresh.ID] = {
            [capabilities.refresh.commands.refresh.NAME] = command_handlers.refresh
        }
    }
})

sonos_driver:call_on_schedule(lifecycle.SUBSCRIBETIME - 5, lifecycle.resubscribe_all, "Re-subscribe timer")

sonos_driver:run()
