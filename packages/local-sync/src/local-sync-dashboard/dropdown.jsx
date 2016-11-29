import {React} from 'nylas-exports';

export default class Dropdown extends React.Component {
  constructor(props) {
    super(props);
    this.state = {
      closed: true,
      selected: props.defaultOption,
      onSelect: props.onSelect,
    }
  }

  open() {
    this.setState({closed: false});
  }

  selectAndClose(selection) {
    this.setState({
      closed: true,
      selected: selection,
    })
    this.state.onSelect(selection);
  }

  close() {
    this.setState({closed: true});
  }

  render() {
    // Currently selected option (includes dropdown arrow)
    const selectedOnClick = this.state.closed ? this.open : this.close;
    const selected = (
      <div className="dropdown-selected" onClick={() => selectedOnClick.call(this)}>
        {this.state.selected}
        <img className="dropdown-arrow" src="../images/dropdown.png" alt="dropdown arrow" />
      </div>
    );

    // All options, not shown if dropdown is closed
    const options = [];
    let optionsWrapper = <span className="dropdown-options" />;
    if (!this.state.closed) {
      for (const opt of this.props.options) {
        options.push(
          <div className="dropdown-option" onMouseDown={() => this.selectAndClose.call(this, opt)}> {opt} </div>
        );
      }
      optionsWrapper = (
        <div className="dropdown-options">
          {options}
        </div>
      )
    }

    return (
      <div className="dropdown-wrapper" tabIndex="0" onBlur={() => this.close.call(this)}>
        {optionsWrapper}
        {selected}
      </div>
    );
  }

}

Dropdown.propTypes = {
  options: React.PropTypes.arrayOf(React.PropTypes.string),
  defaultOption: React.PropTypes.string,
  onSelect: React.PropTypes.func,
}
