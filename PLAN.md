# Planned Features and Ideas

## Known Issues

- The ordering of before/after all output is not reflected well as they are only kept in the database once for the suite and then re-produced for each test. A better strategy might be to reflect them as before-all and after-all output events in the database (using another record field?), and then query and order them appropriately in the final output.
- After-all/after-each processing may not happen if before-all/before-each commands fail:
  - Currently, a test will be marked as failed on the first before-each that fails, the test will not be run and neither will the after-each. So a before-each that creates temporary files before a failure will not be removed.
  - Similarly, execution will stop on the first after-each that fails.
  - Same for before-all and after-all.
  - We could try to accumulate as much context as possible, but it doesn't seem worth complicating the existing design currently.

## Milestone: Version 1.0

- WIP: Support printing to terminal and saving to file
  - Fix the need for two runs in CI (though also need to consider `--fail` with `save`)
- Inconsistency in reports in start/complete and fire-start/fire-finish events
- Exit handling on `--fail` isn't quite right, prints results even if there is no return value
- Get Topiary Nushell formatting working as commit hook (if it's readable)
- JUnit test reports:
  - Add [a badge](https://github.com/EnricoMi/publish-unit-test-result-action/?tab=readme-ov-file#create-a-badge-from-test-results) for test results in CI serving as an example
- Versioning strategy, labels and docs/automation
- Basic contributor agreement if needed

## Post v1 Roadmap

- JUnit test reports:
  - Add error information into the expected JUnit failure elements
  - Add test output
  - Investigate use of styling of errors and strip as necessary
- Support multiple report types in the same run
- Fluent assertion module with pluggable matchers.
- Generate test coverage (in llvm-cov format to allow combining with Nushell coverage)

## Future Ideas

- Support matchers in `list-tests` (a trivial win)
- Optimisation: If nothing requires test output (e.g. summary), we can avoid having to process it
- Optionally write decoded event stream to file to help debug Nutest itself.
- Optionally allow running ignored tests.
- Better support for direct-to-stdout tests by external tools that don't use the print statement. Allow running with sequential or subshell-based processing to capture output. Or even auto-detect and re-run tests.
- Detect flaky tests by re-running failed tests a few times.
- More sophisticated change display rather than simple assertion module output, e.g. differences in records and tables, perhaps displayed as tables
    - Perhaps highlight differences in output using background colours like a diff tool.
- Pluggable displays and reports
- Test timing.
- Dynamic terminal UI, showing the currently executing suites and tests.
    - This will resolve not being able to see the currently running tests in the terminal display
    - Would include things like a progress bar, running total of completed, fails, skips, etc.
    - Would retain error information and output on tail failure
    - If we save historical test run timings, we could:
      - Estimate time left
      - Provide difference reports to provide idea of regressions
- Stream test results. Each suite is run in a separate nu process via `complete` and therefore each suite's results are not reported until the whole suite completed. There are some limitations here due to not being able to process Nushell sub-processes concurrently. However, we may be able to avoid the `complete` command to resolve this. This would also help better reflect current status in the event-based terminal UI.
