#!/bin/sh
# The leak-safety acceptance gate. Installs the CURRENT checkout into a
# temporary library first (a pre-existing install could be stale), then
# runs the full tinytest suite from that temp install (including every
# conversion refusal / longjmp path) under valgrind, with gc() forced
# afterwards so external-pointer finalizers actually run. The exit
# status enforces zero definitely, indirectly, or possibly lost bytes.
set -e
pkg=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT
mkdir "$dir/lib"
echo "installing current checkout into temp library..."
R CMD INSTALL --preclean --library="$dir/lib" "$pkg" >/dev/null 2>&1
cat > "$dir/vg.R" <<'EOF'
library(janssonr)
library(tinytest)
out <- run_test_dir(system.file("tinytest", package = "janssonr"))
stopifnot(all(sapply(out, isTRUE)))
rm(out); invisible(gc()); invisible(gc()); invisible(gc())
cat("suite done, gc forced\n")
EOF
R_LIBS="$dir/lib" R -d "valgrind --leak-check=full --errors-for-leak-kinds=definite,indirect,possible --error-exitcode=99" \
  --vanilla -s -f "$dir/vg.R"
