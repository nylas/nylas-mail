import React from 'react'
import Utils from '../flux/models/utils'

export default function BoldedSearchResult({query = "", value = ""} = {}) {
  const searchTerm = (query || "").trim()

  if (searchTerm.length === 0) return <span>{value}</span>;

  const re = Utils.wordSearchRegExp(searchTerm)
  const parts = value.split(re).map((part) => {
    // The wordSearchRegExp looks for a leading non-word character to
    // deterine if it's a valid place to search. As such, we need to not
    // include that leading character as part of our match.
    if (re.test(part)) {
      if (/\W/.test(part[0])) {
        return <span>{part[0]}<strong>{part.slice(1)}</strong></span>
      }
      return <strong>{part}</strong>
    }
    return part
  });
  return <span>{parts}</span>;
}
BoldedSearchResult.propTypes = {
  query: React.PropTypes.string,
  value: React.PropTypes.string,
}
