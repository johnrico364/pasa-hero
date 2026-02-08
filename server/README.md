# PasaHero Backend Server

Express.js backend server with Firebase Admin SDK integration.

## Setup

### 1. Install Dependencies

```bash
npm install
```

### 2. Configure Firebase Admin SDK

You need to download your Firebase service account key:

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **pasaherodb**
3. Click ⚙️ → **Project Settings**
4. Go to **"Service accounts"** tab
5. Click **"Generate new private key"**
6. Save the downloaded JSON file as `serviceAccountKey.json` in the `server` directory

**⚠️ Important:** Never commit `serviceAccountKey.json` to git! It's already in `.gitignore`.

### 3. Configure Environment Variables

Copy `.env.example` to `.env` and update if needed:

```bash
cp .env.example .env
```

Edit `.env` and set:
- `PORT`: Server port (default: 3000)
- `ALLOWED_ORIGINS`: Comma-separated list of allowed CORS origins
- `GOOGLE_APPLICATION_CREDENTIALS`: Path to service account key (if using file)

### 4. Run the Server

**Development mode (with auto-reload):**
```bash
npm run dev
```

**Production mode:**
```bash
npm start
```

## API Endpoints

### Health Check
- `GET /health` - Server health status

### Users API
- `GET /api/users` - Get all users
- `GET /api/users/:id` - Get user by ID
- `PUT /api/users/:id` - Update user
- `DELETE /api/users/:id` - Delete user

### Authentication
- `POST /api/auth/verify` - Verify Firebase ID token
  - Body: `{ "idToken": "..." }`

## Testing

Test the server is running:
```bash
curl http://localhost:3000/health
```

## Troubleshooting

### Firebase Admin SDK Not Initialized

If you see the warning "Firebase Admin SDK not initialized":
1. Make sure `serviceAccountKey.json` exists in the `server` directory
2. Or set `FIREBASE_SERVICE_ACCOUNT` environment variable with the JSON content
3. Check that the service account has proper permissions in Firebase Console

### CORS Errors

If you get CORS errors:
1. Update `ALLOWED_ORIGINS` in `.env` to include your frontend URL
2. Make sure the origin matches exactly (including protocol and port)

### Port Already in Use

If port 3000 is already in use:
1. Change `PORT` in `.env` to a different port
2. Or kill the process using port 3000
