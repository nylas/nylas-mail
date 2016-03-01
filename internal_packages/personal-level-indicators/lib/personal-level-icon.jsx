import {React} from 'nylas-exports';

export default class PersonalLevelIcon extends React.Component {
  // Note: You should assign a new displayName to avoid naming
  // conflicts when injecting your item
  static displayName = 'PersonalLevelIcon';

  static propTypes = {
    thread: React.PropTypes.object.isRequired,
  };

  // In the constructor, we're setting the component's initial state.
  constructor(props) {
    super(props);

    this.state = {
      level: this._calculateLevel(this.props.thread),
    };
  }

  // Some more application logic which is specific to this package to decide
  // what level of personalness is related to the `thread`.
  _calculateLevel = (thread)=> {
    const hasMe = thread.participants.filter(p=> p.isMe()).length > 0;
    const numOthers = hasMe ? thread.participants.length - 1 : thread.participants.length;

    if (!hasMe) { return 0; }
    if (numOthers > 1) { return 1; }
    if (numOthers === 1) { return 2; }
    return 3;
  }

  // React components' `render` methods return a virtual DOM element to render.
  // The returned DOM fragment is a result of the component's `state` and
  // `props`. In that sense, `render` methods are deterministic.
  render() {
    const levelCharacter = ["", "\u3009", "\u300b", "\u21ba"][this.state.level];

    return (
      <div className="personal-level-icon">
        {levelCharacter}
      </div>
    );
  }
}

module.exports = PersonalLevelIcon
