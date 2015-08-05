CategoryStore = require '../stores/category-store'
FocusedCategoryStore = require '../stores/focused-category-store'

ChangeLabelsTask = require './change-labels-task'
ChangeFolderTask = require './change-folder-task'

NamespaceStore = require '../stores/namespace-store'

class ArchiveThreadHelper

  getArchiveTask: (threads) ->
    @_getTask(threads, "archive")

  getUnarchiveTask: (threads) ->
    @_getTask(threads, "unarchive")

  _getTask: (threads=[], direction) ->
    threads = [threads] unless threads instanceof Array
    namespace = NamespaceStore.current()
    return null unless namespace

    if namespace.usesFolders()
      if direction is "archive"
        archiveFolder = CategoryStore.getStandardCategory("archive")
        if archiveFolder
          return new ChangeFolderTask
            folder: archiveFolder
            threads: threads
        else
          # TODO: Implement some sort of UI for people to pick the folder
          # they want to use as the Archive. Or better yet, automatically
          # add an `Archive` folder first, then move it to there and maybe
          # throw up some sort of notifciation.
          #
          # In the meantime, just throw up a notification so people do it on
          # the backend.
          Actions.postNotification
            type: 'error'
            tag: 'noArchive'
            sticky: true
            message: "You have not created an Archive folder. Please create a folder called 'Archive' with your email provider, restart Nylas Mail, then try again.",
          return null
      else if direction is "unarchive"
        inboxFolder = CategoryStore.getStandardCategory("inbox")
        return new ChangeFolderTask
          folder: inboxFolder
          threads: threads

    else if namespace.usesLabels()
      currentLabel = FocusedCategoryStore.category()
      currentLabel ?= CategoryStore.getStandardCategory("inbox")

      params = {threads}
      if direction is "archive"
        params.labelsToRemove = [currentLabel]
      else if direction is "unarchive"
        params.labelsToAdd = [currentLabel]

      archiveLabel = CategoryStore.getStandardCategory("archive")
      if archiveLabel
        if direction is "archive"
          params.labelsToAdd = [archiveLabel]
        else if direction is "unarchive"
          params.labelsToRemove = [archiveLabel]

      return new ChangeLabelsTask(params)
    else
      throw new Error("Invalid organizationUnit")

module.exports = new ArchiveThreadHelper()
