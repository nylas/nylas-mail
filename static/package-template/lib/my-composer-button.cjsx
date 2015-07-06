{Utils, DraftStore, React} = require 'nylas-exports'
{RetinaImg} = require 'nylas-component-kit'

class MyComposerButton extends React.Component

  # Note: You should assign a new displayName to avoid naming
  # conflicts when injecting your item
  @displayName: 'MyComposerButton'

  # When you register as a composer button, you receive a
  # reference to the draft, and you can look it up to perform
  # actions and retrieve data.
  @propTypes:
    draftLocalId: React.PropTypes.string.isRequired

  render: =>
    <div className="my-package">
      <button className="btn btn-toolbar" onClick={ => @_onClick()} ref="button">
        Hello World
      </button>
    </div>

  _onClick: =>
    # To retrieve information about the draft, we fetch the current editing
    # session from the draft store. We can access attributes of the draft
    # and add changes to the session which will be appear immediately.
    DraftStore.sessionForLocalId(@props.draftLocalId).then (session) =>
      newSubject = "#{session.draft().subject} - It Worked!"

      dialog = @_getDialog()
      dialog.showMessageBox
        title: 'Here we go...'
        detail: "Adjusting the subject line To `#{newSubject}`"
        buttons: ['OK']
        type: 'info'

      session.changes.add({subject: newSubject})

  _getDialog: =>
    require('remote').require('dialog')


module.exports = MyComposerButton