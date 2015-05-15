path = require 'path'
fs = require 'fs-plus'

# This is loaded by atom.coffee. See https://atom.io/docs/api/latest/Config for
# more information about config schemas.
module.exports =
  core:
    type: 'object'
    properties:
      disabledPackages:
        type: 'array'
        default: []
        items:
          type: 'string'
      themes:
        type: 'array'
        default: ['light-ui']
        items:
          type: 'string'



if process.platform in ['win32', 'linux']
  module.exports.core.properties.autoHideMenuBar =
    type: 'boolean'
    default: false
    description: 'Automatically hide the menu bar and toggle it by pressing Alt. This is only supported on Windows & Linux.'
