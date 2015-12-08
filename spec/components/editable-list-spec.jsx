import React, {addons} from 'react/addons';
import EditableList from '../../src/components/editable-list';

const {findDOMNode} = React;
const {TestUtils: {
  renderIntoDocument,
  findRenderedDOMComponentWithTag,
  findRenderedDOMComponentWithClass,
  scryRenderedDOMComponentsWithClass,
  Simulate,
}} = addons;
const makeList = (items = [], props = {})=> {
  return renderIntoDocument(<EditableList {...props}>{items}</EditableList>);
};

describe('EditableList', ()=> {
  describe('_onItemClick', ()=> {
    it('calls onItemSelected', ()=> {
      const onItemSelected = jasmine.createSpy('onItemSelected');
      const list = makeList(['1', '2'], {onItemSelected});
      const item = scryRenderedDOMComponentsWithClass(list, 'editable-item')[0];

      Simulate.click(item);

      expect(onItemSelected).toHaveBeenCalledWith('1', 0);
    });
  });

  describe('_onListKeyDown', ()=> {
    it('calls onItemSelected', ()=> {
      const onItemSelected = jasmine.createSpy('onItemSelected');
      const list = makeList(['1', '2'], {initialState: {selected: 0}, onItemSelected});
      const innerList = findRenderedDOMComponentWithClass(list, 'items-wrapper');

      Simulate.keyDown(innerList, {key: 'ArrowDown'});

      expect(onItemSelected).toHaveBeenCalledWith('2', 1);
    });
  });

  describe('_onCreateInputKeyDown', ()=> {
    it('calls onItemCreated', ()=> {
      const onItemCreated = jasmine.createSpy('onItemCreated');
      const list = makeList(['1', '2'], {initialState: {creatingItem: true}, onItemCreated});
      const createItem = findRenderedDOMComponentWithClass(list, 'create-item-input');
      const input = findRenderedDOMComponentWithTag(createItem, 'input');
      findDOMNode(input).value = 'New Item';

      Simulate.keyDown(input, {key: 'Enter'});

      expect(onItemCreated).toHaveBeenCalledWith('New Item');
    });
  });

  describe('_onCreateItem', ()=> {
    it('should call prop callback when provided', ()=> {
      const onCreateItem = jasmine.createSpy('onCreateItem');
      const list = makeList(['1', '2'], {onCreateItem});

      list._onCreateItem();
      expect(onCreateItem).toHaveBeenCalled();
    });

    it('should set state for creating item when no callback provided', ()=> {
      const list = makeList(['1', '2']);
      spyOn(list, 'setState');
      list._onCreateItem();
      expect(list.setState).toHaveBeenCalledWith({creatingItem: true});
    });
  });

  describe('_renderItem', ()=> {
    const makeItem = (item, idx, state = {}, handlers = {})=> {
      const list = makeList();
      return renderIntoDocument(
        list._renderItem(item, idx, state, handlers)
      );
    };

    it('binds correct click callbacks', ()=> {
      const onClick = jasmine.createSpy('onClick');
      const onDoubleClick = jasmine.createSpy('onDoubleClick');
      const item = makeItem('item 1', 0, {}, {onClick, onDoubleClick});

      Simulate.click(item);
      expect(onClick.calls[0].args[1]).toEqual('item 1');
      expect(onClick.calls[0].args[2]).toEqual(0);

      Simulate.doubleClick(item);
      expect(onDoubleClick.calls[0].args[1]).toEqual('item 1');
      expect(onDoubleClick.calls[0].args[2]).toEqual(0);
    });

    it('renders correctly when item is selected', ()=> {
      const item = findDOMNode(makeItem('item 1', 0, {selected: 0}));
      expect(item.className.indexOf('selected')).not.toEqual(-1);
    });

    it('renders correctly when item is string', ()=> {
      const item = findDOMNode(makeItem('item 1', 0));
      expect(item.className.indexOf('selected')).toEqual(-1);
      expect(item.className.indexOf('editable-item')).not.toEqual(-1);
      expect(item.className.indexOf('component-item')).toEqual(-1);
      expect(item.childNodes[0].textContent).toEqual('item 1');
    });

    it('renders correctly when item is component', ()=> {
      const item = findDOMNode(makeItem(<div></div>, 0));
      expect(item.className.indexOf('selected')).toEqual(-1);
      expect(item.className.indexOf('editable-item')).toEqual(-1);
      expect(item.className.indexOf('component-item')).not.toEqual(-1);
      expect(item.childNodes[0].tagName).toEqual('DIV');
    });

    it('renders correctly when item is in editing state', ()=> {
      const onInputBlur = jasmine.createSpy('onInputBlur');
      const onInputFocus = jasmine.createSpy('onInputFocus');
      const onInputKeyDown = jasmine.createSpy('onInputKeyDown');

      const item = makeItem('item 1', 0, {editing: 0}, {onInputBlur, onInputFocus, onInputKeyDown});
      const input = findRenderedDOMComponentWithTag(item, 'input');

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

  describe('render', ()=> {
    it('renders list of items', ()=> {
      const items = ['1', '2', '3'];
      const list = makeList(items);
      const innerList = findDOMNode(
        findRenderedDOMComponentWithClass(list, 'items-wrapper')
      );
      expect(()=> {
        findRenderedDOMComponentWithClass(list, 'create-item-input');
      }).toThrow();

      expect(innerList.childNodes.length).toEqual(3);
      items.forEach((item, idx)=> expect(innerList.childNodes[idx].textContent).toEqual(item));
    });

    it('renders create input as an item when creating', ()=> {
      const items = ['1', '2', '3'];
      const list = makeList(items, {initialState: {creatingItem: true}});
      const createItem = findRenderedDOMComponentWithClass(list, 'create-item-input');
      expect(createItem).toBeDefined();
    });

    it('renders add button', ()=> {
      const list = makeList();
      const button = scryRenderedDOMComponentsWithClass(list, 'btn-editable-list')[0];

      expect(findDOMNode(button).textContent).toEqual('+');
    });

    it('renders delete button', ()=> {
      const onDeleteItem = jasmine.createSpy('onDeleteItem');
      const list = makeList(['1', '2'], {initialState: {selected: 1}, onDeleteItem});
      const button = scryRenderedDOMComponentsWithClass(list, 'btn-editable-list')[1];

      Simulate.click(button);

      expect(findDOMNode(button).textContent).toEqual('—');
      expect(onDeleteItem).toHaveBeenCalledWith('2', 1);
    });
  });
});
