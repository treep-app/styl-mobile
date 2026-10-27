# Flutter ↔ Backend wiring

The mobile app talks to the STYL API under `/api/v1`.

## Environments

| Target | Base URL |
|--------|----------|
| **Debug (`flutter run`)** | Local: `http://127.0.0.1:3000/api/v1` (Android emulator: `10.0.2.2`) |
| **TestFlight / App Store / release** | `https://api.stylaus.com/api/v1` (localhost overrides ignored) |
| Local (explicit, debug only) | `http://127.0.0.1:3000/api/v1` |
| Local (Android emulator) | `http://10.0.2.2:3000/api/v1` |

Debug console prints `STYL API: …` on launch so you can confirm the target.

## TestFlight / App Store IPA

```bash
./scripts/build_ios_testflight.sh
```

Always pins production `https://api.stylaus.com/api/v1`.

## Run against local backend

1. Start API (from `backend/`):

```bash
npm run prisma:migrate:deploy
npm run prisma:seed
npm run dev
```

Local `.env` should keep `OTP_DELIVERY=log` so codes are printed in the API terminal (and returned as `devCode`).

2. Run the app (from `mobile/`):

```bash
flutter run
```

Debug builds already use the local API. Optional flags:

```bash
flutter run --dart-define=USE_LOCAL_API=true
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:3000/api/v1
```

## Run against production

```bash
flutter run --dart-define=USE_PROD_API=true
# or explicitly:
flutter run --dart-define=API_BASE_URL=https://api.stylaus.com/api/v1
```

## Auth

- OTP length follows the API (`OTP_LENGTH`, currently 4 locally). With `OTP_DELIVERY=log`, the API returns `devCode` and the app shows it in a snackbar.
- Seeded sample phones (sign up or login after OTP):
  - Client: `+15550001111`
  - Barbers: `+15550002222`, `+15550003333`, `+15550004444`

## Layer

- `lib/core/network/` — `ApiClient`, DTOs
- `lib/core/auth/` — `AuthController` + token store (`shared_preferences`)
- Feature `*Api` classes under `features/*/data/`
