const fs = require('fs-extra');
const glob = require('glob');
const path = require('path');
const babel = require('babel-core');

fs.removeSync("n1_cloud_dist")
fs.copySync("packages/cloud-api", "n1_cloud_dist/cloud-api")
fs.copySync("packages/cloud-workers", "n1_cloud_dist/cloud-workers")

fs.copySync("packages/cloud-core", "n1_cloud_dist/cloud-core")
fs.copySync("packages/isomorphic-core", "n1_cloud_dist/isomorphic-core")

glob.sync("n1_cloud_dist/**/*.es6", {absolute: true}).forEach((es6Path) => {
  if (/(node_modules|\.js$)/.test(es6Path)) return
  const outPath = es6Path.replace(path.extname(es6Path), '.js');
  console.log(`---> Compiling ${es6Path.slice(es6Path.indexOf("/n1_cloud_dist") + 15)}`)

  const res = babel.transformFileSync(es6Path, {
    presets: ["electron", "react"],
    plugins: ["transform-async-generator-functions"],
    sourceMaps: true,
    sourceRoot: '/',
    sourceMapTarget: path.relative("n1_cloud_dist/", outPath),
    sourceFileName: path.relative("n1_cloud_dist/", es6Path),
  });

  fs.writeFileSync(outPath, `${res.code}\n//# sourceMappingURL=${path.basename(outPath)}.map\n`);
  fs.writeFileSync(`${outPath}.map`, JSON.stringify(res.map));
  fs.unlinkSync(es6Path);
});

// Lerna bootstrap creates symlinks. Unfortunately it creates absolute
// path symlinks that reference the pre-copied, uncompiled files. This
// does a direct copy for each of the leran bootstrap links to ensure we
// don't encounter symlink path problems on prod
//
// Fix cloud-core symlinks
fs.removeSync("n1_cloud_dist/cloud-core/node_modules/isomorphic-core")
fs.copySync("n1_cloud_dist/isomorphic-core", "n1_cloud_dist/cloud-core/node_modules/isomorphic-core")

// Fix cloud-api symlinks
fs.removeSync("n1_cloud_dist/cloud-api/node_modules/isomorphic-core")
fs.removeSync("n1_cloud_dist/cloud-api/node_modules/cloud-core")
fs.copySync("n1_cloud_dist/isomorphic-core", "n1_cloud_dist/cloud-api/node_modules/isomorphic-core")
fs.copySync("n1_cloud_dist/cloud-core", "n1_cloud_dist/cloud-api/node_modules/cloud-core")

// Fix cloud-workers symlinks
fs.removeSync("n1_cloud_dist/cloud-workers/node_modules/isomorphic-core")
fs.removeSync("n1_cloud_dist/cloud-workers/node_modules/cloud-core")
fs.copySync("n1_cloud_dist/isomorphic-core", "n1_cloud_dist/cloud-workers/node_modules/isomorphic-core")
fs.copySync("n1_cloud_dist/cloud-core", "n1_cloud_dist/cloud-workers/node_modules/cloud-core")

