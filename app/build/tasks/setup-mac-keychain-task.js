/* eslint global-require: 0 */
const path = require('path');
const fs = require('fs-plus');

// Codesigning is a Mac-only process that requires a valid Apple
// certificate, the private key, and access to the Mac keychain.
//
// We can only codesign from keys in the keychain. At the end of the day
// we need the certificate and private key to exist in the keychain
//
// In the case of Travis, we need to setup a temp keychain from encrypted
// files in the repository. We'll decrypt and import our certificates,
// put them in a temporary keychain, and use that.
//
// If you want to verify the app was signed you can run the commands:
//
//     spctl -a -t exec -vv /path/to/N1.app
//
// Which should return "satisfies its Designated Requirement"
//
// And:
//
//     codesign -dvvv /path/to/N1.app
//
// Which should return "accepted"
module.exports = grunt => {
  let getCertData;
  const { spawnP } = grunt.config('taskHelpers');
  const tmpKeychain = 'n1-build.keychain';

  const unlockKeychain = (keychain, keychainPass) => {
    const args = ['unlock-keychain', '-p', keychainPass, keychain];
    return spawnP({ cmd: 'security', args });
  };

  const cleanupKeychain = () => {
    if (fs.existsSync(path.join(process.env.HOME, 'Library', 'Keychains', tmpKeychain))) {
      return spawnP({ cmd: 'security', args: ['delete-keychain', tmpKeychain] });
    }
    return Promise.resolve();
  };

  const buildMacKeychain = () => {
    const crypto = require('crypto');
    const tmpPass = crypto.randomBytes(32).toString('hex');
    const { appleCert, nylasCert, nylasPrivateKey, keyPass } = getCertData();
    const codesignBin = path.join('/', 'usr', 'bin', 'codesign');

    // Create a custom, temporary keychain
    return (
      cleanupKeychain()
        .then(() =>
          spawnP({ cmd: 'security', args: ['create-keychain', '-p', tmpPass, tmpKeychain] })
        )
        // Due to a bug in OSX, you must list-keychain with -s in order for it
        // to actually add it to the list of keychains. See http://stackoverflow.com/questions/20391911/os-x-keychain-not-visible-to-keychain-access-app-in-mavericks
        .then(() => spawnP({ cmd: 'security', args: ['list-keychains', '-s', tmpKeychain] }))
        // Make the custom keychain default, so xcodebuild will use it for signing
        .then(() => spawnP({ cmd: 'security', args: ['default-keychain', '-s', tmpKeychain] }))
        // Unlock the keychain
        .then(() => unlockKeychain(tmpKeychain, tmpPass))
        // Set keychain timeout to 1 hour for long builds
        .then(() =>
          spawnP({
            cmd: 'security',
            args: ['set-keychain-settings', '-t', '3600', '-l', tmpKeychain],
          })
        )
        // Add certificates to keychain and allow codesign to access them
        .then(() =>
          spawnP({
            cmd: 'security',
            args: ['import', appleCert, '-k', tmpKeychain, '-T', codesignBin],
          })
        )
        .then(() =>
          spawnP({
            cmd: 'security',
            args: ['import', nylasCert, '-k', tmpKeychain, '-T', codesignBin],
          })
        )
        // Load the password for the private key from environment variables
        .then(() =>
          spawnP({
            cmd: 'security',
            args: ['import', nylasPrivateKey, '-k', tmpKeychain, '-P', keyPass, '-T', codesignBin],
          })
        )
        // mark that the codesign utility should be allowed to access the keychain without
        // prompting for access. (Needed for Mac OS Sierra and above)
        // https://stackoverflow.com/questions/39868578/security-codesign-in-sierra-keychain-ignores-access-control-settings-and-ui-p
        .then(() =>
          spawnP({
            cmd: 'security',
            args: [
              'set-key-partition-list',
              '-S',
              'apple-tool:,apple:,codesign:',
              '-k',
              tmpPass,
              tmpKeychain,
            ],
          })
        )
    );
  };

  getCertData = () => {
    const certs = path.resolve(path.join(grunt.config('buildDir'), 'resources', 'certs', 'mac'));
    const appleCert = path.join(certs, 'AppleWWDRCA.cer');
    const nylasCert = path.join(certs, 'mac-codesigning.cer');
    const nylasPrivateKey = path.join(certs, 'mac-codesigning.p12');

    const keyPass = process.env.APPLE_CODESIGN_KEY_PASSWORD;

    if (!keyPass) {
      throw new Error('APPLE_CODESIGN_KEY_PASSWORD must be set');
    }
    if (!fs.existsSync(appleCert)) {
      throw new Error(`${appleCert} doesn't exist`);
    }
    if (!fs.existsSync(nylasCert)) {
      throw new Error(`${nylasCert} doesn't exist`);
    }
    if (!fs.existsSync(nylasPrivateKey)) {
      throw new Error(`${nylasPrivateKey} doesn't exist`);
    }

    return { appleCert, nylasCert, nylasPrivateKey, keyPass };
  };

  const shouldRun = () => {
    if (process.platform !== 'darwin') {
      grunt.log.writeln(`Skipping keychain setup since ${process.platform} is not darwin`);
      return false;
    }
    return !!process.env.SIGN_BUILD;
  };

  grunt.registerTask(
    'setup-mac-keychain',
    'Setup Mac Keychain to sign the app',
    function setupMacKeychain() {
      const done = this.async();
      if (!shouldRun()) return done();

      return buildMacKeychain()
        .then(done)
        .catch(grunt.fail.fatal);
    }
  );
};
