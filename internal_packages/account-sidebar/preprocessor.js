var ReactTools = require('react-tools');
var cjsx = require('coffee-react');

module.exports = {
  process: function(src, path) {
    if (path.match(/\.(coffee|cjsx)$/)) {
      return cjsx.compile(src, {'bare': true});
    } else {
      return ReactTools.transform(src);
    }
  }
};
