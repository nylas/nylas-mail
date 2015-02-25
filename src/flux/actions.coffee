ipc = require 'ipc'
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
  "fileUploaded"
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
  "clearDeveloperConsole",

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

  # Notification actions
  "postNotification",
  "notificationActionTaken",
  
  # FullContact Sidebar
  "getFullContactDetails",

  # Templates
  "insertTemplateId",
  "createTemplate",
  "showTemplates",

  # File Actions
  # Some file actions only need to be processed in their current window
  "attachFile",
  "abortUpload",
  "persistUploadedFile", # This touches the DB, should only be in main window
  "removeFile",
  "fetchAndOpenFile",
  "fetchAndSaveFile",
  "fetchFile",
  "abortDownload"
  "fileDownloaded"
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
