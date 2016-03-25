{ComposerExtension} = require 'nylas-exports'
request = require 'request'
post = Promise.promisify(request.post, multiArgs: true)

class AvailabilityComposerExtension extends ComposerExtension

  # When subclassing the ComposerExtension, you can add your own custom logic
  # to execute before a draft is sent in the @applyTransformsToDraft
  # method. Here, we're registering the events before we send the draft.
  @applyTransformsToDraft: ({draft}) ->
    matches = (/data-quick-schedule="(.*)?" style/).exec(draft.body)
    return draft unless matches

    json = atob(matches[1])
    data = JSON.parse(json)
    data.attendees = []
    data.attendees = draft.participants().map (p) ->
      name: p.name, email: p.email, isSender: p.isMe()
    serverUrl = "https://quickschedule.herokuapp.com/register-events"

    return post({
      url: serverUrl,
      body: JSON.stringify(data)
    })
    .then (args) =>
      if args[0].statusCode != 200
        throw new Error()
      data = args[1]
      return Promise.resolve(draft)
    .catch (error) ->
      dialog = require('remote').require('dialog')
      dialog.showErrorBox('Error creating QuickSchedule event',
      "There was a problem connecting to the QuickSchedule server. Make sure you're connected to the internet and "+
      "try sending again. If problems persist, contact the N1 team (using the blue question icon at the bottom right "+
      "of your inbox) and we'll get right on it!")
      return Promise.reject(error)

  @unapplyTransformsToDraft: ({draft}) ->
    return draft


module.exports = AvailabilityComposerExtension
