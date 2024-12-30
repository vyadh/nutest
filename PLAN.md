# Possible Planned Features

## Roadmap

- Handle output from before/after all (ignore it? repeat for every test? custom event?)
- Fluent assertion module with pluggable matchers.
- GitHub Actions for nu-test itself
- Test report in standard format (cargo test JSON or nextest / JUnit XML)
- Generate test coverage (in llvm-cov format to allow combining with Nushell coverage)

## Future Ideas

- Better support for direct-to-stdout tests by external tools that don't use the print statement. Allow running with sequential or subshell-based processing to capture output. Or even auto-detect and re-run tests.
- Detect flaky tests by re-running failed tests a few times.
- More sophisticated change display rather than simple assertion module output, e.g. differences in records and tables, perhaps displayed as tables
    - Perhaps highlight differences in output using background colours like a diff tool.
- Allow custom reporters
    - Also document use of store to translate from event to collected data.
- Test timing.
- Dynamic terminal UI, showing the currently executing suites and tests.
    - This will resolve not being able to see the currently running tests in the terminal reporter
    - Would include things like a progress bar, running total of completed, fails, skips, etc.
    - If we save historical test run timings, we should also estimate time left
- Exclusions of suite and/or tests.
- File stem pattern for gobbing to allow running tests in any file not just test ones
- Optionally allow running ignored tests.
- Stream test results. Each suite is run in a separate nu process via `complete` and therefore each suite's results are not reported until the whole suite completed. There are some limitations here due to Nushell not being able to run processes concurrently. However, we may be able to stream the events and avoid the `complete` command to resolve this. This is ideally required for the event-based terminal UI.
- Per-suite concurrency control (e.g. `#[sequential]` or `#[disable-concurrency]` annotation). This would also avoid the need for separate test_store_success suits and use of subshells in own tests.
- There is some simplicity in the current design that means after-each processing may not happen if before commands fail:
    - Currently, a test will be marked as failed on the first before-each that fails, the test will not be run and neither will the after-each. So a before-each that creates temporary files before a failure will not be removed.
    - Similarly, execution will stop on the first after-each that fails.
    - We could try to accumulate as much context as possible, but it doesn't seem worth it.
