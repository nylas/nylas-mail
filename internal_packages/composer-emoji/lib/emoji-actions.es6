import Reflux from 'reflux';

const EmojiActions = Reflux.createActions([
  "selectEmoji",
  "useEmoji",
]);

for (const key in EmojiActions) {
  EmojiActions[key].sync = true;
}

export default EmojiActions;
