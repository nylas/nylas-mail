import {DraftStore, React} from 'nylas-exports';

export default class MyComposerButton extends React.Component {

  // Note: You should assign a new displayName to avoid naming
  // conflicts when injecting your item
  static displayName = 'MyComposerButton';

  // When you register as a composer button, you receive a
  // reference to the draft, and you can look it up to perform
  // actions and retrieve data.
  static propTypes = {
    draftClientId: React.PropTypes.string.isRequired,
  };

  _onClick = () => {
    // To retrieve information about the draft, we fetch the current editing
    // session from the draft store. We can access attributes of the draft
    // and add changes to the session which will be appear immediately.
    DraftStore.sessionForClientId(this.props.draftClientId).then((session) => {
      const newSubject = `${session.draft().subject} - It Worked!`;

      const dialog = this._getDialog();
      dialog.showMessageBox({
        title: 'Here we go...',
        detail: `Adjusting the subject line To "${newSubject}"`,
        buttons: ['OK'],
        type: 'info',
      });

      session.changes.add({subject: newSubject});
    });
  }

  _getDialog() {
    return require('remote').require('dialog');
  }

  render() {
    return (
      <div className="my-package">
        <button className="btn btn-toolbar" onClick={() => this._onClick()} ref="button">
          Hello World
        </button>
      </div>
    );
  }
}
