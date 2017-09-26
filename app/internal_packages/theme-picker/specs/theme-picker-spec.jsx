import React from 'react';
import ReactDOM from 'react-dom';
import ReactTestUtils from 'react-dom/test-utils';

import Package from '../../../src/package';
import ThemePicker from '../lib/theme-picker';

const { resourcePath } = NylasEnv.getLoadSettings();
const light = new Package(`${resourcePath}/internal_packages/ui-light`);
const dark = new Package(`${resourcePath}/internal_packages/ui-dark`);

describe('ThemePicker', function themePicker() {
  beforeEach(() => {
    spyOn(NylasEnv.themes, 'getAvailableThemes').andReturn([light, dark]);
    spyOn(NylasEnv.themes, 'getActiveTheme').andReturn(light);
    this.component = ReactTestUtils.renderIntoDocument(<ThemePicker />);
  });

  it('changes the active theme when a theme is clicked', () => {
    spyOn(ThemePicker.prototype, '_setActiveTheme').andCallThrough();
    spyOn(ThemePicker.prototype, '_rewriteIFrame');
    const themeOption = ReactDOM.findDOMNode(
      ReactTestUtils.scryRenderedDOMComponentsWithClass(this.component, 'clickable-theme-option')[1]
    );
    ReactTestUtils.Simulate.mouseDown(themeOption);
    expect(ThemePicker.prototype._setActiveTheme).toHaveBeenCalled();
  });
});
