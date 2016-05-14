import React from 'react'

const SearchMatch = (props) => {
  return (
    <span
      data-region-id={props.regionId}
      data-render-index={props.renderIndex}
      className={`search-match ${props.className}`}
    >
      {props.children}
    </span>
  )
}

SearchMatch.propTypes = {
  regionId: React.PropTypes.string,
  className: React.PropTypes.string,
  renderIndex: React.PropTypes.number,
};

export default SearchMatch;
