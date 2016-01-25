{React,
 Actions,
 TaskFactory,
 ComposerExtension,
 FocusedMailViewStore} = require 'nylas-exports'

{RetinaImg} = require 'nylas-component-kit'

class SendAndArchiveExtension extends ComposerExtension
  @sendActionConfig: ({draft}) ->
    if draft.threadId
      return {
        title: "Send and Archive"
        iconUrl: "nylas://send-and-archive/images/composer-archive@2x.png"
        onSend: @_sendAndArchive
      }
    else return null

  @_sendAndArchive: ({draft}) ->
    Actions.sendDraft(draft.clientId)
    archiveTask = TaskFactory.taskForArchiving
      threads: [draft.threadId]
      fromView: FocusedMailViewStore.mailView()
    Actions.queueTask(archiveTask)

module.exports = SendAndArchiveExtension
