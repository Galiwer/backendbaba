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

4. **Set Environment Variables** in Railway Dashboard:
   ```
   MYSQL_HOST=your-mysql-host
   MYSQL_USER=your-mysql-user
   MYSQL_PASSWORD=your-mysql-password
   MYSQL_DATABASE=your-mysql-database
   ```

## 📋 Project Structure

- `main.bal` - Main Ballerina application
- `Ballerina.toml` - Ballerina project configuration
- `Dockerfile` - Multi-stage Docker build
- `railway.json` - Railway deployment configuration
- `deploy-to-railway.sh` - Deployment script
- `test-railway-deployment.sh` - Testing script

## 🔧 Environment Variables

### Required
- `MYSQL_HOST` - MySQL database host
- `MYSQL_USER` - MySQL username
- `MYSQL_PASSWORD` - MySQL password
- `MYSQL_DATABASE` - MySQL database name

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
