import React from 'react';
import {findDOMNode} from 'react-dom';
import {Actions} from 'nylas-exports';
import {RetinaImg, ScrollRegion} from 'nylas-component-kit';

import EmojiStore from './emoji-store';
import EmojiActions from './emoji-actions';
import emoji from 'node-emoji';
import categorizedEmojiList from './categorized-emoji';
import missingEmojiList from './missing-emoji';

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
    this.renderCanvas();
  }

  componentWillUnmount() {
    this._mounted = false;
  }

  onMouseDown = (event) => {
    const emojiName = this.calcEmojiByPosition(this.calcPosition(event));
    if (!emojiName) return null;
    EmojiActions.selectEmoji({emojiName, replaceSelection: false});
    Actions.closePopover();
  }

  onScroll = () => {
    const emojiContainer = document.querySelector(".emoji-finder-container");
    const tabContainer = document.querySelector(".emoji-tabs");
    tabContainer.className = emojiContainer.scrollTop ? "emoji-tabs shadow" : "emoji-tabs";
    if (emojiContainer.scrollTop === 0) {
      this.setState({activeTab: Object.keys(this.state.categorizedEmoji)[0]});
    } else {
      for (const category in this.state.categoryPositions) {
        if (this.state.categoryPositions.hasOwnProperty(category)) {
          if (emojiContainer.scrollTop >= this.state.categoryPositions[category].top &&
            emojiContainer.scrollTop <= this.state.categoryPositions[category].bottom) {
            if (category === 'More People') {
              this.setState({activeTab: 'People'});
            } else {
              this.setState({activeTab: category});
            }
          }
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
      'More People',
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
      for (const category in categorizedEmojiList) {
        if (categorizedEmojiList.hasOwnProperty(category)) {
          categorizedEmoji[category] = categorizedEmojiList[category];
        }
      }
      categoryNames = ["Frequently Used"].concat(categoryNames);
    }
    // Calculates where each category should be (variable because Frequently
    // Used may or may not be present)
    for (const name of categoryNames) {
      categoryPositions[name] = {top: 0, bottom: 0};
    }
    let verticalPos = 25;
    for (const category in categoryPositions) {
      if (categoryPositions.hasOwnProperty(category)) {
        const height = Math.ceil(categorizedEmoji[category].length / 8) * 24;
        categoryPositions[category].top = verticalPos;
        verticalPos += height;
        categoryPositions[category].bottom = verticalPos;
        if (category !== 'People') {
          verticalPos += 24;
        }
      }
    }
    return {
      categoryNames: categoryNames,
      categorizedEmoji: categorizedEmoji,
      categoryPositions: categoryPositions,
    };
  }

  scrollToCategory(category) {
    const container = document.querySelector(".emoji-finder-container");
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
    for (const category in this.state.categoryPositions) {
      if (this.state.categoryPositions.hasOwnProperty(category)) {
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
    }
    return null;
  }

  renderTabs() {
    const tabs = [];
    this.state.categoryNames.forEach((category) => {
      if (category !== 'More People') {
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
              onMouseDown={() => this.scrollToCategory(category)} />
          </div>
        );
      }
    });
    return tabs;
  }

  renderCanvas() {
    const canvas = findDOMNode(this.refs.emojiCanvas);
    const keys = Object.keys(this.state.categoryPositions);
    canvas.height = this.state.categoryPositions[keys[keys.length - 1]].bottom * 2;
    const ctx = canvas.getContext("2d");
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    const position = {
      x: 15,
      y: 45,
    }
    Object.keys(this.state.categorizedEmoji).forEach((category, i) => {
      if (i > 0) {
        setTimeout(() => this.renderCategory(category, i, ctx, position), i * 50);
      } else {
        this.renderCategory(category, i, ctx, position);
      }
    });
  }

  renderCategory(category, i, ctx, position) {
    if (!this._mounted) return;
    if (category !== "More People") {
      if (i > 0) {
        position.x = 18;
        position.y += 48;
      }
      ctx.font = "24px Nylas-Pro";
      ctx.fillStyle = 'rgba(0, 0, 0, 0.5)';
      ctx.fillText(category, position.x, position.y);
    }
    position.x = 18;
    position.y += 48;
    ctx.font = "32px Arial";
    ctx.fillStyle = 'black';
    if (this.state.categorizedEmoji[category].length === 0) return;
    this.state.categorizedEmoji[category].forEach((emojiName, j) => {
      if (process.platform === "darwin" && missingEmojiList.indexOf(emojiName) !== -1) {
        const img = new Image();
        img.src = `images/composer-emoji/missing-emoji/${emojiName}.png`;
        const x = position.x;
        const y = position.y;
        img.onload = () => {
          ctx.drawImage(img, x, y - 30, 32, 32);
        }
      } else {
        const emojiChar = emoji.get(emojiName);
        ctx.fillText(emojiChar, position.x, position.y);
      }
      if (position.x > 325 && j < this.state.categorizedEmoji[category].length - 1) {
        position.x = 18;
        position.y += 48;
      } else {
        position.x += 50;
      }
    })
  }

  render() {
    return (
      <div className="emoji-button-popover" tabIndex="-1">
        <div className="emoji-tabs">
          {this.renderTabs()}
        </div>
        <ScrollRegion
          className="emoji-finder-container"
          onScroll={this.onScroll}>
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
            style={{zoom: "0.5"}}>
          </canvas>
        </ScrollRegion>
        <div className="emoji-name">
          {this.state.emojiName}
        </div>
      </div>
    );
  }
}

export default EmojiButtonPopover;
