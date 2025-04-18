# Nutest

![CI/CD](https://github.com/vyadh/nutest/actions/workflows/tests.yaml/badge.svg)
![Tests](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fgist.githubusercontent.com%2Fvyadh%2F0cbdca67f966d7ea2e6e1eaf7c9083a3%2Fraw%2Ftest-summary.json&query=%24.total&label=Tests)
![Passed](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fgist.githubusercontent.com%2Fvyadh%2F0cbdca67f966d7ea2e6e1eaf7c9083a3%2Fraw%2Ftest-summary.json&query=%24.passed&label=Passed&color=%2331c654)
![Failed](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fgist.githubusercontent.com%2Fvyadh%2F0cbdca67f966d7ea2e6e1eaf7c9083a3%2Fraw%2Ftest-summary.json&query=%24.failed&label=Failed&color=red)
![Skipped](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fgist.githubusercontent.com%2Fvyadh%2F0cbdca67f966d7ea2e6e1eaf7c9083a3%2Fraw%2Ftest-summary.json&query=%24.skipped&label=Skipped&color=yellow)

A [Nushell](https://www.nushell.sh) test framework.

![An example nutest run](resources/test-run.png)

*^ Tests are structured data that can be processed just like any other table.*

![An example nutest run](resources/test-run-terminal.png)

*^ Terminal mode - test results appear as they complete.*


## Requirements

Needs Nushell 0.103.0 or later.
If Nushell 0.101.0+ is required, use Nutest v1.0.1.


## Motivation

Writing tests in Nushell is both powerful and expressive. Not only for testing Nushell code, but also other things, such as APIs, infrastructure, and other scripts. Nutest aims to encourage writing tests for all sorts of things by making testing more accessible.


## Install and Run

### Using [nupm](https://github.com/nushell/nupm)

First-time installation:

```nushell
git https://github.com/vyadh/nutest.git
do { cd nutest; git checkout <version> } # Where <version> is the latest release
nupm install nutest --path
```

Usage:

```nushell
cd <your project>
use nutest
nutest run-tests
```

### Standalone

First-time installation:

```nushell
git https://github.com/vyadh/nutest.git
do { cd nutest; git checkout <version> } # Where <version> is the latest release
cp -r nutest/nutest <a directory referenced by NU_LIB_DIRS / $env.NU_LIB_DIRS>
```

Usage:

```nushell
cd <your project>
use nutest
nutest run-tests
```


## Writing Tests

### Test Suites

A recognised test suite (a Nushell file containing tests) is recognised by nutest as a filename matching one of the following patterns somewhere within the search path, being the working directory tree or via `--path`:
- `test_*.nu`
- `test-*.nu`
- `*_test.nu`
- `*-test.nu`

### Test Commands

**Nutest** uses Nushell command attributes as a tag system for tests, test discovery will ignore non-tagged commands. It supports:

| attribute      | description                             |
|----------------|-----------------------------------------|
| `@test`        | this is the main tag to annotate tests. | 
| `@before-all`  | this is run once before all tests.      |
| `@before-each` | this is run before each test.           |
| `@after-all`   | this is run once after all tests.       |
| `@after-each`  | this is run after each test.            |
| `@ignore`      | ignores the test but still collects it. |

For example:

```nushell
use std assert
use std/testing *

@before-each
def setup [] {
  print "before each"
  {
    data: "xxx"
  }
}

@test
def "some-data is xxx" [] {
  let context = $in
  print $"Running test A: ($context.data)"
  assert equal "xxx" $context.data
}

@test
def "is one equal one" [] {
  print $"Running test B: ($in.data)"
  assert equal 1 1
}

@test
def "is two equal two" [] {
  print $"Running test C: ($in.data)"
  assert equal 2 2
}

@after-each
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

- [x] Supports using Nushell attributes (e.g. `@test`)
  - Note: The previous format of `#[test]` annotations is still supported but deprecated
- [x] Flexible test definitions
- [x] Setup/teardown with created context available to tests
- [x] Filtering of suites and tests
- [x] Terminal completions for suites and tests
- [x] Outputting test results in various ways, including queryable Nushell data tables
- [x] Test output captured and shown against test results
- [x] Parallel test execution and concurrency control
- [x] CI/CD support
  - [x] Non-zero exit code in the form of a `--fail` flag
  - [x] Test report integration compatible with a wide array of tools

### Flexible Tests

Supports running various configurations of tests scripts in flexible configurations, whether defined as a 
Nushell module or scripts that reference other Nushell commands.

Scripts being tested can either be utilised from their public interface as a module via `use <test-file>.nu` or testing their private interface by `source <test-file>.nu`.

Tests are not limited to use with just Nushell scripts. Nutest combined with the power of Nushell can be used to test command-line tools, APIs, infrastructure or bash/other scripts. Add in use of something like [WireMock](https://wiremock.org) Nushell's `http` commands and mocked HTTP endpoints can be configured for tools under tests with the convenience of Nushell records and defined with the test.   

### Context and Setup/Teardown

Specify before/after stages for each test via `[before-each]` and `[after-each]` annotations, or for all tests via `[before-all]` and `[after-all]`.

These setup/teardown commands can also be used to generate contexts used by each test, see Writing Tests section for an example.

### Filtering Suites and Tests

Allows filter of suites and tests to run via a pattern, such as:
```nushell
run-tests --match-suites api --match-tests test[0-9]
```
This will run all files that include `api` in the name and tests that contain `test` followed by a digit.

### Completions

Completions are available not only for normal command values, they are also available for suites and tests, making it easier to run specific suites and tests from the command line.

For example, typing the following and pressing tab will show all available suites that contain the word `api`:
```nushell
run-tests --match-suites api<tab>
```

Typing the following and pressing tab will show all available tests that contain the word `parse`:
```nushell
run-tests --match-tests parse<tab>
```

While test discovery is done concurrently and performant even with many test files, you can specify `--match-suites <pattern>` before `--match-tests` to greatly reduce the amount of work nutest needs to do to find the tests you want to run.

### Results Output

There are several ways to output test results in nutest:
- Displaying to the terminal
- Returning data for pipelines
- Reporting to file

#### Terminal Display

By default, nutest displays tests in a textual format so they can be displayed as they complete, or explicitly as `--display terminal`. Results can also be displayed as a table using `--display table`, which will appear at the end of the run. Examples of these two display types can be seen in the screenshots above.

Terminal output can also be turned off using `--display nothing`.

#### Returning Data

In line with the Nushell philosophy, tests results are also data that can be queried and manipulated. For example, to show only tests that need attention using:

```nushell
run-tests --returns table | where result in [SKIP, FAIL]
```

Alternatively, you can return a summary of the test run as a record using:
```nushell
run-tests --returns summary
```

Which will be shown as:
```
╭─────────┬────╮
│ total   │ 54 │
│ passed  │ 50 │
│ failed  │ 1  │
│ skipped │ 3  │
╰─────────┴────╯
```

This particular feature is used to generate the badges at the top of this README as part of the CI test run.

If a `--returns` is specified, the display report will be deactivated by default, but can be re-enabled by using a `--display` option explicitly.

The combination of `--display` and `--returns` can be used to both see the running tests and also query and manipulate the output once it is complete. It is also helpful for saving output to a file in a format not supported out of the box by the reporting functionality.

#### Reporting to File

Lastly, tests reports can be output to file. See the CI/CD Integration for more details.


### Test Output

Output from the `print` command to stdout and stderr will be captured and shown against test results, which is useful for debugging failing tests.

Output of external commands cannot currently be captured unless specifically handled in the tests by outputting using the `print` command.


### Parallel Test Execution

Tests written in Nutest are run concurrently by default.

This is a good design constraint for self-contained tests that run efficiently. The default concurrency strategy is geared for CPU-bound tests, maximising the use of available CPU cores. However, some cases may need adjustment to run efficiently. For example, IO-bound tests may benefit from lower concurrency and tests waiting on external resources may benefit by not being limited to the available CPU cores.

The level of concurrency adjusted or even disabled by specifying the `--strategy { threads: <n> }` option to the `run-tests` command, where `<n>` is the number of concurrently executing machine threads. The default handles the concurrency level automatically based on the available hardware.

See the Concurrency section under How Does It Work? for more details.

The concurrency level can also be specified at the suite-level by way of a `strategy` annotation. For example, the following strategy will run all tests in the suite sequentially:

```nushell
#[strategy]
def threads []: nothing -> record {
  { threads: 1 }
}
```

This would be beneficial in a project where most tests should run concurrently by default, but a subset perhaps require exclusive access to a resource, or one that needs a setup/tear down cycle via `before-each` and `after-each`.


### CI/CD Support

#### Exit Codes

In normal operation the tests will be run and the results will be returned as a table with the exit code always set to 0. To avoid manually checking the results, the `--fail` flag can be used to set the exit code to 1 if any tests fail. In this mode, if a test fails, the results will only be printed in the default format and cannot be interrogated due to the need to invoke `exit 1` without a result.

```nushell
run-tests --fail
```

This is useful for CI/CD pipelines where it is desirable to fail the current
job. However, note that using this directly in your shell will exit your shell session!

### Test Report Integration

In order to integrate with CI/CD tools, such as the excellent [GitHub Action to Publish Test Results](https://github.com/EnricoMi/publish-unit-test-result-action), you can output the result in the JUnit XML format. The JUnit format was chosen simply as it appears to have the widest level of support by tooling. The report can be created by by specifying the `--report` option to the `run-tests` command:

```nushell
run-tests --fail --report { type: junit, path: "test-report.xml" }
```

### Badges

![Tests](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fgist.githubusercontent.com%2Fvyadh%2F0cbdca67f966d7ea2e6e1eaf7c9083a3%2Fraw%2Ftest-summary.json&query=%24.total&label=Tests)
![Passed](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fgist.githubusercontent.com%2Fvyadh%2F0cbdca67f966d7ea2e6e1eaf7c9083a3%2Fraw%2Ftest-summary.json&query=%24.passed&label=Passed&color=%2331c654)
![Failed](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fgist.githubusercontent.com%2Fvyadh%2F0cbdca67f966d7ea2e6e1eaf7c9083a3%2Fraw%2Ftest-summary.json&query=%24.failed&label=Failed&color=red)
![Skipped](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fgist.githubusercontent.com%2Fvyadh%2F0cbdca67f966d7ea2e6e1eaf7c9083a3%2Fraw%2Ftest-summary.json&query=%24.skipped&label=Skipped&color=yellow)

The above badges serve as an example of how to directly leverage nutest for downstream use. In this case, these badges are generated from the last run on the main branch by saving a summary of the test run to a Gist and leveraging the [shields.io](https://shields.io) project by to query that data by generating a [Dynamic JSON Badge](https://shields.io/badges/dynamic-json-badge). You can see how that can be achieved by looking at [the GitHub Actions workflow in this repository](.github/workflows/tests.yaml).

## Alternative Tools

Nushell has an internal runner for the standard library `testing.nu` but is not itself part of the standard library.

The Nushell package manager [Nupm](https://github.com/nushell/nupm), provides module-focused testing for exported commands.
