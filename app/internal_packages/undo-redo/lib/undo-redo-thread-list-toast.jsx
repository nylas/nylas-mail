import React from 'react';
import { UndoRedoStore } from 'mailspring-exports';
import { UndoToast } from 'mailspring-component-kit';

export default class UndoRedoThreadListToast extends React.Component {
  static displayName = 'UndoRedoThreadListToast';
  static containerRequired = false;

  constructor(props) {
    super(props);

    // Note: we explicitly do /not/ set initial state to the state of
    // the UndoRedoStore here because "getMostRecent" might be more
    // than 3000ms old.
    this.state = { visible: false, tasks: [] };
  }

  componentDidMount() {
    this._unlisten = UndoRedoStore.listen(() => {
      const tasks = UndoRedoStore.getMostRecent();
      this.setState({
        tasks,
        visible: tasks && tasks.length > 0,
      });
    });
  }

  componentWillUnmount() {
    if (this._unlisten) {
      this._unlisten();
    }
  }

  render() {
    return (
      <UndoToast
        visible={this.state.visible}
        visibleDuration={3000}
        className="undo-redo-thread-list-toast"
        onUndo={() => AppEnv.commands.dispatch('core:undo')}
        undoMessage={this.state.tasks.map(t => t.description()).join(', ')}
      />
    );
  }
}
