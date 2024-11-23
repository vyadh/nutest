# nu-test

A Nushell test runner.


## Motivation

Nushell doesn't include a test runner for Nu scripts out of the box. As a shell language, writing the odd script is Nushell's raison d'être. This project aims to encourage writing tests for those scripts by making testing extremely accessible.

The hope is that this runner will be accepted into the Nushell standard library as the value of this is much diminished if the test runner needs to be obtained separately.

Hopefully this project has been archived by the time you read this!


## Current Features

Supports tests scripts in flexible configurations:
- Single file with both implementation and tests
- Separate implementation and test files
- Just test files only
  - This would commonly be the case when using Nushell to test other things, such as for testing bash scripts, APIs, infrastructure. All the things Nushell is great at.
- Nushell modules.

Fast. Runs test suites (a file of tests) and each test in parallel with minimal Nu subshells.

Emits tests as a table of results that can be processed like normal Nu data.

Allows before/after each and before/after all to generate context for each test.

Captures test output for debugging and display.

Filtering of suites and tests to run via a pattern.


## Expected Features 

- Customise thread count
- Combine output and error, but perhaps add error markup (by default).
  - Colourise error output unless `--no-colour` flag is set.
- Emit non-zero exit code when a test fails to make this suitable for CI.
- Resolve TODOs or move to below roadmap/enhancements.

## Roadmap

- Test report in standard format (cargo test JSON or nextest / JUnit XML)
- Generate test coverage


## Possible Enhancements

- Test timing
- Funky dynamic terminal UI
- Suite/test exclusions
- Ensure the two levels of parallelism is core friendly by default given subprocesses, but also allow max to help with I/O bound tests.
- File stem pattern for gobbing to allow running tests in any file not just test ones
- Optionally allow running ignored tests.


## Alternatives

Nushell has its own private runner for the standard library `testing.nu`.

There is also a runner in [nupm](https://github.com/nushell/nupm), the Nushell package manager.

Both of these runners work on modules and are not suitable for testing single scripts. This runner is generic. It works with any Nu script, single files or modules.


## How Does It Work?

Discovers tests by scanning matching files in the path, sourcing that code and collecting test annotations on methods via `scope commands`. The file patterns currently detected are `test_*.nu` and `*_test.nu` for performance of the test discovery. The latter pattern is useful when you're using Nushell to test other things and want the file ordered close to the one being tested.

For each file with tests (a suite), dispatch the suite to run on a single Nu subshell.

Capture test success and failure as well as any output (by overriding print command) and stream as test events on stdout.

Collate all events for all suites and tests being run print the test results table.


## Limitations

Since this is written in Nushell, it cannot currently run processes in the background where we're processing the steamed output. That means that for now, test results for each suite cannot be reported until that Nu subshell completes. 
