import {DraftStore, React} from 'nylas-exports';

class TemplateStatusBar extends React.Component {
  static displayName = 'TemplateStatusBar';

  static propTypes = {
    draftClientId: React.PropTypes.string,
  };

  constructor() {
    super();
    this.state = { draft: null };
  }

  componentDidMount() {
    DraftStore.sessionForClientId(this.props.draftClientId).then((_proxy)=> {
      if (this._unmounted) {
        return;
      }
      if (_proxy.draftClientId === this.props.draftClientId) {
        this._proxy = _proxy;
        this.unsubscribe = this._proxy.listen(this._onDraftChange.bind(this), this);
        this._onDraftChange();
      }
    });
  }

  componentWillUnmount() {
    this._unmounted = true;
    if (this.unsubscribe) this.unsubscribe();
  }

  static containerStyles = {
    textAlign: 'center',
    width: 580,
    margin: 'auto',
  };

  _onDraftChange() {
    this.setState({draft: this._proxy.draft()});
  }

  _draftUsesTemplate() {
    if (this.state.draft) {
      return this.state.draft.body.search(/<code[^>]*class="var[^>]*>/i) > 0;
    }
  }

  render() {
    if (this._draftUsesTemplate()) {
      return (
        <div className="template-status-bar">
          Press "tab" to quickly move between the blanks - highlighting will not be visible to recipients.
        </div>
      );
    }
    return <div></div>;
  }

}

export default TemplateStatusBar;
