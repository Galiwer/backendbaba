# Railway Deployment Guide

This guide will help you deploy your Ballerina Health Records backend to Railway.

## Prerequisites

1. **Railway CLI**: Install the Railway CLI globally
   ```bash
   npm install -g @railway/cli
   ```

2. **Railway Account**: Sign up at [railway.app](https://railway.app)

3. **MySQL Database**: You can use Railway's MySQL service or any external MySQL database

## Quick Deployment

1. **Login to Railway**:
   ```bash
   railway login
   ```

2. **Link to your Railway project**:
   ```bash
   railway link
   ```

3. **Deploy to Railway**:
   ```bash
   railway up
   ```

4. **Set Environment Variables** in Railway Dashboard:
   - Go to your project settings
   - Navigate to Variables tab
   - Add the following variables:
     ```
     MYSQL_HOST=your-mysql-host
     MYSQL_PORT=3306
     MYSQL_USER=your-mysql-user
     MYSQL_PASSWORD=your-mysql-password
     MYSQL_DATABASE=your-mysql-database
     ```

## Environment Variables

### Required Variables
- `MYSQL_HOST`: Your MySQL database host
- `MYSQL_USER`: MySQL username
- `MYSQL_PASSWORD`: MySQL password
- `MYSQL_DATABASE`: MySQL database name

### Optional Variables
- `MYSQL_PORT`: MySQL port (default: 3306)
- `MYSQL_URI`: Complete MySQL connection string (alternative to individual variables)

## Using Railway MySQL Service (Internal Communication)

Since both your backend and MySQL are on Railway in the same account, they can communicate internally using Railway's internal networking.

1. **Create MySQL Service**:
   - In Railway dashboard, click "New Service"
   - Select "MySQL"
   - Railway will automatically set up the database

2. **Connect Your App**:
   - Railway will automatically inject MySQL environment variables
   - Your app will connect to the Railway MySQL instance using internal networking
   - This provides better security and performance

3. **Environment Variables** (automatically set by Railway for internal communication):
   ```
   MYSQL_HOST=mysql.railway.internal
   MYSQL_PORT=3306
   MYSQL_USER=root
   MYSQL_PASSWORD=your-railway-mysql-password
   MYSQL_DATABASE=railway
   ```

4. **Benefits of Internal Communication**:
   - **Security**: No external network exposure
   - **Performance**: Faster internal network communication
   - **Reliability**: Railway handles internal service discovery
   - **Cost**: No external bandwidth charges

## Database Setup

1. **Automatic Setup**: The application will automatically create required tables on first run
2. **Connection**: Railway handles the database connection automatically
3. **Persistence**: Railway MySQL data persists across deployments

## Testing Your Deployment

Once deployed, test your API endpoints:

### Health Check
```bash
curl https://your-app.railway.app/health
```

### User Signup
```bash
curl -X POST https://your-app.railway.app/health/signup \
  -H "Content-Type: application/json" \
  -d '{
    "firstName": "Test",
    "lastName": "User",
    "email": "test@example.com",
    "password": "password123",
    "gender": "male",
    "dateOfBirth": "1990-01-01"
  }'
```

## Railway Configuration

The project includes:
- `railway.json`: Railway-specific configuration
- `Dockerfile`: Multi-stage build for optimal deployment
- Environment variable handling for Railway's MySQL service

## Troubleshooting

### Common Issues

1. **Build Failures**: Ensure all dependencies are properly configured in `Ballerina.toml`
2. **Database Connection**: Verify your MySQL database is accessible and credentials are correct
3. **Environment Variables**: Double-check all environment variables are set in Railway dashboard

### Logs
- Check Railway deployment logs in the dashboard
- Monitor database connection issues
- Verify API responses

## Railway CLI Commands

```bash
# Login to Railway
railway login

# Link to project
railway link

# Deploy
railway up

# View logs
railway logs

# Open in browser
railway open

# Check status
railway status
```

## Support

For issues specific to:
- **Railway**: Check [Railway Documentation](https://docs.railway.app)
- **Ballerina**: Check [Ballerina Documentation](https://ballerina.io/learn/)
- **MySQL**: Railway handles MySQL setup automatically

## Migration from Choreo

This project has been migrated from Choreo to Railway. Key changes:
- Removed Choreo-specific deployment scripts
- Added Railway configuration (`railway.json`)
- Updated deployment instructions
- Maintained the same API endpoints and functionality
- Optimized for Railway's container-based deployment
