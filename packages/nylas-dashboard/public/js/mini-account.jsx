const React = window.React;

class MiniAccount extends React.Component {

  calculateColor() {
    // in milliseconds
    const grayAfter = 1000 * 60 * 10; // 10 minutes
    const elapsedTime = Date.now() - this.props.account.last_sync_completions[0];
    let opacity = 0;
    if (elapsedTime < grayAfter) {
      opacity = 1.0 - elapsedTime / grayAfter;
    }

    return `rgba(0, 255, 157, ${opacity})`;
  }

  render() {
    let errorClass;
    const style = {};
    if (this.props.account.sync_error) {
      errorClass = 'errored';
    } else {
      errorClass = '';
      style.backgroundColor = this.calculateColor();
    }

    return (
      <div
        className={`mini-account ${errorClass}`}
        style={style}
      />
    )
  }
}

MiniAccount.propTypes = {
  account: React.PropTypes.object,
};

window.MiniAccount = MiniAccount;
