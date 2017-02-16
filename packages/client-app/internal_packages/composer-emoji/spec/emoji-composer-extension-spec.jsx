import React from 'react';
import ReactDOM from 'react-dom';
import ReactTestUtils from 'react-addons-test-utils';

import {renderIntoDocument} from '../../../spec/nylas-test-utils';
import Contenteditable from '../../../src/components/contenteditable/contenteditable';
import EmojiComposerExtension from '../lib/emoji-composer-extension';

describe('EmojiComposerExtension', function emojiComposerExtension() {
  beforeEach(() => {
    spyOn(EmojiComposerExtension, 'onContentChanged').andCallThrough()
    spyOn(EmojiComposerExtension, '_onSelectEmoji').andCallThrough()
    this.component = renderIntoDocument(
      <Contenteditable
        html={''}
        onChange={jasmine.createSpy('onChange')}
        extensions={[EmojiComposerExtension]}
      />
    )
    this.editableNode = ReactDOM.findDOMNode(this.component).querySelector('[contenteditable]');
  })

  describe('when emoji trigger is typed', () => {
    beforeEach(() => {
      this._performEdit = (newHTML) => {
        this.editableNode.innerHTML = newHTML;
        const sel = document.getSelection()
        const textNode = this.editableNode.childNodes[0];
        sel.setBaseAndExtent(textNode, textNode.nodeValue.length, textNode, textNode.nodeValue.length);
      }
    })

    it('should show the emoji picker', () => {
      this._performEdit('Testing! :h');
      waitsFor(() => {
        return ReactTestUtils.scryRenderedDOMComponentsWithClass(this.component, 'emoji-picker').length > 0
      });
    })

    it('should be focused on the first emoji in the list', () => {
      this._performEdit('Testing! :h');
      waitsFor(() => {
        return ReactTestUtils.scryRenderedDOMComponentsWithClass(this.component, 'emoji-option').length > 0
      });
      runs(() => {
        expect(ReactDOM.findDOMNode(ReactTestUtils.findRenderedDOMComponentWithClass(this.component, 'emoji-option')).textContent.indexOf(":haircut:") !== -1).toBe(true);
      });
    })

    it('should insert an emoji on enter', () => {
      this._performEdit('Testing! :h');
      waitsFor(() => {
        return ReactTestUtils.scryRenderedDOMComponentsWithClass(this.component, 'emoji-picker').length > 0
      });
      runs(() => {
        ReactTestUtils.Simulate.keyDown(this.editableNode, {key: "Enter", keyCode: 13, which: 13});
      });
      waitsFor(() => {
        return EmojiComposerExtension._onSelectEmoji.calls.length > 0
      })
      runs(() => {
        expect(this.editableNode.innerHTML).toContain("emoji haircut")
      });
    })

    it('should insert an emoji on click', () => {
      this._performEdit('Testing! :h');
      waitsFor(() => {
        return ReactTestUtils.scryRenderedDOMComponentsWithClass(this.component, 'emoji-picker').length > 0
      });
      runs(() => {
        const button = ReactDOM.findDOMNode(ReactTestUtils.findRenderedDOMComponentWithClass(this.component, 'emoji-option'))
        ReactTestUtils.Simulate.mouseDown(button);
        expect(EmojiComposerExtension._onSelectEmoji).toHaveBeenCalled()
      });
      waitsFor(() => {
        return EmojiComposerExtension._onSelectEmoji.calls.length > 0
      })
      runs(() => {
        expect(this.editableNode.innerHTML).toContain("emoji haircut")
      });
    })

    it('should move to the next emoji on arrow down', () => {
      this._performEdit('Testing! :h');
      waitsFor(() => {
        return ReactTestUtils.scryRenderedDOMComponentsWithClass(this.component, 'emoji-option').length > 0
      });
      runs(() => {
        ReactTestUtils.Simulate.keyDown(this.editableNode, {key: "ArrowDown", keyCode: 40, which: 40});
      });
      waitsFor(() => {
        return EmojiComposerExtension.onContentChanged.calls.length > 1
      });
      runs(() => {
        expect(ReactDOM.findDOMNode(ReactTestUtils.findRenderedDOMComponentWithClass(this.component, 'emoji-option')).textContent.indexOf(":hamburger:") !== -1).toBe(true);
      });
    })
  })
})
