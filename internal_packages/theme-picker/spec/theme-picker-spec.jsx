import React from 'react';
const ReactTestUtils = React.addons.TestUtils;

import ThemePackage from '../../../src/theme-package';
import ThemePicker from '../lib/theme-picker';

const {resourcePath} = NylasEnv.getLoadSettings();
const light = new ThemePackage(resourcePath + '/internal_packages/ui-light');
const dark = new ThemePackage(resourcePath + '/internal_packages/ui-dark');
const thirdPartyTheme = new ThemePackage(resourcePath + '/internal_packages/ui-light');
thirdPartyTheme.name = 'third-party-theme'
thirdPartyTheme.path = ''

describe('ThemePicker', ()=> {
  beforeEach(()=> {
    spyOn(NylasEnv.themes, 'getLoadedThemes').andReturn([light, dark, thirdPartyTheme]);
    spyOn(NylasEnv.themes, 'getActiveTheme').andReturn(light);
    this.component = ReactTestUtils.renderIntoDocument(<ThemePicker />);
  });

  it('changes the active theme when a theme is clicked', ()=> {
    spyOn(ThemePicker.prototype, '_setActiveTheme').andCallThrough();
    spyOn(ThemePicker.prototype, '_rewriteIFrame');
    const themeOption = React.findDOMNode(ReactTestUtils.scryRenderedDOMComponentsWithClass(this.component, 'clickable-theme-option')[1]);
    ReactTestUtils.Simulate.mouseDown(themeOption);
    expect(ThemePicker.prototype._setActiveTheme).toHaveBeenCalled();
  });

  it('uninstalls themes on click', ()=> {
    spyOn(ThemePicker.prototype, '_onUninstallTheme').andCallThrough();
    spyOn(ThemePicker.prototype, 'setState').andCallThrough();
    const uninstallButton = React.findDOMNode(ReactTestUtils.scryRenderedDOMComponentsWithClass(this.component, 'theme-uninstall-x')[0]);
    ReactTestUtils.Simulate.mouseDown(uninstallButton);
    expect(ThemePicker.prototype._onUninstallTheme).toHaveBeenCalled();
    expect(ThemePicker.prototype.setState).toHaveBeenCalled();
  });
});
