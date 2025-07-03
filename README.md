# Designer Schedule App

A Flutter scheduling app for managing daily appointments of multiple designers.

## Features

- Designer login page
- Interactive daily schedule from **09:00 to 19:00**
- Tap empty space to **add appointment**
- Tap existing appointment to **edit or delete**
- Prevents **overlapping appointments** for the same designer
- Appointments are **stored separately per day**
- **Edit designer list**: Add/remove designers dynamically
- **InteractiveViewer** support: pinch-to-zoom and drag to scroll
- In-memory data structure (data will reset when app closes)

## Structure

- **main.dart**: All UI and logic in one file
- **Appointment model**: `start`, `end`, `customer`, `designer`
- **In-memory storage**: `Map<String, List<Appointment>>` per date

## To Do / Future Enhancements

- Firebase Firestore for cross-device sync & persistent storage
- Authentication system
- Weekly / Monthly calendar view
- Export / Import schedule
- Save designer list and appointments locally or in cloud

## Getting Started

```bash
flutter pub get
flutter run
