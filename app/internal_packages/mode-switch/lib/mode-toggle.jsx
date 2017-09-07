import {ComponentRegistry,
 WorkspaceStore,
 Actions} from "nylas-exports"
import {RetinaImg} from 'nylas-component-kit'
import React from "react"
import _ from "underscore"

export default class ModeToggle extends React.Component {
  static displayName = 'ModeToggle';

  constructor(props) {
    super(props);
    this.column = WorkspaceStore.Location.MessageListSidebar
    this.state = this._getStateFromStores()
  }

  componentDidMount() {
    this._unsubscriber = WorkspaceStore.listen(this._onStateChanged)
    this._mounted = true;
  }

  componentWillUnmount() {
    this._mounted = false
    if (this._unsubscriber) {
      this._unsubscriber();
    }
  }

  _getStateFromStores() {
    return {
      hidden: WorkspaceStore.isLocationHidden(this.column),
    };
  }

  _onStateChanged = () => {
    // We need to keep track of this because our parent unmounts us in the same
    // event listener cycle that we receive the event in. ie:
    //
    //   for listener in listeners
    //      # 1. workspaceView remove left column
    //      # ---- Mode toggle unmounts, listeners array mutated in place
    //      # 2. ModeToggle update
    if (!this._mounted) {
      return;
    }
    this.setState(this._getStateFromStores());
  }

  _onToggleMode = () => {
    Actions.toggleWorkspaceLocationHidden(this.column)
  }

  render() {
    return (
      <button
        className={`btn btn-toolbar mode-toggle mode-${this.state.hidden}`}
        style={{order: 500}}
        title={this.state.hidden ? "Show sidebar" : "Hide sidebar"}
        onClick={this._onToggleMode}
      >
        <RetinaImg
          name="toolbar-person-sidebar.png"
          mode={RetinaImg.Mode.ContentIsMask}
        />
      </button>
    );
  }
}
