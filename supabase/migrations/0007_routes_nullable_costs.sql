-- Route2Go — Migration 0007: allow unavailable costs in saved routes
--
-- trip-calculate honestly reports fuel_cost = NULL when no live price is
-- available (fuel_prices table empty, provider unreachable, or the manual
-- override is absent). The original schema declared fuel_cost/toll_cost as
-- NOT NULL, which made the route insert fail exactly in the "unavailable"
-- case we must never fabricate around. Make them nullable to match the
-- response contract; callers already treat them as nullable.

alter table public.routes
  alter column fuel_cost drop not null,
  alter column toll_cost drop not null;

-- total_cost is always computed (fuel ?? 0) + toll, so keep it NOT NULL,
-- but make the intent explicit with a positive default for legacy rows.
alter table public.routes
  alter column total_cost set default 0;
