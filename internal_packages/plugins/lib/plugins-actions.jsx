import Reflux from 'reflux';

const Actions = Reflux.createActions([
  'selectTabIndex',
  'setInstalledSearchValue',
  'setGlobalSearchValue',

  'disablePackage',
  'enablePackage',
  'installPackage',
  'installNewPackage',
  'uninstallPackage',
  'createPackage',
  'reloadPackage',
  'showPackage',
  'updatePackage',

  'refreshFeaturedPackages',
  'refreshInstalledPackages',
]);

for (const key of Object.keys(Actions)) {
  Actions[key].sync = true;
}

export default Actions;
