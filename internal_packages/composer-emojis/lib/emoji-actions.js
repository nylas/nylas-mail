/** @babel */
import Reflux from 'reflux';

EmojiActions = Reflux.createActions([
  "selectEmoji"
]);

for (key in EmojiActions) {
  EmojiActions[key].sync = true;
}

export default EmojiActions;