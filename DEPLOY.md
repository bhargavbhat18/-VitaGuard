# 🚀 VitalGuard Deployment Guide

This repository has been equipped with configuration files to deploy both the Backend (FastAPI) and Frontend Portals.
You have two options for deployment:

## Option 1: Managed Cloud platforms (Free Tier Friendly)

This setup uses **Render** for the API (supports persistent WebSockets) and **Vercel** for the UI Portals.

### A. Deploy Frontend to Vercel
1. Push your code to a GitHub repository.
2. Go to [Vercel.com](https://vercel.com/) and create a new project.
3. Import your GitHub repository.
4. Leave all build settings as default. Vercel will automatically detect the `vercel.json` and front-end code.
5. Click **Deploy**.
6. Keep note of your new domain (e.g., `vitalguard.vercel.app`).

### B. Deploy Backend API to Render
1. Go to [Render.com](https://render.com/) and connect your GitHub account.
2. Create a new **Blueprint Instance** (or go to Blueprints).
3. Connect your repository. Render will automatically detect the `render.yaml` and set up the FastAPI service.
4. **Important**: Go to your Render Dashboard -> Environment Variables, and set:
   - `MONGO_URI` (Your MongoDB Atlas connection URI).
   - Any other secrets like `TWILIO_ACCOUNT_SID` or `FIREBASE_CREDENTIALS` (if you added them).
5. Open your Render Web URL to verify it's working (e.g., `vitalguard-api.onrender.com`).

### C. Link Frontend to Backend
- Search across your `hospital_portal`, `family_portal`, and `doctor_portal` HTML/JS files for `localhost:8000`.
- Replace `http://localhost:8000` with `https://vitalguard-api.onrender.com`.
- Replace `ws://localhost:8000/ws/alerts` with `wss://vitalguard-api.onrender.com/ws/alerts`.
- Commit and Push these changes. Vercel will automatically build and update!

---

## Option 2: Docker & VPS Server (AWS, DigitalOcean, Linux)
If you own a virtual machine or server, you can deploy the complete platform in one go using Docker Compose.

### Instructions:
1. SSH into your server.
2. Clone your repository: `git clone <your-repo-url> && cd vitaguard-cit-vishwakarma`.
3. Set your MongoDB URI as an environment variable (or put it in a `.env` file):
   ```bash
   export MONGO_URI="mongodb+srv://user:pass@cluster.mongodb.net"
   ```
4. Run the containers:
   ```bash
   docker-compose up -d --build
   ```
5. Your setup is now live!
   - Portals: `http://<your-server-ip>/`
   - Backend API: `http://<your-server-ip>:8000/`

---

## What about the Mobile App?
To deploy the Flutter companion app:
1. Go to `cd mobile`
2. Run `flutter build web`
3. Deploy the resulting `build/web` folder to Firebase Hosting or Netlify:
   - Example (Firebase): `firebase init` -> `firebase deploy`
