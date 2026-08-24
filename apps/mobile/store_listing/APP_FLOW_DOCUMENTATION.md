# Route2Go — Complete App Flow Documentation

## User Journey: From First Launch to Trip Completion

---

### 1. SPLASH SCREEN (Automatic, ~2 seconds)

**What the user sees:**
- Brand logo animation (Route2Go icon with animated route trail)
- App name "Route2Go" with tagline

**What happens:**
- App checks if onboarding was completed
- If new user → routes to Onboarding
- If returning user → routes to Home Dashboard

---

### 2. ONBOARDING (First-time users only)

**What the user sees:**
- 5 swipeable cards with illustrations:
  1. "Plan your journey" — route planning introduction
  2. "Compare transportation" — route comparison feature
  3. "Book tickets" — train/bus/flight booking
  4. "Navigate your trip" — live navigation
  5. "Save and manage journeys" — trip management

**Buttons:**
- "Skip" (top-right) — skips to Home Dashboard
- "Next" (bottom) — advances to next card
- "Get Started" (bottom, final card) — completes onboarding → Home Dashboard

---

### 3. LOGIN / AUTHENTICATION (Optional)

**What the user sees:**
- Welcome screen with Route2Go branding

**Buttons:**
- "Continue with Google" — Google OAuth sign-in
- "Continue with Email" — shows email/password fields
- "Sign In" / "Sign Up" — toggles between modes
- "Forgot password?" — password reset
- "Skip for now" — enters as Guest (no sign-in required)

**Note:** Guest mode is fully functional. Sign-in is only required for saving trips, notifications, and syncing across devices.

---

### 4. HOME DASHBOARD (Main landing after login)

**AppBar elements:**
- Route2Go wordmark (left)
- Search icon (right)
- Notifications icon (right, gated for guests)
- Avatar (right)

**Screen sections (top to bottom):**

1. **Hero Search Card:**
   - "Where do you want to go?" heading
   - "From" field — tap to enter origin
   - "To" field — tap to enter destination
   - Date selector
   - Travellers count
   - "Plan a Trip" button → Plan Trip Screen

2. **Book Your Journey:**
   - Train card → Book Screen (Train mode)
   - Bus card → Book Screen (Bus mode)
   - Flight card → Book Screen (Flight mode)

3. **Quick Access Grid (2×2):**
   - "New Trip" → Plan Trip Screen
   - "Explore" → Explore Screen
   - "Map" → Map Tab
   - "Favorites" → Favorites Screen (gated)

4. **Suggested Destinations:**
   - Horizontal scrollable cards: Goa, Jaipur, Munnar, Shimla, Pondicherry, Rishikesh
   - Tap → Plan Trip Screen with destination pre-filled

5. **Recent Trips:**
   - List of saved trips with origin → destination, date, status
   - Tap → Trip Detail Screen

---

### 5. PLAN TRIP SCREEN (Route calculation entry)

**AppBar:**
- Title: "Plan a Trip"
- Vehicles icon (right) → Vehicle Garage

**Form fields (top to bottom):**

1. **Starting Point**
   - Text field showing selected location
   - Tap → Location Picker Screen (map + search)

2. **Destination**
   - Text field showing selected location
   - Tap → Location Picker Screen (map + search)

3. **Trip Type**
   - Segmented button: "One-way" | "Round trip"

4. **Vehicle & Fuel Section**
   - Fuel type dropdown: Petrol | Diesel | EV | CNG
   - Mileage field (auto-filled from default vehicle)
   - Fuel price field (₹/litre or ₹/kWh)

5. **Budget & Travellers**
   - Budget field (₹)
   - Travellers dropdown (1–10)

6. **"Calculate Route" button** (bottom, primary CTA)
   - Validates form (origin/destination required, mileage validation)
   - Shows loading dialog → Route Results Screen

---

### 6. LOCATION PICKER SCREEN

**AppBar:**
- Title: "Choose Starting Point" or "Choose Destination"

**Map view:**
- Interactive map with draggable center pin
- Search results appear as list below map

**Search field (top):**
- Type place name or address
- Debounced search (350ms)
- Results show: name, address, category, distance

**Buttons:**
- "Use my location" (floating, bottom-right) — GPS current location
- "Use this spot" (bottom) — confirms pin location → returns to Plan Trip

---

### 7. ROUTE RESULTS SCREEN (Route comparison)

**AppBar:**
- Title: "Route Options"
- Share icon (right) — share route details

**Screen sections:**

1. **Route Map Card:**
   - Interactive map showing all route alternatives
   - Origin (green) and destination (red) markers
   - Colored polylines for each route option

2. **Compare Routes Table:**
   - Columns: Route | Distance | Time | Fuel | Toll | Total | vs Recommended
   - Route options (up to 5): Recommended, Fastest, Shortest, No Toll, etc.
   - Delta column shows +/- vs recommended route
   - Tap row to select route (highlighted)

3. **Budget Tracker Card:**
   - Shows estimated cost breakdown
   - "View" button → Budget Tracker Screen

4. **Flow CTAs (below table):**
   - "Discover places along the route" → Places Screen
   - "Find stays near the route" → Stays Screen
   - "Build your itinerary" → Itinerary Screen

5. **Transport Booking Card:**
   - Train & Bus booking links (external)

6. **"Start Navigation" button** (bottom, primary CTA)
   - → Live Trip Screen

---

### 8. BUDGET TRACKER SCREEN

**AppBar:**
- Title: "Budget Tracker"

**Visual budget meter:**
- Circular progress indicator
- Color-coded: Green (under budget) | Yellow (near limit) | Red (over budget)
- Shows: Total budget | Used amount | Remaining

**Breakdown card:**
- Transport cost
- Accommodation cost
- Food cost
- Miscellaneous
- Estimated total

**Suggestions:**
- Dynamic tips to bring trip back under budget

**Button:**
- "Find stays" → Stays Screen (when accommodation not selected)

---

### 9. PLACES ALONG ROUTE SCREEN

**AppBar:**
- Title: "Places Along Route"

**Filter controls:**
- Category chips: All | Restaurants | Attractions | Fuel Stops | Hotels
- Detour radius selector: 10 km | 30 km | 50 km

**Place cards (list):**
- Place name
- Rating (stars)
- Category tag
- Detour info: +X min, +Y km, +₹Z
- "Add to Trip" toggle button
- "Details" arrow → Place Detail Screen

**Empty state:**
- "No places found" with "Search again" button

---

### 10. STAYS NEAR ROUTE SCREEN

**AppBar:**
- Title: "Stays Near Route"

**Filter controls:**
- Max price/night field
- Min rating dropdown: Any | 4.5+ | 4.0+ | 3.5+

**Stay cards (list):**
- Hotel name
- Rating (stars)
- "Sponsored" badge (if affiliate partner)
- Price per night
- Distance from route
- Amenities icons
- "Photos & details" button → Hotel detail bottom sheet
- "Book" button → external booking URL
- "Add to itinerary" button

**Disclosure:**
- Commission disclosure badge on sponsored listings

---

### 11. ITINERARY SCREEN

**AppBar:**
- Title: "Itinerary"

**Controls:**
- Day selector chips: Day 1 | Day 2 | Day 3...
- "Driving capped at X hrs/day" safety indicator
- "Regenerate" button — recalculates schedule

**Itinerary list (per day):**
- Reorderable list items
- Item types: Place, Hotel, Restaurant, Drive
- Each item shows: time, name, estimated cost

**Buttons:**
- "Add places" → Places Screen
- "Add stays" → Stays Screen
- "Confirm Trip" (bottom, primary CTA) → Confirm Trip Screen

---

### 12. CONFIRM TRIP SCREEN

**AppBar:**
- Title: "Confirm Your Trip"

**Trip summary card:**
- Route: Origin → Destination
- Distance: X km
- Time: Y hours
- Estimated cost: ₹Z
- Places selected: N
- Stays selected: N
- Itinerary days: N

**Buttons:**
- "Start Live Trip" (primary CTA) — requests background location permission → Live Trip Screen
- "Save trip only" — saves without navigation → returns to Home with confirmation

---

### 13. LIVE TRIP SCREEN (Active navigation)

**Full-screen map:**
- Route polyline (colored line)
- Origin marker (green)
- Destination marker (red)
- User position marker (blue, animated with heading)

**Top bar:**
- Destination label
- "End trip" button

**Maneuver card (bottom):**
- Next instruction text ("Turn right onto MG Road")
- Road name
- Distance to maneuver

**Progress card:**
- Remaining distance
- Estimated arrival time
- Status label

**Control buttons:**
- "RECENTER" — re-centers map on user
- "Add stop" — search for waypoint
- "Change dest" — change destination
- "Mute"/"Unmute" — voice guidance toggle
- "Recalc" — recalculate route

**Status banners:**
- "Recalculating..." (off-route)
- "Location unavailable"
- "Arrived" overlay with "Finish trip" button

---

### 14. TRIPS DASHBOARD (Saved trips)

**AppBar:**
- Title: "My Trips"
- "Plan a trip" FAB

**Tab chips (horizontal):**
- Upcoming | Ongoing | Completed | Cancelled
- Each shows count badge

**Trip cards:**
- Origin → Destination
- Date range
- Distance
- Status badge (color-coded)
- Tap → Trip Detail Screen

**Empty state:**
- Contextual message per tab ("No upcoming trips")

---

### 15. TRIP DETAIL SCREEN

**AppBar:**
- Title: "Trip"

**Content:**
- Origin → Destination display
- Trip type, travellers, status
- Route map card (mini-map)
- Shareable summary card (route, cost, time, budget)

**Buttons:**
- "Share trip" — system share sheet
- "Expense tracker" → Expense Tracker Screen
- "Rename" — edit dialog
- "Duplicate" — copy trip
- "Delete trip" — confirmation dialog

---

### 16. EXPENSE TRACKER SCREEN

**AppBar:**
- Title: "Expenses"

**Summary:**
- Total estimated vs actual
- Category breakdown

**Expense list:**
- Icon, description, category
- Estimated amount
- Actual amount (tap to record)
- Delete button

**FAB:**
- "+" → Add Expense Screen

**Phase 2 feature:**
- Group expense splitting (gated)

---

### 17. VEHICLE GARAGE SCREEN

**AppBar:**
- Title: "My Vehicles"
- "Add vehicle" FAB

**Vehicle cards:**
- Vehicle icon, name
- Fuel type badge
- Mileage display
- Default star badge
- "Make default" button
- Edit icon → Vehicle Form Screen
- Delete icon → confirmation dialog

**Empty state:**
- Illustration + "Add a vehicle" button

---

### 18. EXPLORE SCREEN

**AppBar:**
- Title: "Explore"
- Search icon (right)

**Content:**
- "Find your next destination" heading
- Category chips: All | Heritage | Beaches | Hills | Adventure | Cities
- 2-column destination grid:
  - Jaipur, Goa, Munnar, Shimla, Rishikesh, Pondicherry, Agra, Manali, Mumbai, Bengaluru
  - Each card: gradient header, category tag, name, description, state

**Tap destination → Plan Trip Screen (pre-filled)**

---

### 19. BOOK SCREEN (Transport booking)

**AppBar:**
- Title: "Book"
- Compare icon (right)

**Mode selector tabs:**
- Train | Bus | Flight

**Form:**
- "From" field
- "To" field
- Date picker (departure)
- Round trip toggle
- Return date (when round trip)
- Travellers selector (1–6)

**Button:**
- "Search [mode]s" → Book Results Screen

**Honesty note:**
- "Live availability not connected yet" with link to open provider website

---

### 20. SEARCH SCREEN (Global search)

**AppBar:**
- Title: "Search"

**Search field:**
- Autofocus with clear button
- Debounced (300ms)

**Results:**
- Grouped by kind: Places | Hotels | Routes | Saved Trips
- Each result: icon, title, subtitle
- "Navigate" icon on geo results → Route Results

**Empty state:**
- "Type at least 2 characters"

---

### 21. PROFILE TAB

**AppBar:**
- Settings icon (right)

**Profile header:**
- Avatar, name, travel preference
- Sign in/out button

**Stats row:**
- Trips count (tap → Trips Dashboard)
- Vehicles count (tap → Vehicle Garage)

**My travel section:**
- My Vehicles → Vehicle Garage
- Favorites → Favorites Screen
- Offline route packages (Phase 2, gated)

**Support & legal section:**
- Notifications → Notifications Screen
- Help → Help & Support Screen
- Privacy → Privacy Policy Screen
- Terms → Terms of Service Screen

---

### 22. SETTINGS SCREEN

**AppBar:**
- Title: "Settings"

**Menu items:**
- Profile → Profile Edit Screen
- Notifications → Notification preferences
- Admin → Admin Dashboard (role-gated)
- Favorites → Favorites Screen
- Analytics toggle (opt-out switch)
- Privacy Policy → Privacy Screen
- Terms of Service → Terms Screen
- Help & Support → Help Screen
- Delete Account → Delete Account Screen
- App version (bottom)

---

### 23. NOTIFICATIONS SCREEN

**AppBar:**
- Title: "Notifications"

**Content:**
- Notification list with read/unread states
- Tap to mark as read
- Empty state when no notifications

---

### 24. FAVORITES SCREEN

**AppBar:**
- Title: "Favorites"

**Filter chips:**
- All | Places | Hotels | Routes | Trips

**Favorites list:**
- Icon by kind, title, subtitle
- Tap → detail screen (Place Detail or Trip Detail)

---

## COMPLETE USER FLOW DIAGRAM

```
┌─────────────────┐
│  SPLASH SCREEN  │
│  (2 sec timer)  │
└────────┬────────┘
         │
    ┌────▼────┐
    │ First   │──── No ───► HOME DASHBOARD
    │ time?   │
    └────┬────┘
         │ Yes
    ┌────▼────────┐
    │  ONBOARDING │ (5 swipeable cards)
    │  Skip/Get   │
    │  Started    │
    └────┬────────┘
         │
    ┌────▼────────┐
    │LOGIN SCREEN │
    │Google/Email │
    │Guest skip   │
    └────┬────────┘
         │
    ┌────▼────────────────────────────────────────────┐
    │              HOME DASHBOARD                      │
    │  ┌─────────────────────────────────────────┐    │
    │  │ Hero Search: From → To → Plan a Trip    │    │
    │  └─────────────────────────────────────────┘    │
    │  ┌─────────┐ ┌─────────┐ ┌─────────┐           │
    │  │ Train   │ │  Bus    │ │ Flight  │           │
    │  └─────────┘ └─────────┘ └─────────┘           │
    │  ┌──────────┐ ┌──────────┐                      │
    │  │New Trip  │ │ Explore  │                      │
    │  ├──────────┤ ├──────────┤                      │
    │  │Map       │ │Favorites │                      │
    │  └──────────┘ └──────────┘                      │
    │  Suggested destinations (horizontal scroll)     │
    │  Recent trips list                               │
    └─────────────────────────────────────────────────┘
         │
         │ "Plan a Trip"
         ▼
┌─────────────────────────────────────────────────────┐
│                 PLAN TRIP SCREEN                     │
│  ┌──────────────────────────────────────────────┐   │
│  │ Starting Point: [Tap to pick location]       │   │
│  │ Destination:    [Tap to pick location]       │   │
│  └──────────────────────────────────────────────┘   │
│  Trip Type: (●) One-way  ( ) Round trip             │
│  ┌──────────────────────────────────────────────┐   │
│  │ Fuel Type: [Petrol ▼]  Mileage: [15] km/l   │   │
│  │ Fuel Price: [₹105]  per litre               │   │
│  └──────────────────────────────────────────────┘   │
│  Budget: [₹5000]  Travellers: [2 ▼]                 │
│  ┌──────────────────────────────────────────────┐   │
│  │         [ CALCULATE ROUTE ]                  │   │
│  └──────────────────────────────────────────────┘   │
└────────────────────┬────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────┐
│              ROUTE RESULTS SCREEN                    │
│  ┌──────────────────────────────────────────────┐   │
│  │         [Interactive Route Map]              │   │
│  └──────────────────────────────────────────────┘   │
│  ┌──────────────────────────────────────────────┐   │
│  │ Compare Routes:                              │   │
│  │ Route    │Dist│Time│Fuel│Toll│Total│vs Rec.  │   │
│  │──────────│────│────│────│────│─────│─────────│   │
│  │●Recomm.  │146 │224 │850 │120 │970  │  —      │   │
│  │ Fastest  │142 │205 │825 │180 │1005 │+35/+19  │   │
│  │ Shortest │138 │245 │800 │  0 │800  │-170/-21 │   │
│  └──────────────────────────────────────────────┘   │
│  [Discover places] [Find stays] [Build itinerary]   │
│  ┌──────────────────────────────────────────────┐   │
│  │         [ START NAVIGATION ]                 │   │
│  └──────────────────────────────────────────────┘   │
└────────────────────┬────────────────────────────────┘
         │           │            │
         │           │            └────► ITINERARY ──► CONFIRM TRIP
         │           │
         │           └─────────────► STAYS ──► Add to itinerary
         │
         └─────────────────────────► PLACES ──► Add to trip
                     │
                     ▼
┌─────────────────────────────────────────────────────┐
│            CONFIRM TRIP SCREEN                       │
│  ┌──────────────────────────────────────────────┐   │
│  │ Route: Bengaluru → Mysuru                    │   │
│  │ Distance: 146 km                             │   │
│  │ Time: 3 hours 44 minutes                     │   │
│  │ Est. cost: ₹970                              │   │
│  │ Places: 3  │  Stays: 1  │  Days: 2          │   │
│  └──────────────────────────────────────────────┘   │
│  ┌──────────────────────────────────────────────┐   │
│  │      [ START LIVE TRIP ]                     │   │
│  │      [ Save trip only ]                      │   │
│  └──────────────────────────────────────────────┘   │
└────────────────────┬────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────┐
│              LIVE TRIP SCREEN                        │
│  ┌──────────────────────────────────────────────┐   │
│  │  [Destination: Mysuru]      [End trip]       │   │
│  ├──────────────────────────────────────────────┤   │
│  │                                              │   │
│  │         [Full-screen Navigation Map]         │   │
│  │         (Route line + User marker)           │   │
│  │                                              │   │
│  ├──────────────────────────────────────────────┤   │
│  │  Turn right onto Mysuru Road                 │   │
│  │  in 500 m                                    │   │
│  ├──────────────────────────────────────────────┤   │
│  │  Remaining: 120 km │ ETA: 1:45 PM            │   │
│  │  [RECENTER] [Add stop] [Mute] [Recalc]      │   │
│  └──────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────┘
```

---

## KEY APP FEATURES SUMMARY

| Feature | Screen | Description |
|---------|--------|-------------|
| Route Planning | Plan Trip | Enter origin, destination, vehicle details |
| Route Comparison | Route Results | Compare up to 5 routes by cost/time |
| Budget Tracking | Budget Tracker | Visual meter showing budget vs expenses |
| Places Discovery | Places | Find POIs along route with detour costs |
| Stay Discovery | Stays | Hotels near route with honest pricing |
| Itinerary Builder | Itinerary | Day-by-day schedule with driving caps |
| Live Navigation | Live Trip | Turn-by-turn GPS navigation |
| Trip Management | Trips Dashboard | View saved trips by status |
| Expense Tracking | Expenses | Log actual costs vs estimates |
| Vehicle Garage | Vehicles | Manage multiple vehicles |
| Transport Booking | Book | Train/bus/flight search (external) |
| Explore | Explore | Curated destination discovery |
| Global Search | Search | Unified search across all content |

---

## PRIVACY & SAFETY FEATURES

- **Guest mode:** Full functionality without sign-in
- **Location permission:** Explainer before system prompt
- **Background location:** Only requested at Live Trip start
- **Analytics opt-out:** Toggle in Settings
- **Account deletion:** Full data removal with confirmation
- **No fake data:** Honest "unavailable" labels when data missing
- **Confidence badges:** Show data source quality
- **Sponsored disclosure:** Clear labelling of affiliate content
