(import (tests r6rs exceptions)
        (tests scheme test)
        (scheme write))
(display "Running tests for (rnrs exceptions)\n")
(run-exceptions-tests)
(report-test-results)
