import React from 'react';
import {RetinaImg, Flexbox} from 'nylas-component-kit';


class AppearanceModeSwitch extends React.Component {

  static displayName = 'AppearanceModeSwitch';

  static propTypes = {
    config: React.PropTypes.object.isRequired,
  };

  constructor(props) {
    super();
    this.state = {
      value: props.config.get('core.workspace.mode'),
    };
  }

  componentWillReceiveProps(nextProps) {
    this.setState({
      value: nextProps.config.get('core.workspace.mode'),
    });
  }

  _onApplyChanges = () => {
    NylasEnv.commands.dispatch(document.body, `application:select-${this.state.value}-mode`);
  }

  _renderModeOptions() {
    return ['list', 'split'].map((mode) =>
      <AppearanceModeOption
        mode={mode}
        key={mode}
        active={this.state.value === mode}
        onClick={() => this.setState({value: mode})} />
    );
  }

  render() {
    const hasChanges = this.state.value !== this.props.config.get('core.workspace.mode');
    let applyChangesClass = "btn";
    if (!hasChanges) applyChangesClass += " btn-disabled";

    return (
      <div className="appearance-mode-switch">
        <Flexbox
          direction="row"
          style={{alignItems: "center"}}
          className="item">
          {this._renderModeOptions()}
        </Flexbox>
        <div className={applyChangesClass} onClick={this._onApplyChanges}>Apply Layout</div>
      </div>
    );
  }

}


class AppearanceModeOption extends React.Component {
  static propTypes = {
    mode: React.PropTypes.string.isRequired,
    active: React.PropTypes.bool,
    onClick: React.PropTypes.func,
  }

  constructor() {
    super();
  }

  render() {
    let classname = "appearance-mode";
    if (this.props.active) classname += " active";

    const label = {
      'list': 'Single Panel',
      'split': 'Two Panel',
    }[this.props.mode];

    return (
      <div className={classname} onClick={this.props.onClick}>
        <RetinaImg name={`appearance-mode-${this.props.mode}.png`} mode={RetinaImg.Mode.ContentIsMask}/>
        <div>{label}</div>
      </div>
    );
  }
}


class PreferencesAppearance extends React.Component {

  static displayName = 'PreferencesAppearance';

  static propTypes = {
    config: React.PropTypes.object,
    configSchema: React.PropTypes.object,
  }

  onClick = () => {
    NylasEnv.commands.dispatch(document.body, "window:launch-theme-picker");
  }


  render() {
    return (
      <div className="container-appearance">
        <label>Change layout:</label>
        <AppearanceModeSwitch config={this.props.config} />
        <button className="btn btn-large" onClick={this.onClick}>Change theme...</button>
      </div>
    );
  }

}

export default PreferencesAppearance;
