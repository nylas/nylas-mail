/* eslint global-require:0 */

import _ from 'underscore';
import fs from 'fs-plus';
import path from 'path';
import './spec-helper';

function setSpecField(name, value) {
  const specs = jasmine.getEnv().currentRunner().specs();
  if (specs.length === 0) { return; }

  for (let i = 0; i < specs.length; i++) {
    if (specs[i][name]) break;
    specs[i][name] = value
  }
}

function setSpecType(specType) {
  setSpecField('specType', specType);
}

function setSpecDirectory(specDirectory) {
  setSpecField('specDirectory', specDirectory);
}

function requireSpecs(specDirectory) {
  const { specFilePattern } = NylasEnv.getLoadSettings();

  let regex = /-spec\.(coffee|js|jsx|cjsx|es6|es)$/;
  if (_.isString(specFilePattern) && specFilePattern.length > 0) {
    regex = new RegExp(specFilePattern);
  }

  for (const specFilePath of fs.listTreeSync(specDirectory)) {
    if (regex.test(specFilePath)) {
      require(specFilePath)
    }
  }

  // Set spec directory on spec for setting up the project in
  // spec-helper
  setSpecDirectory(specDirectory)
}

function runAllSpecs() {
  const {resourcePath} = NylasEnv.getLoadSettings();

  requireSpecs(path.join(resourcePath, 'spec'));

  setSpecType('core');

  const fixturesPackagesPath = path.join(__dirname, 'fixtures', 'packages');

  // EDGEHILL_CORE: Look in internal_packages instead of node_modules
  let packagePaths = [];
  const iterable = fs.listSync(path.join(resourcePath, "internal_packages"));
  for (let i = 0; i < iterable.length; i++) {
    const packagePath = iterable[i];
    if (fs.isDirectorySync(packagePath)) {
      packagePaths.push(packagePath);
    }
  }

  packagePaths = _.uniq(packagePaths);

  packagePaths = _.groupBy(packagePaths, (packagePath) => {
    if (packagePath.indexOf(`${fixturesPackagesPath}${path.sep}`) === 0) {
      return 'fixtures';
    } else if (packagePath.indexOf(`${resourcePath}${path.sep}`) === 0) {
      return 'bundled';
    }
    return 'user';
  });

  // Run bundled package specs
  const iterable1 = packagePaths.bundled != null ? packagePaths.bundled : [];

  for (let j = 0; j < iterable1.length; j++) {
    const packagePath = iterable1[j];
    requireSpecs(path.join(packagePath, 'spec'));
  }
  setSpecType('bundled');

  // Run user package specs
  const iterable2 = packagePaths.user != null ? packagePaths.user : [];
  for (let k = 0; k < iterable2.length; k++) {
    const packagePath = iterable2[k];
    requireSpecs(path.join(packagePath, 'spec'));
  }
  return setSpecType('user');
}

const specDirectory = NylasEnv.getLoadSettings().specDirectory;
if (specDirectory) {
  requireSpecs(specDirectory);
  setSpecType('user');
} else {
  runAllSpecs();
}
