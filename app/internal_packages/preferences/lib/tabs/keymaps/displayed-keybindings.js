module.exports = [
  {
    title: 'Application',
    items: [['application:new-message', 'New Message'], ['core:focus-search', 'Search']],
  },
  {
    title: 'Actions',
    items: [
      ['core:reply', 'Reply'],
      ['core:reply-all', 'Reply All'],
      ['core:forward', 'Forward'],
      ['core:archive-item', 'Archive'],
      ['core:delete-item', 'Trash'],
      ['core:remove-from-view', 'Remove from view'],
      ['core:gmail-remove-from-view', 'Gmail Remove from view'],
      ['core:star-item', 'Star'],
      ['core:snooze-item', 'Snooze'],
      ['core:change-labels', 'Change Labels'],
      ['core:change-folders', 'Change Folder'],
      ['core:mark-as-read', 'Mark as read'],
      ['core:mark-as-unread', 'Mark as unread'],
      ['core:mark-important', 'Mark as important (Gmail)'],
      ['core:mark-unimportant', 'Mark as unimportant (Gmail)'],
      ['core:remove-and-previous', 'Remove from view and previous'],
      ['core:remove-and-next', 'Remove from view and next'],
    ],
  },
  {
    title: 'Composer',
    items: [
      ['composer:send-message', 'Send Message'],
      ['composer:focus-to', 'Focus the To field'],
      ['composer:show-and-focus-cc', 'Focus the Cc field'],
      ['composer:show-and-focus-bcc', 'Focus the Bcc field'],
      ['composer:select-attachment', 'Select file attachment'],
    ],
  },
  {
    title: 'Navigation',
    items: [
      ['core:pop-sheet', 'Return to conversation list'],
      ['core:focus-item', 'Open selected conversation'],
      ['core:previous-item', 'Move to newer conversation'],
      ['core:next-item', 'Move to older conversation'],
    ],
  },
  {
    title: 'Selection',
    items: [
      ['core:select-item', 'Select conversation'],
      ['multiselect-list:select-all', 'Select all conversations'],
      ['multiselect-list:deselect-all', 'Deselect all conversations'],
      ['thread-list:select-read', 'Select all read conversations'],
      ['thread-list:select-unread', 'Select all unread conversations'],
      ['thread-list:select-starred', 'Select all starred conversations'],
      ['thread-list:select-unstarred', 'Select all unstarred conversations'],
    ],
  },
  {
    title: 'Jumping',
    items: [
      ['navigation:go-to-inbox', 'Go to "Inbox"'],
      ['navigation:go-to-starred', 'Go to "Starred"'],
      ['navigation:go-to-sent', 'Go to "Sent Mail"'],
      ['navigation:go-to-drafts', 'Go to "Drafts"'],
      ['navigation:go-to-all', 'Go to "All Mail"'],
    ],
  },
];
