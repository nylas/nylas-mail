/** @babel */
import plugin from '../package.json'
export const PLUGIN_ID = plugin.appId[NylasEnv.config.get("env")];
export const PLUGIN_NAME = "Send Later"
export const DATE_FORMAT_LONG = 'ddd, MMM D, YYYY h:mmA'
export const DATE_FORMAT_SHORT = 'MMM D h:mmA'

