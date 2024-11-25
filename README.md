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

Emits tests as a table of results that can be processed like normal Nu data. For example, you can filter the results to show only failed tests using:
```nu
testing --no-color | where result == FAIL
```

Allows before/after each/all to generate context for each test.

Captures test output for debugging and display.

Filtering of suites and tests to run via a pattern.


## Expected Features 

- Combine output and error, but perhaps add error markup (by default).
  - Colourise error output unless `--no-colour` flag is set.
- Emit non-zero exit code when a test fails to make this suitable for CI.
- Resolve TODOs or move to below roadmap/enhancements.

## Roadmap

- Test report in standard format (cargo test JSON or nextest / JUnit XML).
- Generate test coverage.
- Custom reporters. Explain use of store to translate from eventing to collected data.


## Possible Enhancements

- Test timing.
- Funky dynamic terminal UI.
- Suite/test exclusions.
- File stem pattern for gobbing to allow running tests in any file not just test ones
- Optionally allow running ignored tests.
- Streaming test results. Each suite is run in a separate nu process via `complete` and therefore each suite's results are not reported until the whole suite completed. There are some limitations here due to Nushell not being able to run processes concurrently. However, we may be able to stream the events and avoid the `complete` command to resolve this.
- Per-suite concurrency control (e.g. `#[sequential]` or `#[disable-concurrency]` annotation).
- Reporter that provides a diff of expected and actual output.


## Alternatives

Nushell has its own private runner for the standard library `testing.nu`.

There is also a runner in [nupm](https://github.com/nushell/nupm), the Nushell package manager.

Both of these runners work on modules and are not suitable for testing single scripts. This runner is generic. It works with any Nu script, single files or modules.


## How Does It Work?

Nutest discovers tests by scanning matching files in the path, sourcing that code and collecting test annotations on methods via `scope commands`. The file patterns currently detected are only `test_*.nu` and `*_test.nu` for performance of the test discovery. The latter pattern is useful when you're using Nushell to test other things so the file is alphabetically ordered close to the files being tested.

For each file with tests (a suite), dispatch the suite to run on a single Nu subshell.

Capture test success and failure as well as any output (by overriding print command) and stream as test events on stdout.

Collate all events for all suites and tests being run print the test results table.

### Concurrency

Tests written in Nutest are run concurrently by default. Assuming your tests need to run in parallel is a good design constraint for self-contained tests that run efficiently. However, if this is not practical, this can be disabled by specifying the `--threads=1` option to the `testing` command.

There are two levels of concurrency used in Nutest, leveraging `par-each`, where the following are run concurrently:
- Suites (file of tests).
- Tests within a suite.

This means that an 8-core CPU would run 8 suites concurrently and within each suite, it would run 8 tests in concurrently. This might suggest Nutest potentially causing excessive CPU context switching, and the run taking longer than is strictly needed. However, this is not necessarily the case as Nushell leverages [Rayon](https://github.com/rayon-rs/rayon) for `par-test`, which purports to be efficient at managing the number of threads and of scheduling work across available CPU cores. For more on this, see Rayon's notion of [potential concurrency](https://smallcultfollowing.com/babysteps/blog/2015/12/18/rayon-data-parallelism-in-rust/), the dynamic nature of it's [parallel iterators](https://github.com/rayon-rs/rayon?tab=readme-ov-file#parallel-iterators-and-more) and the underlying use of Rust's [available parallelism](https://doc.rust-lang.org/stable/std/thread/fn.available_parallelism.html). However, it#s still not clear how well this works across multiple processes.

Additionally, given the kinds of use-cases Nushell is used for, many tests are likely to be I/O bound.

Feedback on how well this works in practice is very welcome.

#### SQLite

Given Nutest runs as much as possible concurrently, this puts an unusual level of pressure on SQLite that collects test results and the output. For this reason, INSERTs sometimes fail and a retry mechanism has been added to attempt to insert the data again up to a particular maximum tries at which point Nutest may give up and throw an error. The retries have had some stress testing to come to a pragmatic value, but please let us know if you're seeing issues.
