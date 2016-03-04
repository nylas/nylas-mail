import React from 'react';
const ReactTestUtils = React.addons.TestUtils;

import ThemePackage from '../../../src/theme-package';
import ThemePicker from '../lib/theme-picker';

const {resourcePath} = NylasEnv.getLoadSettings();
const light = new ThemePackage(resourcePath + '/internal_packages/ui-light');
const dark = new ThemePackage(resourcePath + '/internal_packages/ui-dark');

describe('ThemePicker', ()=> {
  beforeEach(()=> {
    spyOn(ThemePicker.prototype, '_setActiveTheme').andCallThrough();
    spyOn(NylasEnv.themes, 'getLoadedThemes').andReturn([light, dark]);
    spyOn(NylasEnv.themes, 'getActiveTheme').andReturn(light);
    this.component = ReactTestUtils.renderIntoDocument(<ThemePicker />);
  });

  it('changes the active theme when a theme is clicked', ()=> {
    const themeOption = React.findDOMNode(ReactTestUtils.scryRenderedDOMComponentsWithClass(this.component, 'clickable-theme-option')[1]);
    ReactTestUtils.Simulate.mouseDown(themeOption);
    expect(ThemePicker.prototype._setActiveTheme).toHaveBeenCalled();
  });
});
