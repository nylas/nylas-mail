import _ from 'underscore';
import _str from 'underscore.string';
import React, {Component, PropTypes} from 'react';
import DisclosureTriangle from './disclosure-triangle';
import RetinaImg from './retina-img';
import OutlineViewItem from './outline-view-item';


// TODO Docs
class OutlineView extends Component {
  static displayName = 'OutlineView'

  static propTypes = {
    title: PropTypes.string,
    iconName: PropTypes.string,
    items: PropTypes.array,
    collapsed: PropTypes.bool,
    onCreateItem: PropTypes.func,
    onToggleCollapsed: PropTypes.func,
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

  _onInputBlur = ()=> {
    if (!this._clickingCreateButton) {
      this.setState({showCreateInput: false});
    }
  }

  _onInputKeyDown = (event)=> {
    if (event.key === 'Escape') {
      this.setState({showCreateInput: false});
    }
    if (_.includes(['Enter', 'Return'], event.key)) {
      this.props.onCreateItem(event.target.value);
      this.setState({showCreateInput: false});
    }
  }

  _onToggleCollapsed = ()=> {
    if (this.props.onToggleCollapsed) {
      this.props.onToggleCollapsed(this.props);
    }
  }


  // Renderers

  _renderCreateInput(props = this.props) {
    const title = _str.decapitalize(props.title.slice(0, props.title.length - 1));
    const placeholder = `Create new ${title}`;
    return (
      <span className="item-container">
        <div className="item add-item-container">
          <DisclosureTriangle collapsed={false} visible={false} />
          <div className="icon">
            <RetinaImg
              name={props.iconName}
              fallback="folder.png"
              mode={RetinaImg.Mode.ContentIsMask} />
          </div>
          <input
            autoFocus
            type="text"
            tabIndex="1"
            className="add-item-input"
            onKeyDown={this._onInputKeyDown}
            onBlur={this._onInputBlur}
            placeholder={placeholder}/>
        </div>
      </span>
    );
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
            onClick={this._onToggleCollapsed}>
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
    const collapsible = this.props.onToggleCollapsed;
    const collapsed = this.props.collapsed;
    const allowCreate = this.props.onCreateItem != null && !collapsed;

    return (
      <section className="nylas-outline-view">
        {this._renderHeading(allowCreate, collapsed, collapsible)}
        {this._renderOutline(allowCreate, collapsed)}
      </section>
    );
  }
}

export default OutlineView;
