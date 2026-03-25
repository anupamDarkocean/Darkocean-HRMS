# Deployment Guide for Railway & Vercel

## Option 1: Deploy Backend on Railway + Frontend on Vercel (Recommended)

### Backend Deployment (Railway)

1. **Create a Railway project** at [railway.app](https://railway.app)
2. **Connect your GitHub repository**
3. **Set environment variables** in Railway dashboard:
   ```
   FRAPPE_SITE_NAME=site1.local
   DB_HOST=your_postgres_host
   DB_NAME=hrms_db
   DB_USER=postgres
   DB_PASSWORD=your_password
   REDIS_HOST=your_redis_host
   SECRET_KEY=your_secret_key
   ```
4. **Configure services:**
   - Add PostgreSQL service
   - Add Redis service  (optional but recommended)
5. **Deployment command:** The `Procfile` and `railway.json` will handle this

### Frontend Deployment (Vercel)

1. **Go to [vercel.com](https://vercel.com)** and create new project
2. **Import from GitHub** - select the `dohrms` repository
3. **Configure settings:**
   - Root Directory: `frontend`
   - Build Command: `yarn build`
   - Output Directory: `dist`
4. **Set environment variable:**
   ```
   VITE_API_URL=your_railway_backend_url
   ```
5. **Deploy**

---

## Option 2: Deploy Everything on Railway

If you prefer to keep everything in one place:

1. Create Railway project and connect GitHub
2. Add PostgreSQL and Redis services
3. The `Dockerfile` and `Procfile` will build and deploy everything
4. Set the same environment variables as Option 1

---

## Environment Variables (All Services)

### Railway Backend:
```
FRAPPE_SITE_NAME=site1.local
FRAPPE_PORT=8000
DB_TYPE=postgres
DB_HOST=<railway-postgres-host>
DB_NAME=hrms
DB_USER=postgres
DB_PASSWORD=<your-password>
REDIS_CACHE_HOST=<railway-redis-host>
CORS_ORIGINS=["https://your-vercel-frontend.vercel.app"]
```

### Vercel Frontend:
```
VITE_API_URL=https://your-railway-backend.railway.app
VITE_APP_TITLE=Darkocean HRMS
```

---

## Database Setup

After deployment, initialize the database:

### Option A: Via SSH in Railway
```bash
bench new-site site1.local
bench --site site1.local migrate
bench --site site1.local install-app hrms
```

### Option B: Via Local Bench (if available)
```bash
bench new-site site1.local -db-type postgres
bench --site site1.local install-app hrms
```

---

## Troubleshooting

**Error: "No start command detected"**
- Ensure `Procfile` is in the root directory
- Check `railway.json` has correct `startCommand`

**Frontend not loading**
- Verify `VITE_API_URL` environment variable
- Check CORS settings on backend

**Database connection errors**
- Ensure service ports are correctly configured
- Verify environment variable names match exactly

---

## Post-Deployment Steps

1. Access Railway backend URL
2. Create system admin user
3. Configure SMTP for emails
4. Set up backup strategy
5. Enable HTTPS (auto-enabled on Railway/Vercel)
