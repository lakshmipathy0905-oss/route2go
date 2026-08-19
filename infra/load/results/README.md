# Load-test results

Store the per-run evidence here:

- The summary table (template in `LOAD_TEST_PLAN.md` section 6).
- The k6 run output CSV (name like `<date>-<scenario>.csv`).
- Per-node Valhalla metrics (`docker stats` snapshots during the run).
- Any Supabase dashboard screenshots / invocation logs.

Raw CSVs can stay local-only if large; the summary table is the committed
record. A green run updates `BUILD_STATUS.md` only when all acceptance criteria
hold and these numbers are attached.