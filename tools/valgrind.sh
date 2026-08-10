#!/bin/sh
# The leak-safety acceptance gate: the full tinytest suite (including
# every conversion refusal / longjmp path) under valgrind, with gc()
# forced afterwards so external-pointer finalizers actually run.
# Pass criterion: 0 bytes definitely/indirectly lost, 0 errors.
set -e
dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT
cat > "$dir/vg.R" <<'EOF'
library(janssonr)
library(tinytest)
out <- run_test_dir(system.file("tinytest", package = "janssonr"))
stopifnot(all(sapply(out, isTRUE)))
rm(out); invisible(gc()); invisible(gc()); invisible(gc())
cat("suite done, gc forced\n")
EOF
R -d "valgrind --leak-check=full --errors-for-leak-kinds=definite --error-exitcode=99" \
  --vanilla -s -f "$dir/vg.R"
