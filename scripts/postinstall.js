#!/usr/bin/env node
/* eslint global-require: 0 */
/* eslint quote-props: 0 */
const path = require('path');
const safeExec = require('./utils/child-process-wrapper.js').safeExec;

const npmEnvs = {
  system: process.env,
  electron: Object.assign({}, process.env, {
    'npm_config_target': require('../app/package.json').dependencies.electron,
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

npm('install', {cwd: './app', env: 'electron'})
.then(() => npm('dedupe', {cwd: './app', env: 'electron'}))
