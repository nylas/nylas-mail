# Where do I start?

Thanks for checking out Mailspring! We'd love for you to contribute. Whether you're a first-time open source contributor or an experienced developer, there are ways you can help make Mailspring great:

1. Grab an issue tagged with [Help Wanted](https://github.com/Foundry376/Mailspring/labels/help%20wanted) and dig in! We try to add context to these issues when adding the tag so you know where to get started in the codebase.

2. Triage issues that haven't been addressed. With a large community of users on many platforms, we have trouble keeping up GitHub issues and moving the project forward at the same time. If you're good at addressing issues, we're happy to give you rights to label and close issues!

# Filing an Issue

If you have a feature request or bug to report, *please* search for existing issues **including closed ones!**: https://github.com/Foundry376/Mailspring/issues?utf8=%E2%9C%93&q=is%3Aissue. If someone has already requested the feature you have in mind, upvote it using the "Add Reaction" feature - our team often sorts issues to find the most upvoted ones. For bugs, please verify that you're running the latest version of Mailspring. If you file an issue without providing detail, we may close it without comment.

# Pull requests

The first time you submit a pull request, a bot will ask you to sign a standard, bare-bones Contributor License Agreement. The CLA states that you waive any patent or copyright claims you might have to the code you're contributing. (e.g.: you can't submit a PR and then sue Mailspring for using your code.)

### Commit Format

We decided to not impose super strict commit guidelines on the community.

We're trusting you to be thoughtful, responsible, committers.

We do have a few heuristics:

- Keep commits fairly isolated. Don't jam lots of different functionality
  in 1 squashed commit. `git bisect` and `git cherry-pick` should still be
  reasonable things to do.
- Keep commits fairly significant. DO `squash` all those little file
  changes and "fixmes". Don't make it difficult to browse our history.
  Play the balance between this idea and the last point. If a commit
  doesn't deserve your time to write a long thoughtful message about, then
  squash it.
- Be hyper-descriptive in your commit messages. I care less about what
  you did (I can read the code), **I want to know WHY you did it**. Put
  that in the commit body (not the subject). Itemize the major semantic
  changes that happened.
- Read "[How to Write a Git Commit Message](http://chris.beams.io/posts/git-commit/)" if you haven't already (but don't be too prescriptivist about it!)
