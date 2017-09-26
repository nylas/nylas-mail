import { React, PropTypes, DateUtils } from 'mailspring-exports';

class MessageTimestamp extends React.Component {
  static displayName = 'MessageTimestamp';

  static propTypes = {
    date: PropTypes.object.isRequired,
    className: PropTypes.string,
    isDetailed: PropTypes.bool,
    onClick: PropTypes.func,
  };

  shouldComponentUpdate(nextProps) {
    return nextProps.date !== this.props.date || nextProps.isDetailed !== this.props.isDetailed;
  }

  render() {
    let formattedDate = null;
    if (this.props.isDetailed) {
      formattedDate = DateUtils.mediumTimeString(this.props.date);
    } else {
      formattedDate = DateUtils.shortTimeString(this.props.date);
    }
    return (
      <div
        className={this.props.className}
        title={DateUtils.fullTimeString(this.props.date)}
        onClick={this.props.onClick}
      >
        {formattedDate}
      </div>
    );
  }
}

export default MessageTimestamp;
