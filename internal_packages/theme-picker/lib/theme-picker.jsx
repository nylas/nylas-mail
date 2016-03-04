import React from 'react';
import Actions from '../../../src/flux/actions'

import {Flexbox, RetinaImg} from 'nylas-component-kit';
import ThemeOption from './theme-option';


class ThemePicker extends React.Component {
  static displayName = 'ThemePicker';

  constructor(props) {
    super(props);
    this._themeManager = NylasEnv.themes;
    this.state = this._getState();
  }

  componentDidMount() {
    this.disposable = this._themeManager.onDidChangeActiveThemes(() => {
      this.setState(this._getState());
    });
  }

  componentWillUnmount() {
    this.disposable.dispose();
  }

  _getState() {
    return {
      themes: this._themeManager.getLoadedThemes(),
      activeTheme: this._themeManager.getActiveTheme().name,
    }
  }

  _setActiveTheme(theme) {
    const prevActiveTheme = this.state.activeTheme;
    this.setState({activeTheme: theme});
    this._themeManager.setActiveTheme(theme);
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
    const themeOptions = this.state.themes.map((theme) =>
        <div
          className="clickable-theme-option"
          onMouseDown={() => this._setActiveTheme(theme.name)}
          style={{cursor: "pointer", width: "115px", margin: "2px"}}>
          <ThemeOption
            key={theme.name}
            theme={theme}
            active={this.state.activeTheme === theme.name} />
        </div>
      )
    return themeOptions;
  }

  render() {
    return (
      <div style={{textAlign: "center", cursor: "default"}}>
        <Flexbox direction="column">
          <RetinaImg
            style={{width: "14", height: "14", margin: "8px"}}
            name="picker-close.png"
            mode={RetinaImg.Mode.ContentDark}
            onMouseDown={() => Actions.closeModal()} />
          <h4 style={{color: "#313435"}}>Themes</h4>
          <div style={{color: "rgba(35, 31, 32, 0.5)"}}>Click any theme to preview.</div>
          <div style={{margin: "10px 5px 0 5px", height: "300px", overflow: "auto"}}>
            <Flexbox
              direction="row"
              height="auto"
              style={{alignItems: "flex-start", flexWrap: "wrap"}}>
              {this._renderThemeOptions()}
            </Flexbox>
          </div>
        </Flexbox>
      </div>
    );
  }
}

export default ThemePicker;
