import plugin from '../package.json'

let pluginId = plugin.name;
let pluginUrl = plugin.serverUrl[NylasEnv.config.get("env")];

if (NylasEnv.inSpecMode()) {
  pluginId = "TEST_SCHEDULER_PLUGIN_ID"
  pluginUrl = "https://edgehill-test.nylas.com"
}

export const PLUGIN_ID = pluginId;
export const PLUGIN_URL = pluginUrl;
export const PLUGIN_NAME = "Quick Schedule"
export const CALENDAR_ID = "QUICK SCHEDULE"
