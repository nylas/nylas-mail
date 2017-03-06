import fs from 'fs-plus'
import path from 'path'
import childProcess from 'child_process'

async function spawn(cmd, args, opts = {}) {
  return new Promise((resolve, reject) => {
    const options = Object.assign({stdio: 'inherit'}, opts);
    const proc = childProcess.spawn(cmd, args, options)
    proc.on("error", reject)
    proc.on("exit", resolve)
  })
}

function unlinkIfExistsSync(p) {
  try {
    if (fs.lstatSync(p)) {
      fs.removeSync(p);
    }
  } catch (err) {
    return
  }
}

function copyErrorLoggerExtensions(privateDir) {
  const from = path.join(privateDir, 'src')
  const to = path.resolve(path.join('packages', 'client-app', 'src'))
  unlinkIfExistsSync(path.join(to, 'error-logger-extensions'));
  fs.copySync(from, to);
}

async function installPrivateResources() {
  console.log("\n---> Linking private plugins")
  const privateDir = path.resolve(path.join('packages', 'client-private-plugins'))
  if (!fs.existsSync(privateDir)) {
    console.log("\n---> No client app to link. Moving on")
    return;
  }

  copyErrorLoggerExtensions(privateDir)

  // link private plugins
  for (const plugin of fs.readdirSync(path.join(privateDir, 'packages'))) {
    const from = path.resolve(path.join(privateDir, 'packages', plugin));
    const to = path.resolve(path.join('packages', 'client-app', 'internal_packages', plugin));
    unlinkIfExistsSync(to);
    fs.symlinkSync(from, to, 'dir');
  }

  // link client-sync
  const clientSyncDir = path.resolve(path.join('packages', 'client-sync'));
  const destination = path.resolve(path.join('packages', 'client-app', 'internal_packages', 'client-sync'));
  unlinkIfExistsSync(destination);
  fs.symlinkSync(clientSyncDir, destination, 'dir');
}

async function lernaBootstrap() {
  console.log("\n---> Installing packages");
  await spawn("lerna", ["bootstrap", '--loglevel=silly'])
}

const npmEnvs = {
  system: process.env,
  apm: Object.assign({}, process.env, {
    NPM_CONFIG_TARGET: '0.10.40',
  }),
  electron: Object.assign({}, process.env, {
    NPM_CONFIG_TARGET: '1.4.15',
    NPM_CONFIG_ARCH: process.arch,
    NPM_CONFIG_TARGET_ARCH: process.arch,
    NPM_CONFIG_DISTURL: 'https://atom.io/download/electron',
    NPM_CONFIG_RUNTIME: 'electron',
    NPM_CONFIG_BUILD_FROM_SOURCE: true,
  }),
};

async function npm(cmd, options) {
  const {cwd, env} = Object.assign({cwd: '.', env: 'system'}, options);
  await spawn("npm", [cmd], {
    cwd: path.resolve(__dirname, '..', cwd),
    env: npmEnvs[env],
  })
}

async function electronRebuild() {
  if (!fs.existsSync(path.join("packages", "client-app", "apm"))) {
    console.log("\n---> No client app to rebuild. Moving on")
    return;
  }
  await npm('install', {
    cwd: path.join('packages', 'client-app', 'apm'),
    env: 'apm',
  })
  await npm('rebuild', {
    cwd: path.join('packages', 'client-app'),
    env: 'electron',
  })
}

const getJasmineDir = (packageName) => path.resolve(
  path.join('packages', packageName, 'spec', 'jasmine')
)
const getJasmineConfigPath = (packageName) => path.resolve(
  path.join(getJasmineDir(packageName), 'config.json')
)

function linkJasmineConfigs() {
  console.log("\n---> Linking Jasmine configs");
  const linkToPackages = ['cloud-api', 'cloud-core', 'cloud-workers']
  const from = getJasmineConfigPath('isomorphic-core')

  for (const packageName of linkToPackages) {
    const dir = getJasmineDir(packageName)
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir)
    }
    const to = getJasmineConfigPath(packageName)
    unlinkIfExistsSync(to)
    fs.symlinkSync(from, to, 'file')
  }
}

function linkIsomorphicCoreSpecs() {
  console.log("\n---> Linking isomorphic-core specs to client-app specs")
  const from = path.resolve(path.join('packages', 'isomorphic-core', 'spec'))
  const to = path.resolve(path.join('packages', 'client-app', 'spec', 'isomorphic-core'))
  unlinkIfExistsSync(to)
  fs.symlinkSync(from, to, 'dir')
}

async function main() {
  try {
    await installPrivateResources()
    await lernaBootstrap();

    // Given that `lerna bootstrap` does not install optional dependencies, we
    // need to manually run `npm install` inside `client-app` so
    // `node-mac-notifier` get's correctly installed and included in the build
    // See https://github.com/lerna/lerna/issues/121
    console.log("\n---> Reinstalling client-app dependencies to include optional dependencies");
    await npm('install', {cwd: 'packages/client-app'})

    await electronRebuild();

    linkJasmineConfigs();
    linkIsomorphicCoreSpecs();
  } catch (err) {
    console.error(err);
    process.exit(1);
  }
}
main()
