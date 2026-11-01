# Optional popularity discovery server

Apple Maps nearby search runs directly on iPhone and needs no server/API key. This optional dependency-free Node 20+ server adds Google Places Nearby Search (New), ranked by `POPULARITY`. This ranking does not measure recent growth: no comprehensive real-time trending feed is connected. There are no fabricated results.

Deploy this directory as a Node service (for example Render: root `server`, start `npm start`). Set `ACCESS_TOKEN` to a strong unique code and `GOOGLE_MAPS_API_KEY` to a server key with Places API (New), billing and an appropriate Google quota. Restrict the key to Places API and server egress IPs where available. Keep keys out of the Xcode project. In the app: Backup → Discovery connection → HTTPS service origin and access code. There is intentionally no default deployed server or bundled secret. Without configuration, Apple nearby search and all personal passport features still work.

Authenticated endpoints: GET `/api/status`; POST `/api/popular` with `{lat,lon,radius}`. Radius: 1000, 3000, 5000 or 10000 metres. Only a rounded coordinate/radius reaches Google. History/photos are never sent. Keys use headers and the Google URL is fixed; upstream redirects are refused. Requests are limited to 30/minute per connection IP (shared hosting proxies can share this limit). `/privacy` and `/terms` are public: review for your deployment. Apply Google quotas/billing alerts to bound costs.

Results are not cached or written to disk, exported, or plotted on Apple Maps. The app displays Google Maps attribution separately and opens the returned Google Maps link. Only place IDs and the user's independently entered name/notes can be retained from the Google flow; ratings/addresses are not copied into records. Optional live Google requests need your key and were not tested without it.

References checked 1 November 2026:
- https://developers.google.com/maps/documentation/places/web-service/nearby-search
- https://developers.google.com/maps/documentation/places/web-service/policies

Run `npm test` from this directory. There are no production dependencies. Use HTTPS in production; the native client refuses insecure servers and redirects.
