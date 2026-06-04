# MatchMate

MatchMate is a SwiftUI iOS assignment app that displays matrimonial-style profile cards backed by JSONPlaceholder users and local Core Data persistence.

## Features

- Fetches users from `https://jsonplaceholder.typicode.com/users`.
- Displays match cards in a SwiftUI `List` with profile image, name, generated age, address, email, and accept/decline actions.
- Stores profiles and decisions in Core Data for offline use.
- Allows Accept/Decline while offline; unsynced decisions show a small pending sync badge.
- Uses `NWPathMonitor` to retry pending decision sync when connectivity returns.
- Uses MVVM: SwiftUI views, `MatchListViewModel`, `MatchRepository`, `APIClient`, and Core Data persistence are separated.

## Libraries and Frameworks

- SwiftUI for UI.
- URLSession for API calls.
- Core Data for local database and persistence.
- Combine for view model/network state updates.
- Network framework for connectivity monitoring.
- AsyncImage for image loading from deterministic avatar URLs.

## Running

Open `MatchMate.xcodeproj` in Xcode 26.2 or newer and run the `MatchMate` scheme on an iOS simulator or device.

The app works without a network connection after its first successful fetch. JSONPlaceholder accepts mutation requests but does not persist them, so remote sync is represented by a successful `PATCH /users/{id}` response while Core Data remains the source of truth for decisions.
