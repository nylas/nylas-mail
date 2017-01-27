import React, {Component, PropTypes} from 'react';
import {ButtonDropdown, Menu} from 'nylas-component-kit'
import ReactDOM from 'react-dom';

/*
Renders a drop down of items that can have multiple selected
Item can be string or object

@param {object} props - props for MultiselectDropdown
@param {string} props.className - css class applied to the component
@param {array} props.items - items to be rendered in the dropdown
@param {props.itemChecked} - props.itemChecked -- a function to determine if the item should be checked or not
@param {props.onToggleItem} - props.onToggleItem -- function called when an item is clicked
@param {props.itemKey} - props.itemKey -- function that indicates how to select the key for each MenuItem
@param {props.buttonText} - props.buttonText -- string to be rendered in the button
**/

class MultiselectDropdown extends Component {
  static displayName = 'MultiselectDropdown'

  static propTypes = {
    className: PropTypes.string,
    items: PropTypes.array.isRequired,
    itemChecked: PropTypes.func,
    onToggleItem: PropTypes.func,
    itemKey: PropTypes.func,
    buttonText: PropTypes.string,
    itemContent: PropTypes.func,
  }

  static defaultProps = {
    className: '',
    items: [],
    itemChecked: {},
    onToggleItem: () => {},
    itemKey: () => {},
    buttonText: '',
    itemContent: () => {},
  }

  componentDidUpdate() {
    if (ReactDOM.findDOMNode(this.refs.select)) {
      ReactDOM.findDOMNode(this.refs.select).focus()
    }
  }


  _onItemClick = (item) => {
    this.props.onToggleItem(item)
  }

  _renderItem = (item) => {
    const MenuItem = Menu.Item
    return (
      <MenuItem onMouseDown={() => this._onItemClick(item)} checked={this.props.itemChecked(item)} key={this.props.itemKey(item)} content={this.props.itemContent(item)} />
    )
  }


  _renderMenu= (items) => {
    return (
      <Menu
        items={items}
        itemContent={this._renderItem}
        itemKey={item => item.id}
        onSelect={() => {}}
      />
    )
  }

  render() {
    const {items} = this.props
    const menu = this._renderMenu(items)
    return (
      <ButtonDropdown
        className={'btn-multiselect'}
        primaryItem={<span>{this.props.buttonText}</span>}
        menu={menu}
      />
    )
  }
}
export default MultiselectDropdown
