/** @babel */
import plugin from '../package.json'

export const PLUGIN_ID = plugin.appId[NylasEnv.config.get("env")];
export const PLUGIN_NAME = "Snooze Plugin"
export const SNOOZE_CATEGORY_NAME = "N1-Snoozed"
