import {React, ComponentRegistry, NylasTestUtils} from 'nylas-exports';
import {InjectedComponentSet} from 'nylas-component-kit';
const {renderIntoDocument} = NylasTestUtils;

const reactStub = (displayName)=> {
  return React.createClass({
    displayName,
    render() { return <div className={displayName}></div>; },
  });
};


describe('InjectedComponentSet', ()=> {
  describe('render', ()=> {
    beforeEach(()=> {
      const components = [reactStub('comp1'), reactStub('comp2')];
      spyOn(ComponentRegistry, 'findComponentsMatching').andReturn(components);
    });

    it('calls `onComponentsDidRender` when all child comps have actually been rendered to the dom', ()=> {
      let rendered;
      const onComponentsDidRender = ()=> {
        rendered = true;
      };
      runs(()=> {
        renderIntoDocument(
          <InjectedComponentSet
            matching={{}}
            onComponentsDidRender={onComponentsDidRender} />
        );
      });

      waitsFor(
        ()=> { return rendered; },
        '`onComponentsDidMount` should be called',
        100
      );

      runs(()=> {
        expect(rendered).toBe(true);
        expect(document.querySelectorAll('.comp1').length).toEqual(1);
        expect(document.querySelectorAll('.comp2').length).toEqual(1);
      });
    });
  });
});
