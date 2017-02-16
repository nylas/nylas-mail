/**
 * CREATE TABLE IF NOT EXISTS `threadLabels` (
 *   `createdAt` DATETIME NOT NULL,
 *   `updatedAt` DATETIME NOT NULL,
 *   `labelId` VARCHAR(65) NOT NULL REFERENCES `labels` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
 *   `threadId` VARCHAR(65) NOT NULL REFERENCES `threads` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
 *   PRIMARY KEY (`labelId`, `threadId`)
 * );
 *
 * sqlite_autoindex_threadLabels_1 labelId, threadId
 */
module.exports = (sequelize) => {
  return sequelize.define('threadLabel', {
  }, {
    indexes: [
      // NOTE: When SQLite sets up this table, it creates an auto index in
      // the order ['labelId', 'threadId']. This is the correct index we
      // need for queries requesting Threads for a certain Label.
      //
      // We need to create one more index to allow queries from the
      // reverse direction requesting Labels for a certain Thread.
      {fields: ['threadId', 'labelId']},
    ],
  });
};
