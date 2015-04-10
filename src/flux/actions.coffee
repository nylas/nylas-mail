Reflux = require 'reflux'

# These actions are rebroadcast through the ActionBridge to all
# windows. You can listen for them regardless of where they are
# fired within the app.

globalActions = [
  "didSwapModel",
  "didPassivelyReceiveNewModels",
  "logout",

  # File Actions
  # Since the TaskQueue is only in the main window, these actions need to
  # be rebroadcasted to all windows so you can watch the upload progress
  # from the popout composers
  "uploadStateChanged",
  "fileAborted",
  "downloadStateChanged",
  "fileUploaded",
  "attachFileComplete",

  "multiWindowNotification",

  # Draft actions
  "sendDraftError",
  "sendDraftSuccess"
]

# These actions are rebroadcast through the ActionBridge to the
# main window if they are fired in a secondary window. You should
# only listen to these actions in the main window.

# NOTE: Some of these actions carry a significant payload, and
# re-broadcasting them to all windows would be expensive and pointless.

mainWindowActions = [
  # Actions for Tasks
  "queueTask",
  "dequeueTask",
  "dequeueAllTasks",
  "dequeueMatchingTask",
  "longPollStateChanged",
  "longPollReceivedRawDeltas",
  "longPollConnected",
  "longPollOffline",
  "didMakeAPIRequest",
]

# These actions are broadcast within their originating window only. Almost
# all actions that are related to user interaction state belong here.

windowActions = [
  # Fired when a dialog is opened and a file is selected
  "showDeveloperConsole",
  "clearDeveloperConsole",

  # Actions for Selection State
  "selectNamespaceId",
  "selectView",
  "selectLayoutMode",

  "focusKeyboardInCollection",
  "focusInCollection",
  "focusTag",

  "selectThreads",
  
  "toggleMessageIdExpanded",

  # Actions for composer
  "composeReply",
  "composeForward",
  "composeReplyAll",
  "composePopoutDraft",
  "composeNewBlankDraft",

  "sendDraft",
  "destroyDraft",

  "archiveAndPrevious",
  "archiveCurrentThread",
  "archiveAndNext",

  # Actions for Search
  "searchQueryChanged",
  "searchQueryCommitted",
  "searchConstantsChanged",
  "searchBlurred",

  # Notification actions
  "postNotification",
  "notificationActionTaken",

  # FullContact Sidebar
  "getFullContactDetails",
  "focusContact",

  # Templates
  "insertTemplateId",
  "createTemplate",
  "showTemplates",

  # File Actions
  # Some file actions only need to be processed in their current window
  "attachFile",
  "attachFilePath",
  "abortUpload",
  "removeFile",
  "fetchAndOpenFile",
  "fetchAndSaveFile",
  "fetchFile",
  "abortDownload",
  "fileDownloaded",

  "popSheet",
  "pushSheet"
]

allActions = [].concat(windowActions).concat(globalActions).concat(mainWindowActions)

Actions = Reflux.createActions(allActions)
for key, action of Actions
  action.sync = true

Actions.windowActions = windowActions
Actions.mainWindowActions = mainWindowActions
Actions.globalActions = globalActions

module.exports = Actions
