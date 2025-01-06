# Nu-test

A [Nushell](https://www.nushell.sh) test runner.

![An example nu-test run](resources/test-run.png)

*^ Tests are structured data that can be processed just like any other table.*

![An example nu-test run](resources/test-run-terminal.png)

*^ Terminal mode - test results appear as they complete.*

## Requirements

Nushell 0.101.0 or later.

## Motivation

Writing tests in Nushell is both powerful and expressive. Not only for testing Nushell code, but also other things, such as APIs, infrastructure, and other scripts. However, Nushell doesn't currently include a test runner for Nu scripts in the standard library. While a runner is not strictly necessary, Nutest aims to encourage writing tests for scripts by making testing more easily accessible.

## Writing Tests

### Test Suites

A recognised test suite (a Nushell file containing tests) is recognised by nu-test is defined as a filename matching one of the following patterns somewhere within the path:
- `test_*.nu`
- `test-*.nu`
- `*_test.nu`
- `*-test.nu`

### Test Commands

**Nu-test** uses the command description as a tag system for tests, test discovery will ignore non-tagged commands. It supports:

| tag                 | description                             |
|---------------------|-----------------------------------------|
| **\[test\]**        | this is the main tag to annotate tests. | 
| **\[before-all\]**  | this is run once before all tests.      |
| **\[before-each\]** | this is run before each test.           |
| **\[after-all\]**   | this is run once after all tests.       |
| **\[after-each\]**  | this is run after each test.            |
| **\[ignore\]**      | ignores the test but still collects it. |

For example:

```nu
use std assert

#[before-each]
def setup [] {
  print "before each"
  {
    data: "xxx"
  }
}

#[test]
def "some-data is xxx" [] {
  let context = $in
  print $"Running test A: ($context.data)"
  assert equal "xxx" $context.data
}

#[test]
def "is one equal one" [] {
  print $"Running test B: ($in.data)"
  assert equal 1 1
}

#[test]
def "is two equal two" [] {
  print $"Running test C: ($in.data)"
  assert equal 2 2
}

#[after-each]
def cleanup [] {
  let context = $in
  print "after each"
  print $context
}
```

Will return:
```
╭───────────┬──────────────────┬────────┬─────────────────────╮
│   suite   │       test       │ result │       output        │
├───────────┼──────────────────┼────────┼─────────────────────┤
│ test_base │ is one equal one │ PASS   │ before each         │
│           │                  │        │ Running test B: xxx │
│           │                  │        │ after each          │
│           │                  │        │ {data: xxx}         │
│ test_base │ is two equal two │ PASS   │ before each         │
│           │                  │        │ Running test C: xxx │
│           │                  │        │ after each          │
│           │                  │        │ {data: xxx}         │
│ test_base │ some-data is xxx │ PASS   │ before each         │
│           │                  │        │ Running test A: xxx │
│           │                  │        │ after each          │
│           │                  │        │ {data: xxx}         │
╰───────────┴──────────────────┴────────┴─────────────────────╯
```

## Current Features

- [x] Flexible test definitions
- [x] Setup/teardown with context available to tests
- [x] Filtering of the suites and tests to run
- [x] Terminal completions for suites and tests
- [x] Reporting in various ways, including queryable Nushell data tables
- [x] Test output captured and shown against test results
- [x] CI/CD support in the form of a `--fail` flag
- [x] Parallel test execution and concurrency control

### Flexible Tests

Supports tests scripts in flexible configurations:
- Single file with both implementation and tests
- Separate implementation and test files
- Just test files only
  - This would commonly be the case when using Nushell to test other things, such as for testing bash scripts, APIs, infrastructure. All the things Nushell is great at.
- Nushell modules.

Nushell scripts being tested can either be utilised from their public interface as a module via `use <test-file>.nu` or testing their private interface by `source <test-file>.nu`.

### Context and Setup/Teardown

Specify before/after for each test via `[before-each]` and `[after-each]` annotations, or for all tests via `[before-all]` and `[after-all]`.

These setup/teardown commands can also be used to generate contexts used by each test, see Writing Tests section for ane example.

### Filtering

Allows filter of suites and tests to run via a pattern, such as:
```nu
run-tests --match-suites api --match-tests test[0-9]
```
This will run all files that include `api` in the name and tests that contain `test` followed by a digit.

### Completions

Completions are available not only for normal command values, they are also available for suites and tests, making it easier to run specific suites and tests from the command line.

For example, typing the following and pressing tab will show all available suites that contain the word `api`:
```nu
run-tests --match-suites api<tab>
```

Typing the following and pressing tab will show all available tests that contain the word `parse`:
```nu
run-tests --match-tests parse<tab>
```

While test discovery is done concurrently and quick even with many test files, you can specify `--match-suites <pattern>` before `--match-tests` to greatly reduce the amount of work nu-test needs to do to find the tests you want to run.

### Reporting

By default, there is the terminal reporter that outputs the test results as they complete. This is useful for long-running tests where you want to see the results as they happen.

It is also possible to emit test results as a normal data table that can be processed like other Nushell data. For example, you can filter the results to show only tests that need attention using:
```nu
run-tests --reporter table | where result in [SKIP, FAIL]
```

See screenshots above for examples of the output (in that case using `--reporter table-pretty`).

Finally, there is a reporter that just shows the summary of the test run:
```nu
run-tests --reporter summary
```
Will return:
```
╭─────────┬────╮
│ total   │ 54 │
│ passed  │ 50 │
│ failed  │ 1  │
│ skipped │ 3  │
╰─────────┴────╯
```

### Test Output

Output from the `print` command to stdout and stderr will be captured and shown against test results, which is useful for debugging failing tests.


### CI/CD Support

In normal operation the tests will be run and the results will be returned as a table with the exit code always set to 0. To avoid manually checking the results, the `--fail` flag can be used to set the exit code to 1 if any tests fail. In this mode, the test results will be printed in the default format and cannot be interrogated.

```nu
run-tests --fail
```

This is useful for CI/CD pipelines where it is desirable to fail the current
job. However, note that using this directly in your shell will exit your shell session!

### Parallel Test Execution

Tests written in Nutest are run concurrently by default.

This is a good design constraint for self-contained tests that run efficiently. The default concurrency strategy is geared for CPU-bound tests, maximising the use of available CPU cores. However, some cases may need adjustment to run efficiently. For example, IO-bound tests may benefit from lower concurrency and tests waiting on external resources may benefit by not being limited to the available CPU cores.

The level of concurrency adjusted or even disabled by specifying the `--strategy { threads: <n> }` option to the `run-tests` command, where `<n>` is the number of concurrently executing machine threads. The default is handling the concurrency automatically.

See the Concurrency section under How Does It Work? for more details.

The concurrency level can also be specified at the suite-level by way of a `strategy` annotation. For example, the following strategy will run all tests in the suite sequentially:

```nu
#[strategy]
def threads []: nothing -> record {
  { threads: 1 }
}
```

This would be beneficial in a project where most tests should run concurrently by default, but a subset perhaps require exclusive access to a resource, or one that needs resetting on a per-test basis.

## Alternatives

Nushell has its own private runner for the standard library `testing.nu`.

There is also a runner in [nupm](https://github.com/nushell/nupm), the Nushell package manager.

Both of these runners work on modules and so cannot be used for testing independent scripts. This runner is generic. It works with any Nu script, be that single files or modules.
