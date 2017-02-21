/* eslint global-require: 0 *//* eslint prefer-template: 0 */
/* eslint quote-props: 0 */
const packager = require('electron-packager');
const path = require('path');
const util = require('util');
const tmpdir = path.resolve(require('os').tmpdir(), 'nylas-build');
const fs = require('fs-plus');
const coffeereact = require('coffee-react');
const glob = require('glob');
const babel = require('babel-core');
const symlinkedPackages = []

module.exports = (grunt) => {
  const packageJSON = grunt.config('appJSON');
  const babelPath = path.join(grunt.config('rootDir'), '.babelrc')
  const babelOptions = JSON.parse(fs.readFileSync(babelPath))

  function runCopyAPM(buildPath, electronVersion, platform, arch, callback) {
    // Move APM up out of the /app folder which will be inside the ASAR
    const apmTargetDir = path.resolve(buildPath, '..', 'apm');
    fs.moveSync(path.join(buildPath, 'apm'), apmTargetDir)

    // Move /apm/node_modules/atom-package-manager up a level. We're
    // essentially pulling the atom-package-manager module up outside of
    // the node_modules folder, which is necessary because npmV3 installs
    // nested dependencies in the same dir.
    const apmPackageDir = path.join(apmTargetDir, 'node_modules', 'atom-package-manager')
    for (const name of fs.readdirSync(apmPackageDir)) {
      fs.renameSync(path.join(apmPackageDir, name), path.join(apmTargetDir, name));
    }

    const apmSymlink = path.join(apmTargetDir, 'node_modules', '.bin', 'apm');
    if (fs.existsSync(apmSymlink)) {
      fs.unlinkSync(apmSymlink);
    }
    fs.rmdirSync(apmPackageDir);
    callback();
  }

  function runCopyPlatformSpecificResources(buildPath, electronVersion, platform, arch, callback) {
    // these files (like nylas-mailto-default.reg) go alongside the ASAR,
    // not inside it, so we need to move out of the `app` directory.
    const resourcesDir = path.resolve(buildPath, '..');
    if (platform === 'win32') {
      fs.copySync(path.resolve(grunt.config('appDir'), 'build', 'resources', 'win'), resourcesDir);
    }
    callback();
  }

  /**
   * We have to resolve the symlink paths (and cache the results) before
   * copying over the files since some symlinks may be relative paths (like
   * those created by lerna). We'll keep absolute references of those paths
   * for the symlink copy function to use after the packaging is complete.
   */
  function resolveRealSymlinkPaths(appDir) {
    console.log("---> Resolving symlinks");
    const dirs = [
      'internal_packages',
      'src',
      'node_modules',
    ];

    dirs.forEach((dir) => {
      absoluteDir = path.join(appDir, dir);
      fs.readdirSync(absoluteDir).forEach((packageName) => {
        const relativePackageDir = path.join(dir, packageName)
        const absolutePackageDir = path.join(absoluteDir, packageName)
        const realPackagePath = fs.realpathSync(absolutePackageDir).replace('/private/', '/')
        if (realPackagePath !== absolutePackageDir) {
          console.log(`  ---> Resolving '${relativePackageDir}' to '${realPackagePath}'`)
          symlinkedPackages.push({realPackagePath, relativePackageDir})
        }
      });
    });
  }

  function runCopySymlinkedPackages(buildPath, electronVersion, platform, arch, callback) {
    console.log("---> Moving symlinked node modules / internal packages into build folder.")

    symlinkedPackages.forEach(({realPackagePath, relativePackageDir}) => {
      const packagePath = path.join(buildPath, relativePackageDir)
      console.log(`  ---> Copying ${realPackagePath} to ${packagePath}`);
      fs.removeSync(packagePath);
      fs.copySync(realPackagePath, packagePath);
    });

    callback();
  }

  /**
   * We don't need the K2 folder anymore since the previous step hard
   * copied the client-sync package (and its isomorphic-core dependency)
   * into /internal_packages. The remains of the folder are N1-Cloud
   * pieces that aren't necessary
   */
  function removeUnnecessaryFiles(buildPath, electronVersion, platform, arch, callback) {
    fs.removeSync(path.join(buildPath, 'src', 'K2'))
    callback();
  }

  function runTranspilers(buildPath, electronVersion, platform, arch, callback) {
    console.log("---> Running babel and coffeescript transpilers")

    grunt.config('source:coffeescript').forEach(pattern => {
      glob.sync(pattern, {cwd: buildPath}).forEach((relPath) => {
        const coffeepath = path.join(buildPath, relPath)
        if (/(node_modules|\.js$)/.test(coffeepath)) return
        console.log(`  ---> Compiling ${coffeepath.slice(coffeepath.indexOf("/app") + 4)}`)
        const outPath = coffeepath.replace(path.extname(coffeepath), '.js');
        const res = coffeereact.compile(grunt.file.read(coffeepath), {
          bare: false,
          join: false,
          separator: grunt.util.normalizelf(grunt.util.linefeed),

          sourceMap: true,
          sourceRoot: '/',
          generatedFile: path.basename(outPath),
          sourceFiles: [path.relative(buildPath, coffeepath)],
        });
        grunt.file.write(outPath, `${res.js}\n//# sourceMappingURL=${path.basename(outPath)}.map\n`);
        grunt.file.write(`${outPath}.map`, res.v3SourceMap);
        fs.unlinkSync(coffeepath);
      });
    });

    grunt.config('source:es6').forEach(pattern => {
      glob.sync(pattern, {cwd: buildPath}).forEach((relPath) => {
        const es6Path = path.join(buildPath, relPath)
        if (/(node_modules|\.js$)/.test(es6Path)) return
        const outPath = es6Path.replace(path.extname(es6Path), '.js');
        console.log(`  ---> Compiling ${es6Path.slice(es6Path.indexOf("/app") + 4)}`)
        const res = babel.transformFileSync(es6Path, Object.assign(babelOptions, {
          sourceMaps: true,
          sourceRoot: '/',
          sourceMapTarget: path.relative(buildPath, outPath),
          sourceFileName: path.relative(buildPath, es6Path),
        }));
        grunt.file.write(outPath, `${res.code}\n//# sourceMappingURL=${path.basename(outPath)}.map\n`);
        grunt.file.write(`${outPath}.map`, JSON.stringify(res.map));
        fs.unlinkSync(es6Path);
      });
    });

    callback();
  }

  const platform = grunt.option('platform');

  // See: https://github.com/electron-userland/electron-packager/blob/master/usage.txt
  grunt.config.merge({
    'packager': {
      'app-version': packageJSON.version,
      'platform': platform,
      'protocols': [{
        name: "Nylas Protocol",
        schemes: ["nylas"],
      }, {
        name: "Mailto Protocol",
        schemes: ["mailto"],
      }],
      'dir': grunt.config('appDir'),
      'app-category-type': "public.app-category.business",
      'tmpdir': tmpdir,
      'arch': {
        'win32': 'ia32',
      }[platform],
      'icon': {
        darwin: path.resolve(grunt.config('appDir'), 'build', 'resources', 'mac', 'nylas.icns'),
        win32: path.resolve(grunt.config('appDir'), 'build', 'resources', 'win', 'nylas.ico'),
        linux: undefined,
      }[platform],
      'name': {
        darwin: 'Nylas Mail',
        win32: 'nylas',
        linux: 'nylas',
      }[platform],
      'app-copyright': `Copyright (C) 2014-${new Date().getFullYear()} Nylas, Inc. All rights reserved.`,
      'derefSymlinks': false,
      'asar': {
        'unpack': "{" + [
          '*.node',
          '**/vendor/**',
          'examples/**',
          '**/src/tasks/**',
          '**/node_modules/spellchecker/**',
          '**/node_modules/windows-shortcuts/**',
        ].join(',') + "}",
      },
      'ignore': [
        // top level dirs we never want
        '^[\\/]+arclib',
        '^[\\/]+build',
        '^[\\/]+electron',
        '^[\\/]+flow-typed',
        '^[\\/]+spec_integration',

        // general dirs we never want
        '[\\/]+gh-pages$',
        '[\\/]+docs$',
        '[\\/]+obj[\\/]+gen',
        '[\\/]+\\.deps$',

        // specific files we never want
        '\\.DS_Store$',
        '\\.jshintrc$',
        '\\.npmignore$',
        '\\.pairs$',
        '\\.travis\\.yml$',
        'appveyor\\.yml$',
        '\\.idea$',
        '\\.editorconfig$',
        '\\.lint$',
        '\\.lintignore$',
        '\\.arcconfig$',
        '\\.arclint$',
        '\\.flowconfig$',
        '\\.jshintignore$',
        '\\.gitattributes$',
        '\\.gitkeep$',
        '\\.pdb$',
        '\\.cc$',
        '\\.h$',
        '\\.d\\.ts$',
        '\\.js\\.flow$',
        '\\.map$',
        'binding\\.gyp$',
        'target\\.mk$',
        '\\.node\\.dYSM$',
        'autoconf-\\d*\\.tar\\.gz$',

        // specific (large) module bits we know we don't need
        'node_modules[\\/]+less[\\/]+dist$',
        'node_modules[\\/]+react[\\/]+dist$',
        'node_modules[\\/].*[\\/]tests?$',
        'node_modules[\\/].*[\\/]coverage$',
        'node_modules[\\/].*[\\/]benchmark$',
        '@paulbetts[\\/]+cld[\\/]+deps[\\/]+cld',
      ],
      'out': grunt.config('outputDir'),
      'overwrite': true,
      'prune': true,
      /**
       * This will automatically look for the identity in the keychain. It
       * runs the `security find-identity` command. Note that TRAVIS needs
       * us to setup the keychain first and install the identity. We do
       * this in the setup-travis-keychain-task
       */
      'osx-sign': grunt.config('taskHelpers').shouldPublishBuild(),
      'win32metadata': {
        CompanyName: 'Nylas, Inc.',
        FileDescription: 'The best email app for people and teams at work',
        LegalCopyright: `Copyright (C) 2014-${new Date().getFullYear()} Nylas, Inc. All rights reserved.`,
        ProductName: 'Nylas Mail',
      },
      // NOTE: The following plist keys can NOT be set in the
      // nylas-Info.plist since they are manually overridden by
      // electron-packager based on this config file:
      //
      // CFBundleDisplayName: 'name',
      // CFBundleExecutable: 'name',
      // CFBundleIdentifier: 'app-bundle-id',
      // CFBundleName: 'name'
      //
      // See https://github.com/electron-userland/electron-packager/blob/master/mac.js#L50
      //
      // Our own nylas-Info.plist gets extended on top of the
      // Electron.app/Contents/Info.plist. A majority of the defaults are
      // left in the Electron Info.plist file
      'extend-info': path.resolve(grunt.config('appDir'), 'build', 'resources', 'mac', 'nylas-Info.plist'),
      'app-bundle-id': "com.nylas.nylas-mail",
      'afterCopy': [
        runCopyPlatformSpecificResources,
        runCopyAPM,
        runCopySymlinkedPackages,
        removeUnnecessaryFiles,
        runTranspilers,
      ],
    },
  })

  grunt.registerTask('packager', 'Package build of Nylas Mail', function pack() {
    const done = this.async();
    const start = Date.now();

    console.log('---> Running build with options:');
    console.log(util.inspect(grunt.config.get('packager'), true, 7, true));

    const ongoing = setInterval(() => {
      const elapsed = Math.round((Date.now() - start) / 1000.0)
      console.log(`---> Packaging for ${elapsed}s`);
    }, 1000)

    resolveRealSymlinkPaths(grunt.config('appDir'))

    packager(grunt.config.get('packager'), (err, appPaths) => {
      clearInterval(ongoing)
      if (err) {
        grunt.fail.fatal(err);
        return done(err);
      }
      console.log(`---> Done Successfully. Built into: ${appPaths}`);
      return done();
    });
  });
};
