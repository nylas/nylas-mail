# This is loaded by atom.coffee. See https://atom.io/docs/api/latest/Config for
# more information about config schemas.
module.exports =
  core:
    type: 'object'
    properties:
      workspace:
        type: 'object'
        properties:
          mode:
            type: 'string'
            default: 'list'
            enum: ['split', 'list']
      showUnreadBadge:
        type: 'boolean'
        default: true
      showImportant:
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
        default: 'Gmail'
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
