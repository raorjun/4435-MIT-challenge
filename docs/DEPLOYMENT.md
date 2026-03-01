# Deployment Guide

## Mobile App Deployment

### iOS (TestFlight)

Coming soon...

### Android (Google Play Beta)

Coming soon...

## Backend Deployment (Optional)

If you build the backend API:

### Docker
```bash
cd backend
docker build -t indoor-nav-backend .
docker run -p 8000:8000 indoor-nav-backend
```

### Heroku
```bash
heroku create indoor-nav-api
git push heroku main
```

More details coming soon...
