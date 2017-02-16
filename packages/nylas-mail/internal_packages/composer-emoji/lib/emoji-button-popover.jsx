import React from 'react';
import {findDOMNode} from 'react-dom';
import {Actions} from 'nylas-exports';
import {RetinaImg, ScrollRegion} from 'nylas-component-kit';

import EmojiStore from './emoji-store';
import EmojiActions from './emoji-actions';
import categorizedEmojiList from './categorized-emoji';

class EmojiButtonPopover extends React.Component {
  static displayName = 'EmojiButtonPopover';

  constructor() {
    super();
    const {categoryNames,
      categorizedEmoji,
      categoryPositions} = this.getStateFromStore();
    this.state = {
      emojiName: "Emoji Picker",
      categoryNames: categoryNames,
      categorizedEmoji: categorizedEmoji,
      categoryPositions: categoryPositions,
      searchValue: "",
      activeTab: Object.keys(categorizedEmoji)[0],
    };
  }

  componentDidMount() {
    this._mounted = true;
    this._emojiPreloadImage = new Image();
    this.renderCanvas();
  }

  componentWillUnmount() {
    this._emojiPreloadImage.onload = null;
    this._emojiPreloadImage = null;
    this._mounted = false;
  }

  onMouseDown = (event) => {
    const emojiName = this.calcEmojiByPosition(this.calcPosition(event));
    if (!emojiName) return null;
    EmojiActions.selectEmoji({emojiName: emojiName, replaceSelection: false});
    Actions.closePopover();
    return null
  }

  onScroll = () => {
    const emojiContainer = document.querySelector(".emoji-finder-container .scroll-region-content");
    const tabContainer = document.querySelector(".emoji-tabs");
    tabContainer.className = emojiContainer.scrollTop ? "emoji-tabs shadow" : "emoji-tabs";
    if (emojiContainer.scrollTop === 0) {
      this.setState({activeTab: Object.keys(this.state.categorizedEmoji)[0]});
    } else {
      for (const category of Object.keys(this.state.categoryPositions)) {
        if (emojiContainer.scrollTop >= this.state.categoryPositions[category].top &&
          emojiContainer.scrollTop <= this.state.categoryPositions[category].bottom) {
          this.setState({activeTab: category});
        }
      }
    }
  }

  onHover = (event) => {
    const emojiName = this.calcEmojiByPosition(this.calcPosition(event));
    if (emojiName) {
      this.setState({emojiName: emojiName});
    } else {
      this.setState({emojiName: "Emoji Picker"});
    }
  }

  onMouseOut = () => {
    this.setState({emojiName: "Emoji Picker"});
  }

  onChange = (event) => {
    const searchValue = event.target.value;
    if (searchValue.length > 0) {
      const searchMatches = this.findSearchMatches(searchValue);
      this.setState({
        categorizedEmoji: {
          'Search Results': searchMatches,
        },
        categoryPositions: {
          'Search Results': {
            top: 25,
            bottom: 25 + Math.ceil(searchMatches.length / 8) * 24,
          },
        },
        searchValue: searchValue,
        activeTab: null,
      }, this.renderCanvas);
    } else {
      this.setState(this.getStateFromStore, () => {
        this.setState({
          searchValue: searchValue,
          activeTab: Object.keys(this.state.categorizedEmoji)[0],
        }, this.renderCanvas);
      });
    }
  }

  getStateFromStore = () => {
    let categorizedEmoji = categorizedEmojiList;
    const categoryPositions = {};
    let categoryNames = [
      'People',
      'Nature',
      'Food and Drink',
      'Activity',
      'Travel and Places',
      'Objects',
      'Symbols',
      'Flags',
    ];
    const frequentlyUsedEmoji = EmojiStore.frequentlyUsedEmoji();
    if (frequentlyUsedEmoji.length > 0) {
      categorizedEmoji = {'Frequently Used': frequentlyUsedEmoji};
      for (const category of Object.keys(categorizedEmojiList)) {
        categorizedEmoji[category] = categorizedEmojiList[category];
      }
      categoryNames = ["Frequently Used"].concat(categoryNames);
    }
    // Calculates where each category should be (variable because Frequently
    // Used may or may not be present)
    for (const name of categoryNames) {
      categoryPositions[name] = {top: 0, bottom: 0};
    }
    let verticalPos = 25;
    for (const category of Object.keys(categoryPositions)) {
      const height = Math.ceil(categorizedEmoji[category].length / 8) * 24;
      categoryPositions[category].top = verticalPos;
      verticalPos += height;
      categoryPositions[category].bottom = verticalPos;
      verticalPos += 24;
    }
    return {
      categoryNames: categoryNames,
      categorizedEmoji: categorizedEmoji,
      categoryPositions: categoryPositions,
    };
  }

  scrollToCategory(category) {
    const container = document.querySelector(".emoji-finder-container .scroll-region-content");
    if (this.state.searchValue.length > 0) {
      this.setState({searchValue: ""});
      this.setState(this.getStateFromStore, () => {
        this.renderCanvas();
        container.scrollTop = this.state.categoryPositions[category].top + 16;
      });
    } else {
      container.scrollTop = this.state.categoryPositions[category].top + 16;
    }
    this.setState({activeTab: category})
  }

  findSearchMatches(searchValue) {
    // TODO: Find matches for aliases, too.
    const searchMatches = [];
    for (const category of Object.keys(categorizedEmojiList)) {
      categorizedEmojiList[category].forEach((emojiName) => {
        if (emojiName.indexOf(searchValue) !== -1) {
          searchMatches.push(emojiName);
        }
      });
    }
    return searchMatches;
  }

  calcPosition(event) {
    const rect = event.target.getBoundingClientRect();
    const position = {
      x: event.pageX - rect.left / 2,
      y: event.pageY - rect.top / 2,
    };
    return position;
  }

  calcEmojiByPosition = (position) => {
    for (const category of Object.keys(this.state.categoryPositions)) {
      const LEFT_BOUNDARY = 8;
      const RIGHT_BOUNDARY = 204;
      const EMOJI_WIDTH = 24.5;
      const EMOJI_HEIGHT = 24;
      const EMOJI_PER_ROW = 8;
      if (position.x >= LEFT_BOUNDARY &&
          position.x <= RIGHT_BOUNDARY &&
          position.y >= this.state.categoryPositions[category].top &&
          position.y <= this.state.categoryPositions[category].bottom) {
        const x = Math.round((position.x + 5) / EMOJI_WIDTH);
        const y = Math.round((position.y - this.state.categoryPositions[category].top + 10) / EMOJI_HEIGHT);
        const index = x + (y - 1) * EMOJI_PER_ROW - 1;
        return this.state.categorizedEmoji[category][index];
      }
    }
    return null;
  }

  renderTabs() {
    const tabs = [];
    this.state.categoryNames.forEach((category) => {
      let className = `emoji-tab ${(category.replace(/ /g, '-')).toLowerCase()}`
      if (category === this.state.activeTab) {
        className += " active";
      }
      tabs.push(
        <div key={`${category} container`} style={{flex: 1}}>
          <RetinaImg
            key={`${category} tab`}
            className={className}
            name={`icon-emojipicker-${(category.replace(/ /g, '-')).toLowerCase()}.png`}
            mode={RetinaImg.Mode.ContentIsMask}
            onMouseDown={() => this.scrollToCategory(category)}
          />
        </div>
      );
    });
    return tabs;
  }

  renderCanvas() {
    const canvas = findDOMNode(this.refs.emojiCanvas);
    const keys = Object.keys(this.state.categoryPositions);
    canvas.height = this.state.categoryPositions[keys[keys.length - 1]].bottom * 2;
    const ctx = canvas.getContext("2d");
    ctx.font = "24px Nylas-Pro";
    ctx.fillStyle = 'rgba(0, 0, 0, 0.5)';
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    const position = {
      x: 15,
      y: 45,
    }

    let idx = 0;
    const categoryNames = Object.keys(this.state.categorizedEmoji);
    const renderNextCategory = () => {
      if (!categoryNames[idx]) return;
      if (!this._mounted) return;
      this.renderCategory(categoryNames[idx], idx, ctx, position, renderNextCategory);
      idx += 1;
    }
    renderNextCategory();
  }

  renderCategory(category, i, ctx, pos, callback) {
    const position = pos
    if (i > 0) {
      position.x = 18;
      position.y += 48;
    }
    ctx.fillText(category, position.x, position.y);
    position.x = 18;
    position.y += 48;

    const emojiNames = this.state.categorizedEmoji[category];
    if (!emojiNames || emojiNames.length === 0) return;

    const emojiToDraw = emojiNames.map((emojiName, j) => {
      const x = position.x;
      const y = position.y;
      const src = EmojiStore.getImagePath(emojiName);

      if (position.x > 325 && j < this.state.categorizedEmoji[category].length - 1) {
        position.x = 18;
        position.y += 48;
      } else {
        position.x += 50;
      }

      return {src, x, y};
    });

    const drawEmojiAt = ({src, x, y} = {}) => {
      if (!src) {
        return;
      }
      this._emojiPreloadImage.onload = () => {
        this._emojiPreloadImage.onload = null;
        ctx.drawImage(this._emojiPreloadImage, x, y - 30, 32, 32);
        if (emojiToDraw.length === 0) {
          callback();
        } else {
          drawEmojiAt(emojiToDraw.shift());
        }
      }
      this._emojiPreloadImage.src = src;
    }

    drawEmojiAt(emojiToDraw.shift());
  }

  render() {
    return (
      <div className="emoji-button-popover" tabIndex="-1">
        <div className="emoji-tabs">
          {this.renderTabs()}
        </div>
        <ScrollRegion
          className="emoji-finder-container"
          onScroll={this.onScroll}
        >
          <div className="emoji-search-container">
            <input
              type="text"
              className="search"
              value={this.state.searchValue}
              onChange={this.onChange}
            />
          </div>
          <canvas
            ref="emojiCanvas"
            width="400"
            height="2000"
            onMouseDown={this.onMouseDown}
            onMouseOut={this.onMouseOut}
            onMouseMove={this.onHover}
            style={{zoom: "0.5"}}
          />
        </ScrollRegion>
        <div className="emoji-name">
          {this.state.emojiName}
        </div>
      </div>
    );
  }
}

export default EmojiButtonPopover;
