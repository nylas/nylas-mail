/** @babel */
import Reflux from 'reflux';

EmojiActions = Reflux.createActions([
  "selectEmoji",
  "useEmoji"
]);

for (key in EmojiActions) {
  EmojiActions[key].sync = true;
}

export default EmojiActions;