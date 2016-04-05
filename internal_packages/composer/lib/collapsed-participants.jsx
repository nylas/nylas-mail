import React from 'react';
import ReactDOM from 'react-dom';
import {Utils} from 'nylas-exports';
import {InjectedComponentSet} from 'nylas-component-kit';

const NUM_TO_DISPLAY_MAX = 999;

export default class CollapsedParticipants extends React.Component {
  static displayName = "CollapsedParticipants";

  static propTypes = {
    // Arrays of Contact objects.
    to: React.PropTypes.array,
    cc: React.PropTypes.array,
    bcc: React.PropTypes.array,
  }

  static defaultProps = {
    to: [],
    cc: [],
    bcc: [],
  }

  constructor(props = {}) {
    super(props);
    this.state = {
      numToDisplay: NUM_TO_DISPLAY_MAX,
      numRemaining: 0,
      numBccRemaining: 0,
    }
  }

  componentDidMount() {
    this._setNumHiddenParticipants();
  }

  componentWillReceiveProps(nextProps) {
    if (!Utils.isEqualReact(nextProps, this.props)) {
      // Always re-evaluate the hidden participant count when the participant set changes
      this.setState({
        numToDisplay: NUM_TO_DISPLAY_MAX,
        numRemaining: 0,
        numBccRemaining: 0,
      });
    }
  }

  shouldComponentUpdate(nextProps, nextState) {
    return !Utils.isEqualReact(nextProps, this.props) || !Utils.isEqualReact(nextState, this.state);
  }

  componentDidUpdate() {
    if (this.state.numToDisplay === NUM_TO_DISPLAY_MAX) {
      this._setNumHiddenParticipants();
    }
  }

  _setNumHiddenParticipants() {
    const $wrap = ReactDOM.findDOMNode(this.refs.participantsWrap);
    const $regulars = Array.from($wrap.getElementsByClassName("regular-contact"));
    const $bccs = Array.from($wrap.getElementsByClassName("bcc-contact"));

    const availableSpace = $wrap.getBoundingClientRect().width;
    let numRemaining = this.props.to.length + this.props.cc.length;
    let numBccRemaining = this.props.bcc.length;
    let numToDisplay = 0;
    let widthAccumulator = 0;

    for (const $p of $regulars) {
      widthAccumulator += $p.getBoundingClientRect().width;
      if (widthAccumulator >= availableSpace) {
        break;
      }
      numRemaining -= 1;
      numToDisplay += 1;
    }

    for (const $p of $bccs) {
      widthAccumulator += $p.getBoundingClientRect().width;
      if (widthAccumulator >= availableSpace) {
        break;
      }
      numBccRemaining -= 1;
      numToDisplay += 1;
    }

    this.setState({numToDisplay, numRemaining, numBccRemaining});
  }

  _renderNumRemaining() {
    let str = null;
    if (this.state.numRemaining === 0 && this.state.numBccRemaining === 0) {
      return null;
    } else if (this.state.numRemaining > 0 && this.state.numBccRemaining === 0) {
      str = `${this.state.numRemaining} more`;
    } else if (this.state.numRemaining === 0 && this.state.numBccRemaining > 0) {
      str = `${this.state.numBccRemaining} Bcc`;
    } else if (this.state.numRemaining > 0 && this.state.numBccRemaining > 0) {
      str = `${this.state.numRemaining + this.state.numBccRemaining} more (${this.state.numBccRemaining} Bcc)`;
    }

    return (
      <div className="num-remaining-wrap tokenizing-field">
        <div className="show-more-fade"></div>
        <div className="num-remaining token">{str}</div>
      </div>
    );
  }

  _collapsedContact = (contact) => {
    const name = contact.displayName();
    const key = contact.email + contact.name;

    return (
      <span
        key={key}
        className="collapsed-contact regular-contact">
        <InjectedComponentSet
          matching={{role: "Composer:RecipientChip"}}
          exposedProps={{contact: contact}}
          direction="column"
          inline
        />
        {name}
      </span>
    );
  }

  _collapsedBccContact = (contact, i) => {
    let name = contact.displayName();
    const key = contact.email + contact.name;
    if (i === 0) {
      name = `Bcc: ${name}`;
    }
    return (
      <span key={key} className="collapsed-contact bcc-contact">{name}</span>
    );
  }

  render() {
    const contacts = this.props.to.concat(this.props.cc).map(this._collapsedContact)
    const bcc = this.props.bcc.map(this._collapsedBccContact);

    let toDisplay = contacts.concat(bcc);
    toDisplay = toDisplay.splice(0, this.state.numToDisplay);
    if (toDisplay.length === 0) {
      toDisplay = "Recipients";
    }

    return (
      <div
        tabIndex={0}
        ref="participantsWrap"
        className="collapsed-composer-participants">
        {this._renderNumRemaining()}
        {toDisplay}
      </div>
    );
  }
}
