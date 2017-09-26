import React from 'react';
import PropTypes from 'prop-types';

const SearchMatch = props => {
  return (
    <span
      data-region-id={props.regionId}
      data-render-index={props.renderIndex}
      className={`search-match ${props.className}`}
    >
      {props.children}
    </span>
  );
};

SearchMatch.propTypes = {
  regionId: PropTypes.string,
  className: PropTypes.string,
  renderIndex: PropTypes.number,
};

export default SearchMatch;
