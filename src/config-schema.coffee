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
          systemTray:
            type: 'boolean'
            default: true
            title: "Show icon in menu bar"
            platforms: ['darwin', 'linux']
          showImportant:
            type: 'boolean'
            default: true
            title: "Show Gmail-style important markers (Gmail Only)"
          showUnreadForAllCategories:
            type: 'boolean'
            default: false
            title: "Show unread counts for all folders / labels"
          interfaceZoom:
            title: "Override standard interface scaling"
            type: 'number'
            default: 1
            enum: [0.6, 0.8, 1, 1.2, 1.4]
            enumLabels: ['60%', '80%', '100%', '120%', '140%']
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
            enumLabels: ['When Received', 'When Read', 'Manually']
            title: "Download attachments for new mail"
      reading:
        type: 'object'
        properties:
          markAsReadDelay:
            type: 'integer'
            default: 500
            enum: [0, 500, 2000, -1]
            enumLabels: ['Instantly', 'After ½ Second', 'After 2 Seconds', 'Manually']
            title: "When reading messages, mark as read"
          autoloadImages:
            type: 'boolean'
            default: true
            title: "Automatically load images in viewed messages"
          backspaceDelete:
            type: 'boolean'
            default: false
            title: "Use backspace / delete to move messages to trash"
      sending:
        type: 'object'
        properties:
          sounds:
            type: 'boolean'
            default: true
            title: "Play sound when a message is sent"
          defaultReplyType:
            type: 'string'
            default: 'reply-all'
            enum: ['reply', 'reply-all']
            enumLabels: ['Reply', 'Reply All']
            title: "Default reply behavior"
      notifications:
        type: 'object'
        properties:
          enabled:
            type: 'boolean'
            default: true
            title: "Show notifications for new unread messages"
          sounds:
            type: 'boolean'
            default: true
            title: "Play sound when receiving new mail"
          unreadBadge:
            type: 'boolean'
            default: true
            title: "Show badge on the app icon"
            platforms: ['darwin']
