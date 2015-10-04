Reflux = require 'reflux'

Actions = [
  'selectTabIndex',
  'setInstalledSearchValue'
  'setGlobalSearchValue',

  'disablePackage',
  'enablePackage',
  'installPackage',
  'uninstallPackage',
  'createPackage',
  'reloadPackage',
  'showPackage',
  'updatePackage',

  'refreshFeaturedPackages',
  'refreshInstalledPackages',
]

for key in Actions
  Actions[key] = Reflux.createAction(name)
  Actions[key].sync = true

module.exports = Actions
