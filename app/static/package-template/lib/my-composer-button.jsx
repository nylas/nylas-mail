import { React, PropTypes } from 'mailspring-exports';

export default class MyComposerButton extends React.Component {
  // Note: You should assign a new displayName to avoid naming
  // conflicts when injecting your item
  static displayName = 'MyComposerButton';

  // When you register as a composer button, you receive a
  // reference to the draft, and you can look it up to perform
  // actions and retrieve data.
  static propTypes = {
    draft: PropTypes.object.isRequired,
    session: PropTypes.object.isRequired,
  };

  shouldComponentUpdate(nextProps) {
    // Our render method doesn't use the provided `draft`, and the draft changes
    // constantly (on every keystroke!) `shouldComponentUpdate` helps keep Mailspring fast.
    return nextProps.session !== this.props.session;
  }

  _onClick = () => {
    const { session, draft } = this.props;

    // To retrieve information about the draft, we fetch the current editing
    // session from the draft store. We can access attributes of the draft
    // and add changes to the session which will be appear immediately.
    const newSubject = `${draft.subject} - It Worked!`;

    const dialog = this._getDialog();
    dialog.showMessageBox({
      title: 'Here we go...',
      detail: `Adjusting the subject line To "${newSubject}"`,
      buttons: ['OK'],
      type: 'info',
    });

    session.changes.add({ subject: newSubject });
  };

  _getDialog() {
    return require('electron').remote.dialog;
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
