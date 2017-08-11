#!/usr/bin/env node
/* eslint global-require: 0 */
/* eslint quote-props: 0 */
const path = require('path');
const fs = require('fs');
const rimraf = require('rimraf');
const safeExec = require('./utils/child-process-wrapper.js').safeExec;

const npmElectronTarget = require('../app/package.json').dependencies.electron;
const npmEnvs = {
  system: process.env,
  electron: Object.assign({}, process.env, {
    'npm_config_target': npmElectronTarget,
    'npm_config_arch': process.arch,
    'npm_config_target_arch': process.arch,
    'npm_config_disturl': 'https://atom.io/download/atom-shell',
    'npm_config_runtime': 'electron',
    'npm_config_build_from_source': true,
  }),
};

function npm(cmd, options) {
  const {cwd, env} = Object.assign({cwd: '.', env: 'system'}, options);

  return new Promise((resolve, reject) => {
    console.log(`\n-- Running npm ${cmd} in ${cwd} with ${env} config --`)

    safeExec(`npm ${cmd}`, {
      cwd: path.resolve(__dirname, '..', cwd),
      env: npmEnvs[env],
    }, (err) => {
      return err ? reject(err) : resolve(null);
    });
  });
}

async function go() {
  // For speed, we cache app/node_modules. However, we need to
  // be sure to do a full rebuild of native node modules when the
  // Electron version changes. To do this we check a marker file.
  const cacheVersionPath = './app/node_modules/.postinstall-target-version';
  const cacheElectronTarget = fs.existsSync(cacheVersionPath) && fs.readFileSync(cacheVersionPath).toString();

  if (cacheElectronTarget !== npmElectronTarget) {
    console.log(`\n-- Clearing app/node_modules --`)
    rimraf.sync(path.resolve(__dirname, '..', 'app', 'node_modules'));
  }

  // run `npm install` in ./app with Electron NPM config
  await npm('install', {cwd: './app', env: 'electron'});

  // run `npm dedupe` in ./app with Electron NPM config
  await npm('dedupe', {cwd: './app', env: 'electron'});

  // write the marker with the electron version
  fs.writeFileSync(cacheVersionPath, npmElectronTarget);
}

go();
