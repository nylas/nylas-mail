import fs from 'fs'
import path from 'path'

// This function prevents old N1 from destroying its own config and copying the
// one from Nylas Mail 2.0. The expected workflow now is to migrate from old
// N1 (1.5.0) to Nylas Mail (2.0) instead of the other way around
// See https://github.com/nylas/nylas-mail/blob/n1-pro/src/browser/nylas-pro-migrator.es6 for details
export default function preventLegacyN1Migration(configDirPath) {
  try {
    const legacyConfigPath = path.join(configDirPath, '..', '.nylas', 'config.json')
    if (!fs.existsSync(legacyConfigPath)) { return }
    const legacyConfig = require(legacyConfigPath) || {}  // eslint-disable-line
    if (!legacyConfig['*']) {
      legacyConfig['*'] = {}
    }
    legacyConfig['*'].nylasMailBasicMigrationTime = Date.now()
    fs.writeFileSync(legacyConfigPath, JSON.stringify(legacyConfig))
  } catch (err) {
    console.error('Error preventing legacy N1 migration')
    console.error(err)
  }
}
