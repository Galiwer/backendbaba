# Choreo Deployment Guide with Railway MySQL

## 🚀 **Deploy Ballerina Backend to Choreo**

### **Prerequisites:**
- Railway MySQL database (already set up)
- Choreo account
- Ballerina project ready

### **Step 1: Prepare for Choreo Deployment**

Your Ballerina application is ready for deployment. The code is configured to use Railway MySQL when deployed on Choreo.

### **Step 2: Deploy to Choreo**

1. **Go to Choreo Console**: https://console.choreo.dev/
2. **Create New Project**: Create a new project for your health records app
3. **Import Ballerina Project**: Import your `backend/ballerinahealthrec` directory
4. **Set Environment Variables**:

```
MYSQL_HOST=mysql.railway.internal
MYSQL_PORT=3306
MYSQL_USER=root
MYSQL_PASSWORD=ElBlPtqKfjEFfDBjcYzwfuqcTVTzEHCl
MYSQL_DATABASE=railway
```

### **Step 3: Deploy**

1. **Build**: Choreo will automatically build your Ballerina project
2. **Deploy**: Deploy to Choreo environment
3. **Get URL**: Note the Choreo service URL (e.g., `https://your-app.choreo.dev`)

### **Step 4: Test the Deployment**

Once deployed, test the signup functionality:

```bash
curl -X POST https://your-app.choreo.dev/health/signup \
  -H "Content-Type: application/json" \
  -d '{
    "firstName": "Test",
    "lastName": "User",
    "email": "test@example.com",
    "password": "password123",
    "gender": "male",
    "dateOfBirth": "1990-01-01",
    "phoneNumber": "1234567890"
  }'
```

### **Step 5: Update Frontend**

Update your React frontend to use the Choreo backend URL instead of localhost.

## 🔧 **Why This Works**

- **Railway Private Domain**: `mysql.railway.internal:3306` works perfectly with JDBC
- **No TCP Proxy Issues**: Direct connection within Railway's network
- **Auto-scaling**: Choreo provides auto-scaling capabilities
- **Production Ready**: Enterprise-grade deployment platform

## 📊 **Expected Results**

After deployment:
- ✅ Users will be saved to Railway MySQL
- ✅ All CRUD operations will work
- ✅ Data persistence confirmed
- ✅ Production-ready application

## 🎯 **Next Steps**

1. Deploy to Choreo
2. Test signup functionality
3. Update frontend API endpoints
4. Go live with your health records application!

---

**Note**: The local development issue with Railway TCP proxy is resolved by deploying to Choreo, where Railway's private domain works perfectly with JDBC drivers.
