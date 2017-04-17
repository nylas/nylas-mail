/**
 * CREATE TABLE IF NOT EXISTS `messageLabels` (
 *   `createdAt` DATETIME NOT NULL,
 *   `updatedAt` DATETIME NOT NULL,
 *   `labelId` VARCHAR(65) NOT NULL REFERENCES `labels` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
 *   `messageId` VARCHAR(65) NOT NULL REFERENCES `messages` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
 *   PRIMARY KEY (`labelId`, `messageId`)
 * );
 *
 * sqlite_autoindex_messageLabels_1 (labelId, messageId)
 */
module.exports = (sequelize) => {
  return sequelize.define('messageLabel', {
  }, {
    indexes: [
      // NOTE: When SQLite sets up this table, it creates an auto index in
      // the order ['labelId', 'messageId']. This is the correct index we
      // need for queries requesting Messages for a certain Label.
      //
      // We need to create one more index to allow queries from the
      // reverse direction requesting Labels for a certain Message.
      {fields: ['messageId', 'labelId']},
    ],
  });
};
