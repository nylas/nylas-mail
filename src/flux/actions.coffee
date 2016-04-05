Reflux = require 'reflux'

ActionScopeWindow = 'window'
ActionScopeGlobal = 'global'
ActionScopeWorkWindow = 'work'

###
Public: In the Flux {Architecture.md}, almost every user action
is translated into an Action object and fired globally. Stores in the app observe
these actions and perform business logic. This loose coupling means that your
packages can observe actions and perform additional logic, or fire actions which
the rest of the app will handle.

In Reflux, each {Action} is an independent object that acts as an event emitter.
You can listen to an Action, or invoke it as a function to fire it.

## Action Scopes

N1 is a multi-window application. The `scope` of an Action dictates
how it propogates between windows.

- **Global**: These actions can be listened to from any window and fired from any
  window. The action is sent from the originating window to all other windows via
  IPC, so they should be used with care. Firing this action from anywhere will
  cause all listeners in all windows to fire.

- **Main Window**: You can fire these actions in any window. They'll be sent
  to the main window and triggered there.

- **Window**: These actions only trigger listeners in the window they're fired in.

## Firing Actions

```coffee
Actions.postNotification({message: "Removed Thread", type: 'success'})

Actions.queueTask(new ChangeStarredTask(thread: @_thread, starred: true))
```

## Listening for Actions

If you're using Reflux to create your own Store, you can use the `listenTo`
convenience method to listen for an Action. If you're creating your own class
that is not a Store, you can still use the `listen` method provided by Reflux:

```coffee
setup: ->
  @unlisten = Actions.didPassivelyReceiveNewModels.listen(@onNewMailReceived, @)

onNewMailReceived: (data) ->
  console.log("You've got mail!", data)

teardown: ->
  @unlisten()
```

Section: General
###
class Actions

  ###
  Public: Fired when the Nylas API Connector receives new data from the API.

  *Scope: Global*

  Receives an {Object} of {Array}s of {Model}s, for example:

  ```json
  {
    'thread': [<Thread>, <Thread>]
    'contact': [<Contact>]
  }
  ```
  ###
  @didPassivelyReceiveNewModels: ActionScopeGlobal

  @downloadStateChanged: ActionScopeGlobal

  ###
  Public: Fired when a draft is successfully sent
  *Scope: Global*

  Recieves the clientId of the message that was sent
  ###
  @sendDraftSuccess: ActionScopeGlobal
  @sendToAllWindows: ActionScopeGlobal
  @draftSendingFailed: ActionScopeGlobal

  ###
  Public: Queue a {Task} object to the {TaskQueue}.

  *Scope: Work Window*
  ###
  @queueTask: ActionScopeWorkWindow

  ###
  Public: Queue multiple {Task} objects to the {TaskQueue}, which should be
  undone as a single user action.

  *Scope: Work Window*
  ###
  @queueTasks: ActionScopeWorkWindow

  @undoTaskId: ActionScopeWorkWindow

  ###
  Public: Dequeue all {Task}s from the {TaskQueue}. Use with care.

  *Scope: Work Window*
  ###
  @dequeueAllTasks: ActionScopeWorkWindow
  @dequeueTask: ActionScopeWorkWindow

  ###
  Public: Dequeue a {Task} matching the description provided.

  *Scope: Work Window*
  ###
  @dequeueMatchingTask: ActionScopeWorkWindow

  @longPollReceivedRawDeltas: ActionScopeWorkWindow
  @longPollReceivedRawDeltasPing: ActionScopeGlobal
  @longPollProcessedDeltas: ActionScopeWorkWindow
  @willMakeAPIRequest: ActionScopeWorkWindow
  @didMakeAPIRequest: ActionScopeWorkWindow

  ###
  Public: Retry the initial sync

  *Scope: Work Window*
  ###
  @retrySync: ActionScopeWorkWindow

  ###
  Public: Open the preferences view.

  *Scope: Global*
  ###
  @openPreferences: ActionScopeGlobal

  ###
  Public: Switch to the preferences tab with the specific name

  *Scope: Global*
  ###
  @switchPreferencesTab: ActionScopeGlobal

  ###
  Public: Clear the developer console for the current window.

  *Scope: Window*
  ###
  @clearDeveloperConsole: ActionScopeWindow

  ###
  Public: Remove the selected account

  *Scope: Window*
  ###
  @removeAccount: ActionScopeWindow

  ###
  Public: Update the provided account

  *Scope: Window*

  ```
  Actions.updateAccount(account.id, {accountName: 'new'})
  ```
  ###
  @updateAccount: ActionScopeWindow

  ###
  Public: Re-order the provided account in the account list.

  *Scope: Window*

  ```
  Actions.reorderAccount(account.id, newIndex)
  ```
  ###
  @reorderAccount: ActionScopeWindow

  ###
  Public: Select the provided sheet in the current window. This action changes
  the top level sheet.

  *Scope: Window*

  ```
  Actions.selectRootSheet(WorkspaceStore.Sheet.Threads)
  ```
  ###
  @selectRootSheet: ActionScopeWindow

  ###
  Public: Toggle whether a particular column is visible. Call this action
  with one of the Sheet location constants:

  ```
  Actions.toggleWorkspaceLocationHidden(WorkspaceStore.Location.MessageListSidebar)
  ```
  ###
  @toggleWorkspaceLocationHidden: ActionScopeWindow

  ###
  Public: Focus the keyboard on an item in a collection. This action moves the
  `keyboard focus` element in lists and other components,  but does not change
  the focused DOM element.

  *Scope: Window*

  ```
  Actions.setCursorPosition(collection: 'thread', item: <Thread>)
  ```
  ###
  @setCursorPosition: ActionScopeWindow

  ###
  Public: Focus on an item in a collection. This action changes the selection
  in lists and other components, but does not change the focused DOM element.

  *Scope: Window*

  ```
  Actions.setFocus(collection: 'thread', item: <Thread>)
  ```
  ###
  @setFocus: ActionScopeWindow

  ###
  Public: Focus the interface on a specific {MailboxPerspective}.

  *Scope: Window*

  ```
  Actions.focusMailboxPerspective(<Category>)
  ```
  ###
  @focusMailboxPerspective: ActionScopeWindow

  ###
  Public: Focus the interface on the default mailbox perspective for the provided
  account id.

  *Scope: Window*
  ###
  @focusDefaultMailboxPerspectiveForAccounts: ActionScopeWindow

  ###
  Public: If the message with the provided id is currently beign displayed in the
  thread view, this action toggles whether it's full content or snippet is shown.

  *Scope: Window*

  ```
  message = <Message>
  Actions.toggleMessageIdExpanded(message.id)
  ```
  ###
  @toggleMessageIdExpanded: ActionScopeWindow

  ###
  Public: Toggle whether messages from trash and spam are shown in the current
  message view.
  ###
  @toggleHiddenMessages: ActionScopeWindow

  ###
  Public: This action toggles wether to collapse or expand all messages in a
  thread depending on if there are currently collapsed messages.

  *Scope: Window*

  ```
  Actions.toggleAllMessagesExpanded()
  ```
  ###
  @toggleAllMessagesExpanded: ActionScopeWindow

  ###
  Public: Print the currently selected thread.

  *Scope: Window*

  ```
  thread = <Thread>
  Actions.printThread(thread)
  ```
  ###
  @printThread: ActionScopeWindow

  ###
  Public: Create a new reply to the provided threadId and messageId and populate
  it with the body provided.

  *Scope: Window*

  ```
  message = <Message>
  Actions.sendQuickReply({threadId: '123', messageId: '234'}, "Thanks Ben!")
  ```
  ###
  @sendQuickReply: ActionScopeWindow

  ###
  Public: Create a new reply to the provided threadId and messageId. Note that
  this action does not focus on the thread, so you may not be able to see the new draft
  unless you also call {::setFocus}.

  *Scope: Window*

  ```
  # Compose a reply to the last message in the thread
  Actions.composeReply({threadId: '123'})

  # Compose a reply to a specific message in the thread
  Actions.composeReply({threadId: '123', messageId: '123'})
  ```
  ###
  @composeReply: ActionScopeWindow

  ###
  Public: Create a new draft for forwarding the provided threadId and messageId. See
  {::composeReply} for parameters and behavior.

  *Scope: Window*
  ###
  @composeForward: ActionScopeWindow

  ###
  Public: Pop out the draft with the provided ID so the user can edit it in another
  window.

  *Scope: Window*

  ```
  messageId = '123'
  Actions.composePopoutDraft(messageId)
  ```
  ###
  @composePopoutDraft: ActionScopeWindow

  @focusDraft: ActionScopeWindow

  ###
  Public: Open a new composer window for creating a new draft from scratch.

  *Scope: Window*

  ```
  Actions.composeNewBlankDraft()
  ```
  ###
  @composeNewBlankDraft: ActionScopeWindow

  ###
  Public: Send the draft with the given ID. This Action is handled by the {DraftStore},
  which finalizes the {DraftChangeSet} and allows {ComposerExtension}s to display
  warnings and do post-processing. To change send behavior, you should consider using
  one of these objects rather than listening for the {sendDraft} action.

  *Scope: Window*

  ```
  Actions.sendDraft('123')
  ```
  ###
  @sendDraft: ActionScopeWindow
  @ensureDraftSynced: ActionScopeWindow

  ###
  Public: Destroys the draft with the given ID. This Action is handled by the {DraftStore},
  and does not display any confirmation UI.

  *Scope: Window*
  ###
  @destroyDraft: ActionScopeWindow

  ###
  Public: Submits the user's response to an RSVP event.

  *Scope: Window*
  ###
  @RSVPEvent: ActionScopeWindow

  ###
  Public: Fire to display an in-window notification to the user in the app's standard
  notification interface.

  *Scope: Global*

  ```
  # A simple notification
  Actions.postNotification({message: "Removed Thread", type: 'success'})

  # A sticky notification with actions
  NOTIF_ACTION_YES = 'YES'
  NOTIF_ACTION_NO = 'NO'

  Actions.postNotification
    type: 'info',
    sticky: true
    message: "Thanks for trying out N1! Would you like to make it your default mail client?",
    icon: 'fa-inbox',
    actions: [{
      label: 'Yes'
      default: true
      dismisses: true
      id: NOTIF_ACTION_YES
    },{
      label: 'More Info'
      dismisses: false
      id: NOTIF_ACTION_MORE_INFO
    }]

  ```
  ###
  @postNotification: ActionScopeGlobal

  @dismissNotificationsMatching: ActionScopeGlobal

  ###
  Public: Listen to this action to handle user interaction with notifications you
  published via `postNotification`.

  *Scope: Global*

  ```
  @_unlisten = Actions.notificationActionTaken.listen(@_onActionTaken, @)

  _onActionTaken: ({notification, action}) ->
    if action.id is NOTIF_ACTION_YES
      # perform action
  ```
  ###
  @notificationActionTaken: ActionScopeGlobal

  # FullContact Sidebar
  @getFullContactDetails: ActionScopeWindow
  @focusContact: ActionScopeWindow

  # Templates
  @insertTemplateId: ActionScopeWindow
  @createTemplate: ActionScopeWindow
  @showTemplates: ActionScopeWindow

  ###
  Public: Remove a file from a draft.

  *Scope: Window*

  ```
  Actions.removeFile
    file: fileObject
    messageClientId: draftClientId
  ```
  ###
  @removeFile: ActionScopeWindow

  # File Actions
  # Some file actions only need to be processed in their current window
  @addAttachment: ActionScopeWindow
  @selectAttachment: ActionScopeWindow
  @removeAttachment: ActionScopeWindow

  @fetchAndOpenFile: ActionScopeWindow
  @fetchAndSaveFile: ActionScopeWindow
  @fetchAndSaveAllFiles: ActionScopeWindow
  @fetchFile: ActionScopeWindow
  @abortFetchFile: ActionScopeWindow

  ###
  Public: Pop the current sheet off the Sheet stack maintained by the {WorkspaceStore}.
  This action has no effect if the window is currently showing a root sheet.

  *Scope: Window*
  ###
  @popSheet: ActionScopeWindow

  ###
  Public: Push a sheet of a specific type onto the Sheet stack maintained by the
  {WorkspaceStore}. Note that sheets have no state. To show a *specific* thread,
  you should push a Thread sheet and call `setFocus` to select the thread.

  *Scope: Window*

  ```
  WorkspaceStore.defineSheet 'Thread', {},
      list: ['MessageList', 'MessageListSidebar']

  ...

  @pushSheet(WorkspaceStore.Sheet.Thread)
  ```
  ###
  @pushSheet: ActionScopeWindow

  ###
  Public: Publish a user event to any analytics services linked to N1.
  ###
  @recordUserEvent: ActionScopeWindow

  @addMailRule: ActionScopeWindow
  @reorderMailRule: ActionScopeWindow
  @updateMailRule: ActionScopeWindow
  @deleteMailRule: ActionScopeWindow
  @disableMailRule: ActionScopeWindow

  @openPopover: ActionScopeWindow
  @closePopover: ActionScopeWindow

  @openModal: ActionScopeWindow
  @closeModal: ActionScopeWindow

  ###
  Public: Set metadata for a specified model and pluginId.

  *Scope: Window*

  Receives an {Model} or {Array} of {Model}s, a plugin id, and an Object that
  represents the metadata value.
  ###
  @setMetadata: ActionScopeWindow

  @draftParticipantsChanged: ActionScopeWindow

  @findInThread: ActionScopeWindow
  @nextSearchResult: ActionScopeWindow
  @previousSearchResult: ActionScopeWindow

# Read the actions we declared on the dummy Actions object above
# and translate them into Reflux Actions

# This helper method exists to trick the Donna lexer so it doesn't
# try to understand what we're doing to the Actions object.
create = (obj, name, scope) ->
  obj[name] = Reflux.createAction(name)
  obj[name].scope = scope
  obj[name].sync = true

scopes = {'window': [], 'global': [], 'work': []}

for name in Object.getOwnPropertyNames(Actions)
  continue if name in ['length', 'name', 'arguments', 'caller', 'prototype']
  continue unless Actions[name] in ['window', 'global', 'work']
  scope = Actions[name]
  scopes[scope].push(name)
  create(Actions, name, scope)

Actions.windowActions = scopes['window']
Actions.workWindowActions = scopes['work']
Actions.globalActions = scopes['global']

module.exports = Actions
