import React, { Component } from 'react';
import { findDOMNode } from 'react-dom';
import PropTypes from 'prop-types';

const MIN_RANGE_SIZE = 2;

function getRange({ total, itemHeight, containerHeight, scrollTop = 0 } = {}) {
  const itemsPerBody = Math.floor(containerHeight / itemHeight);
  const start = Math.max(0, Math.floor(scrollTop / itemHeight) - itemsPerBody * 2);
  const end = Math.max(MIN_RANGE_SIZE, Math.min(start + 4 * itemsPerBody, total));
  return { start, end };
}

class LazyRenderedList extends Component {
  static propTypes = {
    items: PropTypes.array,
    itemHeight: PropTypes.number,
    containerHeight: PropTypes.number,
    BufferTag: PropTypes.string,
    ItemRenderer: PropTypes.oneOfType([PropTypes.func, PropTypes.string]),
    RootRenderer: PropTypes.oneOfType([PropTypes.func, PropTypes.string]),
  };

  static defaultProps = {
    items: [],
    itemHeight: 30,
    containerHeight: 150,
    BufferTag: 'div',
  };

  constructor(props) {
    super(props);
    this.state = this.getRangeState(props);
  }

  componentWillReceiveProps(nextProps) {
    this.updateRangeState(nextProps);
  }

  onScroll = () => {
    this.updateRangeState(this.props);
  };

  getRangeState({ items, itemHeight, containerHeight, scrollTop }) {
    return getRange({ total: items.length, itemHeight, containerHeight, scrollTop });
  }

  updateRangeState(props) {
    const { scrollTop } = findDOMNode(this);
    this.setState(this.getRangeState({ ...props, scrollTop }));
  }

  renderItems() {
    const { items, itemHeight, BufferTag, ItemRenderer } = this.props;
    const { start, end } = this.state;
    const topHeight = start * itemHeight;
    const bottomHeight = (items.length - end) * itemHeight;

    const top = <BufferTag key="lazy-top" style={{ height: topHeight }} />;
    const bottom = <BufferTag key="lazy-bottom" style={{ height: bottomHeight }} />;
    const elements = items
      .slice(start, end)
      .map((item, idx) => (
        <ItemRenderer key={`item-${start + idx}`} item={item} idx={start + idx} />
      ));
    elements.unshift(top);
    elements.push(bottom);

    return elements;
  }

  render() {
    const { RootRenderer, containerHeight } = this.props;
    return (
      <RootRenderer
        style={{ height: containerHeight, overflowX: 'hidden', overflowY: 'auto' }}
        onScroll={this.onScroll}
      >
        {this.renderItems()}
      </RootRenderer>
    );
  }
}

export default LazyRenderedList;
