# Railway Internal Communication Troubleshooting

## 🚨 Current Issue: Connection Refused

Your backend is getting "Connection refused" when trying to connect to `mysql.railway.internal`.

## 🔍 Step-by-Step Troubleshooting

### 1. Check MySQL Service Status

1. **Go to Railway Dashboard**
2. **Check if MySQL service is running**:
   - Look for green status indicator
   - Check if MySQL service is deployed and healthy

### 2. Verify Service Connection

1. **In Railway Dashboard**:
   - Go to your backend service
   - Click "Variables" tab
   - Check if these variables are set:
     ```
     MYSQL_HOST=mysql.railway.internal
     MYSQL_PORT=3306
     MYSQL_USER=root
     MYSQL_PASSWORD=<some-password>
     MYSQL_DATABASE=railway
     ```

### 3. Check Service Discovery

1. **Verify both services are in the same project**:
   - Backend and MySQL must be in the same Railway project
   - Check project settings

2. **Check service names**:
   - MySQL service should be named something like "MySQL" or "Database"
   - Backend service should be your app name

### 4. Alternative Connection Methods

If internal communication isn't working, try these alternatives:

#### Option A: Use External MySQL Connection
1. **Get MySQL external connection details**:
   - Go to MySQL service in Railway dashboard
   - Click "Connect" tab
   - Copy the external connection string

2. **Set environment variables manually**:
   ```
   MYSQL_HOST=<external-host>.railway.app
   MYSQL_PORT=<external-port>
   MYSQL_USER=root
   MYSQL_PASSWORD=<password>
   MYSQL_DATABASE=railway
   ```

#### Option B: Use Railway's Auto-Generated Variables
1. **Check what Railway actually set**:
   ```bash
   railway logs
   ```
   Look for the actual environment variables being used.

### 5. Manual Environment Variable Setup

If Railway isn't setting the variables automatically:

1. **Go to your backend service**
2. **Click "Variables" tab**
3. **Add these variables manually**:
   ```
   MYSQL_HOST=mysql.railway.internal
   MYSQL_PORT=3306
   MYSQL_USER=root
   MYSQL_PASSWORD=<your-mysql-password>
   MYSQL_DATABASE=railway
   ```

### 6. Check MySQL Service Configuration

1. **Verify MySQL service is properly configured**:
   - Check if MySQL is accepting connections
   - Verify the database exists
   - Check MySQL logs for any errors

### 7. Redeploy Services

1. **Redeploy MySQL service**:
   ```bash
   railway up --service mysql
   ```

2. **Redeploy backend service**:
   ```bash
   railway up --service your-backend-service
   ```

## 🔧 Quick Fix Commands

### Check Current Environment
```bash
railway logs
```

### Redeploy Everything
```bash
railway up
```

### Check Service Status
```bash
railway status
```

## 🚀 Alternative: Use External Connection

If internal communication continues to fail, use external connection:

1. **Get external MySQL details from Railway dashboard**
2. **Set environment variables**:
   ```
   MYSQL_HOST=<external-host>.railway.app
   MYSQL_PORT=<external-port>
   MYSQL_USER=root
   MYSQL_PASSWORD=<password>
   MYSQL_DATABASE=railway
   ```
3. **Redeploy**:
   ```bash
   railway up
   ```

## 📞 Next Steps

1. **Check Railway dashboard** for service status
2. **Verify environment variables** are set correctly
3. **Try external connection** if internal fails
4. **Check Railway documentation** for latest internal communication setup
5. **Contact Railway support** if issues persist

## 🔗 Useful Links

- [Railway Documentation](https://docs.railway.app)
- [Railway MySQL Service](https://docs.railway.app/databases/mysql)
- [Railway Internal Networking](https://docs.railway.app/deploy/deployments#internal-networking)
