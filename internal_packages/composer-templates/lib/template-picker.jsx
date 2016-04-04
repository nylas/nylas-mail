import {Actions, React, ReactDOM} from 'nylas-exports';
import {Menu, RetinaImg} from 'nylas-component-kit';
import TemplateStore from './template-store';

class TemplatePicker extends React.Component {
  static displayName = 'TemplatePicker';

  static propTypes = {
    draftClientId: React.PropTypes.string,
  };

  constructor() {
    super();
    this.state = {
      searchValue: '',
      templates: TemplateStore.items(),
    };
  }

  componentDidMount() {
    this.unsubscribe = TemplateStore.listen(this._onStoreChange.bind(this));
  }

  componentWillUnmount() {
    if (this.unsubscribe) this.unsubscribe();
  }

  _filteredTemplates(search = this.state.searchValue) {
    const items = TemplateStore.items();

    if (!search.length) { return items; }

    return items.filter((t)=> {
      return t.name.toLowerCase().indexOf(search.toLowerCase()) === 0;
    });
  }

  _onStoreChange() {
    return this.setState({
      templates: this._filteredTemplates(),
    });
  }

  _onSearchValueChange = () => {
    const newSearch = event.target.value;
    return this.setState({
      searchValue: newSearch,
      templates: this._filteredTemplates(newSearch),
    });
  };

  _onChooseTemplate = (template) => {
    Actions.insertTemplateId({templateId: template.id, draftClientId: this.props.draftClientId});
    Actions.closePopover()
  };

  _onManageTemplates = () => {
    Actions.showTemplates();
  };

  _onNewTemplate = () => {
    Actions.createTemplate({draftClientId: this.props.draftClientId});
  };

  _onClickButton = ()=> {
    const buttonRect = ReactDOM.findDOMNode(this).getBoundingClientRect()
    Actions.openPopover(
      this._renderPopover(),
      {originRect: buttonRect, direction: 'up'}
    )
  };

  _renderPopover() {
    const headerComponents = [
      <input
        type="text"
        tabIndex="1"
        key="textfield"
        className="search"
        value={this.state.searchValue}
        onChange={this._onSearchValueChange} />,
    ];

    const footerComponents = [
      <div className="item" key="new" onMouseDown={this._onNewTemplate}>Save Draft as Template...</div>,
      <div className="item" key="manage" onMouseDown={this._onManageTemplates}>Manage Templates...</div>,
    ];

    return (
      <Menu
        className="template-picker"
        headerComponents={headerComponents}
        footerComponents={footerComponents}
        items={this.state.templates}
        itemKey={ (item)=> item.id }
        itemContent={ (item)=> item.name }
        onSelect={this._onChooseTemplate.bind(this)}
      />
    );
  }

  render() {
    return (
      <button
        tabIndex={-1}
        className="btn btn-toolbar narrow pull-right"
        onClick={this._onClickButton}
        title="Insert email template…">
        <RetinaImg url="nylas://composer-templates/assets/icon-composer-templates@2x.png" mode={RetinaImg.Mode.ContentIsMask}/>
        &nbsp;
        <RetinaImg name="icon-composer-dropdown.png" mode={RetinaImg.Mode.ContentIsMask}/>
      </button>
    );
  }
}

export default TemplatePicker;
