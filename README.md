# Stack Validation Prototype

**React (Vite) + Django REST Framework + Capacitor**

This is a stack validation prototype — minimal UI, minimal logic, just enough to prove each layer talks to the next.

---

## What This Validates

| Layer | Technology | What's Tested |
|-------|-----------|---------------|
| Backend API | Django + DRF + SimpleJWT | JWT auth, protected endpoints, CORS |
| Frontend SPA | React + Vite | Login flow, token storage, protected routing |
| Native Bridge | Capacitor | `@capacitor/preferences` for token storage, native platform detection |

---

## Backend Setup

```bash
cd backend
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
python manage.py migrate
python manage.py shell -c "from django.contrib.auth.models import User; User.objects.create_superuser('testuser', '', 'testpass123') if not User.objects.filter(username='testuser').exists() else None"
python manage.py runserver
```

The backend runs on `http://127.0.0.1:8000`.

---

## Frontend Setup

```bash
cd frontend
npm install
```

### To test in browser:

```bash
npm run dev
```

Open `http://localhost:5173` and login with:
- **Username:** `testuser`
- **Password:** `testpass123`

### To build and prepare for Android:

```bash
npm run build
npx cap add android
npx cap sync
```

### To test on Android emulator:

```bash
npx cap open android
```

Run from Android Studio. The app will hit `http://10.0.2.2:8000` which maps to your Mac's localhost.

---

## API Endpoints

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| POST | `/api/token/` | No | Returns `access` + `refresh` JWT tokens |
| POST | `/api/token/refresh/` | No | Returns new `access` token given a `refresh` token |
| GET | `/api/protected/` | Yes (Bearer) | Returns `{ "message": "JWT is working", "user": "<username>" }` |

---

## How to Verify the Stack Works

### Step 1: Backend is running

```bash
curl http://127.0.0.1:8000/api/token/ \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"username": "testuser", "password": "testpass123"}'
```

**Expected:** JSON response with `access` and `refresh` tokens.

### Step 2: Protected endpoint rejects unauthenticated requests

```bash
curl http://127.0.0.1:8000/api/protected/
```

**Expected:** `401 Unauthorized` response.

### Step 3: Protected endpoint works with JWT

```bash
# Use the access token from Step 1
curl http://127.0.0.1:8000/api/protected/ \
  -H "Authorization: Bearer <access_token_from_step_1>"
```

**Expected:** `{ "message": "JWT is working", "user": "testuser" }`

### Step 4: Frontend login flow (browser)

1. Start the backend: `python manage.py runserver`
2. Start the frontend: `npm run dev` (in `/frontend`)
3. Open `http://localhost:5173`
4. You should see the Login screen
5. Enter `testuser` / `testpass123` and click Sign In
6. You should be redirected to the Dashboard showing "JWT is working" and "Authenticated as: testuser"
7. Click Logout — you should return to the Login screen
8. Try navigating directly to `http://localhost:5173/dashboard` — you should be redirected back to Login (token was cleared)

### Step 5: Capacitor integration (Android)

1. Build the frontend: `npm run build`
2. Sync with Capacitor: `npx cap sync`
3. Open in Android Studio: `npx cap open android`
4. Run on an emulator
5. The app should load and behave identically to the browser version
6. Token is stored via `@capacitor/preferences` (native storage on Android, localStorage fallback in browser)

---

## Project Structure

```
├── README.md
├── backend/
│   ├── manage.py
│   ├── requirements.txt
│   ├── core/
│   │   ├── __init__.py
│   │   ├── settings.py
│   │   ├── urls.py
│   │   └── wsgi.py
│   └── api/
│       ├── __init__.py
│       ├── views.py
│       └── urls.py
└── frontend/
    ├── package.json
    ├── vite.config.js
    ├── capacitor.config.json
    ├── index.html
    └── src/
        ├── main.jsx
        ├── App.jsx
        ├── api.js
        └── pages/
            ├── Login.jsx
            └── Dashboard.jsx
```

---

## Test Credentials

| Username | Password |
|----------|----------|
| `testuser` | `testpass123` |

---

## Constraints (by design)

- No TypeScript — plain JSX only
- No CSS frameworks — inline styles only
- No Redux — React `useState` and `useEffect` only
- `CORS_ALLOW_ALL_ORIGINS = True` — prototype only, not for production
- SQLite database — prototype only
