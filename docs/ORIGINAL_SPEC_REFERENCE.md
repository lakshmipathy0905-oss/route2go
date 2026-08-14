# Original Specification Reference

The full Route2Go Product & Technical Specification (v1.0) and the original
One-Shot Master Build Prompt are the two PDFs you uploaded alongside this build.
Keep them in this `docs/` folder (e.g. `docs/Route2Go_Product_Technical_Specification.pdf`)
so anyone continuing the build — human or agent — has the full 41-page spec on hand
for screen-by-screen detail, edge cases, and the requirements traceability matrix.

This repository's code follows that spec's formulas and data model exactly for the
parts already built (fuel cost engine, budget engine, database schema). Where this
repo's implementation deviates from the original spec (Firebase Auth + Supabase +
flutter_map instead of the spec's Flutter + plain PostgreSQL baseline), that's an
intentional, documented substitution per the master prompt's own instructions —
not a scope reduction.
