import React from 'react';
import ReactDOM from 'react-dom';
import PropTypes from 'prop-types';
import fs from 'fs-plus';
import path from 'path';

import { EventedIFrame } from 'mailspring-component-kit';
import LessCompileCache from '../../../src/less-compile-cache';

class ThemeOption extends React.Component {
  static propTypes = {
    theme: PropTypes.object.isRequired,
    active: PropTypes.bool.isRequired,
    onSelect: PropTypes.func.isRequired,
  };

  constructor(props) {
    super(props);
    this.lessCache = null;
  }

  componentDidMount() {
    this._writeContent();
  }

  _getImportPaths() {
    return [
      this.props.theme.getStylesheetsPath(),
      AppEnv.themes.getBaseTheme().getStylesheetsPath(),
    ];
  }

  _loadStylesheet(stylesheetPath) {
    if (path.extname(stylesheetPath) === '.less') {
      return this._loadLessStylesheet(stylesheetPath);
    }
    return fs.readFileSync(stylesheetPath, 'utf8');
  }

  _loadLessStylesheet(lessStylesheetPath) {
    const { configDirPath, resourcePath } = AppEnv.getLoadSettings();
    if (this.lessCache) {
      this.lessCache.setImportPaths(this._getImportPaths());
    } else {
      const importPaths = this._getImportPaths();
      this.lessCache = new LessCompileCache({ configDirPath, resourcePath, importPaths });
    }
    const themeVarPath = path.relative(
      `${resourcePath}/internal_packages/theme-picker/preview-styles`,
      this.props.theme.getStylesheetsPath()
    );
    let varImports = `@import "../../../static/base/ui-variables";`;
    if (fs.existsSync(`${this.props.theme.getStylesheetsPath()}/ui-variables.less`)) {
      varImports += `@import "${themeVarPath}/ui-variables";`;
    }
    if (fs.existsSync(`${this.props.theme.getStylesheetsPath()}/theme-colors.less`)) {
      varImports += `@import "${themeVarPath}/theme-colors";`;
    }
    const less = fs.readFileSync(lessStylesheetPath, 'utf8');
    return this.lessCache.cssForFile(lessStylesheetPath, [varImports, less].join('\n'));
  }

  _writeContent() {
    const doc = ReactDOM.findDOMNode(this._iframeComponent).contentDocument;
    if (!doc) return;

    const { resourcePath } = AppEnv.getLoadSettings();
    const css = `<style>${this._loadStylesheet(
      `${resourcePath}/internal_packages/theme-picker/preview-styles/theme-option.less`
    )}</style>`;
    const html = `<!DOCTYPE html>
                  ${css}
                  <body>
                    <div class="theme-option active-${this.props.active}">
                      <div class="theme-name ">${this.props.theme.displayName}</div>
                      <div class="swatches" style="display:flex;flex-direction:row;">
                        <div class="swatch font-color"></div>
                        <div class="swatch active-color"></div>
                        <div class="swatch toolbar-color"></div>
                      </div>
                      <div class="divider-black"></div>
                      <div class="divider-white"></div>
                      <div class="strip"></div>
                    </div>
                  </body>`;

    doc.open();
    doc.write(html);
    doc.close();
  }

  render() {
    return (
      <div className="clickable-theme-option" onMouseDown={this.props.onSelect}>
        <EventedIFrame
          ref={cm => {
            this._iframeComponent = cm;
          }}
          className={`theme-preview-${this.props.theme.name.replace(/\./g, '-')}`}
          frameBorder="0"
          width="115px"
          height="70px"
        />
      </div>
    );
  }
}

export default ThemeOption;
