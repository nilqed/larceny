(import (tests r6rs programs)
        (tests scheme test)
        (scheme write))
(display "Running tests for (rnrs programs)\n")
(run-programs-tests)
(report-test-results)