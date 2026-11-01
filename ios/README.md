# Native Restaurant Passport for iPhone

Open **Passport.xcodeproj** with Xcode 16 or newer, choose the Passport scheme and an installed iPhone simulator, then Run. Minimum iOS 17. For your own iPhone, select your Apple signing team and a unique bundle identifier. No third-party iOS packages are required. `python3 generate_project.py` regenerates the committed Xcode project after adding Swift files.

## Design and features

Native SwiftUI, not a web wrapper: black/white controls, serif editorial headings, monochrome food-photo backgrounds, high-contrast white forms, labelled icons and Dynamic Type. Personal visit photos keep their colour. Bundled stock backgrounds work offline, never represent recommended venues and make no remote image requests.

Five tabs:
- Passport: unique restaurants, visits, spending, rated-visit average, per-visit/per-person spending, most visited/highest rated, cuisines and monthly spending.
- History: restaurant/dish/place/notes search; cuisine/minimum-rating/favourite filters; newest/rating/cost sorting; detail/edit/repeat visit; ratings, AUD cost, party size, order/notes, favourite/revisit choice and offline food photo.
- Discover: entered-area or explicit one-shot GPS search, selectable radius, Apple Maps nearby restaurants/cafes/bakeries, map links and save-for-later. Optional separate Google popularity results.
- Want to visit: saved places, price/cuisine/location sorting, notes, edit/delete and Mark visited. The saved place is removed atomically only after the visit is saved.
- Backup: full JSON merge/import/export, CSV, Undo, unreadable-storage recovery and discovery configuration.

## Bring across existing data

On the original website, in the browser that holds your data: **Backup → Save backup (JSON)**. Keep an independent copy in Files. In the native app: **Backup → Import website or native backup → confirm import**. Safari IndexedDB cannot be directly accessed by a separate native app.

Supports the original `{app:"restaurant-passport",version:1,visits:[],wants:[]}` export, unwrapped legacy state and arrays of complete visits. IDs, civil dates, notes, original ratings/costs, photos, saved places and unknown fields are preserved. Imports merge missing IDs; existing records win ID conflicts. Duplicates within a supplied file, unsupported versions, invalid dates/amounts/ratings/people or malformed/oversized photo data are rejected before replacement. There is no hidden seeded personal data. Native JSON can be imported by the original website, which reads its supported fields (its existing cleaner can drop unknown custom metadata).

Every saved change/import/deletion retains one previous full snapshot for Undo. There is no automatic sync. Data and recovery files use complete iOS file protection. Unreadable existing storage blocks overwrites and allows original-file export for recovery. Full JSON includes photos/notes; keep it private. Backups are limited to 100 MB; individual embedded photos to 10 MB. New selected images up to 20 MB are reduced to a maximum 1400-pixel side and converted to metadata-free JPEG. No full photo-library permission is requested: PhotosPicker grants selected-image access. Existing photo data is retained unchanged during import. Keep original photos elsewhere if desired.

## Trending and nearby coverage

The Discover screen distinguishes **nearby matches**, **Google popularity**, and unavailable **recent trend growth**. There is no verified live social/trending feed, review-velocity signal or invented trend score. The section proposes places using available nearby/popularity signals, not a claim that those restaurants are currently going viral.

Apple Maps search works without an API key or server. Location permission is optional; an entered suburb/city is resolved through Apple Maps and shown before restaurant lookup. GPS is requested only after tapping Use my location, to kilometre-level accuracy, and the chosen centre is rounded to three decimals. Nearby results are filtered to the selected radius. Apple coverage is not a popularity ranking. Offline/unavailable searches never substitute fake restaurants.

Optional Google Places Nearby Search (New) uses `POPULARITY` ordering, rating and review count where available. This is not recent growth. Set up the separate `../server` service over HTTPS with **GOOGLE_MAPS_API_KEY**, Places API (New), billing and **ACCESS_TOKEN**; then save the server URL/code under Backup → Discovery connection. No server is deployed by default. The Google API key remains server-side; only your server code is held in Keychain and is excluded from exports. Changing server origins reloads that origin's code rather than forwarding the previous one. Native requests refuse HTTP, arbitrary API paths and redirects. Only rounded coordinates/radius go to the server/Google; no dining history, notes or photos are shared.

Google content stays transient in its own attributed results section, is not plotted on Apple Maps or included in exports, and links out to Google Maps. Saving from a Google result retains only the place ID and a name/notes you enter independently, not copied ratings/addresses. Review the server's public terms/privacy for your deployment. Google coverage, pricing and regional terms apply; no live Google lookup was verified without a configured key. Confirm hours, dietary suitability and availability with each venue. There is no reservation or payments engine.

## Validation and device checks

`swift test --package-path ios` covers the portable production archive, migration, merge, data/date validation, statistics, CSV safety and discovery models. `xcodebuild -project ios/Passport.xcodeproj -scheme Passport -destination 'platform=iOS Simulator,name=<installed iPhone>' CODE_SIGNING_ALLOWED=NO test` additionally exercises persistence/Undo/corrupt-storage recovery, photo processing and mocked HTTP errors/privacy. `npm test --prefix server` runs the provider/server tests. GitHub Actions selects an installed iPhone automatically and uploads test results plus a native home-screen screenshot.

The Linux editor has no Xcode/Swift toolchain; macOS CI is the native build gate. Physical iPhone checks remain: location allow/deny, real Apple Maps coverage, photo/iCloud selection, large text/VoiceOver, backup sharing/restoring and airplane-mode access to saved data/photos. Live Google service verification requires a configured server key. No comprehensive real-time trend data is bundled.

Photography/source licences: see ASSET_CREDITS.md. Reference documentation checked 1 November 2026:
- https://developer.apple.com/documentation/mapkit/mklocalpointsofinterestrequest
- https://developers.google.com/maps/documentation/places/web-service/nearby-search
- https://developers.google.com/maps/documentation/places/web-service/policies
