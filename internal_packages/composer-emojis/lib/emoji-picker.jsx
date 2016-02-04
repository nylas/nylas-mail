import {React} from 'nylas-exports'
import EmojiActions from './emoji-actions'
const emoji = require('node-emoji');

class EmojiPicker extends React.Component {
  static displayName = "EmojiPicker"
  static propTypes = {
    emojiOptions: React.PropTypes.array,
    selectedEmoji: React.PropTypes.string,
  };

  constructor(props) {
    super(props);
    this.state = {};
  }

  componentDidUpdate() {
    const selectedButton = React.findDOMNode(this).querySelector(".emoji-option");
    if (selectedButton) {
      selectedButton.scrollIntoViewIfNeeded();
    }
  }

  onMouseDown(emojiChar) {
    EmojiActions.selectEmoji({emojiChar});
  }

  render() {
    const emojis = [];
    let emojiIndex = this.props.emojiOptions.indexOf(this.props.selectedEmoji);
    if (emojiIndex === -1) emojiIndex = 0;
    if (this.props.emojiOptions) {
      this.props.emojiOptions.forEach((emojiOption, i) => {
        const emojiChar = emoji.get(emojiOption);
        const emojiClass = emojiIndex === i ? "btn btn-icon emoji-option" : "btn btn-icon";
        emojis.push(<button onMouseDown={() => this.onMouseDown(emojiChar)} className={emojiClass}>{emojiChar} :{emojiOption}:</button>);
        emojis.push(<br />);
      })
    }
    return (
      <div className="emoji-picker">
        {emojis}
      </div>
    );
  }
}

export default EmojiPicker;
