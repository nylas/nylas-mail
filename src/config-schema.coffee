path = require 'path'
fs = require 'fs-plus'

# This is loaded by atom.coffee. See https://atom.io/docs/api/latest/Config for
# more information about config schemas.
module.exports =
  core:
    type: 'object'
    properties:
      showUnreadBadge:
        type: 'boolean'
        default: true
      disabledPackages:
        type: 'array'
        default: []
        items:
          type: 'string'
      themes:
        type: 'array'
        default: ['ui-light']
        items:
          type: 'string'
      keymapTemplate:
        type: 'string'
        default: 'Gmail.cson'
      attachments:
        type: 'object'
        properties:
          downloadPolicy:
            type: 'string'
            default: 'on-read'
            enum: ['on-receive', 'on-read', 'manually']
      reading:
        type: 'object'
        properties:
          markAsReadDelay:
            type: 'integer'
            default: 500
      sending:
        type: 'object'
        properties:
          sounds:
            type: 'boolean'
            default: true
          defaultReplyType:
            type: 'string'
            default: 'reply-all'
            enum: ['reply', 'reply-all']

if process.platform in ['win32', 'linux']
  module.exports.core.properties.autoHideMenuBar =
    type: 'boolean'
    default: false
    description: 'Automatically hide the menu bar and toggle it by pressing Alt. This is only supported on Windows & Linux.'
