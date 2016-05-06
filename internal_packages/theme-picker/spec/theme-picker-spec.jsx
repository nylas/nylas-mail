import React from 'react';
import ReactDOM from 'react-dom';
import ReactTestUtils from 'react-addons-test-utils';

import ThemePackage from '../../../src/theme-package';
import ThemePicker from '../lib/theme-picker';

const {resourcePath} = NylasEnv.getLoadSettings();
const light = new ThemePackage(`${resourcePath}/internal_packages/ui-light`);
const dark = new ThemePackage(`${resourcePath}/internal_packages/ui-dark`);

describe('ThemePicker', function themePicker() {
  beforeEach(() => {
    spyOn(NylasEnv.themes, 'getLoadedThemes').andReturn([light, dark]);
    spyOn(NylasEnv.themes, 'getActiveTheme').andReturn(light);
    this.component = ReactTestUtils.renderIntoDocument(<ThemePicker />);
  });

  it('changes the active theme when a theme is clicked', () => {
    spyOn(ThemePicker.prototype, '_setActiveTheme').andCallThrough();
    spyOn(ThemePicker.prototype, '_rewriteIFrame');
    const themeOption = ReactDOM.findDOMNode(ReactTestUtils.scryRenderedDOMComponentsWithClass(this.component, 'clickable-theme-option')[1]);
    ReactTestUtils.Simulate.mouseDown(themeOption);
    expect(ThemePicker.prototype._setActiveTheme).toHaveBeenCalled();
  });
});
