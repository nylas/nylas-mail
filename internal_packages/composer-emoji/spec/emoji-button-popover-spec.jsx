import React, {addons} from 'react/addons';
import {findDOMNode} from 'react-dom';
import {renderIntoDocument} from '../../../spec/nylas-test-utils';
import Contenteditable from '../../../src/components/contenteditable/contenteditable';
import EmojiButtonPopover from '../lib/emoji-button-popover';
import EmojiComposerExtension from '../lib/emoji-composer-extension';

const ReactTestUtils = addons.TestUtils;

describe('EmojiButtonPopover', ()=> {
  beforeEach(()=> {
    const position = {
      x: 20,
      y: 40,
    }
    spyOn(EmojiButtonPopover.prototype, 'calcPosition').andReturn(position);
    spyOn(EmojiComposerExtension, '_onSelectEmoji').andCallThrough();
    this.component = renderIntoDocument(<EmojiButtonPopover />);
    this.composer = renderIntoDocument(
      <Contenteditable
        html={'Testing!'}
        onChange={jasmine.createSpy('onChange')}
        extensions={[EmojiComposerExtension]} />
    );
    this.editableNode = findDOMNode(ReactTestUtils.findRenderedDOMComponentWithAttr(this.composer, 'contentEditable'));
    this.editableNode.innerHTML = "Testing!";
    const sel = document.getSelection()
    const textNode = this.editableNode.childNodes[0];
    sel.setBaseAndExtent(textNode, textNode.nodeValue.length, textNode, textNode.nodeValue.length);
    this.canvas = findDOMNode(ReactTestUtils.findRenderedDOMComponentWithTag(this.component, 'canvas'));
  });

  describe('when inserting emoji', ()=> {
    it('should insert emoji on click', ()=> {
      ReactTestUtils.Simulate.mouseDown(this.canvas);
      waitsFor(()=> {
        return EmojiComposerExtension._onSelectEmoji.calls.length > 0
      });
      expect(this.editableNode.textContent).toEqual("Testing!😀");
    });

    it('should insert an image for missing emoji', ()=> {
      const position = {
        x: 140,
        y: 60,
      }
      EmojiButtonPopover.prototype.calcPosition.andReturn(position);
      ReactTestUtils.Simulate.mouseDown(this.canvas);
      waitsFor(()=> {
        return EmojiComposerExtension._onSelectEmoji.calls.length > 0
      });
      expect(this.editableNode.innerHTML.indexOf("missing-emoji") > -1).toBe(true);
    });
  });

  describe('when searching for emoji', ()=> {
    it('should filter for matches', ()=> {
      this.searchNode = findDOMNode(ReactTestUtils.findRenderedDOMComponentWithClass(this.component, 'search'))
      const event = {
        target: {
          value: "heart",
        },
      }
      ReactTestUtils.Simulate.change(this.searchNode, event);
      ReactTestUtils.Simulate.mouseDown(this.canvas);
      waitsFor(()=> {
        return EmojiComposerExtension._onSelectEmoji.calls.length > 0
      });
      expect(this.editableNode.textContent).toEqual("Testing!😍");
    });
  });
});
