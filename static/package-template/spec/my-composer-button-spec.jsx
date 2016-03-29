import {React, ReactDOM} from 'nylas-exports';
const ReactTestUtils = require('react-addons-test-utils')

import MyComposerButton from '../lib/my-composer-button';

describe("MyComposerButton", () => {
  beforeEach(() => {
    this.component = ReactTestUtils.renderIntoDocument(
      <MyComposerButton draftClientId="test" />
    );
  });

  it("should render into the page", () => {
    expect(this.component).toBeDefined();
  });

  it("should have a displayName", () => {
    expect(MyComposerButton.displayName).toBe('MyComposerButton');
  });

  it("should show a dialog box when clicked", () => {
    spyOn(this.component, '_onClick');
    const buttonNode = ReactDOM.findDOMNode(this.component.refs.button);
    ReactTestUtils.Simulate.click(buttonNode);
    expect(this.component._onClick).toHaveBeenCalled();
  });
});
