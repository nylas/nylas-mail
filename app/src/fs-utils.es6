import fs from 'fs';
import Utils from './flux/models/utils';

export function atomicWriteFileSync(filepath, content) {
  const randomId = Utils.generateTempId();
  const backupPath = `${filepath}.${randomId}.bak`;
  fs.writeFileSync(backupPath, content);
  fs.renameSync(backupPath, filepath);
}
