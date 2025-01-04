# Planned Features / Ideas

## Known Issues

- The ordering of before/after all output is not reflected well as they are only kept in the database once for the suite and then re-produced for each test. A better strategy might be to reflect them as before-all and after-all output events in the database (using another record field?), and then query and order them appropriately in the final output.
- After-all/after-each processing may not happen if before-all/before-each commands fail:
  - Currently, a test will be marked as failed on the first before-each that fails, the test will not be run and neither will the after-each. So a before-each that creates temporary files before a failure will not be removed.
  - Similarly, execution will stop on the first after-each that fails.
  - Same for before-all and after-all.
  - We could try to accumulate as much context as possible, but it doesn't seem worth complicating the existing design currently.

## Roadmap

- Remove multi-threading from runner so we can remove weird sorting and can confirm order of events
- Test report in standard format (cargo test JSON or nextest / JUnit XML) and integrate into CI as example
- Fluent assertion module with pluggable matchers.
- Generate test coverage (in llvm-cov format to allow combining with Nushell coverage)

## Future Ideas

- Optionally write event stream to file to help debug Nutest itself.
- Better support for direct-to-stdout tests by external tools that don't use the print statement. Allow running with sequential or subshell-based processing to capture output. Or even auto-detect and re-run tests.
- Detect flaky tests by re-running failed tests a few times.
- More sophisticated change display rather than simple assertion module output, e.g. differences in records and tables, perhaps displayed as tables
    - Perhaps highlight differences in output using background colours like a diff tool.
- Allow custom reporters
- Test timing.
- Dynamic terminal UI, showing the currently executing suites and tests.
    - This will resolve not being able to see the currently running tests in the terminal reporter
    - Would include things like a progress bar, running total of completed, fails, skips, etc.
    - If we save historical test run timings, we should also estimate time left
- Exclusions of suite and/or tests.
- Allow customising of file stem pattern for gobbing to allow running tests in any file not just test ones.
- Optionally allow running ignored tests.
- Stream test results. Each suite is run in a separate nu process via `complete` and therefore each suite's results are not reported until the whole suite completed. There are some limitations here due to Nushell not being able to run processes concurrently. However, we may be able to stream the events and avoid the `complete` command to resolve this. This is ideally required for the event-based terminal UI.
