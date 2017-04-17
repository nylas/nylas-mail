// In order to be able to represent 4-byte characters such as some emoji, we
// must use the 'utf8mb4' character set on MySQL. Any table using this
// character set can't have indexes on fields longer than this length without
// triggering the error
//
// ERROR 1071 (42000): Specified key was too long; max key length is 767 bytes
//
// (or, without sql_mode = TRADITIONAL - getting silently truncated!)
const MAX_INDEXABLE_LENGTH = 191;

export {MAX_INDEXABLE_LENGTH};
