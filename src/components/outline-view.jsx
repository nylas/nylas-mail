import React, {Component, PropTypes} from 'react';
import RetinaImg from './retina-img';
import OutlineViewItem from './outline-view-item';


/**
 * Renders a section that contains a list of {@link OutlineViewItem}s. These items can
 * be arbitrarily nested. See docs for {@link OutlineViewItem}.
 * An OutlineView behaves like a controlled React component, with callbacks for
 * collapsing and creating items, and respective props for their value. Is it up
 * to the parent component to determine the state of the OutlineView.
 *
 * This component resembles OS X's default OutlineView or Sourcelist
 *
 * OutlineView supports:
 * - Collapsing and uncollapsing
 * - Adding new items to the outline view
 *
 * @param {object} props - props for OutlineView
 * @param {string} props.title - Title to display
 * @param {string} props.iconName - Icon name to use when displaying input to
 * add a new item. See {@link RetinaImg} for further reference.
 * @param {array} props.items - Array of strings or numbers to display as {@link
 * OutlineViewItem}s
 * @param {boolean} props.collapsed - Whether the OutlineView is collapsed or
 * not
 * @param {props.onItemCreated} props.onItemCreated
 * @param {props.onCollapseToggled} props.onCollapseToggled
 * @class OutlineView
 */
class OutlineView extends Component {
  static displayName = 'OutlineView'

  /**
   * If provided, this function will be called when an item has been created.
   * @callback props.onItemCreated
   * @param {string} value - The value for the created item
   */
  /**
   * If provided, this function will be called when the user clicks the action
   * to collapse or uncollapse the OutlineView
   * @callback props.onCollapseToggled
   * @param {object} props - The entire props object for this OutlineView
   */
  static propTypes = {
    title: PropTypes.string,
    iconName: PropTypes.string,
    items: PropTypes.array,
    collapsed: PropTypes.bool,
    onItemCreated: PropTypes.func,
    onCollapseToggled: PropTypes.func,
  }

  static defaultProps = {
    title: '',
    items: [],
  }

  state = {
    showCreateInput: false,
  }


  // Handlers

  _onCreateButtonMouseDown = ()=> {
    this._clickingCreateButton = true;
  }

  _onCreateButtonClicked = ()=> {
    this._clickingCreateButton = false;
    this.setState({showCreateInput: !this.state.showCreateInput});
  }

  _onCollapseToggled = ()=> {
    if (this.props.onCollapseToggled) {
      this.props.onCollapseToggled(this.props);
    }
  }

  _onItemCreated = (item, value)=> {
    this.setState({showCreateInput: false});
    this.props.onItemCreated(value)
  }

  _onCreateInputCleared = ()=> {
    if (!this._clickingCreateButton) {
      this.setState({showCreateInput: false});
    }
  }


  // Renderers

  _renderCreateInput(props = this.props) {
    const item = {
      id: `add-item-${props.title}`,
      name: '',
      children: [],
      editing: true,
      iconName: props.iconName,
      onEdited: this._onItemCreated,
      inputPlaceholder: 'Create new item',
      onInputCleared: this._onCreateInputCleared,
    }
    return <OutlineViewItem item={item} />;
  }

  _renderCreateButton() {
    const title = this.props.title;
    return (
      <span
        className="add-item-button"
        onMouseDown={this._onCreateButtonMouseDown}
        onMouseUp={this._onCreateButtonClicked.bind(this, title)}>
        <RetinaImg
          url="nylas://account-sidebar/assets/icon-sidebar-addcategory@2x.png"
          style={{height: 14, width: 14}}
          mode={RetinaImg.Mode.ContentIsMask} />
      </span>
    );
  }

  _renderHeading(allowCreate, collapsed, collapsible) {
    const collapseLabel = collapsed ? 'Show' : 'Hide';
    return (
      <div className="heading">
        {this.props.title}
        {allowCreate ? this._renderCreateButton() : void 0}
        {collapsible ?
          <span
            className="collapse-button"
            onClick={this._onCollapseToggled}>
            {collapseLabel}
          </span>
          : void 0
        }
      </div>
    );
  }

  _renderItems() {
    return this.props.items.map(item => (
      <OutlineViewItem key={item.id} item={item} />
    ));
  }

  _renderOutline(allowCreate, collapsed) {
    if (collapsed) {
      return <span />;
    }

    const showInput = allowCreate && this.state.showCreateInput;
    return (
      <div>
        {showInput ? this._renderCreateInput() : void 0}
        {this._renderItems()}
      </div>
    );
  }

  render() {
    const collapsible = this.props.onCollapseToggled;
    const collapsed = this.props.collapsed;
    const allowCreate = this.props.onItemCreated != null && !collapsed;

    return (
      <section className="nylas-outline-view">
        {this._renderHeading(allowCreate, collapsed, collapsible)}
        {this._renderOutline(allowCreate, collapsed)}
      </section>
    );
  }
}

export default OutlineView;
