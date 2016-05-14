import Reflux from 'reflux';

const SearchActions = Reflux.createActions([
  "querySubmitted",
  "queryChanged",
  "searchBlurred",
  "searchCompleted",
]);

for (const key of Object.keys(SearchActions)) {
  SearchActions[key].sync = true;
}

export default SearchActions
