ipc = require 'ipc'
Reflux = require 'reflux'

# These actions are rebroadcast through the ActionBridge to all
# windows. You can listen for them regardless of where they are
# fired within the app.

globalActions = [
  "didSwapModel",
  "logout",
]

# These actions are rebroadcast through the ActionBridge to the
# main window if they are fired in a secondary window. You should
# only listen to these actions in the main window.

# NOTE: Some of these actions carry a significant payload, and
# re-broadcasting them to all windows would be expensive and pointless.

mainWindowActions = [
  # Actions for Tasks
  "queueTask",
  "abortTask",
  "restartTaskQueue",
  "resetTaskQueue",
  "longPollStateChanged",
  "didMakeAPIRequest",
]

# These actions are broadcast within their originating window only. Almost
# all actions that are related to user interaction state belong here.

windowActions = [
  "developerPanelSelectSection",

  # Fired when a dialog is opened and a file is selected
  "openPathsSelected",
  "savePathSelected",

  # Actions for Selection State
  "selectNamespaceId",
  "selectThreadId",
  "selectTagId",

  # Actions for composer
  "composeReply",
  "composeForward",
  "composeReplyAll",
  "composePopoutDraft",
  "composeNewBlankDraft",

  "saveDraft",
  "sendDraft",
  "destroyDraft",

  # Actions for Search
  "searchQueryChanged",
  "searchQueryCommitted",
  "searchConstantsChanged",
  "searchBlurred",

  # File Actions
  "attachFile",
  "abortUpload",
  "uploadStateChanged",
  "fileUploaded",
  "fileAborted",
  "removeFile",
  "fetchAndOpenFile",
  "fetchAndSaveFile",
  "fetchFile",
  "abortDownload",

  # Notification actions
  "postNotification",
  "notificationActionTaken",
  
  # FullContact Sidebar
  "getFullContactDetails",

  # Templates
  "insertTemplateId",
  "createTemplate",
  "showTemplates",
]

allActions = [].concat(windowActions).concat(globalActions).concat(mainWindowActions)

Actions = Reflux.createActions(allActions)
for key, action of Actions
  action.sync = true

Actions.windowActions = windowActions
Actions.mainWindowActions = mainWindowActions
Actions.globalActions = globalActions

ipc.on "paths-to-open", (pathsToOpen=[]) ->
  Actions.openPathsSelected(pathsToOpen)

ipc.on "save-file-selected", (savePath) ->
  Actions.savePathSelected(savePath)

module.exports = Actions
