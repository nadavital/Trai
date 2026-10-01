# Simulator test personas

The three sample histories are `new`, `consistent`, and `returning`. They run only in a Debug simulator build. Their SwiftData store is in memory, and the sample profile disables food and weight export to Apple Health. Use a dedicated simulator named `Trai Persona QA` so its Keychain, app defaults, and account session are separate from personal testing. Create one in Xcode's Devices and Simulators window, or choose an installed device type and runtime from `xcrun simctl list devicetypes` and `xcrun simctl list runtimes` and create it with `xcrun simctl create "Trai Persona QA" <device-type-id> <runtime-id>`.

Build and install a Debug app, then launch a persona from the Mac:

```sh
xcodebuild -project Trai.xcodeproj -scheme Trai -configuration Debug -sdk iphonesimulator \
  -destination "id=$SIMULATOR_UDID" -derivedDataPath /tmp/TraiPersonaDerivedData build
SIMULATOR_UDID=<dedicated-simulator-udid> ./scripts/run_test_persona.sh \
  consistent live /tmp/TraiPersonaDerivedData/Build/Products/Debug-iphonesimulator/Trai.app
```

Choose `new` to walk through onboarding, `consistent` for recent food/workout/weight history, or `returning` for a gap since the last entries. Each launch starts with a fresh sample database. The runner refuses to install on a simulator whose name does not contain `Trai Persona QA`.

`live` sends AI requests through the app's normal staging backend route. It requires a real account session obtained through Sign in with Apple on that simulator and a real AI entitlement with quota. If the account is absent, the account gate stays visible until sign-in; no fabricated production token or subscription is installed. A previous ordinary UI-test token is discarded. The fixture photo, when used, is input to real image analysis, and its result still needs review before logging. A successful build or visible seeded data alone does not prove that hosted AI responded; verify the returned AI content and a matching staging request or log.

`deterministic` uses the existing local food-analysis fixture and offline UI-test session. It is useful for repeatable navigation and food review checks, but does not prove hosted AI. Other AI features may still need their own fixture and should not be treated as deterministic coverage.

`local-live` uses the existing Debug UI-test bootstrap against `http://127.0.0.1:8789`. The local backend must already be running with a real AI provider key, `TRAI_ENVIRONMENT=localDevelopment`, and `ALLOW_DEV_APPLE_BYPASS=true`. It applies the existing local developer subscription override, then uses the normal app AI proxy path. This proves an app-to-local-backend-to-model request when the response is verified. It does not prove hosted staging authentication, billing, or quota behavior. Run `./scripts/run_test_persona.sh consistent local-live ...` to select it.

The opt-in UI check `testPersonaLocalLiveFoodPhotoUsesRealAIAndSavesResult` runs only when `RUN_PERSONA_LOCAL_LIVE_AI_UI_TEST=1` is set on the Xcode test process. It waits for local auth, captures the test meal, checks a nonmock estimate and nonzero calories, saves it, and verifies that Nutrition shows the meal. It requires the local backend above and should run only on the dedicated simulator.

To provide an image without using a camera, append a host image path to the runner. It copies that image into the dedicated simulator's app Documents directory and passes `--test-food-image-path` to the app. With no path, the food capture test flow can use the bundled `AppStoreFoodCameraSample` asset. The app accepts the fixture only with an active Debug simulator persona. Do not use a personal photo when testing the hosted service; staging receives the analysis input.
