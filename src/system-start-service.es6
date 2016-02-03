import path from 'path'
import fs from 'fs'
import {exec} from 'child_process'
import ws from 'windows-shortcuts'

class SystemStartServiceBase {
  checkAvailability() {
    return Promise.resolve(false);
  }

  doesLaunchOnSystemStart() {
    throw new Error("doesLaunchOnSystemStart is not available");
  }

  configureToLaunchOnSystemStart() {
    throw new Error("configureToLaunchOnSystemStart is not available")
  }

  dontLaunchOnSystemStart() {
    throw new Error("dontLaunchOnSystemStart is not available")
  }
}

class SystemStartServiceDarwin extends SystemStartServiceBase {
  checkAvailability() {
    return new Promise((resolve) => {
      fs.access(this._launcherPath(), fs.R_OK | fs.W_OK, (err) => {
        if (err) { resolve(false) } else { resolve(true) }
      });
    });
  }

  doesLaunchOnSystemStart() {
    return new Promise((resolve) => {
      fs.access(this._plistPath(), fs.R_OK | fs.W_OK, (err) => {
        if (err) { resolve(false) } else { resolve(true) }
      });
    });
  }

  configureToLaunchOnSystemStart() {
    fs.writeFile(this._plistPath(), JSON.stringify(this._launchdPlist()), (err) => {
      if (!err) {
        exec(`plutil -convert xml1 ${this._plistPath()}`)
      }
    })
  }

  dontLaunchOnSystemStart() {
    return fs.unlink(this._plistPath())
  }

  _launcherPath() {
    return path.join("/", "Applications", "Nylas N1.app", "Contents",
                     "MacOS", "Nylas")
  }

  _plistPath() {
    return path.join(process.env.HOME, "Library",
                     "LaunchAgents", "com.nylas.plist");
  }

  _launchdPlist() {
    return {
      "Label": "com.nylas.n1",
      "Program": this._launcherPath(),
      "ProgramArguments": ["--background"],
      "RunAtLoad": true,
    }
  }
}

class SystemStartServiceWin32 extends SystemStartServiceBase {
  checkAvailability() {
    return new Promise((resolve) => {
      fs.access(this._launcherPath(), fs.R_OK | fs.W_OK, (err) => {
        if (err) { resolve(false) } else { resolve(true) }
      });
    });
  }

  doesLaunchOnSystemStart() {
    return new Promise((resolve) => {
      fs.access(this._shortcutPath(), fs.R_OK | fs.W_OK, (err) => {
        if (err) { resolve(false) } else { resolve(true) }
      });
    });
  }

  configureToLaunchOnSystemStart() {
    ws.create(this._shortcutPath(), {
      target: this._launcherPath(),
      args: "--processStart=nylas.exe --process-start-args=--background",
      runStyle: ws.MIN,
      desc: "An extensible, open-source mail client built on the modern web.",
    }, (err) => {
      if (err) NylasEnv.emitError(err)
    });
  }

  dontLaunchOnSystemStart() {
    return fs.unlink(this._shortcutPath())
  }

  _launcherPath() {
    return path.join(process.env.LOCALAPPDATA, "nylas", "Update.exe")
  }

  _shortcutPath() {
    return path.join(process.env.APPDATA, "Microsoft", "Windows",
                     "Start Menu", "Programs", "Startup", "Nylas.lnk")
  }
}

class SystemStartServiceLinux extends SystemStartServiceBase {

}


let SystemStartService;
if (process.platform === "darwin") {
  SystemStartService = SystemStartServiceDarwin;
} else if (process.platform === "linux") {
  SystemStartService = SystemStartServiceLinux;
} else if (process.platform === "win32") {
  SystemStartService = SystemStartServiceWin32;
} else {
  SystemStartService = SystemStartServiceBase;
}

export default SystemStartService
