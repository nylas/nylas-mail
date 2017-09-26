import React from 'react';
import ReactDOM from 'react-dom';
import {
  findRenderedDOMComponentWithClass,
  scryRenderedDOMComponentsWithClass,
  Simulate,
} from 'react-dom/test-utils';

import EditableList from '../../src/components/editable-list';
import { renderIntoDocument, simulateCommand } from '../mailspring-test-utils';

const { findDOMNode } = ReactDOM;

const makeList = (items = [], props = {}) => {
  const list = renderIntoDocument(<EditableList {...props} items={items} />);
  if (props.initialState) {
    list.setState(props.initialState);
  }
  return list;
};

describe('EditableList', function editableList() {
  describe('_onItemClick', () => {
    it('calls onSelectItem', () => {
      const onSelectItem = jasmine.createSpy('onSelectItem');
      const list = makeList(['1', '2'], { onSelectItem });
      const item = scryRenderedDOMComponentsWithClass(list, 'editable-item')[0];

      Simulate.click(item);

      expect(onSelectItem).toHaveBeenCalledWith('1', 0);
    });
  });

  describe('_onItemEdit', () => {
    it('enters editing mode when double click', () => {
      const list = makeList(['1', '2']);
      spyOn(list, 'setState');
      const item = scryRenderedDOMComponentsWithClass(list, 'editable-item')[0];

      Simulate.doubleClick(item);

      expect(list.setState).toHaveBeenCalledWith({ editingIndex: 0 });
    });

    it('enters editing mode when edit icon clicked', () => {
      const list = makeList(['1', '2']);
      spyOn(list, 'setState');
      const editIcon = scryRenderedDOMComponentsWithClass(list, 'edit-icon')[0];

      Simulate.click(editIcon);

      expect(list.setState).toHaveBeenCalledWith({ editingIndex: 0 });
    });
  });

  describe('core:previous-item / core:next-item', () => {
    it('calls onSelectItem', () => {
      const onSelectItem = jasmine.createSpy('onSelectItem');
      const list = makeList(['1', '2'], { selected: '1', onSelectItem });
      const innerList = findRenderedDOMComponentWithClass(list, 'items-wrapper');

      simulateCommand(innerList, 'core:next-item');

      expect(onSelectItem).toHaveBeenCalledWith('2', 1);
    });

    it('does not select an item when at the bottom of the list and moves down', () => {
      const onSelectItem = jasmine.createSpy('onSelectItem');
      const list = makeList(['1', '2'], { selected: '2', onSelectItem });
      const innerList = findRenderedDOMComponentWithClass(list, 'items-wrapper');

      simulateCommand(innerList, 'core:next-item');

      expect(onSelectItem).not.toHaveBeenCalled();
    });

    it('does not select an item when at the top of the list and moves up', () => {
      const onSelectItem = jasmine.createSpy('onSelectItem');
      const list = makeList(['1', '2'], { selected: '1', onSelectItem });
      const innerList = findRenderedDOMComponentWithClass(list, 'items-wrapper');

      simulateCommand(innerList, 'core:previous-item');

      expect(onSelectItem).not.toHaveBeenCalled();
    });

    it('does not clear the selection when esc pressed but prop does not allow it', () => {
      const onSelectItem = jasmine.createSpy('onSelectItem');
      const list = makeList(['1', '2'], {
        selected: '1',
        allowEmptySelection: false,
        onSelectItem,
      });
      const innerList = findRenderedDOMComponentWithClass(list, 'items-wrapper');

      Simulate.keyDown(innerList, { key: 'Escape' });

      expect(onSelectItem).not.toHaveBeenCalled();
    });
  });

  describe('_onCreateInputKeyDown', () => {
    it('calls onItemCreated', () => {
      const onItemCreated = jasmine.createSpy('onItemCreated');
      const list = makeList(['1', '2'], { initialState: { creatingItem: true }, onItemCreated });
      const createItem = findRenderedDOMComponentWithClass(list, 'create-item-input');
      const input = createItem.querySelector('input');
      findDOMNode(input).value = 'New Item';

      Simulate.keyDown(input, { key: 'Enter' });

      expect(onItemCreated).toHaveBeenCalledWith('New Item');
    });

    it('does not call onItemCreated when no value entered', () => {
      const onItemCreated = jasmine.createSpy('onItemCreated');
      const list = makeList(['1', '2'], { initialState: { creatingItem: true }, onItemCreated });
      const createItem = findRenderedDOMComponentWithClass(list, 'create-item-input');
      const input = createItem.querySelector('input');
      findDOMNode(input).value = '';

      Simulate.keyDown(input, { key: 'Enter' });

      expect(onItemCreated).not.toHaveBeenCalled();
    });
  });

  describe('_onCreateItem', () => {
    it('should call prop callback when provided', () => {
      const onCreateItem = jasmine.createSpy('onCreateItem');
      const list = makeList(['1', '2'], { onCreateItem });

      list._onCreateItem();
      expect(onCreateItem).toHaveBeenCalled();
    });

    it('should set state for creating item when no callback provided', () => {
      const list = makeList(['1', '2']);
      spyOn(list, 'setState');
      list._onCreateItem();
      expect(list.setState).toHaveBeenCalledWith({ creatingItem: true });
    });
  });

  describe('_onDeleteItem', () => {
    let onSelectItem;
    let onDeleteItem;
    beforeEach(() => {
      onSelectItem = jasmine.createSpy('onSelectItem');
      onDeleteItem = jasmine.createSpy('onDeleteItem');
    });
    it('deletes the item from the list', () => {
      const list = makeList(['1', '2'], { selected: '2', onDeleteItem, onSelectItem });
      const button = scryRenderedDOMComponentsWithClass(list, 'btn-editable-list')[1];

      Simulate.click(button);
      expect(onDeleteItem).toHaveBeenCalledWith('2', 1);
    });
    it('sets the selected item to the one above if it exists', () => {
      const list = makeList(['1', '2'], { selected: '2', onDeleteItem, onSelectItem });
      const button = scryRenderedDOMComponentsWithClass(list, 'btn-editable-list')[1];

      Simulate.click(button);
      expect(onSelectItem).toHaveBeenCalledWith('1', 0);
    });
    it('sets the selected item to the one below if it is at the top', () => {
      const list = makeList(['1', '2'], { selected: '1', onDeleteItem, onSelectItem });
      const button = scryRenderedDOMComponentsWithClass(list, 'btn-editable-list')[1];

      Simulate.click(button);
      expect(onSelectItem).toHaveBeenCalledWith('2', 1);
    });
    it('sets the selected item to nothing when you delete the last item', () => {
      const list = makeList(['1'], { selected: '1', onDeleteItem, onSelectItem });
      const button = scryRenderedDOMComponentsWithClass(list, 'btn-editable-list')[1];

      Simulate.click(button);
      expect(onSelectItem).not.toHaveBeenCalled();
    });
  });
  describe('_renderItem', () => {
    const makeItem = (item, idx, state = {}, handlers = {}) => {
      const list = makeList([], { initialState: state });
      return renderIntoDocument(list._renderItem(item, idx, state, handlers));
    };

    it('binds correct click callbacks', () => {
      const onClick = jasmine.createSpy('onClick');
      const onEdit = jasmine.createSpy('onEdit');
      const item = makeItem('item 1', 0, {}, { onClick, onEdit });

      Simulate.click(item);
      expect(onClick.calls[0].args[1]).toEqual('item 1');
      expect(onClick.calls[0].args[2]).toEqual(0);

      Simulate.doubleClick(item);
      expect(onEdit.calls[0].args[1]).toEqual('item 1');
      expect(onEdit.calls[0].args[2]).toEqual(0);
    });

    it('renders correctly when item is selected', () => {
      const item = findDOMNode(makeItem('item 1', 0, { selected: 'item 1' }));
      expect(item.className.indexOf('selected')).not.toEqual(-1);
    });

    it('renders correctly when item is string', () => {
      const item = findDOMNode(makeItem('item 1', 0));
      expect(item.className.indexOf('selected')).toEqual(-1);
      expect(item.className.indexOf('editable-item')).not.toEqual(-1);
      expect(item.innerText).toEqual('item 1');
    });

    it('renders correctly when item is component', () => {
      const item = findDOMNode(makeItem(<div />, 0));
      expect(item.className.indexOf('selected')).toEqual(-1);
      expect(item.className.indexOf('editable-item')).toEqual(-1);
      expect(item.childNodes[0].tagName).toEqual('DIV');
    });

    it('renders correctly when item is in editing state', () => {
      const onInputBlur = jasmine.createSpy('onInputBlur');
      const onInputFocus = jasmine.createSpy('onInputFocus');
      const onInputKeyDown = jasmine.createSpy('onInputKeyDown');

      const item = makeItem(
        'item 1',
        0,
        { editingIndex: 0 },
        { onInputBlur, onInputFocus, onInputKeyDown }
      );
      const input = item.querySelector('input');

      Simulate.focus(input);
      Simulate.keyDown(input);
      Simulate.blur(input);

      expect(onInputFocus).toHaveBeenCalled();
      expect(onInputBlur).toHaveBeenCalled();
      expect(onInputKeyDown.calls[0].args[1]).toEqual('item 1');
      expect(onInputKeyDown.calls[0].args[2]).toEqual(0);

      expect(findDOMNode(input).tagName).toEqual('INPUT');
    });
  });

  describe('render', () => {
    it('renders list of items', () => {
      const items = ['1', '2', '3'];
      const list = makeList(items);
      const innerList = findDOMNode(
        findRenderedDOMComponentWithClass(list, 'scroll-region-content-inner')
      );
      expect(() => {
        findRenderedDOMComponentWithClass(list, 'create-item-input');
      }).toThrow();

      expect(innerList.childNodes.length).toEqual(3);
      items.forEach((item, idx) => expect(innerList.childNodes[idx].textContent).toEqual(item));
    });

    it('renders create input as an item when creating', () => {
      const items = ['1', '2', '3'];
      const list = makeList(items, { initialState: { creatingItem: true } });
      const createItem = findRenderedDOMComponentWithClass(list, 'create-item-input');
      expect(createItem).toBeDefined();
    });

    it('renders add button', () => {
      const list = makeList();
      const button = scryRenderedDOMComponentsWithClass(list, 'btn-editable-list')[0];

      expect(findDOMNode(button).textContent).toEqual('+');
    });

    it('renders delete button', () => {
      const list = makeList(['1', '2'], { selected: '2' });
      const button = scryRenderedDOMComponentsWithClass(list, 'btn-editable-list')[1];

      expect(findDOMNode(button).textContent).toEqual('—');
    });

    it('disables the delete button when no item is selected', () => {
      const onSelectItem = jasmine.createSpy('onSelectItem');
      const onDeleteItem = jasmine.createSpy('onDeleteItem');
      const list = makeList(['1', '2'], { selected: null, onDeleteItem, onSelectItem });
      const button = scryRenderedDOMComponentsWithClass(list, 'btn-editable-list')[1];

      Simulate.click(button);

      expect(onDeleteItem).not.toHaveBeenCalledWith('2', 1);
    });
  });
});
