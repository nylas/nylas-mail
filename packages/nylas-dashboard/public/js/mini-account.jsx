const React = window.React;

class MiniAccount extends React.Component {

  calculateColor() {
    // in milliseconds
    const grayAfter = 10000;
    const elapsedTime = Date.now() - this.props.account.last_sync_completions[0];
    let opacity = 0;
    if (elapsedTime < grayAfter) {
      opacity = 1.0 - elapsedTime / grayAfter;
    }

    return `rgba(0, 255, 157, ${opacity})`;
  }

  render() {
    const {account, assignment, active} = this.props;

    let errorClass;
    let style;
    if (account.sync_error) {
      errorClass = 'errored';
      style = {};
    } else {
      errorClass = '';
      style = {backgroundColor: this.calculateColor()};
    }

    return (
      <div
        className={`mini-account ${errorClass}`}
        style={style}
      ></div>
    )
  }
}

MiniAccount.propTypes = {
  account: React.PropTypes.object,
  active: React.PropTypes.bool,
  assignment: React.PropTypes.string,
  count: React.PropTypes.number,
};

window.MiniAccount = MiniAccount;
