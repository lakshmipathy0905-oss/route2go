# Route2Go — Gap Analysis Report

**Date:** 2026-08-24
**Spec Version:** v3.0 (Final Master)
**Codebase State:** Post-P0 implementation, CI green

---

## Summary

| Category | Status | Notes |
|----------|--------|-------|
| P0 - MVP Core | ✅ Complete | All critical features implemented |
| P1 - Safety & Sharing | 🟡 Partial | Basic structure, needs completion |
| P2 - Offline & Group | 🟡 Shells only | Phase2Gate placeholders |
| P3 - AI & B2B | ❌ Not started | Future roadmap |

---

## Detailed Gap Analysis

### 1. Safety Features (Spec Section 11)

| Feature | Status | Files | Gap |
|---------|--------|-------|-----|
| Trusted contacts UI | ❌ Missing | - | No screen for managing trusted contacts |
| Trusted contacts backend | ❌ Missing | - | No `trusted_contacts` table/function |
| Live trip link sharing | 🟡 Partial | `trip_detail_screen.dart` | Share exists, no expiring links |
| Emergency shortcut | ❌ Missing | - | No emergency button in Live Trip |
| "I am safe" update | ❌ Missing | - | No safety status feature |
| Long-stop warning | ❌ Missing | - | No detection logic |
| Fatigue/rest reminder | ❌ Missing | - | No driving timer alerts |
| Route deviation alert | ✅ Implemented | `live_trip_screen.dart` | Off-route detection exists |

**Priority Action:** Add Safety Centre screen with trusted contacts CRUD.

---

### 2. Notifications (Spec Section 12)

| Feature | Status | Files | Gap |
|---------|--------|-------|-----|
| FCM initialization | ✅ Implemented | `fcm_service.dart` | Token registration works |
| Trip reminders | ❌ Missing | - | No scheduled notifications |
| Budget warnings | ❌ Missing | - | No budget threshold alerts |
| Fuel/charging reminders | ❌ Missing | - | No range-based alerts |
| Trip completion | 🟡 Partial | `live_trip_screen.dart` | UI only, no push notification |

**Priority Action:** Add notification scheduling edge functions.

---

### 3. Booking & Partner Layer (Spec Section 9)

| Feature | Status | Files | Gap |
|---------|--------|-------|-----|
| Book screen UI | ✅ Implemented | `book_screen.dart` | Mode selection, date picker |
| Train booking | 🟡 Partial | `booking_links.dart` | External deep link only |
| Bus booking | 🟡 Partial | `booking_links.dart` | External deep link only |
| Flight booking | 🟡 Partial | `book_screen.dart` | UI only, no results |
| Hotel booking | 🟡 Partial | `stays_screen.dart` | External link, no inventory |
| Partner adapter | ❌ Missing | - | No adapter pattern implemented |

**Priority Action:** Create partner adapter interface for future integrations.

---

### 4. AI Recommendation & Voice (Spec Section 14)

| Feature | Status | Files | Gap |
|---------|--------|-------|-----|
| Voice/TTS service | ✅ Implemented | `voice_service.dart` | Announcements in Live Trip |
| Natural language planning | ❌ Missing | - | No AI trip generation |
| AI explanations | ❌ Missing | - | No "why this route" AI |
| Voice commands | ❌ Missing | - | No wake word or commands |
| AI trip summary | ❌ Missing | - | No text generation |

**Priority Action:** Defer to P2/P3 - AI requires backend integration.

---

### 5. Offline Features (Spec Section 20, P2)

| Feature | Status | Files | Gap |
|---------|--------|-------|-----|
| Offline banner | ✅ Implemented | `app_widgets.dart` | Shows when cached |
| Offline route packages | 🟡 Shell | `phase2_gate.dart` | Placeholder only |
| Trip cache strategy | 🟡 Partial | `preferences_store.dart` | Basic local caching |
| Offline place search | ❌ Missing | - | No offline geocoding |
| Offline map tiles | ❌ Missing | - | No tile caching |

**Priority Action:** Implement tile caching and offline trip packs.

---

### 6. Group Planning (Spec Section 12, P2)

| Feature | Status | Files | Gap |
|---------|--------|-------|-----|
| Expense split field | 🟡 Partial | `expense.dart` | `splitType` field exists |
| Group split UI | 🟡 Shell | `expense_tracker_screen.dart` | Phase2Gate placeholder |
| Invite participants | ❌ Missing | - | No invitation system |
| Vote on places | ❌ Missing | - | No voting mechanism |
| Collaborative editing | ❌ Missing | - | No real-time sync |

**Priority Action:** Build group invitation and voting system.

---

### 7. Analytics (Spec Section 19)

| Feature | Status | Files | Gap |
|---------|--------|-------|-----|
| Firebase Analytics | ✅ Implemented | `profile_provider.dart` | Opt-out supported |
| iOS ATT prompt | ✅ Implemented | `tracking_permission_service.dart` | Gates analytics |
| Custom event tracking | ❌ Missing | - | No `trip_created`, `route_selected` events |
| Analytics dashboard | ❌ Missing | - | No admin analytics view |
| KPI monitoring | ❌ Missing | - | No metrics collection |

**Priority Action:** Add product event tracking per spec Section 19.

---

### 8. Accessibility (Spec Section 25)

| Feature | Status | Files | Gap |
|---------|--------|-------|-----|
| Screen-reader labels | 🟡 Partial | Various | Some `Semantics` widgets |
| Dynamic text size | 🟡 Partial | - | Uses `MediaQuery` in places |
| Reduced motion | ❌ Missing | - | No `MediaQuery.reduceMotion` check |
| Sufficient contrast | ✅ Implemented | `app_theme.dart` | Color system defined |
| Large touch targets | ✅ Implemented | Various | 44x44 minimum |

**Priority Action:** Add reduced motion support and audit semantics.

---

## Implementation Priority

### Immediate (Store Submission)

1. **Safety Centre Screen** — Trusted contacts UI + backend
2. **Product Analytics Events** — Track core funnel events
3. **Reduced Motion Support** — Accessibility compliance

### Post-Launch (P2)

1. **Offline Trip Packs** — Tile caching, offline search
2. **Group Planning** — Invitations, voting, expense splitting
3. **Notification Scheduling** — Trip reminders, budget alerts

### Future (P3)

1. **AI Assistant** — Natural language planning, explanations
2. **Partner Booking APIs** — Direct inventory integration
3. **B2B Features** — Fleet, corporate, APIs

---

## Files Requiring Attention

### New Files to Create
- `apps/mobile/lib/presentation/screens/safety/safety_centre_screen.dart`
- `apps/mobile/lib/presentation/screens/safety/trusted_contacts_screen.dart`
- `apps/mobile/lib/presentation/providers/safety_provider.dart`
- `apps/mobile/lib/data/repositories/safety_repository.dart`
- `supabase/functions/trusted-contacts/` (CRUD endpoints)
- `supabase/migrations/0008_trusted_contacts.sql`

### Files to Modify
- `apps/mobile/lib/presentation/screens/trip_planning/live_trip_screen.dart` — Add emergency button
- `apps/mobile/lib/presentation/screens/settings/settings_screen.dart` — Add Safety menu item
- `apps/mobile/lib/presentation/providers/analytics_provider.dart` — Add event tracking
- `apps/mobile/lib/main.dart` — Initialize analytics events

---

## Compliance Notes

The following spec requirements are **NOT yet implemented** and may affect store submission:

- [ ] Safety/emergency features (Section 11)
- [ ] Complete notification system (Section 12)
- [ ] Product analytics events (Section 19)
- [ ] Reduced motion accessibility (Section 25.2)

**Recommendation:** Implement Safety Centre and analytics events before store submission. Other items can be P2.
