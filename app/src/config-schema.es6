export default {
  core: {
    type: 'object',
    properties: {
      sync: {
        type: 'object',
        properties: {
          verboseUntil: {
            type: 'number',
            default: 0,
            title: 'Enable verbose IMAP / SMTP logging',
          },
        },
      },
      workspace: {
        type: 'object',
        properties: {
          mode: {
            type: 'string',
            default: 'list',
            enum: ['split', 'list'],
          },
          systemTray: {
            type: 'boolean',
            default: true,
            title: 'Show icon in menu bar / system tray',
            platforms: ['darwin', 'linux'],
          },
          showImportant: {
            type: 'boolean',
            default: true,
            title: 'Show Gmail-style important markers (Gmail Only)',
          },
          showUnreadForAllCategories: {
            type: 'boolean',
            default: false,
            title: 'Show unread counts for all folders / labels',
          },
          use24HourClock: {
            type: 'boolean',
            default: false,
            title: 'Use 24-hour clock',
          },
          interfaceZoom: {
            title: 'Override standard interface scaling',
            type: 'number',
            default: 1,
            advanced: true,
          },
        },
      },
      disabledPackages: {
        type: 'array',
        default: [],
        items: {
          type: 'string',
        },
      },
      themes: {
        type: 'array',
        default: ['ui-light'],
        items: {
          type: 'string',
        },
      },
      keymapTemplate: {
        type: 'string',
        default: 'Gmail',
      },
      attachments: {
        type: 'object',
        properties: {
          downloadPolicy: {
            type: 'string',
            default: 'on-read',
            enum: ['on-read', 'manually'],
            enumLabels: ['When Read', 'Manually'],
            title: 'Download attachments for new mail',
          },
          displayFilePreview: {
            type: 'boolean',
            default: true,
            title: 'Display thumbnail previews for attachments when available. (macOS only)',
          },
        },
      },
      reading: {
        type: 'object',
        properties: {
          markAsReadDelay: {
            type: 'integer',
            default: 500,
            enum: [0, 500, 2000, -1],
            enumLabels: ['Instantly', 'After ½ Second', 'After 2 Seconds', 'Manually'],
            title: 'When reading messages, mark as read',
          },
          autoloadImages: {
            type: 'boolean',
            default: true,
            title: 'Automatically load images in viewed messages',
          },
          backspaceDelete: {
            type: 'boolean',
            default: false,
            title: 'Swipe gesture and backspace / delete move messages to trash',
          },
          descendingOrderMessageList: {
            type: 'boolean',
            default: false,
            title: 'Display conversations in descending chronological order',
          },
        },
      },
      composing: {
        type: 'object',
        properties: {
          spellcheck: {
            type: 'boolean',
            default: true,
            title: 'Check messages for spelling',
          },
        },
      },
      sending: {
        type: 'object',
        properties: {
          sounds: {
            type: 'boolean',
            default: true,
            title: 'Play sound when a message is sent',
          },
          defaultReplyType: {
            type: 'string',
            default: 'reply-all',
            enum: ['reply', 'reply-all'],
            enumLabels: ['Reply', 'Reply All'],
            title: 'Default reply behavior',
          },
          undoSend: {
            type: 'number',
            default: 5000,
            enum: [5000, 15000, 30000, 60000, 0],
            enumLabels: ['5 seconds', '15 seconds', '30 seconds', '60 seconds', 'Disable'],
            title: 'After sending, enable undo for',
          },
        },
      },
      notifications: {
        type: 'object',
        properties: {
          enabled: {
            type: 'boolean',
            default: true,
            title: 'Show notifications for new unread messages',
          },
          sounds: {
            type: 'boolean',
            default: true,
            title: 'Play sound when receiving new mail',
          },
          unsnoozeToTop: {
            type: 'boolean',
            default: true,
            title: 'Resurface messages to the top of the inbox when unsnoozing',
          },
          countBadge: {
            type: 'string',
            default: 'unread',
            enum: ['hide', 'unread', 'total'],
            enumLabels: ['Hide Badge', 'Show Unread Count', 'Show Total Count'],
            title: 'Show badge on the app icon',
          },
        },
      },
    },
  },
};
