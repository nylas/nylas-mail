/**
 * CREATE TABLE IF NOT EXISTS `threadFolders` (
 *   `createdAt` DATETIME NOT NULL,
 *   `updatedAt` DATETIME NOT NULL,
 *   `threadId` VARCHAR(65) NOT NULL REFERENCES `threads` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
 *   `folderId` VARCHAR(65) NOT NULL REFERENCES `folders` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
 *   PRIMARY KEY (`threadId`, `folderId`)
 * );
 *
 * sqlite_autoindex_threadFolders_1 (threadId, folderId)
 */
module.exports = (sequelize) => {
  return sequelize.define('threadFolder', {
  }, {
    indexes: [
      // NOTE: When SQLite sets up this table, it creates an auto index in
      // the order ['threadId', 'folderId']. This is the correct index we
      // need for queries requesting Folders for a certain Thread.
      //
      // We need to create one more index to allow queries from the
      // reverse direction requesting Threads for a certain Folder.
      {fields: ['folderId', 'threadId']},
    ],
  });
};
