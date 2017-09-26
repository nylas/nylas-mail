import plugin from '../package.json';

export const PLUGIN_NAME = plugin.title;
export const PLUGIN_ID = plugin.name;
export const PLUGIN_URL = plugin.serverUrl[AppEnv.config.get('env')];
