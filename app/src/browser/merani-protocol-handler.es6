import {protocol} from 'electron';
import fs from 'fs';
import path from 'path';

// Handles requests with 'nylas' protocol.
//
// It's created by {N1Application} upon instantiation and is used to create a
// custom resource loader for 'mailspring://' URLs.
//
// The following directories are searched in order:
//   * <config-dir>/assets
//   * <config-dir>/dev/packages (unless in safe mode)
//   * <config-dir>/packages
//   * RESOURCE_PATH/node_modules
//
export default class NylasProtocolHandler {
  constructor({configDirPath, resourcePath, safeMode}) {
    this.loadPaths = [];

    if (!safeMode) {
      this.loadPaths.push(path.join(configDirPath, 'dev', 'packages'));
    }
    this.loadPaths.push(path.join(configDirPath, 'packages'));
    this.loadPaths.push(path.join(resourcePath, 'internal_packages'));

    this.registerNylasProtocol();
  }

  // Creates the 'Nylas' custom protocol handler.
  registerNylasProtocol() {
    protocol.registerFileProtocol('mailspring', (request, callback) => {
      const relativePath = path.normalize(request.url.substr(7));

      let filePath = null;
      for (const loadPath of this.loadPaths) {
        filePath = path.join(loadPath, relativePath);
        const fileStats = fs.statSyncNoException(filePath);
        if (fileStats.isFile && fileStats.isFile()) {
          break;
        }
      }

      callback(filePath);
    });
  }
}
