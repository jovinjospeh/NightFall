# NIGHTFALL // INCO

A fictional agency-style operations dashboard and browser-based training simulation.

## Features
- Interactive OpenStreetMap with illustrative locations and public Google News searches when a marker is clicked.
- Fictional mission board with local scenario creation and completion status.
- Local-only demo chat interface.
- Optional camera preview with a simulated green night-vision-style filter.
- Photo masking utility: manually draw solid black rectangles over faces/details and export a flattened PNG.
- Fictional agent roster.

## Run locally
Open `index.html` in a modern browser. Map tiles and the Leaflet library require an internet connection. Camera access generally requires HTTPS or localhost and browser permission.

## Enable GitHub Pages
1. Open the repository's **Settings → Pages**.
2. Under **Build and deployment**, select **Deploy from a branch**.
3. Choose branch **main**, folder **/(root)**, then **Save**.
4. Wait for GitHub Pages to publish the site. The expected URL is `https://jovinjospeh.github.io/NightFall/`.

## Privacy and limitations
- No accounts, backend, persistent chat, or encryption are implemented. Chat is a local demo only.
- The camera preview and photo masking run in the browser; the app does not upload images.
- Face masking is manual, not automatic face detection. Review the exported image before sharing.
- The green camera filter is a visual effect, not actual night vision or thermal imaging.
- The map uses OpenStreetMap tiles. Marker locations are illustrative; news links open public Google News searches.
- The location button requests browser location only after the user presses it. Location is displayed in the current session and is not saved by the app.
- This is an unofficial fictional simulation and is not affiliated with any government or intelligence agency.

Made by **INCO**.
