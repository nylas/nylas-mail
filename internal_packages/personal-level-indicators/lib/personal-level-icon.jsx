import {React} from 'nylas-exports';
import {RetinaImg} from 'nylas-component-kit';

const StaticEmptyIndicator = (
  <div className="personal-level-icon" />
);

export default class PersonalLevelIcon extends React.Component {
  // Note: You should assign a new displayName to avoid naming
  // conflicts when injecting your item
  static displayName = 'PersonalLevelIcon';

  static propTypes = {
    thread: React.PropTypes.object.isRequired,
  };

  renderIndicator(level) {
    return (
      <div className="personal-level-icon">
        <RetinaImg
          url={`nylas://personal-level-indicators/assets/PLI-Level${level}@2x.png`}
          mode={RetinaImg.Mode.ContentDark}
        />
      </div>
    )
  }

  // React components' `render` methods return a virtual DOM element to render.
  // The returned DOM fragment is a result of the component's `state` and
  // `props`. In that sense, `render` methods are deterministic.
  render() {
    const {thread} = this.props;
    const me = thread.participants.find(p => p.isMe());

    if (me && thread.participants.length === 2) {
      return this.renderIndicator(2);
    }
    if (me && thread.participants.length > 2) {
      return this.renderIndicator(1);
    }

    return StaticEmptyIndicator;
  }
}
