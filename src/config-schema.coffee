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
            title: "Show icon in menu bar / system tray"
            platforms: ['darwin', 'linux']
          showImportant:
            type: 'boolean'
            default: true
            title: "Show Gmail-style important markers (Gmail Only)"
          showUnreadForAllCategories:
            type: 'boolean'
            default: false
            title: "Show unread counts for all folders / labels"
          use24HourClock:
            type: 'boolean'
            default: false
            title: "Use 24-hour clock"
          interfaceZoom:
            title: "Override standard interface scaling"
            type: 'number'
            default: 1
            advanced: true
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
            title: "Swipe gesture and backspace / delete move messages to trash"
          useLongDisplayNames:
            type: 'boolean'
            default: false
            title: "Use full contact names instead of compact"
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
          defaultSendType:
            type: 'string'
            default: 'send'
            enum: ['send', 'send-and-archive']
            enumLabels: ['Send', 'Send and Archive']
            title: "Default send behavior"
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
          countBadge:
            type: 'string'
            default: 'unread'
            enum: ['hide', 'unread', 'total']
            enumLabels: ['Hide Badge', 'Show Unread Count', 'Show Total Count']
            title: "Show badge on the app icon"
