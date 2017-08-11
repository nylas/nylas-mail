/* eslint import/no-dynamic-require:0 */
/**
 * NOTE: Due to path issues, this script must be run outside of grunt
 * directly from a powershell command.
 */
const path = require('path')
const createWindowsInstaller = require('electron-winstaller').createWindowsInstaller

const appDir = path.join(__dirname, "..");
const version = require(path.join(appDir, 'package.json')).version;

const config = {
  usePackageJson: false,
  outputDirectory: path.join(appDir, 'dist'),
  appDirectory: path.join(appDir, 'dist', 'merani-win32-ia32'),
  loadingGif: path.join(appDir, 'build', 'resources', 'win', 'loading.gif'),
  iconUrl: 'http://edgehill.s3.amazonaws.com/static/nylas.ico',
  certificateFile: process.env.CERTIFICATE_FILE,
  certificatePassword: process.env.WINDOWS_CODESIGN_KEY_PASSWORD,
  description: "Merani",
  version: version,
  title: "merani",
  authors: 'Foundry 376, LLC',
  setupIcon: path.join(appDir, 'build', 'resources', 'win', 'nylas.ico'),
  setupExe: 'MeraniSetup.exe',
  exe: 'merani.exe',
  name: 'Merani',
}
console.log(config);
console.log("---> Starting")
createWindowsInstaller(config, console.log, console.error)
