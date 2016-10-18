import {React, ReactDOM} from 'nylas-exports';
import emoji from 'node-emoji';

import EmojiStore from './emoji-store';
import EmojiActions from './emoji-actions';


class EmojiPicker extends React.Component {
  static displayName = "EmojiPicker";
  static propTypes = {
    emojiOptions: React.PropTypes.array,
    selectedEmoji: React.PropTypes.string,
  };

  constructor(props) {
    super(props);
    this.state = {};
  }

  componentDidUpdate() {
    const selectedButton = ReactDOM.findDOMNode(this).querySelector(".emoji-option");
    if (selectedButton) {
      selectedButton.scrollIntoViewIfNeeded();
    }
  }

  onMouseDown(emojiName) {
    EmojiActions.selectEmoji({emojiName, replaceSelection: true});
  }

  render() {
    const emojiButtons = [];
    let emojiIndex = this.props.emojiOptions.indexOf(this.props.selectedEmoji);
    if (emojiIndex === -1) emojiIndex = 0;
    if (this.props.emojiOptions) {
      this.props.emojiOptions.forEach((emojiOption, i) => {
        const emojiClass = emojiIndex === i ? "btn btn-icon emoji-option" : "btn btn-icon";
        let emojiChar = emoji.get(emojiOption);
        emojiChar = (
          <img
            alt={emojiOption}
            src={EmojiStore.getImagePath(emojiOption)}
            width="16"
            height="16"
            style={{marginTop: "-4px", marginRight: "3px"}}
          />
        );
        emojiButtons.push(
          <button
            key={emojiOption}
            onMouseDown={() => this.onMouseDown(emojiOption)}
            className={emojiClass}
          >
            {emojiChar} :{emojiOption}:
          </button>
        );
        emojiButtons.push(<br key={`${emojiOption} br`} />);
      });
    }
    return (
      <div className="emoji-picker">
        {emojiButtons}
      </div>
    );
  }
}

export default EmojiPicker;
