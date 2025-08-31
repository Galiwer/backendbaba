# Health Records Backend - Railway Deployment

A Ballerina-based health records management system deployed on Railway.

## 🚀 Quick Start

### Prerequisites
- Railway CLI: `npm install -g @railway/cli`
- Railway account at [railway.app](https://railway.app)

### Deployment Steps

1. **Login to Railway**:
   ```bash
   railway login
   ```

2. **Link to your Railway project**:
   ```bash
   railway link
   ```

3. **Deploy**:
   ```bash
   railway up
   ```

4. **Environment Variables** (Railway sets these automatically for internal communication):
   ```
   MYSQL_HOST=mysql.railway.internal (auto-set by Railway)
   MYSQL_USER=root
   MYSQL_PASSWORD=your-railway-mysql-password
   MYSQL_DATABASE=railway
   ```

## 📋 Project Structure

- `main.bal` - Main Ballerina application
- `Ballerina.toml` - Ballerina project configuration
- `Dockerfile` - Multi-stage Docker build
- `railway.json` - Railway deployment configuration
- `deploy-to-railway.sh` - Deployment script
- `test-railway-deployment.sh` - Testing script

## 🔧 Environment Variables

### Railway Internal Communication
When both backend and MySQL are on Railway, these are automatically set:
- `MYSQL_HOST` - `mysql.railway.internal` (auto-set by Railway)
- `MYSQL_USER` - `root`
- `MYSQL_PASSWORD` - Railway MySQL password
- `MYSQL_DATABASE` - `railway`

### Optional
- `MYSQL_PORT` - MySQL port (default: 3306)
- `MYSQL_URI` - Complete MySQL connection string

## 🧪 Testing

Test your deployment:
```bash
./test-railway-deployment.sh https://your-app.railway.app
```

## 📚 Documentation

See [RAILWAY_DEPLOYMENT.md](RAILWAY_DEPLOYMENT.md) for detailed deployment instructions.

## 🔗 API Endpoints

- `GET /health` - Health check
- `POST /health/signup` - User registration
- `POST /health/login` - User authentication
- `GET /health/records` - Get health records
- `POST /health/records` - Create health record

## 🛠️ Local Development

```bash
# Run locally with MySQL
./run-local-mysql.sh

# Run with Railway environment
./run-railway.sh
```

## 📖 License

MIT License
