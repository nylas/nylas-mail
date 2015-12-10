import fs from 'fs-plus'
import path from 'path'
import CSON from 'season'

var root = path.resolve(path.dirname(__dirname))

const DEFAULT_CONFIG_DIR = path.join(root, "fixtures", "default_test_config")
export const CONFIG_DIR_PATH = path.join(root, ".integration-test-config")
export const FAKE_DATA_PATH = path.join(root, "fixtures", "test_account_data")

export function setupDefaultConfig() {
  if (fs.existsSync(CONFIG_DIR_PATH)) fs.removeSync(CONFIG_DIR_PATH);
  fs.copySync(DEFAULT_CONFIG_DIR, CONFIG_DIR_PATH)
}

export function clearConfig() {
  if (fs.existsSync(CONFIG_DIR_PATH)) fs.removeSync(CONFIG_DIR_PATH);
}

export function currentConfig(){
  version = JSON.parse(fs.readFileSync(path.join(root, '..', 'package.json'))).version;
  config = CSON.readFileSync(path.join(DEFAULT_CONFIG_DIR, 'config.cson'))["*"]
  id = config.updateIdentity
  email = config.nylas.accounts[0].email_address

  return {id, email, version}
}
