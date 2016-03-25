import React, {addons} from 'react/addons';
import {renderIntoDocument} from '../../../spec/nylas-test-utils';
import Contenteditable from '../../../src/components/contenteditable/contenteditable';
import EmojiComposerExtension from '../lib/emoji-composer-extension';

const ReactTestUtils = addons.TestUtils;

describe('EmojiComposerExtension', ()=> {
  beforeEach(()=> {
    spyOn(EmojiComposerExtension, 'onContentChanged').andCallThrough()
    spyOn(EmojiComposerExtension, '_onSelectEmoji').andCallThrough()
    const html = 'Testing!'
    const onChange = jasmine.createSpy('onChange')
    this.component = renderIntoDocument(
      <Contenteditable html={html} onChange={onChange} extensions={[EmojiComposerExtension]}/>
    )
    this.editableNode = React.findDOMNode(ReactTestUtils.findRenderedDOMComponentWithAttr(this.component, 'contentEditable'));
  })

  describe('when emoji trigger is typed', ()=> {
    beforeEach(()=> {
      this._performEdit = (newHTML) => {
        this.editableNode.innerHTML = newHTML;
        const sel = document.getSelection()
        const textNode = this.editableNode.childNodes[0];
        sel.setBaseAndExtent(textNode, textNode.nodeValue.length, textNode, textNode.nodeValue.length);
      }
    })

    it('should show the emoji picker', ()=> {
      runs(()=> {
        this._performEdit('Testing! :h');
      });
      waitsFor(()=> {
        return ReactTestUtils.scryRenderedDOMComponentsWithClass(this.component, 'emoji-picker').length > 0
      });
    })

    it('should be focused on the first emoji in the list', ()=> {
      runs(()=> {
        this._performEdit('Testing! :h');
      });
      waitsFor(()=> {
        return ReactTestUtils.scryRenderedDOMComponentsWithClass(this.component, 'emoji-option').length > 0
      });
      runs(()=> {
        expect(React.findDOMNode(ReactTestUtils.findRenderedDOMComponentWithClass(this.component, 'emoji-option')).textContent === "💇 :haircut:").toBe(true);
      });
    })

    it('should insert an emoji on enter', ()=> {
      runs(()=> {
        this._performEdit('Testing! :h');
      });
      waitsFor(()=> {
        return ReactTestUtils.scryRenderedDOMComponentsWithClass(this.component, 'emoji-picker').length > 0
      });
      runs(()=> {
        ReactTestUtils.Simulate.keyDown(this.editableNode, {key: "Enter", keyCode: 13, which: 13});
      });
      waitsFor(()=> {
        return EmojiComposerExtension._onSelectEmoji.calls.length > 0
      })
      runs(()=> {
        expect(this.editableNode.textContent === "Testing! 💇").toBe(true);
      });
    })

    it('should insert an emoji on click', ()=> {
      runs(()=> {
        this._performEdit('Testing! :h');
      });
      waitsFor(()=> {
        return ReactTestUtils.scryRenderedDOMComponentsWithClass(this.component, 'emoji-picker').length > 0
      });
      runs(()=> {
        const button = React.findDOMNode(ReactTestUtils.findRenderedDOMComponentWithClass(this.component, 'emoji-option'))
        ReactTestUtils.Simulate.mouseDown(button);
        expect(EmojiComposerExtension._onSelectEmoji).toHaveBeenCalled()
      });
      waitsFor(()=> {
        return EmojiComposerExtension._onSelectEmoji.calls.length > 0
      })
      runs(()=> {
        expect(this.editableNode.textContent).toEqual("Testing! 💇");
      });
    })

    it('should move to the next emoji on arrow down', ()=> {
      runs(()=> {
        this._performEdit('Testing! :h');
      });
      waitsFor(()=> {
        return ReactTestUtils.scryRenderedDOMComponentsWithClass(this.component, 'emoji-option').length > 0
      });
      runs(()=> {
        ReactTestUtils.Simulate.keyDown(this.editableNode, {key: "ArrowDown", keyCode: 40, which: 40});
      });
      waitsFor(()=> {
        return EmojiComposerExtension.onContentChanged.calls.length > 1
      });
      runs(()=> {
        expect(React.findDOMNode(ReactTestUtils.findRenderedDOMComponentWithClass(this.component, 'emoji-option')).textContent).toEqual("🍔 :hamburger:");
      });
    })

    it('should be able to insert two emoji next to each other', ()=> {
      runs(()=> {
        this._performEdit('Testing! 🍔 :h');
      });
      waitsFor(()=> {
        return ReactTestUtils.scryRenderedDOMComponentsWithClass(this.component, 'emoji-picker').length > 0
      });
    })
  })
})
