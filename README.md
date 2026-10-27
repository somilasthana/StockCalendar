# StockCalendar Lite

A phone calendar for stocks you plan to buy. This release is StockCalendar Lite. One account and its buys stay on the phone. It runs on Android and iPhone from one Flutter project. The month view is the home screen. Saturday and Sunday stay empty because the market is closed. A weekday holiday still gets the buy.

Alerts are scheduled on the phone at **10:30am and 3:00pm India time (IST)** for each stock that day. The phone can be in any time zone. 10:30am IST is 5:00am UTC, which is **3:00pm in Sydney** during Australian Eastern Standard Time (UTC+10) and **4:00pm** during daylight saving (UTC+11). 3:00pm IST is 7:30pm in Sydney on standard time and 8:30pm during daylight saving.

The home-screen name is StockCalendar Lite. The Android package stays `com.mystockcalendar.stock_calendar`.

## What you need

- Flutter stable (this project was started on 3.47)
- Android Studio, or the Android SDK plus an emulator, to run it on Windows
- A Mac with Xcode to build the iPhone app

Lite does not need Firebase. A later release can turn on email login and cloud sync. Those steps stay in the Firebase section below.

## Sign-in on this phone

The first time the app is opened on a phone, the button says **Registration**. The screen asks for:

- Email
- A 4-digit PIN (`0123` is allowed)
- Secret Key, directly under the PIN

The Secret Key must match `secretKey` in `assets/data.json`. Spaces at the ends are ignored. Capital letters must match. A wrong or empty key shows **Insert the correct secret key.** and does not save the account. The email and PIN are checked first. A PIN that is not exactly four digits shows **Enter a 4 digit PIN.**

Set the key before you build, then rebuild so the installed app contains it:

```json
{
  "secretKey": "the key the person must type"
}
```

The current key is in `assets/data.json`. Sign-in after registration does not read that key. The file stays in the app for a later release.

The key is inside the APK. It stops someone who only copies the APK onto another phone and opens it. It does not stop someone who unpacks the APK and reads `assets/data.json`.

Registration stores the email and PIN on the phone and opens the calendar. The app stays signed in until **Log out**. After log out, the button says **Sign In**. That screen asks for the same email and PIN only. A wrong email or PIN shows **Email or PIN is incorrect.**

One phone holds one account. Sign in with a different email fails. **Create an account** and **Forgot password** stay in the login screen and are hidden. There is no screen to change the PIN. Clearing the app data or uninstalling removes the account and the buys. The next open is registration again, including the secret key.

An account saved by an older build used a longer password. Log out on that phone, then clear the app data, and register again with a 4-digit PIN.

## Windows setup

1. Install [Git for Windows](https://git-scm.com/download/win).
2. Install the Flutter SDK from [the Flutter Windows install page](https://docs.flutter.dev/install/manual/windows). A typical folder is `C:\Users\<you>\develop\flutter`.
3. Add `flutter\bin` to your user Path.
4. Install [Android Studio](https://developer.android.com/studio). During setup, install the Android SDK and create a virtual device that includes Google Play.
5. Open a new terminal and run:

```powershell
flutter doctor
flutter doctor --android-licenses
```

`flutter doctor` should show Flutter and Android toolchain as ready. The Xcode line stays empty on Windows. That is expected.

On the computer where this project was first set up, Flutter is at `%USERPROFILE%\develop\flutter`, a portable Git is at `%USERPROFILE%\develop\mingit`, the JDK is at `%USERPROFILE%\develop\jdk\jdk-21.0.12.1+1`, and the Android SDK is at `%USERPROFILE%\develop\android-sdk`. Flutter, Git, `JAVA_HOME`, and `ANDROID_HOME` are set for this user. Open a new terminal before running `flutter` so that Path update is picked up. A Play Store emulator named `mystock` is already created. Start it with `flutter emulators --launch mystock`, then `flutter run`.

6. In this folder:

```powershell
flutter pub get
flutter run
```

Pick the Android emulator or a phone with USB debugging turned on.

If the project lives in OneDrive and the build fails with a file-lock error, pause OneDrive sync for this folder and run `flutter run` again.

## Mac setup

1. Install Xcode from the App Store and open it once so it can finish installing components.
2. Install Flutter: [the Flutter macOS install page](https://docs.flutter.dev/install/manual/macos).
3. Install CocoaPods if `flutter doctor` asks for it: `sudo gem install cocoapods`.
4. Point Xcode at the command line tools:

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
```

5. In this folder:

```bash
flutter pub get
cd ios && pod install && cd ..
flutter run
```

Use an iPhone simulator or a phone. The first iOS build also needs the notification text in `ios/Runner/Info.plist` (already in the project after the iOS folder is generated) and a signing team in Xcode if you run on a physical iPhone.

iPhone only keeps a limited queue of scheduled alerts (about 64). Open the app every few days so it can refill the queue. Android uses the same limit here so both phones behave the same way.

## Firebase

StockCalendar Lite does not use Firebase. The account, PIN, and buys stay on the phone. The steps below are for a later release. Create an account and Forgot password are already in the login screen, hidden, so that release can show them again.

Stay on the **Spark** plan. This app does not use Cloud Functions or push messaging. Alerts are scheduled on the phone.

1. Open the [Firebase console](https://console.firebase.google.com/) and create a project. Leave Google Analytics off if you do not need it.
2. Build → Authentication → Get started → Sign-in method → enable **Email/Password**.
3. Build → Firestore Database → Create database. Start in production mode. The rules in `firestore.rules` replace the default. Each person can read and write only `users/{their uid}/series`.
4. Deploy the rules from this folder after the Firebase CLI is installed:

```powershell
npm install -g firebase-tools
firebase login
firebase deploy --only firestore:rules
```

5. Project settings → Your apps → Add app → **Android**.
   - Package name: `com.mystockcalendar.stock_calendar`
   - Download `google-services.json` and put it in `android/app/google-services.json`.
6. Add app → **iOS**.
   - Bundle ID: `com.mystockcalendar.stockCalendar`
   - Download `GoogleService-Info.plist` and put it in `ios/Runner/GoogleService-Info.plist`.
7. Install the FlutterFire CLI and generate the Dart config:

```powershell
dart pub global activate flutterfire_cli
flutterfire configure
```

`flutterfire configure` replaces `lib/firebase_options.dart`. Then open `lib/firebase_config.dart` and set:

```dart
const bool kFirebaseConfigured = true;
```

8. Run the app again. That later release signs in with email and password through Firebase. Forgot password sends a reset email through Firebase.

Do not create a service-account private key. The Android and iPhone config files are the only credentials the app needs. Do not commit a service-account JSON file if you download one by mistake.

### What is stored

Each buy is one document when Firebase is on:

`users/{uid}/series/{id}`

- `stockName`, `symbol`, `notes`
- `anchorDate` as `yyyy-MM-dd` (the first weekday)
- `frequency`: `none`, `days`, `weeks`, `months`, or `years`
- `interval` (used for days; otherwise 1)
- `endType`: `forever`, `count`, or `until`
- `count`, `untilDate`
- `cutBefore` when a later day was edited or deleted
- `createdAt`

On Lite, the same buys are stored on the phone. Repeated days are calculated on the phone. They are not copied into the database one day at a time.

## Repeat rules

Saturday and Sunday are never used. A holiday that falls on a weekday is still a buy, and it still counts.

- **Every N days** means every Nth weekday. The day you start on counts as the first. From Wednesday 23 Sept 2026, every 1 weekday, 10 times: 23, 24, 25, 28, 29, 30 Sept, then 1, 2, 5, 6 Oct. Friday 2 Oct is included even though the exchange is closed that day.
- Every 3 weekdays, 4 times from that Wednesday: 23 Sept, 28 Sept, 1 Oct, 6 Oct.
- **Every week** stays on the same weekday.
- **Every month** uses the same date. If that date is a weekend, that month is skipped and does not count. If the month has no such date (31 Jan to February), the buy uses the last weekday of that month.
- **Every year** follows the same rule one year apart.
- Forever, a number of times, or an until date applies to day, week, month, and year. Only the day choice has a number you can change.
- The until calendar cannot move before the start month, and it will not select a weekend or a day before the start.
- The same symbol is shown once on a day. A second save of that symbol on that day is rejected.
- Editing or deleting a repeated buy changes that day and every later day. Earlier days stay.

## Alerts

Each visible stock on a day gets its own alert at the open and another at the close. Four stocks means four alerts at 10:30am IST and four more at 3:00pm IST. Snooze is 5, 10, or 30 minutes and applies only to the alert you snooze.

Android may ask for notification permission and for alarms and reminders. Allow both so the times stay exact.

In a debug build, open the side menu, tap **StockCalendar Lite**, then **Send a test alert**. It fires a sample in about 10 seconds so you can check the banner and the snooze buttons. Release builds do not show that button. Saved buys still alert at 10:30am and 3:00pm IST.

## Tests

```powershell
flutter test
```

The tests cover the 23 Sept 2026 examples, a weekend month that is skipped, a 31st that falls in a short month, an until date, and the India time conversion. The calendar flow test registers with the secret key from `assets/data.json`, adds a buy, and opens the other views.

## Useful commands

```powershell
flutter analyze
flutter test
flutter run
flutter build apk
```

On a Mac, `flutter build ios` needs Xcode signing before it can be installed on a phone.
