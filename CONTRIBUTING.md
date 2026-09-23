# Contributing

## Getting started

1. Clone the repo:

       git clone git@github.com:sferik/x-ruby.git

2. Enter the repo’s directory:

       cd x-ruby

3. Install dependencies via Bundler:

       bin/setup

   The root, `x-core`, `x-uploader`, and `x-objects` each have their own bundle, so `bundle update` in the root updates only the root bundle. To update them all:

       bin/update

4. Run the default Rake task to ensure all tests pass:

       bundle exec rake

   Each of `x-core`, `x-uploader`, and `x-objects` has its own `Gemfile`, `Rakefile`, `Steepfile`, signatures, test suite, and mutation config, and can be checked on its own:

       cd x-core && bundle exec rake

   From the root, `rake test`, `rake mutant`, `rake steep`, and `rake yardstick` run each gem's task inside that gem's directory, with that gem's bundle. Append a gem's name to run one, as in `rake test:x-core`, `rake steep:x-objects`, or `rake yardstick:x`.

   On GitHub, each gem's workflow runs only when that gem, or a gem it depends on, changes. The `x` workflow runs when the meta-gem or the code and signatures of any gem change, and the linter runs when any Ruby file changes. Every workflow runs when `VERSION` changes as well, so the commit that prepares a release runs them all, which the workflow that pushes the gems waits for.

5. To release, write the new version to `VERSION`, run `rake update_versions` to write it into each gem's `version.rb`, record the release in each of the four changelogs, `CHANGELOG.md`, `x-core/CHANGELOG.md`, `x-uploader/CHANGELOG.md`, and `x-objects/CHANGELOG.md`, with the link to its changes at the foot of each, commit on `main`, and run `rake release`, which checks that the versions agree and that the branch is `main`, builds every gem, and tags the release.

6. Create a new branch for your feature or bug fix:

       git checkout -b my-new-branch

## Pull requests

Bug reports and pull requests are welcome on GitHub at https://github.com/sferik/x-ruby.

Pull requests will only be accepted if they meet all the following criteria:

1. Code must conform to [Standard Ruby](https://github.com/standardrb/standard#readme). This can be verified with:

       bundle exec rake standard

2. Code must conform to the [RuboCop rules](https://github.com/rubocop/rubocop#readme). This can be verified with:

       bundle exec rake rubocop

3. 100% line, branch, and method coverage in each gem. This can be verified with:

       bundle exec rake test

4. 100% mutation coverage in `x-core`, `x-uploader`, and `x-objects`. This can be verified with:

       bundle exec rake mutant

5. RBS type signatures (in each gem's `sig` directory). This can be verified with:

       bundle exec rake steep

6. 100% documentation coverage. This can be verified with:

       bundle exec rake yardstick
