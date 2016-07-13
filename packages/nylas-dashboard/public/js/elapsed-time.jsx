const React = window.React;

class ElapsedTime extends React.Component {
  constructor(props) {
    super(props);
    this.state = {
      elapsed: 0,
    }
  }

  componentDidMount() {
    this.interval = setInterval(() => {
      this.setState({elapsed: Date.now() - this.props.refTimestamp})
    }, 1000);
  }

  componentWillUnmount() {
    clearInterval(this.interval);
  }

  render() {
    return <span>{this.props.formatTime(this.state.elapsed)} </span>
  }
}

ElapsedTime.propTypes = {
  refTimestamp: React.PropTypes.number, // milliseconds
  formatTime: React.PropTypes.func,
}

window.ElapsedTime = ElapsedTime;
