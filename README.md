# Designer Schedule App

A Flutter scheduling app for managing daily appointments of multiple designers.

## Features

- Designer login page
- Interactive daily schedule from 09:00 to 19:00
- Tap on empty grid to add appointment
- Tap on existing appointment to edit or delete
- Prevents overlapping appointments for the same designer
- Appointments are saved separately per day (in-memory)

## Structure

- **main.dart**: All UI and logic in a single file
- **Appointment model**: `start`, `end`, `customer`, `designer`
- **In-memory storage**: `Map<String, List<Appointment>>` by date

## To Do / Future Enhancements

- Persistent storage (e.g. SQLite, Hive)
- Authentication system
- Weekly/monthly view
- Export/Import schedule

## Getting Started

```bash
flutter pub get
flutter run
