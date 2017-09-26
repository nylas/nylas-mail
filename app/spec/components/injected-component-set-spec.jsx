/* eslint react/prefer-es6-class: "off" */
/* eslint react/prefer-stateless-function: "off" */

import { React, ComponentRegistry, MailspringTestUtils } from 'mailspring-exports';
import { InjectedComponentSet } from 'mailspring-component-kit';

const { renderIntoDocument } = MailspringTestUtils;

const reactStub = displayName => {
  class StubWithName extends React.Component {
    static displayName = displayName;
    render() {
      return <div className={displayName} />;
    }
  }
  return StubWithName;
};

describe('InjectedComponentSet', function injectedComponentSet() {
  describe('render', () => {
    beforeEach(() => {
      const components = [reactStub('comp1'), reactStub('comp2')];
      spyOn(ComponentRegistry, 'findComponentsMatching').andReturn(components);
    });

    it('calls `onComponentsDidRender` when all child comps have actually been rendered to the dom', () => {
      let rendered;
      const onComponentsDidRender = () => {
        rendered = true;
      };
      runs(() => {
        renderIntoDocument(
          <InjectedComponentSet matching={{}} onComponentsDidRender={onComponentsDidRender} />
        );
      });

      waitsFor(
        () => {
          return rendered;
        },
        '`onComponentsDidMount` should be called',
        100
      );

      runs(() => {
        expect(rendered).toBe(true);
        expect(document.querySelectorAll('.comp1').length).toEqual(1);
        expect(document.querySelectorAll('.comp2').length).toEqual(1);
      });
    });
  });
});
