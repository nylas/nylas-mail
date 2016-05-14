import Reflux from 'reflux';

const EmojiActions = Reflux.createActions([
  "selectEmoji",
  "useEmoji",
]);

for (const key of Object.keys(EmojiActions)) {
  EmojiActions[key].sync = true;
}

export default EmojiActions;
