#!/usr/bin/env babel-node
const childProcess = require('child_process')
const mkdirp = require('mkdirp')
const semver = require('semver')
const program = require('commander')
const pkg = require('../packages/client-app/package.json')


async function spawn(cmd, args, opts = {}) {
  return new Promise((resolve, reject) => {
    const env = Object.assign({}, process.env, opts.env || {})
    delete opts.env
    const options = Object.assign({stdio: 'inherit', env}, opts);
    const proc = childProcess.spawn(cmd, args, options)
    proc.on("error", reject)
    proc.on("exit", resolve)
  })
}

function exec(cmd, opts = {}) {
  return new Promise((resolve, reject) => {
    childProcess.exec(cmd, opts, (err, stdout) => {
      if (err) {
        return reject(err)
      }
      return resolve(stdout)
    })
  })
}

function git(subCmd, opts = {}) {
  const optsString = Object.keys(opts).reduce((prev, key) => {
    const optVal = opts[key]
    if (optVal == null) {
      return key.length > 1 ? `${prev} --${key}` : `${prev} -${key}`
    }
    return key.length > 1 ? `${prev} --${key}=${optVal}` : `${prev} -${key} ${optVal}`
  }, '')
  return exec(`git ${subCmd} ${optsString}`, {cwd: './'})
}

async function prependToFile(filepath, string) {
  mkdirp.sync('./tmp')
  await exec(`echo "${string}" > ./tmp/tmpfile`)
  await exec(`cat ${filepath} >> ./tmp/tmpfile`)
  await exec(`mv ./tmp/tmpfile ${filepath}`)
}

async function sliceFileLines(filepath, idx) {
  await exec(`tail -n +${1 + idx} ${filepath} > ./tmp/tmpfile`)
  await exec(`mv ./tmp/tmpfile ${filepath}`)
}

async function updateChangelogFile(changelogString) {
  await sliceFileLines('./packages/client-app/CHANGELOG.md', 2)
  await prependToFile('./packages/client-app/CHANGELOG.md', changelogString)
}

function getFormattedLogs(mainLog) {
  const formattedMainLog = (
    mainLog
    .filter(line => line.length > 0)
    .filter(line => !/^bump/i.test(line) && !/changelog/i.test(line))
    .map(line => `  + ${line.replace('*', '\\*')}`)
    .join('\n')
  )
  return `${formattedMainLog}\n`
}

function getChangelogHeader(nextVersion) {
  const date = new Date().toLocaleDateString()
  return (
    `# Nylas Mail Changelog

### ${nextVersion} (${date})

`
  )
}

function validateArgs(args) {
  if (args.editChangelog && !process.env.EDITOR) {
    throw new Error(`You can't edit the changelog without a default EDITOR in your env`)
  }
}

// TODO add progress indicators with ora
// TODO add options
// --update-daily-channel
// --notify
// --quiet
async function main(args) {
  const currentVersion = pkg.version
  const nextVersion = semver.inc(currentVersion, 'patch')

  validateArgs(args)

  // Pull latest changes
  try {
    await git(`checkout master`)
    await git(`pull --rebase`)
  } catch (err) {
    console.error(err)
    process.exit(1)
  }

  // Make sure working directory is clean
  try {
    await exec('git diff --exit-code && git diff --cached --exit-code')
  } catch (err) {
    console.error('Git working directory is not clean!')
    process.exit(1)
  }

  // Make sure there is a diff to build
  let mainLog = '';
  try {
    mainLog = (await git(`log ${currentVersion}..master --format='%s'`)).split('\n')
    if (mainLog.length <= 1) {
      console.error(`There are no changes to build since ${currentVersion}`)
      process.exit(1)
    }
  } catch (err) {
    console.error(err)
    process.exit(1)
  }

  // Update CHANGELOG
  try {
    const commitLogSinceLatestVersion = await getFormattedLogs(mainLog)
    const changelogHeader = getChangelogHeader(nextVersion)
    const changelogString = `${changelogHeader}${commitLogSinceLatestVersion}`
    await updateChangelogFile(changelogString)
    console.log(changelogString)
  } catch (err) {
    console.error('Could not update changelog file')
    console.error(err)
    process.exit(1)
  }

  // Allow editing
  if (args.editChangelog) {
    try {
      await spawn(process.env.EDITOR, ['./packages/client-app/CHANGELOG.md'], {stdio: 'inherit'})
    } catch (err) {
      console.error('Error editing CHANGELOG.md')
      console.error(err)
      process.exit(1)
    }
  }

  // Bump patch version in package.json
  try {
    await exec('npm --no-git-tag-version version patch', {cwd: 'packages/client-app'})
  } catch (err) {
    console.error('Could not bump version in package.json')
    console.error(err)
    process.exit(1)
  }

  if (args.noCommit) {
    return
  }

  // Commit changes
  try {
    await git('add .')
    await git(`commit -m 'bump(version): ${nextVersion}'`)
  } catch (err) {
    console.error('Could not commit changes')
    console.error(err)
    process.exit(1)
  }

  if (args.noTag) {
    return
  }

  // Tag commit
  try {
    await git(`tag ${nextVersion}`)
  } catch (err) {
    console.error('Could not tag commit')
    console.error(err)
    process.exit(1)
  }

  if (args.noPush) {
    return
  }

  // Push changes
  try {
    await git(`push origin master --tags`)
  } catch (err) {
    console.error('Could not tag commit')
    console.error(err)
    process.exit(1)
  }

  // Build locally. This should only be used when building from our in-office
  // coffee machine mac mini
  if (args.build) {
    try {
      await spawn('git', ['clean', '-xdf'])
      await spawn('cp', ['-r', '../n1-keys-and-certificates', 'packages/client-app/build/resources/certs'])
      await spawn('npm', ['install'], {env: {ONLY_CLIENT: true}})
      await spawn('npm', ['run', 'build-client'], {env: {SIGN_BUILD: true}})
      await spawn('codesign', ['--verify', '--deep', '--verbose=2', '"packages/client-app/dist/Nylas Mail-darwin-x64/Nylas Mail.app"'])
      await spawn('npm', ['run', 'upload-client'])
    } catch (err) {
      console.error('Errored while running build')
      console.error(err)
      process.exit(1)
    }

    // TODO Update `daily` channel

    // TODO send out notification email
  }

  console.log('Done!')
}

program
.version('0.0.1')
.usage('[options]')
.description('This script will bump the version in package.json, edit the changelog with the latest\n  git log (for easier editing), commit and tag the changes, and push to Github to trigger\n  a build')
.option('--edit-changelog', 'Open your $EDITOR to edit CHANGELOG before commiting version bump.')
.option('--no-commit', 'Wether to commit changes to CHANGELOG.md and package.json')
.option('--no-tag', 'Wether to tag the version bump commit (no-op if --no-commit is used)')
.option('--no-push', 'Wether to push changes to the Github remote')
.option('--build', 'Wether to build the app locally. This should only be used when building from our in-office Mac Mini by the coffee machine')
.parse(process.argv)

main(program)
