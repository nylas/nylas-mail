import fs from 'fs-plus'
import path from 'path'
import child_process from 'child_process'

async function spawn(cmd, args, opts={}) {
  return new Promise((resolve, reject) => {
    const options = Object.assign({stdio: 'inherit'}, opts);
    const proc = child_process.spawn(cmd, args, options)
    proc.on("error", reject)
    proc.on("exit", resolve)
  })
}

async function installPrivateResources() {
  console.log("\n---> Linking private plugins")
  const privateDir = path.resolve(path.join('packages', 'client-private-plugins'))
  if (!fs.existsSync(privateDir)) {
    console.log("\n---> No client app to link. Moving on")
    return;
  }
  const unlinkIfExistsSync = (p) => {
    try {
      if (fs.lstatSync(p)) {
        fs.removeSync(p);
      }
    } catch (err) {
      return
    }
  }

  // copy Source Extensions
  unlinkIfExistsSync(path.join('packages', 'client-app', 'src', 'error-logger-extensions'));
  fs.copySync(path.join(privateDir, 'src'), 'src');

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
  await spawn("lerna", ["bootstrap"])
}

const npmEnvs = {
  system: process.env,
  apm: Object.assign({}, process.env, {
    'NPM_CONFIG_TARGET': '0.10.40',
  }),
  electron: Object.assign({}, process.env, {
    'NPM_CONFIG_TARGET': '1.4.15',
    'NPM_CONFIG_ARCH': process.arch,
    'NPM_CONFIG_TARGET_ARCH': process.arch,
    'NPM_CONFIG_DISTURL': 'https://atom.io/download/electron',
    'NPM_CONFIG_RUNTIME': 'electron',
    'NPM_CONFIG_BUILD_FROM_SOURCE': true,
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
  if (!fs.existsSync(path.join("packages", "client-app"))) {
    console.log("\n---> No client app to rebuild. Moving on")
    return;
  }
  await npm('rebuild', {cwd: path.join('packages', 'client-app', 'apm'),
                        env: 'apm'})
  await npm('rebuild', {cwd: path.join('packages', 'client-app'),
                        env: 'electron'})
}

async function main() {
  try {
    await installPrivateResources()
    await lernaBootstrap();
    await electronRebuild();
  } catch (err) {
    console.error(err);
    process.exit(1);
  }
}
main()
