import React from 'react';
import Actions from '../../../src/flux/actions'

import {Flexbox, RetinaImg} from 'nylas-component-kit';
import ThemeOption from './theme-option';


class ThemePicker extends React.Component {
  static displayName = 'ThemePicker';

  constructor(props) {
    super(props);
    this.themes = NylasEnv.themes;
    this.state = this._getState();
  }

  componentDidMount() {
    this.disposable = this.themes.onDidChangeActiveThemes(() => {
      this.setState(this._getState());
    });
  }

  componentWillUnmount() {
    this.disposable.dispose();
  }

  _getState() {
    return {
      themes: this.themes.getLoadedThemes(),
      activeTheme: this.themes.getActiveTheme().name,
    }
  }

  _setActiveTheme(theme) {
    const prevActiveTheme = this.state.activeTheme;
    this.themes.setActiveTheme(theme);
    this._rewriteIFrame(prevActiveTheme, theme);
  }

  _rewriteIFrame(prevActiveTheme, activeTheme) {
    const prevActiveThemeDoc = document.querySelector(`.theme-preview-${prevActiveTheme}`).contentDocument;
    const prevActiveElement = prevActiveThemeDoc.querySelector(".theme-option.active-true");
    prevActiveElement.className = "theme-option active-false";
    const activeThemeDoc = document.querySelector(`.theme-preview-${activeTheme}`).contentDocument;
    const activeElement = activeThemeDoc.querySelector(".theme-option.active-false");
    activeElement.className = "theme-option active-true";
  }

  _renderThemeOptions() {
    return this.state.themes.map((theme) =>
      <ThemeOption
        key={theme.name}
        theme={theme}
        active={this.state.activeTheme === theme.name}
        onSelect={() => this._setActiveTheme(theme.name)} />
    );
  }

  render() {
    return (
      <div className="theme-picker">
        <Flexbox direction="column">
          <RetinaImg
            style={{width: "14", height: "14", margin: "12px", WebkitFilter: "none"}}
            name="picker-close.png"
            mode={RetinaImg.Mode.ContentDark}
            onMouseDown={() => Actions.closeModal()} />
          <h4 style={{color: "#434648"}}>Themes</h4>
          <div style={{color: "rgba(35, 31, 32, 0.5)", fontSize: "12px"}}>Click any theme to apply:</div>
          <div style={{margin: "10px 5px 0 5px", height: "290px", overflow: "auto"}}>
            <Flexbox
              direction="row"
              height="auto"
              style={{alignItems: "flex-start", flexWrap: "wrap"}}>
              {this._renderThemeOptions()}
            </Flexbox>
          </div>
          <div className="create-theme">
            <a href="https://github.com/nylas/N1-theme-starter">Create a Theme</a>
          </div>
        </Flexbox>
      </div>
    );
  }
}

export default ThemePicker;
