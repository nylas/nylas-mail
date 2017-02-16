import {React} from 'nylas-exports';

class TemplateStatusBar extends React.Component {
  static displayName = 'TemplateStatusBar';

  static propTypes = {
    draft: React.PropTypes.object.isRequired,
  };

  shouldComponentUpdate(nextProps) {
    return (this._usingTemplate(nextProps) !== this._usingTemplate(this.props));
  }

  _usingTemplate({draft}) {
    return draft && draft.body.search(/<code[^>]*class="var[^>]*>/i) > 0;
  }

  render() {
    if (this._usingTemplate(this.props)) {
      return (
        <div className="template-status-bar">
          Press &quot;tab&quot; to quickly move between the blanks - highlighting will not be visible to recipients.
        </div>
      );
    }
    return <div />;
  }

}

TemplateStatusBar.containerStyles = {
  textAlign: 'center',
  width: 580,
  margin: 'auto',
};

export default TemplateStatusBar;
