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
    NylasEnv.commands.dispatch(`application:select-${this.state.value}-mode`);
  }

  _renderModeOptions() {
    return ['list', 'split'].map((mode) =>
      <AppearanceModeOption
        mode={mode}
        key={mode}
        active={this.state.value === mode}
        onClick={() => this.setState({value: mode})}
      />
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
          className="item"
        >
          {this._renderModeOptions()}
        </Flexbox>
        <div className={applyChangesClass} onClick={this._onApplyChanges}>Apply Layout</div>
      </div>
    );
  }

}

const AppearanceModeOption = function AppearanceModeOption(props) {
  let classname = "appearance-mode";
  if (props.active) classname += " active";

  const label = {
    list: 'Single Panel',
    split: 'Two Panel',
  }[props.mode];

  return (
    <div className={classname} onClick={props.onClick}>
      <RetinaImg name={`appearance-mode-${props.mode}.png`} mode={RetinaImg.Mode.ContentIsMask} />
      <div>{label}</div>
    </div>
  );
}
AppearanceModeOption.propTypes = {
  mode: React.PropTypes.string.isRequired,
  active: React.PropTypes.bool,
  onClick: React.PropTypes.func,
}

class PreferencesAppearance extends React.Component {

  static displayName = 'PreferencesAppearance';

  static propTypes = {
    config: React.PropTypes.object,
    configSchema: React.PropTypes.object,
  }

  onClick = () => {
    NylasEnv.commands.dispatch("window:launch-theme-picker");
  }

  render() {
    return (
      <div className="container-appearance">
        <label htmlFor="change-layout">Change layout:</label>
        <AppearanceModeSwitch id="change-layout" config={this.props.config} />
        <button className="btn btn-large" onClick={this.onClick}>Change theme...</button>
      </div>
    );
  }
}

export default PreferencesAppearance;
