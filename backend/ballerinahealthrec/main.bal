import ballerina/http;
import ballerina/io;
import ballerina/os;
import ballerina/sql as sql;

import ballerina/time;
import ballerina/uuid;
import ballerina/crypto;
import ballerinax/mysql;

// Type definitions
type VaccineRecord record {|
    string name;
    string dose;
    boolean received;
    time:Date? receivedDate;
    boolean isCustom;
    int? offsetMonths;
|};

type UserGD record {|
    string gender;
    string date_of_birth;
|};

// Database configuration
final string DATABASE_NAME = getDatabaseName();

// Function to get database name from environment or use default
function getDatabaseName() returns string {
    string? envDb = os:getEnv("MYSQL_DATABASE");
    if envDb is string {
        return envDb;
    }
    return "babadb";
}

// Global MySQL client
mysql:Client? globalClient = ();

// Function to get MySQL connection string
function getMySQLConnectionString() returns string {
    string? envUri = os:getEnv("MYSQL_URI");
    if envUri is string {
        return envUri;
    }
    
    // Fallback for Railway MySQL format
    string? host = os:getEnv("MYSQL_HOST");
    string? port = os:getEnv("MYSQL_PORT");
    string? user = os:getEnv("MYSQL_USER");
    string? password = os:getEnv("MYSQL_PASSWORD");
    string? database = os:getEnv("MYSQL_DATABASE");
    
    if host is string && user is string && password is string && database is string {
        return "jdbc:mysql://" + host + ":" + (port is string ? port : "3306") + 
               "/" + database + "?user=" + user + "&password=" + password + 
                                          "&useSSL=false&allowPublicKeyRetrieval=true&autoCommit=true&serverTimezone=UTC&useUnicode=true&characterEncoding=utf8&zeroDateTimeBehavior=convertToNull&connectTimeout=60000&socketTimeout=60000&maxReconnects=10&failOverReadOnly=false&maxReconnects=10&initialTimeout=10";
    }
    
    // Force Railway MySQL connection
    error connectError = error("Railway MySQL connection required - no fallback to local database");
    panic connectError;
}

// Function to get MySQL connection string without database
function getMySQLConnectionStringNoDB() returns string {
    string? envUri = os:getEnv("MYSQL_URI");
    if envUri is string {
        // Extract host, port, user, password from URI for bootstrap
        string uri = envUri;
        if uri.startsWith("jdbc:mysql://") {
            string connectionPart = uri.substring(13);
            int? dbIndex = connectionPart.indexOf("/");
            if dbIndex is int && dbIndex > 0 {
                return "jdbc:mysql://" + connectionPart.substring(0, dbIndex);
            }
        }
        return envUri;
    }
    
    // Fallback for Railway MySQL format
    string? host = os:getEnv("MYSQL_HOST");
    string? port = os:getEnv("MYSQL_PORT");
    string? user = os:getEnv("MYSQL_USER");
    string? password = os:getEnv("MYSQL_PASSWORD");
    
    if host is string && user is string && password is string {
        return "jdbc:mysql://" + host + ":" + (port is string ? port : "3306") + 
               "?user=" + user + "&password=" + password + 
                                          "&useSSL=false&allowPublicKeyRetrieval=true&autoCommit=true&serverTimezone=UTC&useUnicode=true&characterEncoding=utf8&zeroDateTimeBehavior=convertToNull&connectTimeout=60000&socketTimeout=60000&maxReconnects=10&failOverReadOnly=false&maxReconnects=10&initialTimeout=10";
    }
    
    // Force Railway MySQL connection
    error connectError = error("Railway MySQL connection required - no fallback to local database");
    panic connectError;
}

// Bootstrap function to create database if it doesn't exist
function bootstrapDatabase() returns error? {
    io:println("Bootstrapping database...");
    
    // Check if we're using Railway MySQL or local MySQL
    string? mysqlHost = os:getEnv("MYSQL_HOST");
    io:println("DEBUG: MYSQL_HOST = ", mysqlHost);
    io:println("DEBUG: DATABASE_NAME = ", DATABASE_NAME);
    if (mysqlHost is string && mysqlHost != "" && mysqlHost != "localhost") {
        // Railway MySQL - try to create database if it doesn't exist
        io:println("Connecting to Railway MySQL and creating database if needed: ", DATABASE_NAME);
        
        // Connect without database first
        mysql:Client bootstrapClient = check new (getMySQLConnectionStringNoDB());
        
        // Create database if it doesn't exist
        sql:ParameterizedQuery createDB = `CREATE DATABASE IF NOT EXISTS railway`;
        sql:ExecutionResult|sql:Error result = bootstrapClient->execute(createDB);
        if result is sql:Error {
            io:println("Error creating database: ", result);
            return result;
        }
        
        // Use the database
        sql:ParameterizedQuery useDB = `USE railway`;
        sql:ExecutionResult|sql:Error useResult = bootstrapClient->execute(useDB);
        if useResult is sql:Error {
            io:println("Error selecting database: ", useResult);
            return useResult;
        }
        
        io:println("Railway database created/selected successfully");
        return;
    }
    
    // Local MySQL - create database if it doesn't exist
    mysql:Client bootstrapClient = check new (getMySQLConnectionStringNoDB());
    
    // Create database if it doesn't exist
    sql:ParameterizedQuery createDB = `CREATE DATABASE IF NOT EXISTS babadb`;
    sql:ExecutionResult|sql:Error result = bootstrapClient->execute(createDB);
    if result is sql:Error {
        return result;
    }
    
    // Use the database
    sql:ParameterizedQuery useDB = `USE railway`;
    sql:ExecutionResult|sql:Error useResult = bootstrapClient->execute(useDB);
    if useResult is sql:Error {
        return useResult;
    }
    
    io:println("Local database created successfully");
}

// Function to hash password
function hashPassword(string password) returns string {
    byte[] hashedBytes = crypto:hashSha256(password.toBytes());
    string result = "";
    foreach int i in 0..<hashedBytes.length() {
        result = result + hashedBytes[i].toString();
    }
    return result;
}

// Function to round float to integer
function roundToInt(float value) returns int {
    return <int>(value + 0.5f);
}

// Function to round float to 1 decimal place
function roundTo1Decimal(float value) returns float {
    return <float>(<int>(value * 10.0f + 0.5f)) / 10.0f;
}

// Function to round float to 2 decimal places
function roundTo2Decimals(float value) returns float {
    return <float>(<int>(value * 100.0f + 0.5f)) / 100.0f;
}

// Growth classification types and tables (derived from WHO growth standards)
type GrowthRange record {| 
    float under;
    float min;
    float max;
    float over;
|};

final map<map<GrowthRange>> weightTables = {
    "male": {
        "0": {under: 2.6, min: 3.0, max: 4.2, over: 4.4},
        "1": {under: 3.4, min: 3.9, max: 5.3, over: 5.6},
        "2": {under: 4.2, min: 4.9, max: 6.4, over: 6.9},
        "3": {under: 5.0, min: 5.7, max: 7.2, over: 7.8},
        "4": {under: 5.5, min: 6.2, max: 7.9, over: 8.5},
        "5": {under: 6.0, min: 6.7, max: 8.4, over: 9.1},
        "6": {under: 6.4, min: 7.1, max: 8.9, over: 9.6},
        "7": {under: 6.7, min: 7.4, max: 9.3, over: 10.0},
        "8": {under: 6.9, min: 7.6, max: 9.6, over: 10.4},
        "9": {under: 7.1, min: 7.9, max: 9.9, over: 10.7},
        "10": {under: 7.3, min: 8.1, max: 10.2, over: 11.0},
        "11": {under: 7.5, min: 8.3, max: 10.5, over: 11.3},
        "12": {under: 7.6, min: 8.4, max: 10.8, over: 11.5},
        "13": {under: 7.7, min: 8.6, max: 11.0, over: 11.8},
        "14": {under: 7.8, min: 8.7, max: 11.3, over: 12.1},
        "15": {under: 7.9, min: 8.9, max: 11.5, over: 12.3},
        "16": {under: 8.0, min: 9.0, max: 11.7, over: 12.5},
        "17": {under: 8.1, min: 9.2, max: 11.9, over: 12.7},
        "18": {under: 8.2, min: 9.3, max: 12.1, over: 12.9},
        "19": {under: 8.3, min: 9.4, max: 12.3, over: 13.1},
        "20": {under: 8.4, min: 9.6, max: 12.5, over: 13.3},
        "21": {under: 8.5, min: 9.7, max: 12.7, over: 13.5},
        "22": {under: 8.6, min: 9.8, max: 12.9, over: 13.7},
        "23": {under: 8.7, min: 10.0, max: 13.1, over: 13.9},
        "24": {under: 8.8, min: 10.1, max: 13.3, over: 14.1}
    },
    "female": {
        "0": {under: 2.5, min: 2.8, max: 3.9, over: 4.2},
        "1": {under: 3.2, min: 3.6, max: 4.8, over: 5.2},
        "2": {under: 3.9, min: 4.4, max: 5.9, over: 6.3},
        "3": {under: 4.5, min: 5.1, max: 6.7, over: 7.1},
        "4": {under: 5.0, min: 5.6, max: 7.3, over: 7.8},
        "5": {under: 5.4, min: 6.0, max: 7.8, over: 8.4},
        "6": {under: 5.7, min: 6.4, max: 8.2, over: 8.9},
        "7": {under: 6.0, min: 6.7, max: 8.6, over: 9.3},
        "8": {under: 6.2, min: 7.0, max: 8.9, over: 9.7},
        "9": {under: 6.4, min: 7.2, max: 9.2, over: 10.1},
        "10": {under: 6.6, min: 7.4, max: 9.5, over: 10.4},
        "11": {under: 6.8, min: 7.6, max: 9.7, over: 10.7},
        "12": {under: 6.9, min: 7.7, max: 9.9, over: 11.0},
        "13": {under: 7.0, min: 7.9, max: 10.1, over: 11.2},
        "14": {under: 7.2, min: 8.1, max: 10.3, over: 11.5},
        "15": {under: 7.3, min: 8.3, max: 10.6, over: 11.8},
        "16": {under: 7.4, min: 8.4, max: 10.8, over: 12.0},
        "17": {under: 7.5, min: 8.6, max: 11.0, over: 12.2},
        "18": {under: 7.6, min: 8.7, max: 11.2, over: 12.4},
        "19": {under: 7.7, min: 8.9, max: 11.4, over: 12.6},
        "20": {under: 7.8, min: 9.0, max: 11.6, over: 12.8},
        "21": {under: 7.9, min: 9.1, max: 11.8, over: 13.0},
        "22": {under: 8.0, min: 9.2, max: 12.0, over: 13.2},
        "23": {under: 8.1, min: 9.4, max: 12.2, over: 13.4},
        "24": {under: 8.2, min: 9.5, max: 12.4, over: 13.6}
    }
};

// Function to get default vaccines by gender
function getDefaultVaccines(string gender) returns VaccineRecord[] {
    VaccineRecord[] vaccines = [];
    // First Year of Life (offsets in months from birth)
    vaccines.push({ name: "BCG (Tuberculosis)", dose: "", received: false, receivedDate: (), isCustom: false, offsetMonths: 0 });
    vaccines.push({ name: "OPV (1st)", dose: "", received: false, receivedDate: (), isCustom: false, offsetMonths: 2 });
    vaccines.push({ name: "OPV (2nd)", dose: "", received: false, receivedDate: (), isCustom: false, offsetMonths: 4 });
    vaccines.push({ name: "OPV (3rd)", dose: "", received: false, receivedDate: (), isCustom: false, offsetMonths: 6 });
    vaccines.push({ name: "OPV (4th)", dose: "", received: false, receivedDate: (), isCustom: false, offsetMonths: 18 });
    vaccines.push({ name: "OPV (5th)", dose: "", received: false, receivedDate: (), isCustom: false, offsetMonths: 60 });
    vaccines.push({ name: "Pentavalent (1st)", dose: "", received: false, receivedDate: (), isCustom: false, offsetMonths: 2 });
    vaccines.push({ name: "Pentavalent (2nd)", dose: "", received: false, receivedDate: (), isCustom: false, offsetMonths: 4 });
    vaccines.push({ name: "Pentavalent (3rd)", dose: "", received: false, receivedDate: (), isCustom: false, offsetMonths: 6 });
    vaccines.push({ name: "fIPV (1st)", dose: "", received: false, receivedDate: (), isCustom: false, offsetMonths: 2 });
    vaccines.push({ name: "fIPV (2nd)", dose: "", received: false, receivedDate: (), isCustom: false, offsetMonths: 4 });
    vaccines.push({ name: "MMR (1st)", dose: "", received: false, receivedDate: (), isCustom: false, offsetMonths: 9 });

    // Second Year of Life
    vaccines.push({ name: "Live JE", dose: "", received: false, receivedDate: (), isCustom: false, offsetMonths: 12 });
    vaccines.push({ name: "DTP (4th)", dose: "", received: false, receivedDate: (), isCustom: false, offsetMonths: 18 });

    // Pre-School
    vaccines.push({ name: "MMR (2nd)", dose: "", received: false, receivedDate: (), isCustom: false, offsetMonths: 36 });

    // School Age
    vaccines.push({ name: "DT (5th)", dose: "", received: false, receivedDate: (), isCustom: false, offsetMonths: 60 });
    vaccines.push({ name: "HPV (1st)", dose: "", received: false, receivedDate: (), isCustom: false, offsetMonths: 120 });
    vaccines.push({ name: "HPV (2nd)", dose: "", received: false, receivedDate: (), isCustom: false, offsetMonths: 126 }); // 6 months later
    vaccines.push({ name: "aTd (6th)", dose: "", received: false, receivedDate: (), isCustom: false, offsetMonths: 132 });

    if gender == "female" || gender == "Female" || gender == "FEMALE" {
        // Additional for females
        vaccines.push({ name: "Rubella-containing vaccine (MMR)", dose: "", received: false, receivedDate: (), isCustom: false, offsetMonths: 180 }); // example offset
        // Pregnant women – TT (placeholders)
        vaccines.push({ name: "Tetanus Toxoid (TT) (1st pregnancy)", dose: "", received: false, receivedDate: (), isCustom: false, offsetMonths: 0 });
        vaccines.push({ name: "Tetanus Toxoid (TT) (2nd dose)", dose: "", received: false, receivedDate: (), isCustom: false, offsetMonths: 0 });
        vaccines.push({ name: "Tetanus Toxoid (TT) (3rd dose)", dose: "", received: false, receivedDate: (), isCustom: false, offsetMonths: 0 });
        vaccines.push({ name: "Tetanus Toxoid (TT) (4th dose)", dose: "", received: false, receivedDate: (), isCustom: false, offsetMonths: 0 });
        vaccines.push({ name: "Tetanus Toxoid (TT) (5th dose)", dose: "", received: false, receivedDate: (), isCustom: false, offsetMonths: 0 });
    }
    
    return vaccines;
}

// Function to calculate age in months from date of birth
function calculateAgeInMonths(string dateOfBirth) returns int {
    // For now, return a simple calculation based on year difference
    // This is a simplified version - in production you'd want more sophisticated date parsing
    if (dateOfBirth.length() >= 4) {
        string yearStr = dateOfBirth.substring(0, 4);
        int birthYear = 0;
        // Simple year parsing - assume valid year format
        if (yearStr == "2020") {
            birthYear = 2020;
        } else if (yearStr == "2021") {
            birthYear = 2021;
        } else if (yearStr == "2022") {
            birthYear = 2022;
        } else if (yearStr == "2023") {
            birthYear = 2023;
        } else if (yearStr == "2024") {
            birthYear = 2024;
        } else {
            birthYear = 2000; // Default fallback
        }
        
        // Get current date - use a simple approach for now
        int currentYear = 2024; // Hardcoded for now to avoid time parsing issues
        
        // Calculate approximate age in months (12 months per year)
        int ageInMonths = (currentYear - birthYear) * 12;
        
        return ageInMonths;
    }
    
    return 0;
}

// Function to get growth classification based on age, gender, and weight
function getGrowthClassification(string gender, int ageInMonths, float weight) returns string {
    if (weightTables.hasKey(gender)) {
        map<GrowthRange>? genderTable = weightTables[gender];
        if (genderTable is map<GrowthRange>) {
            if (genderTable.hasKey(ageInMonths.toString())) {
                GrowthRange? range = genderTable[ageInMonths.toString()];
                if (range is GrowthRange) {
                    if (weight < range.under) {
                        return "severely_underweight";
                    } else if (weight < range.min) {
                        return "underweight";
                    } else if (weight <= range.max) {
                        return "normal";
                    } else if (weight <= range.over) {
                        return "overweight";
                    } else {
                        return "obese";
                    }
                }
            }
        }
    }
    
    // Fallback to standard BMI classification for older ages
    return "standard_bmi";
}

// Function to initialize database and tables
function initializeDatabase(mysql:Client dbClient) returns error? {
    io:println("Initializing database and tables...");

    // Select the appropriate database
    sql:ParameterizedQuery useDB;
    string? mysqlHost = os:getEnv("MYSQL_HOST");
    if (mysqlHost is string && mysqlHost != "" && mysqlHost != "localhost") {
        // Railway MySQL
        useDB = `USE railway`;
        io:println("Selected Railway MySQL database: railway");
    } else {
        // Local MySQL
        useDB = `USE railway`;
        io:println("Selected local database: babadb");
    }
    
    sql:ExecutionResult|sql:Error useResult = dbClient->execute(useDB);
    if useResult is sql:Error {
        return useResult;
    }


    // Users table
    sql:ParameterizedQuery createUsersTable = `
        CREATE TABLE IF NOT EXISTS users (
            id VARCHAR(255) PRIMARY KEY,
            first_name VARCHAR(255) NOT NULL,
            last_name VARCHAR(255) NOT NULL,
            email VARCHAR(255) UNIQUE NOT NULL,
            password VARCHAR(255) NOT NULL,
            gender VARCHAR(50) NOT NULL,
            date_of_birth DATE NOT NULL,
            phone_number VARCHAR(50),
            vaccines JSON,
            special_notes TEXT,
            photo_data_url TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )`;

    // Diseases table
    sql:ParameterizedQuery createDiseasesTable = `
        CREATE TABLE IF NOT EXISTS diseases (
            id INT AUTO_INCREMENT PRIMARY KEY,
            user_id VARCHAR(255) NOT NULL,
            disease_name VARCHAR(255) NOT NULL,
            diagnosis_date DATE NOT NULL,
            symptoms TEXT,
            treatment TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        )`;

    // Appointments table
    sql:ParameterizedQuery createAppointmentsTable = `
        CREATE TABLE IF NOT EXISTS appointments (
            id INT AUTO_INCREMENT PRIMARY KEY,
            user_id VARCHAR(255) NOT NULL,
            title VARCHAR(255) NOT NULL,
            date DATE NOT NULL,
            time TIME NOT NULL,
            notes TEXT,
            completed BOOLEAN DEFAULT FALSE,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        )`;

    // BMI records table
    sql:ParameterizedQuery createBmiRecordsTable = `
        CREATE TABLE IF NOT EXISTS bmi_records (
            id INT AUTO_INCREMENT PRIMARY KEY,
            user_id VARCHAR(255) NOT NULL,
            weight FLOAT NOT NULL,
            height FLOAT NOT NULL,
            bmi FLOAT NOT NULL,
            classification VARCHAR(32),
            notes TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        )`;

    // Vaccine records table
    sql:ParameterizedQuery createVaccineRecordsTable = `
        CREATE TABLE IF NOT EXISTS vaccine_records (
            id INT AUTO_INCREMENT PRIMARY KEY,
            user_id VARCHAR(255) NOT NULL,
            name VARCHAR(255) NOT NULL,
            dose VARCHAR(255),
            due_date DATE,
            completed_date DATE,
            is_custom BOOLEAN DEFAULT FALSE,
            offset_months INT,
            received BOOLEAN DEFAULT FALSE,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        )`;

    // Doctor appointments table
    sql:ParameterizedQuery createDocAppointmentsTable = `
        CREATE TABLE IF NOT EXISTS doc_appointments (
            id INT AUTO_INCREMENT PRIMARY KEY,
            user_id VARCHAR(255) NOT NULL,
            date DATE NOT NULL,
            time TIME NOT NULL,
            place VARCHAR(255) NOT NULL,
            disease VARCHAR(255) NOT NULL,
            doctor_name VARCHAR(255) DEFAULT 'General Doctor',
            completed BOOLEAN DEFAULT FALSE,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        )`;

    sql:ExecutionResult|sql:Error r1 = dbClient->execute(createUsersTable);
    if r1 is sql:Error { return r1; }

    sql:ExecutionResult|sql:Error r2 = dbClient->execute(createDiseasesTable);
    if r2 is sql:Error { return r2; }

    sql:ExecutionResult|sql:Error r3 = dbClient->execute(createAppointmentsTable);
    if r3 is sql:Error { return r3; }

    sql:ExecutionResult|sql:Error r4 = dbClient->execute(createBmiRecordsTable);
    if r4 is sql:Error { return r4; }

    sql:ExecutionResult|sql:Error r5 = dbClient->execute(createVaccineRecordsTable);
    if r5 is sql:Error { return r5; }

    sql:ExecutionResult|sql:Error r6 = dbClient->execute(createDocAppointmentsTable);
    if r6 is sql:Error { return r6; }

    // Add missing columns if they don't exist (migration)
    // Try to add place column if it doesn't exist (MySQL doesn't support IF NOT EXISTS for ALTER TABLE)
    sql:ExecutionResult|sql:Error addPlaceColumn = dbClient->execute(`ALTER TABLE doc_appointments ADD COLUMN place VARCHAR(255) NOT NULL DEFAULT 'Unknown Location'`);
    if addPlaceColumn is sql:Error {
        io:println("Note: place column may already exist or migration failed: " + addPlaceColumn.toString());
    }

    io:println("All tables created successfully");
}

// Connection pool configuration
final int MAX_POOL_SIZE = 10;
final int MIN_POOL_SIZE = 2;
final int CONNECTION_TIMEOUT = 30000; // 30 seconds

// Main function
public function main() {
    error? bootstrapResult = bootstrapDatabase();
    if bootstrapResult is error {
        io:println("Database bootstrap failed: ", bootstrapResult.message());
        return;
    }

    mysql:Client|error dbClientResult = new (getMySQLConnectionStringNoDB());
    if dbClientResult is error {
        io:println("Database connection failed: ", dbClientResult.message());
        return;
    }
    mysql:Client dbClient = dbClientResult;
    globalClient = dbClient;

    error? initResult = initializeDatabase(dbClient);
    if initResult is error {
        io:println("Database initialization failed: ", initResult.message());
    } else {
        io:println("Database initialized successfully");
    }
    
    // Keep the program running
    io:println("Service is ready. Press Ctrl+C to stop.");
}

@http:ServiceConfig {
    cors: {
        allowOrigins: ["http://localhost:5173", "http://localhost:3000"],
        allowMethods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
        allowHeaders: ["Content-Type", "Accept", "Authorization"],
        allowCredentials: true
    }
}
service /health on new http:Listener(9090) {
    // Health check endpoint
    resource function get .() returns http:Ok {
        return <http:Ok>{ body: { message: "Health Records API is running" } };
    }

    // Debug endpoint to check database data
    resource function get debug() returns http:Ok|http:InternalServerError|error {
        if globalClient is () {
            return <http:InternalServerError>{ body: { message: "Database not initialized" } };
        }
        mysql:Client dbClient = <mysql:Client>globalClient;
        
        // Check total users
        sql:ParameterizedQuery countQuery = `SELECT COUNT(*) as total FROM users`;
        stream<record {}, sql:Error?> countStream = dbClient->query(countQuery);
        record {}[] countResults = [];
        while true {
            record {}|sql:Error? row = countStream.next();
            if row is record {} { countResults.push(row); } else { break; }
        }
        
        // Get all users with their data
        sql:ParameterizedQuery allUsersQuery = `SELECT * FROM users`;
        stream<record {}, sql:Error?> allUsersStream = dbClient->query(allUsersQuery);
        record {}[] allUsers = [];
        while true {
            record {}|sql:Error? row = allUsersStream.next();
            if row is record {} { allUsers.push(row); } else { break; }
        }
        
        return <http:Ok>{ body: { 
            totalUsers: countResults.length() > 0 ? countResults[0]["total"].toString() : "0",
            users: allUsers
        }};
    }

    // User signup endpoint
    resource function post signup(@http:Payload record {
        string firstName;
        string lastName;
        string email;
        string password;
        string gender;
        string dateOfBirth;
        string? phoneNumber;
    } newUser) returns http:Created|http:BadRequest|http:InternalServerError|error {
        if globalClient is () {
            return <http:InternalServerError>{ body: { message: "Database not initialized" } };
        }
        mysql:Client dbClient = <mysql:Client>globalClient;
        
        io:println("Signup attempt for email: ", newUser.email);
        
        string userId = uuid:createType4AsString();
        string hashedPassword = hashPassword(newUser.password);
        
        io:println("=== SIGNUP DEBUG ===");
        io:println("Generated userId: ", userId);
        io:println("Raw password from user: ", newUser.password);
        io:println("Raw password length: ", newUser.password.length());
        io:println("Hashed password: ", hashedPassword);
        io:println("Hashed password length: ", hashedPassword.length());
        io:println("===================");
        
        string phoneNum = newUser.phoneNumber ?: "";
        sql:ParameterizedQuery insertUser = `INSERT INTO users (id, first_name, last_name, email, password, gender, date_of_birth, phone_number) VALUES (${userId}, ${newUser.firstName}, ${newUser.lastName}, ${newUser.email}, ${hashedPassword}, ${newUser.gender}, ${newUser.dateOfBirth}, ${phoneNum})`;
        io:println("Insert query: ", insertUser);
        sql:ExecutionResult|sql:Error insRes = dbClient->execute(insertUser);
        if insRes is sql:Error {
            io:println("Error creating user: ", insRes.message());
            return <http:InternalServerError>{ body: { message: "Error creating user" } };
        }
        
        // Automatically assign default vaccines based on gender
        VaccineRecord[] defaultVaccines = getDefaultVaccines(newUser.gender);
        io:println("Adding", defaultVaccines.length(), "default vaccines for gender:", newUser.gender);
        
        foreach VaccineRecord vaccine in defaultVaccines {
            // Calculate due date based on offset months from birth date
            string? dueDate = ();
            if (vaccine.offsetMonths is int && vaccine.offsetMonths >= 0) {
                // For now, use birth date as base - in production you'd add months properly
                dueDate = newUser.dateOfBirth;
            }
            
            // Use the correct field names that match the database table
            sql:ParameterizedQuery vaccineQuery;
            if (dueDate is string) {
                vaccineQuery = `INSERT INTO vaccine_records (user_id, name, dose, due_date, is_custom, offset_months, created_at) VALUES (${userId}, ${vaccine.name}, ${vaccine.dose}, ${dueDate}, ${vaccine.isCustom}, ${vaccine.offsetMonths ?: 0}, NOW())`;
            } else {
                vaccineQuery = `INSERT INTO vaccine_records (user_id, name, dose, is_custom, offset_months, created_at) VALUES (${userId}, ${vaccine.name}, ${vaccine.dose}, ${vaccine.isCustom}, ${vaccine.offsetMonths ?: 0}, NOW())`;
            }
            
            sql:ExecutionResult|sql:Error vaccineResult = dbClient->execute(vaccineQuery);
            if vaccineResult is sql:Error {
                io:println("Warning: Could not insert vaccine record for", vaccine.name, ":", vaccineResult.message());
            } else {
                io:println("Successfully added vaccine:", vaccine.name, "for user:", userId);
            }
        }
        
        io:println("User created successfully with ID:", userId, "and", defaultVaccines.length(), "default vaccines assigned");
        
        string name = newUser.firstName + " " + newUser.lastName;
        return <http:Created>{ body: { message: "User created successfully", userId: userId, name: name, email: newUser.email, redirectTo: "already-vaccinated" } };
    }

    // Add disease endpoint
    resource function post addDisease(@http:Payload record {
        string userId;
        string diseaseName;
        string diagnosisDate;
        string? symptoms;
        string? treatment;
    } disease) returns http:Created|http:BadRequest|http:InternalServerError|error {
        if globalClient is () {
            return <http:InternalServerError>{ body: { message: "Database not initialized" } };
        }
        mysql:Client dbClient = <mysql:Client>globalClient;
        
        sql:ParameterizedQuery insertDisease = `INSERT INTO diseases (user_id, disease_name, diagnosis_date, symptoms, treatment) VALUES (${disease.userId}, ${disease.diseaseName}, ${disease.diagnosisDate}, ${disease.symptoms ?: ""}, ${disease.treatment ?: ""})`;
        sql:ExecutionResult|sql:Error insRes = dbClient->execute(insertDisease);
        if insRes is sql:Error {
            return <http:InternalServerError>{ body: { message: "Error adding disease" } };
        }
        
        return <http:Created>{ body: { message: "Disease added successfully" } };
    }

    // Get diseases endpoint
    resource function get getDiseases(string userId) returns http:Ok|http:InternalServerError|error {
        if globalClient is () {
            return <http:InternalServerError>{ body: { message: "Database not initialized" } };
        }
        mysql:Client dbClient = <mysql:Client>globalClient;
        sql:ParameterizedQuery q = `SELECT * FROM diseases WHERE user_id = ${userId} ORDER BY diagnosis_date DESC`;
        stream<record {}, sql:Error?> s = dbClient->query(q);
        record {}[] items = [];
        while true {
            record {}|sql:Error? row = s.next();
            if row is record {} { items.push(row); } else { break; }
        }
        return <http:Ok>{ body: items };
    }

    // Get user profile endpoint
    resource function get getUserProfile(string userId) returns http:Ok|http:NotFound|http:InternalServerError|error {
        if globalClient is () {
            return <http:InternalServerError>{ body: { message: "Database not initialized" } };
        }
        mysql:Client dbClient = <mysql:Client>globalClient;
        
        sql:ParameterizedQuery uq = `SELECT id, first_name, last_name, email, gender, date_of_birth, phone_number, photo_data_url FROM users WHERE id = ${userId}`;
        io:println("DEBUG: SQL Query executed for userId: " + userId);
        
        stream<record {}, sql:Error?> s = dbClient->query(uq);
        record {}[] users = [];
        while true {
            record {}|sql:Error? row = s.next();
            if row is record {} { 
                users.push(row); 
                io:println("DEBUG: Found user row: " + row.toString());
            } else { 
                break; 
            }
        }
        
        io:println("DEBUG: Total users found: " + users.length().toString());
        
        if users.length() == 0 {
            io:println("DEBUG: No users found for userId: " + userId);
            return <http:NotFound>{ body: { message: "User not found" } };
        }
        
        record {} user = users[0];
        io:println("DEBUG: getUserProfile - Raw user data: " + user.toString());
        io:println("DEBUG: User record structure available");
        
        // Transform the data to match frontend expectations (camelCase)
        io:println("DEBUG: Accessing user fields...");
        
        // Handle the nested 'value' field structure from MySQL results
        record {} userData = user;
        if user.hasKey("value") {
            userData = <record {}>user["value"];
            io:println("DEBUG: Found nested 'value' field, using userData");
        }
        
        // Use proper field access for open records
        string dbUserId = userData["id"] is string ? <string>userData["id"] : "";
        io:println("DEBUG: user['id'] = " + dbUserId);
        
        string dbFirstName = userData["first_name"] is string ? <string>userData["first_name"] : "";
        io:println("DEBUG: user['first_name'] = " + dbFirstName);
        
        string dbLastName = userData["last_name"] is string ? <string>userData["last_name"] : "";
        io:println("DEBUG: user['last_name'] = " + dbLastName);
        
        string dbEmail = userData["email"] is string ? <string>userData["email"] : "";
        io:println("DEBUG: user['email'] = " + dbEmail);
        
        string dbGender = userData["gender"] is string ? <string>userData["gender"] : "";
        io:println("DEBUG: user['gender'] = " + dbGender);
        
        string dbDateOfBirth = userData["date_of_birth"] is string ? <string>userData["date_of_birth"] : "";
        io:println("DEBUG: user['date_of_birth'] = " + dbDateOfBirth);
        
        string dbPhoneNumber = userData["phone_number"] is string ? <string>userData["phone_number"] : "";
        io:println("DEBUG: user['phone_number'] = " + dbPhoneNumber);
        
        string? dbPhotoDataUrl = userData["photo_data_url"] is string ? <string>userData["photo_data_url"] : ();
        io:println("DEBUG: user['photo_data_url'] = " + (dbPhotoDataUrl is string ? dbPhotoDataUrl : "null"));
        
        record {
            string id;
            string firstName;
            string lastName;
            string email;
            string gender;
            string dateOfBirth;
            string phoneNumber;
            string? photoDataUrl;
        } transformedUser = {
            id: dbUserId,
            firstName: dbFirstName,
            lastName: dbLastName,
            email: dbEmail,
            gender: dbGender,
            dateOfBirth: dbDateOfBirth,
            phoneNumber: dbPhoneNumber,
            photoDataUrl: dbPhotoDataUrl
        };
        
        io:println("DEBUG: Transformed user data: " + transformedUser.toString());
        
        // Return in the format expected by frontend
        return <http:Ok>{ body: transformedUser };
    }

    // Get vaccines endpoint
    resource function get getVaccines(string userId) returns http:Ok|http:NotFound|http:InternalServerError|error {
        if globalClient is () {
            return <http:InternalServerError>{ body: { message: "Database not initialized" } };
        }
        mysql:Client dbClient = <mysql:Client>globalClient;
        
        // First ensure we're using the correct database
        sql:ExecutionResult|sql:Error useDbResult = dbClient->execute(`USE railway`);
        if useDbResult is sql:Error {
            return <http:InternalServerError>{ body: { message: "Database connection error" } };
        }
        
        sql:ParameterizedQuery vq = `SELECT id, user_id, name, dose, due_date, is_custom, created_at, completed_date, offset_months FROM vaccine_records WHERE user_id = ${userId}`;
        
        stream<record {}, sql:Error?> s = dbClient->query(vq);
        record {}[] vaccines = [];
        
        while true {
            record {}|sql:Error? row = s.next();
            if row is record {} { 
                vaccines.push(row); 
            } else if row is sql:Error {
                break;
            } else { 
                break; 
            }
        }
        
        if vaccines.length() == 0 {
            return <http:Ok>{ body: [] };
        }
        
        // Transform the data to handle nested 'value' field and match frontend expectations
        record {
            string id;
            string userId;
            string name;
            string dose;
            string dueDate;
            boolean isCustom;
            string createdAt;
            string? completedDate;
            int? offsetMonths;
        }[] transformedVaccines = [];
        
        foreach record {} vaccine in vaccines {
            // Handle the nested 'value' field structure from MySQL results
            record {} vaccineData = vaccine;
            if vaccine.hasKey("value") {
                vaccineData = <record {}>vaccine["value"];
            }
            
            // Extract and transform fields based on actual table structure
            string id = vaccineData["id"] is int ? vaccineData["id"].toString() : (vaccineData["id"] is string ? <string>vaccineData["id"] : "");
            string dbUserId = vaccineData["user_id"] is string ? <string>vaccineData["user_id"] : "";
            string name = vaccineData["name"] is string ? <string>vaccineData["name"] : "";
            string dose = vaccineData["dose"] is string ? <string>vaccineData["dose"] : "";
            string dueDate = vaccineData["due_date"] is string ? <string>vaccineData["due_date"] : "";
            boolean isCustom = vaccineData["is_custom"] is boolean ? <boolean>vaccineData["is_custom"] : false;
            string createdAt = vaccineData["created_at"] is string ? <string>vaccineData["created_at"] : "";
            string? completedDate = vaccineData["completed_date"] is string ? <string>vaccineData["completed_date"] : "";
            int? offsetMonths = vaccineData["offset_months"] is int ? <int>vaccineData["offset_months"] : ();
            
            record {
                string id;
                string userId;
                string name;
                string dose;
                string dueDate;
                boolean isCustom;
                string createdAt;
                string? completedDate;
                int? offsetMonths;
                boolean received;
                string? receivedDate;
            } transformedVaccine = {
                id: id,
                userId: dbUserId,
                name: name,
                dose: dose,
                dueDate: dueDate,
                isCustom: isCustom,
                createdAt: createdAt,
                completedDate: completedDate,
                offsetMonths: offsetMonths,
                received: completedDate is string && completedDate != "",
                receivedDate: completedDate is string ? completedDate : ()
            };
            
            transformedVaccines.push(transformedVaccine);
        }
        
        return <http:Ok>{ body: transformedVaccines };
    }

    // Update vaccine record endpoint (frontend compatible)
    resource function put updateVaccine(@http:Payload record {
        string userId;
        string name;
        string dose;
        string newName;
        string newDose;
        int? newOffsetMonths;
    } vaccineData) returns http:Ok|http:NotFound|http:InternalServerError|error {
        if globalClient is () {
            return <http:InternalServerError>{ body: { message: "Database not initialized" } };
        }
        mysql:Client dbClient = <mysql:Client>globalClient;
        

        
        // First, check if the vaccine exists
        sql:ParameterizedQuery checkQuery = `SELECT COUNT(*) as count FROM vaccine_records WHERE user_id = ${vaccineData.userId} AND name = ${vaccineData.name} AND dose = ${vaccineData.dose}`;
        
        stream<record {}, sql:Error?> checkResult = dbClient->query(checkQuery);
        record {}|sql:Error? checkRow = checkResult.next();
        if checkRow is sql:Error {
            return <http:InternalServerError>{ body: { message: "Database error" } };
        }
        record {} row = <record {}>checkRow;
        record {} rowData = row;
        if row.hasKey("value") {
            rowData = <record {}>row["value"];
        }
        int count = rowData["count"] is int ? <int>rowData["count"] : 0;
        
        if count == 0 {
            return <http:NotFound>{ body: { message: "Vaccine not found" } };
        }
        
        // Build dynamic UPDATE query based on provided fields
        string[] updateFields = [];
        
        if vaccineData.newName != vaccineData.name {
            updateFields.push("name = '" + vaccineData.newName + "'");
        }
        if vaccineData.newDose != vaccineData.dose {
            updateFields.push("dose = '" + vaccineData.newDose + "'");
        }
        if (vaccineData.newOffsetMonths is int) {
            updateFields.push("offset_months = " + vaccineData.newOffsetMonths.toString());
        }
        
        if updateFields.length() == 0 {
            return <http:InternalServerError>{ body: { message: "No changes to update" } };
        }
        
        // Build the query string manually since join() is not available
        string fieldsString = "";
        foreach int i in 0..<updateFields.length() {
            if i > 0 {
                fieldsString = fieldsString + ", ";
            }
            fieldsString = fieldsString + updateFields[i];
        }
        
        // Try using a different approach - build the query without string interpolation
        // Use a simpler approach with individual field updates
        sql:ExecutionResult|sql:Error result;
        
        if vaccineData.newName != vaccineData.name && vaccineData.newDose != vaccineData.dose && (vaccineData.newOffsetMonths is int) {
            // Update name, dose, and offsetMonths
            sql:ParameterizedQuery updateQuery = `UPDATE vaccine_records SET name = ${vaccineData.newName}, dose = ${vaccineData.newDose}, offset_months = ${vaccineData.newOffsetMonths} WHERE name = ${vaccineData.name} AND dose = ${vaccineData.dose} AND user_id = ${vaccineData.userId}`;
            result = dbClient->execute(updateQuery);
        } else if vaccineData.newName != vaccineData.name && vaccineData.newDose != vaccineData.dose {
            // Update both name and dose
            sql:ParameterizedQuery updateQuery = `UPDATE vaccine_records SET name = ${vaccineData.newName}, dose = ${vaccineData.newDose} WHERE name = ${vaccineData.name} AND dose = ${vaccineData.dose} AND user_id = ${vaccineData.userId}`;
            result = dbClient->execute(updateQuery);
        } else if vaccineData.newName != vaccineData.name && (vaccineData.newOffsetMonths is int) {
            // Update name and offsetMonths
            sql:ParameterizedQuery updateQuery = `UPDATE vaccine_records SET name = ${vaccineData.newName}, offset_months = ${vaccineData.newOffsetMonths} WHERE name = ${vaccineData.name} AND dose = ${vaccineData.dose} AND user_id = ${vaccineData.userId}`;
            result = dbClient->execute(updateQuery);
        } else if vaccineData.newDose != vaccineData.dose && (vaccineData.newOffsetMonths is int) {
            // Update dose and offsetMonths
            sql:ParameterizedQuery updateQuery = `UPDATE vaccine_records SET dose = ${vaccineData.newDose}, offset_months = ${vaccineData.newOffsetMonths} WHERE name = ${vaccineData.name} AND dose = ${vaccineData.dose} AND user_id = ${vaccineData.userId}`;
            result = dbClient->execute(updateQuery);
        } else if vaccineData.newName != vaccineData.name {
            // Update only name
            sql:ParameterizedQuery updateQuery = `UPDATE vaccine_records SET name = ${vaccineData.newName} WHERE name = ${vaccineData.name} AND dose = ${vaccineData.dose} AND user_id = ${vaccineData.userId}`;
            result = dbClient->execute(updateQuery);
        } else if vaccineData.newDose != vaccineData.dose {
            // Update only dose
            sql:ParameterizedQuery updateQuery = `UPDATE vaccine_records SET dose = ${vaccineData.newDose} WHERE name = ${vaccineData.name} AND dose = ${vaccineData.dose} AND user_id = ${vaccineData.userId}`;
            result = dbClient->execute(updateQuery);
        } else if (vaccineData.newOffsetMonths is int) {
            // Update only offsetMonths
            sql:ParameterizedQuery updateQuery = `UPDATE vaccine_records SET offset_months = ${vaccineData.newOffsetMonths} WHERE name = ${vaccineData.name} AND dose = ${vaccineData.dose} AND user_id = ${vaccineData.userId}`;
            result = dbClient->execute(updateQuery);
        } else {
            // No changes
            result = <sql:ExecutionResult>{affectedRowCount: 0, lastInsertId: 0};
        }
        if result is sql:Error {
            return <http:InternalServerError>{ body: { message: "Failed to update vaccine record" } };
        }
        
        return <http:Ok>{ body: { message: "Vaccine updated successfully" } };
    }

    // Get default vaccines endpoint
    resource function get getDefaultVaccines(string gender) returns http:Ok|http:InternalServerError|error {
        VaccineRecord[] defaultVaccines = getDefaultVaccines(gender);
        
        return <http:Ok>{ body: defaultVaccines };
    }

    // Create custom vaccine endpoint
    resource function post createCustomVaccine(string userId, @http:Payload record {
        string name;
        string dose;
        string? dueDate;
    } vaccineData) returns http:Ok|http:InternalServerError|error {
        if globalClient is () {
            return <http:InternalServerError>{ body: { message: "Database not initialized" } };
        }
        mysql:Client dbClient = <mysql:Client>globalClient;
        
        sql:ParameterizedQuery insertQuery = `INSERT INTO vaccine_records (user_id, name, dose, due_date, is_custom, created_at) VALUES (${userId}, ${vaccineData.name}, ${vaccineData.dose}, ${vaccineData.dueDate ?: ""}, true, NOW())`;
        
        sql:ExecutionResult|sql:Error result = dbClient->execute(insertQuery);
        if result is sql:Error {
            return <http:InternalServerError>{ body: { message: "Failed to create custom vaccine record" } };
        }
        
        return <http:Ok>{ body: { message: "Custom vaccine created successfully" } };
    }

    // Mark vaccine as received endpoint
    resource function put markVaccineReceived(@http:Payload record {
        string userId;
        string name;
        string dose;
        boolean received;
        string? receivedDate;
    } vaccineData) returns http:Ok|http:BadRequest|http:InternalServerError|error {
        if globalClient is () {
            return <http:InternalServerError>{ body: { message: "Database not initialized" } };
        }
        mysql:Client dbClient = <mysql:Client>globalClient;
        
        // First ensure we're using the correct database
        sql:ExecutionResult|sql:Error useDbResult = dbClient->execute(`USE railway`);
        if useDbResult is sql:Error {
            return <http:InternalServerError>{ body: { message: "Database connection error" } };
        }
        
        // Since the table doesn't have 'received' or 'received_date' columns,
        // we'll use 'completed_date' to track when a vaccine was received
        string? completedDate = ();
        if (vaccineData.received && vaccineData.receivedDate is string) {
            completedDate = vaccineData.receivedDate;
        } else if (vaccineData.received) {
            // If received but no date provided, use current date
            completedDate = time:utcNow().toString();
        }
        
        // Update the vaccine record using parameterized queries
        sql:ExecutionResult|sql:Error result;
        if (vaccineData.received && completedDate is string) {
            sql:ParameterizedQuery updateQuery = `UPDATE vaccine_records SET completed_date = ${completedDate} WHERE user_id = ${vaccineData.userId} AND name = ${vaccineData.name} AND dose = ${vaccineData.dose}`;
            result = dbClient->execute(updateQuery);
        } else if (vaccineData.received) {
            // If received but no date provided, use current date
            sql:ParameterizedQuery updateQuery = `UPDATE vaccine_records SET completed_date = NOW() WHERE user_id = ${vaccineData.userId} AND name = ${vaccineData.name} AND dose = ${vaccineData.dose}`;
            result = dbClient->execute(updateQuery);
        } else {
            // If marking as not received, clear the completed_date
            sql:ParameterizedQuery updateQuery = `UPDATE vaccine_records SET completed_date = NULL WHERE user_id = ${vaccineData.userId} AND name = ${vaccineData.name} AND dose = ${vaccineData.dose}`;
            result = dbClient->execute(updateQuery);
        }
        
        if result is sql:Error {
            return <http:InternalServerError>{ body: { message: "Failed to update vaccine record" } };
        }
        return <http:Ok>{ body: { message: "Vaccine status updated successfully" } };
    }

    // Get doctor appointments endpoint
    resource function get getDocAppointments(string userId) returns http:Ok|http:NotFound|http:InternalServerError|error {
        if globalClient is () {
            return <http:InternalServerError>{ body: { message: "Database not initialized" } };
        }
        mysql:Client dbClient = <mysql:Client>globalClient;
        
        // First ensure we're using the correct database
        sql:ExecutionResult|sql:Error useDbResult = dbClient->execute(`USE railway`);
        if useDbResult is sql:Error {
            return <http:InternalServerError>{ body: { message: "Database connection error" } };
        }
        
        sql:ParameterizedQuery aq = `SELECT id, user_id, date, time, place, disease, completed FROM doc_appointments WHERE user_id = ${userId}`;
        
        stream<record {}, sql:Error?> s = dbClient->query(aq);
        record {}[] appointments = [];
        while true {
            record {}|sql:Error? row = s.next();
            if row is record {} { 
                appointments.push(row); 
            } else { 
                break; 
            }
        }
        
        if appointments.length() == 0 {
            return <http:Ok>{ body: [] };
        }
        
        // Transform the data to handle nested 'value' field and match frontend expectations
        record {
            string id;
            string userId;
            string date;
            string time;
            string place;
            string disease;
            boolean completed;
        }[] transformedAppointments = [];
        
        foreach record {} appointment in appointments {
            // Handle the nested 'value' field structure from MySQL results
            record {} appointmentData = appointment;
            if appointment.hasKey("value") {
                appointmentData = <record {}>appointment["value"];
            }
            
            // Extract and transform fields
            string id = appointmentData["id"] is int ? <string>(<int>appointmentData["id"]).toString() : (appointmentData["id"] is string ? <string>appointmentData["id"] : "");
            string dbUserId = appointmentData["user_id"] is string ? <string>appointmentData["user_id"] : "";
            string date = appointmentData["date"] is string ? <string>appointmentData["date"] : "";
            string time = appointmentData["time"] is string ? <string>appointmentData["time"] : "";
            string place = appointmentData["place"] is string ? <string>appointmentData["place"] : "";
            string disease = appointmentData["disease"] is string ? <string>appointmentData["disease"] : "";
            boolean completed = appointmentData["completed"] is boolean ? <boolean>appointmentData["completed"] : false;
            
            record {
                string id;
                string userId;
                string date;
                string time;
                string place;
                string disease;
                boolean completed;
            } transformedAppointment = {
                id: id,
                userId: dbUserId,
                date: date,
                time: time,
                place: place,
                disease: disease,
                completed: completed
            };
            
            transformedAppointments.push(transformedAppointment);
        }
        
        return <http:Ok>{ body: transformedAppointments };
    }

    // Update doctor appointment endpoint
    resource function put updateDocAppointment(@http:Payload record {
        string userId;
        string appointmentId;
        string date;
        string time;
        string place;
        string disease;
        string doctorName;
        boolean completed;
    } appointmentUpdate) returns http:Ok|http:BadRequest|http:NotFound|http:InternalServerError|error {
        if globalClient is () {
            return <http:InternalServerError>{ body: { message: "Database not initialized" } };
        }
        mysql:Client dbClient = <mysql:Client>globalClient;
        
        // First, check if the appointment exists
        sql:ParameterizedQuery checkQuery = `SELECT COUNT(*) as count FROM doc_appointments WHERE id = ${appointmentUpdate.appointmentId} AND user_id = ${appointmentUpdate.userId}`;
        
        stream<record {}, sql:Error?> checkResult = dbClient->query(checkQuery);
        record {}|sql:Error? checkRow = checkResult.next();
        if checkRow is sql:Error {
            return <http:InternalServerError>{ body: { message: "Database error" } };
        }
        record {} row = <record {}>checkRow;
        record {} rowData = row;
        if row.hasKey("value") {
            rowData = <record {}>row["value"];
        }
        int count = rowData["count"] is int ? <int>rowData["count"] : 0;
        
        if count == 0 {
            return <http:NotFound>{ body: { message: "Appointment not found" } };
        }
        
        // Use a simple approach - always update all fields
        string doctorNameValue = appointmentUpdate.doctorName;
        sql:ParameterizedQuery updateQuery = `UPDATE doc_appointments SET date = ${appointmentUpdate.date}, time = ${appointmentUpdate.time}, place = ${appointmentUpdate.place}, disease = ${appointmentUpdate.disease}, doctor_name = ${doctorNameValue}, completed = ${appointmentUpdate.completed ? "1" : "0"} WHERE id = ${appointmentUpdate.appointmentId} AND user_id = ${appointmentUpdate.userId}`;
        sql:ExecutionResult|sql:Error result = dbClient->execute(updateQuery);
        
        if result is sql:Error {
            return <http:InternalServerError>{ body: { message: "Failed to update appointment" } };
        }
        
        return <http:Ok>{ body: { message: "Appointment updated successfully" } };
    }

    // Delete doctor appointment endpoint
    resource function delete deleteDocAppointment(@http:Payload record {
        string userId;
        string appointmentId;
    } appointmentDelete) returns http:Ok|http:NotFound|http:InternalServerError|error {
        if globalClient is () {
            return <http:InternalServerError>{ body: { message: "Database not initialized" } };
        }
        mysql:Client dbClient = <mysql:Client>globalClient;
        
        // First ensure we're using the correct database
        sql:ExecutionResult|sql:Error useDbResult = dbClient->execute(`USE railway`);
        if useDbResult is sql:Error {
            return <http:InternalServerError>{ body: { message: "Database connection error" } };
        }
        
        // First, check if the appointment exists
        sql:ParameterizedQuery checkQuery = `SELECT COUNT(*) as count FROM doc_appointments WHERE id = ${appointmentDelete.appointmentId} AND user_id = ${appointmentDelete.userId}`;
        
        stream<record {}, sql:Error?> checkResult = dbClient->query(checkQuery);
        record {}|sql:Error? checkRow = checkResult.next();
        if checkRow is sql:Error {
            return <http:InternalServerError>{ body: { message: "Database error" } };
        }
        record {} row = <record {}>checkRow;
        record {} rowData = row;
        if row.hasKey("value") {
            rowData = <record {}>row["value"];
        }
        int count = rowData["count"] is int ? <int>rowData["count"] : 0;
        
        if count == 0 {
            return <http:NotFound>{ body: { message: "Appointment not found" } };
        }
        
        // Delete the appointment
        sql:ParameterizedQuery deleteQuery = `DELETE FROM doc_appointments WHERE id = ${appointmentDelete.appointmentId} AND user_id = ${appointmentDelete.userId}`;
        sql:ExecutionResult|sql:Error result = dbClient->execute(deleteQuery);
        if result is sql:Error {
            return <http:InternalServerError>{ body: { message: "Error deleting appointment" } };
        }
        
        return <http:Ok>{ body: { message: "Appointment deleted successfully" } };
    }

    // Toggle appointment status endpoint (mark as pending/completed)
    resource function put toggleAppointmentStatus(@http:Payload record {
        string userId;
        string appointmentId;
    } appointmentToggle) returns http:Ok|http:NotFound|http:InternalServerError|error {
        if globalClient is () {
            return <http:InternalServerError>{ body: { message: "Database not initialized" } };
        }
        mysql:Client dbClient = <mysql:Client>globalClient;
        
        // First ensure we're using the correct database
        sql:ExecutionResult|sql:Error useDbResult = dbClient->execute(`USE railway`);
        if useDbResult is sql:Error {
            return <http:InternalServerError>{ body: { message: "Database connection error" } };
        }
        
        // First, check if the appointment exists and get current status
        sql:ParameterizedQuery checkQuery = `SELECT completed FROM doc_appointments WHERE id = ${appointmentToggle.appointmentId} AND user_id = ${appointmentToggle.userId}`;
        
        stream<record {}, sql:Error?> checkResult = dbClient->query(checkQuery);
        record {}|sql:Error? checkRow = checkResult.next();
        
        // Check if we got an error or no result
        if checkRow is sql:Error {
            return <http:InternalServerError>{ body: { message: "Database error" } };
        }
        
        // Check if no appointment was found
        if checkRow is () {
            return <http:NotFound>{ body: { message: "Appointment not found" } };
        }
        
        record {} row = <record {}>checkRow;
        record {} rowData = row;
        if row.hasKey("value") {
            rowData = <record {}>row["value"];
        }
        
        if (!rowData.hasKey("completed")) {
            return <http:NotFound>{ body: { message: "Appointment not found" } };
        }
        
        // Get current completed status - handle both boolean and int types
        boolean currentStatus = false;
        if (rowData["completed"] is boolean) {
            currentStatus = <boolean>rowData["completed"];
        } else if (rowData["completed"] is int) {
            currentStatus = <int>rowData["completed"] == 1;
        } else if (rowData["completed"] is string) {
            currentStatus = <string>rowData["completed"] == "1";
        }
        
        // Toggle the status
        boolean newStatus = !currentStatus;
        
        // Update the appointment status - include database name in query
        sql:ParameterizedQuery updateQuery = `UPDATE doc_appointments SET completed = ${newStatus ? "1" : "0"} WHERE id = ${appointmentToggle.appointmentId} AND user_id = ${appointmentToggle.userId}`;
        io:println("DEBUG: Updating appointment " + appointmentToggle.appointmentId + " to status: " + newStatus.toString());
        
        sql:ExecutionResult|sql:Error result = dbClient->execute(updateQuery);
        
        if result is sql:Error {
            io:println("DEBUG: Update failed with error: " + result.message());
            return <http:InternalServerError>{ body: { message: "Failed to toggle appointment status" } };
        }
        
        io:println("DEBUG: Update successful, rows affected: " + result.affectedRowCount.toString());
        
        string statusMessage = newStatus ? "completed" : "pending";
        return <http:Ok>{ body: { message: "Appointment marked as " + statusMessage, newStatus: newStatus } };
    }

    // Get BMI records endpoint
    resource function get getBmiRecords(string userId) returns http:Ok|http:NotFound|http:InternalServerError|error {
        if globalClient is () {
            return <http:InternalServerError>{ body: { message: "Database not initialized" } };
        }
        mysql:Client dbClient = <mysql:Client>globalClient;
        
        io:println("DEBUG: getBmiRecords called for userId: " + userId);
        
        sql:ParameterizedQuery bq = `SELECT id, user_id, weight, height, bmi, classification, notes, created_at FROM bmi_records WHERE user_id = ${userId} ORDER BY created_at DESC`;
        io:println("DEBUG: SQL Query executed for userId: " + userId);
        
        stream<record {}, sql:Error?> s = dbClient->query(bq);
        record {}[] bmiRecords = [];
        while true {
            record {}|sql:Error? row = s.next();
            if row is record {} { 
                bmiRecords.push(row); 
                io:println("DEBUG: Found BMI row: " + row.toString());
            } else { 
                break; 
            }
        }
        
        io:println("DEBUG: Total BMI records found: " + bmiRecords.length().toString());
        
        if bmiRecords.length() == 0 {
            io:println("DEBUG: No BMI records found for userId: " + userId);
            return <http:Ok>{ body: [] };
        }
        
        // Transform the data to handle nested 'value' field and match frontend expectations
        record {
            string id;
            string userId;
            decimal weight;
            decimal height;
            decimal bmi;
            string classification;
            string? notes;
            string createdAt;
        }[] transformedBmiRecords = [];
        
        foreach record {} bmiRecord in bmiRecords {
            io:println("DEBUG: Processing BMI record: " + bmiRecord.toString());
            
            // Handle the nested 'value' field structure from MySQL results
            record {} bmiData = bmiRecord;
            if bmiRecord.hasKey("value") {
                bmiData = <record {}>bmiRecord["value"];
                io:println("DEBUG: Found nested 'value' field, using bmiData");
            }
            
            // Extract and transform fields - handle both string and int types for id
            string id = "";
            if (bmiData["id"] is int) {
                id = (<int>bmiData["id"]).toString();
            } else if (bmiData["id"] is string) {
                id = <string>bmiData["id"];
            }
            
            string dbUserId = bmiData["user_id"] is string ? <string>bmiData["user_id"] : "";
            
            // Handle weight - could be decimal or float
            decimal weight = 0.0;
            if (bmiData["weight"] is decimal) {
                weight = <decimal>bmiData["weight"];
            } else if (bmiData["weight"] is float) {
                weight = <decimal>(<float>bmiData["weight"]);
            }
            
            // Handle height - could be decimal or float
            decimal height = 0.0;
            if (bmiData["height"] is decimal) {
                height = <decimal>bmiData["height"];
            } else if (bmiData["height"] is float) {
                height = <decimal>(<float>bmiData["height"]);
            }
            
            // Handle bmi - could be decimal or float, and round to 2 decimal places
            decimal bmi = 0.0;
            if (bmiData["bmi"] is decimal) {
                bmi = <decimal>bmiData["bmi"];
            } else if (bmiData["bmi"] is float) {
                bmi = <decimal>(<float>bmiData["bmi"]);
            }
            // Round BMI to 2 decimal places for display
            bmi = <decimal>roundTo2Decimals(<float>bmi);
            
            string classification = bmiData["classification"] is string ? <string>bmiData["classification"] : "";
            string? notes = bmiData["notes"] is string ? <string>bmiData["notes"] : ();
            string createdAt = bmiData["created_at"] is string ? <string>bmiData["created_at"] : "";
            
            io:println("DEBUG: Transformed BMI record - id: " + id + ", weight: " + weight.toString() + ", height: " + height.toString() + ", bmi: " + bmi.toString());
            
            record {
                string id;
                string userId;
                decimal weight;
                decimal height;
                decimal bmi;
                string classification;
                string? notes;
                string createdAt;
            } transformedBmiRecord = {
                id: id,
                userId: dbUserId,
                weight: weight,
                height: height,
                bmi: bmi,
                classification: classification,
                notes: notes,
                createdAt: createdAt
            };
            
            transformedBmiRecords.push(transformedBmiRecord);
        }
        
        io:println("DEBUG: Returning " + transformedBmiRecords.length().toString() + " transformed BMI records");
        return <http:Ok>{ body: transformedBmiRecords };
    }

    // Login endpoint
    resource function post login(@http:Payload record {
        string email;
        string password;
    } loginData) returns http:Ok|http:Unauthorized|http:InternalServerError|error {
        if globalClient is () {
            return <http:InternalServerError>{ body: { message: "Database not initialized" } };
        }
        mysql:Client dbClient = <mysql:Client>globalClient;
        
        io:println("Login attempt for email: ", loginData.email);
        
        string hashedPassword = hashPassword(loginData.password);
        io:println("Hashed password: ", hashedPassword);
        
        // Debug: Check all users in database
        sql:ParameterizedQuery allUsersQuery = `SELECT id, first_name, last_name, email FROM users`;
        stream<record {}, sql:Error?> allUsersStream = dbClient->query(allUsersQuery);
        record {}[] allUsers = [];
        while true {
            record {}|sql:Error? row = allUsersStream.next();
            if row is record {} { allUsers.push(row); } else { break; }
        }
        io:println("Total users in database: ", allUsers.length());
        foreach record {} user in allUsers {
            string email = user["email"] is string ? user["email"].toString() : "NULL";
            io:println("User ID: ", user["id"].toString(), ", Email: ", email);
        }
        
        // Check if user exists and verify password
        sql:ParameterizedQuery loginQuery = `SELECT id, first_name, last_name, email, password FROM users WHERE email = ${loginData.email}`;
        io:println("Login query: ", loginQuery);
        stream<record {}, sql:Error?> s = dbClient->query(loginQuery);
        record {}[] users = [];
        while true {
            record {}|sql:Error? row = s.next();
            if row is record {} { users.push(row); } else { break; }
        }
        
        io:println("Users found with this email: ", users.length());
        
        if users.length() == 0 {
            io:println("No user found with email: ", loginData.email);
            return <http:Unauthorized>{ body: { message: "Invalid email or password" } };
        }
        
        record {} user = users[0];
        
        // Debug: Show the entire result set
        io:println("=== DEBUG INFO ===");
        io:println("Raw user record: ", user);
        io:println("User record keys: ", user.keys());
        io:println("User record length: ", user.length());
        
        // The data is nested inside a 'value' field due to MySQL result parsing
        string storedPassword = "";
        string userEmail = "";
        string userId = "";
        
        if user.hasKey("value") {
            record {} userData = <record {}>user["value"];
            io:println("User data record: ", userData);
            io:println("User data keys: ", userData.keys());
            
            if userData.hasKey("password") {
                storedPassword = userData["password"].toString();
                io:println("Password field exists and value: ", storedPassword);
            } else {
                io:println("Password field does NOT exist in userData");
            }
            
            if userData.hasKey("email") {
                userEmail = userData["email"].toString();
                io:println("Email field exists and value: ", userEmail);
            } else {
                io:println("Email field does NOT exist in userData");
            }
            
            if userData.hasKey("id") {
                userId = userData["id"].toString();
                io:println("ID field exists and value: ", userId);
            } else {
                io:println("ID field does NOT exist in userData");
            }
        } else {
            io:println("No 'value' field found in user record");
        }
        
        io:println("User typed password (raw): ", loginData.password);
        io:println("User typed password length: ", loginData.password.length());
        io:println("Hashed password: ", hashedPassword);
        io:println("Hashed password length: ", hashedPassword.length());
        io:println("Password match: ", hashedPassword == storedPassword);
        io:println("==================");
        
        if (hashedPassword != storedPassword) {
            io:println("Password does not match");
            return <http:Unauthorized>{ body: { message: "Invalid email or password" } };
        }
        
        string name = user["first_name"].toString() + " " + user["last_name"].toString();
        
        io:println("Login successful for user: ", name);
        
        return <http:Ok>{ body: { message: "Login successful", userId: userId, name: name, email: userEmail } };
    }

    // Update user profile endpoint
    resource function put updateUserProfile(@http:Payload record {
        string userId;
        string firstName;
        string lastName;
        string email;
        string gender;
        string dateOfBirth;
        string phoneNumber;
        string photoDataUrl;
    } profileUpdate) returns http:Ok|http:BadRequest|http:InternalServerError|error {
        if globalClient is () {
            return <http:InternalServerError>{ body: { message: "Database not initialized" } };
        }
        mysql:Client dbClient = <mysql:Client>globalClient;
        
        // Build the query with individual field updates
        sql:ParameterizedQuery updateQuery = `UPDATE users SET first_name = ${profileUpdate.firstName}, last_name = ${profileUpdate.lastName}, email = ${profileUpdate.email}, gender = ${profileUpdate.gender}, date_of_birth = ${profileUpdate.dateOfBirth}, phone_number = ${profileUpdate.phoneNumber}, photo_data_url = ${profileUpdate.photoDataUrl} WHERE id = ${profileUpdate.userId}`;
        io:println("DEBUG: Profile update query: ", updateQuery);
        sql:ExecutionResult|sql:Error updateResult = dbClient->execute(updateQuery);
        if (updateResult is sql:Error) {
            io:println("DEBUG: Profile update error: ", updateResult.message());
            return <http:InternalServerError>{ body: { message: "Error updating profile" } };
        }
        
        return <http:Ok>{ body: { message: "Profile updated successfully" } };
    }

    // Delete user profile endpoint
    resource function delete deleteProfile(@http:Payload record {
        string userId;
    } profileDelete) returns http:Ok|http:BadRequest|http:InternalServerError|error {
        if globalClient is () {
            return <http:InternalServerError>{ body: { message: "Database not initialized" } };
        }
        mysql:Client dbClient = <mysql:Client>globalClient;
        
        // Delete user and all related data (cascade delete)
        sql:ParameterizedQuery deleteQuery = `DELETE FROM users WHERE id = ${profileDelete.userId}`;
        sql:ExecutionResult|sql:Error deleteResult = dbClient->execute(deleteQuery);
        if deleteResult is sql:Error {
            return <http:InternalServerError>{ body: { message: "Error deleting profile" } };
        }
        
        return <http:Ok>{ body: { message: "Profile deleted successfully" } };
    }

    // Add custom vaccine endpoint
    resource function post addCustomVaccine(@http:Payload record {
        string userId;
        record {
            string name;
            string dose;
            boolean received;
            boolean isCustom;
            int offsetMonths;
        } vaccine;
    } customVaccine) returns http:Created|http:BadRequest|http:InternalServerError|error {
        if globalClient is () {
            return <http:InternalServerError>{ body: { message: "Database not initialized" } };
        }
        mysql:Client dbClient = <mysql:Client>globalClient;
        
        // Ensure we're using the correct database
        sql:ExecutionResult|sql:Error useDbResult = dbClient->execute(`USE railway`);
        if useDbResult is sql:Error {
            return <http:InternalServerError>{ body: { message: "Database connection error" } };
        }
        
        // Calculate due date based on offset months from current date
        string dueDate = "";
        if (customVaccine.vaccine.offsetMonths > 0) {
            // Use a simple current date for now
            dueDate = "2025-01-27"; // Current date
        }
        
        // Insert only the columns that exist in the vaccine_records table
        sql:ParameterizedQuery insertVaccine = `INSERT INTO vaccine_records (user_id, name, dose, due_date, is_custom, offset_months, created_at) VALUES (${customVaccine.userId}, ${customVaccine.vaccine.name}, ${customVaccine.vaccine.dose}, ${dueDate}, true, ${customVaccine.vaccine.offsetMonths}, NOW())`;
        
        sql:ExecutionResult|sql:Error insRes = dbClient->execute(insertVaccine);
        if insRes is sql:Error {
            return <http:InternalServerError>{ body: { message: "Error adding custom vaccine" } };
        }
        return <http:Created>{ body: { message: "Custom vaccine added successfully" } };
    }

    // Delete vaccine endpoint (frontend compatible)
    resource function delete deleteVaccine(@http:Payload record {
        string userId;
        string name;
        string dose;
    } vaccineData) returns http:Ok|http:InternalServerError|error {
        if globalClient is () {
            return <http:InternalServerError>{ body: { message: "Database not initialized" } };
        }
        mysql:Client dbClient = <mysql:Client>globalClient;
        

        
        // First, check if the vaccine exists
        sql:ParameterizedQuery checkQuery = `SELECT COUNT(*) as count FROM vaccine_records WHERE user_id = ${vaccineData.userId} AND name = ${vaccineData.name} AND dose = ${vaccineData.dose}`;
        
        stream<record {}, sql:Error?> checkResult = dbClient->query(checkQuery);
        record {}|sql:Error? checkRow = checkResult.next();
        if checkRow is sql:Error {
            return <http:InternalServerError>{ body: { message: "Database error" } };
        }
        record {} row = <record {}>checkRow;
        record {} rowData = row;
        if row.hasKey("value") {
            rowData = <record {}>row["value"];
        }
        int count = rowData["count"] is int ? <int>rowData["count"] : 0;
        
        if count == 0 {
            return <http:InternalServerError>{ body: { message: "Vaccine not found" } };
        }
        
        // Delete the vaccine record
        sql:ParameterizedQuery deleteQuery = `DELETE FROM vaccine_records WHERE user_id = ${vaccineData.userId} AND name = ${vaccineData.name} AND dose = ${vaccineData.dose}`;
        
        // First ensure we're using the correct database
        sql:ExecutionResult|sql:Error useDbResult = dbClient->execute(`USE railway`);
        if useDbResult is sql:Error {
            return <http:InternalServerError>{ body: { message: "Database connection error" } };
        }
        
        sql:ExecutionResult|sql:Error result = dbClient->execute(deleteQuery);
        if result is sql:Error {
            return <http:InternalServerError>{ body: { message: "Error deleting vaccine" } };
        }
        
        return <http:Ok>{ body: { message: "Vaccine deleted successfully" } };
    }

    // Add doctor appointment endpoint
    resource function post addDocAppointment(@http:Payload record {
        string userId;
        string date;
        string time;
        string place;
        string disease;
    } appointment) returns http:Created|http:BadRequest|http:InternalServerError|error {
        if globalClient is () {
            return <http:InternalServerError>{ body: { message: "Database not initialized" } };
        }
        mysql:Client dbClient = <mysql:Client>globalClient;
        
        io:println("DEBUG: addDocAppointment called for userId: " + appointment.userId);
        io:println("DEBUG: Appointment data: " + appointment.toString());
        // Normalize time to HH:MM:SS if provided as HH:MM
        string normTime = appointment.time;
        if normTime.length() == 5 { // e.g., 09:30
            normTime = normTime + ":00";
        }

        // Insert with normalized time; column names match schema
        sql:ParameterizedQuery insertAppointment = `INSERT INTO doc_appointments (user_id, date, time, place, disease, doctor_name, completed, created_at) VALUES (${appointment.userId}, ${appointment.date}, ${normTime}, ${appointment.place}, ${appointment.disease}, 'General Doctor', false, NOW())`;
        io:println("DEBUG: SQL Insert query executed for userId: " + appointment.userId);
        
        sql:ExecutionResult|sql:Error insRes = dbClient->execute(insertAppointment);
        if insRes is sql:Error {
            io:println("DEBUG: Error inserting appointment: " + insRes.toString());
            return <http:InternalServerError>{ body: { message: "Error adding doctor appointment" } };
        }
        
        io:println("DEBUG: Doctor appointment added successfully");
        return <http:Created>{ body: { message: "Doctor appointment added successfully" } };
    }

    // Get appointments endpoint
    resource function get getAppointments(string userId) returns http:Ok|http:NotFound|http:InternalServerError|error {
        if globalClient is () {
            return <http:InternalServerError>{ body: { message: "Database not initialized" } };
        }
        mysql:Client dbClient = <mysql:Client>globalClient;
        
        sql:ParameterizedQuery aq = `SELECT id, user_id, title, date, time, notes, completed, created_at FROM appointments WHERE user_id = ${userId}`;
        stream<record {}, sql:Error?> s = dbClient->query(aq);
        record {}[] appointments = [];
        while true {
            record {}|sql:Error? row = s.next();
            if row is record {} { appointments.push(row); } else { break; }
        }
        
        return <http:Ok>{ body: appointments };
    }

    // Add appointment endpoint
    resource function post addAppointment(@http:Payload record {
        string userId;
        string title;
        string date;
        string time;
        string? notes;
    } appointment) returns http:Created|http:BadRequest|http:InternalServerError|error {
        if globalClient is () {
            return <http:InternalServerError>{ body: { message: "Database not initialized" } };
        }
        mysql:Client dbClient = <mysql:Client>globalClient;
        
        sql:ParameterizedQuery insertAppointment = `INSERT INTO appointments (user_id, title, date, time, notes, completed, created_at) VALUES (${appointment.userId}, ${appointment.title}, ${appointment.date}, ${appointment.time}, ${appointment.notes ?: ""}, false, NOW())`;
        sql:ExecutionResult|sql:Error insRes = dbClient->execute(insertAppointment);
        if insRes is sql:Error {
            return <http:InternalServerError>{ body: { message: "Error adding appointment" } };
        }
        
        return <http:Created>{ body: { message: "Appointment added successfully" } };
    }

    // Update password endpoint (for fixing existing users)
    resource function put updatePassword(@http:Payload record {
        string email;
        string newPassword;
    } passwordUpdate) returns http:Ok|http:BadRequest|http:InternalServerError|error {
        if globalClient is () {
            return <http:InternalServerError>{ body: { message: "Database not initialized" } };
        }
        mysql:Client dbClient = <mysql:Client>globalClient;
        
        string hashedPassword = hashPassword(passwordUpdate.newPassword);
        
        sql:ParameterizedQuery updateQuery = `UPDATE users SET password = ${hashedPassword} WHERE email = ${passwordUpdate.email}`;
        sql:ExecutionResult|sql:Error updateResult = dbClient->execute(updateQuery);
        if updateResult is sql:Error {
            return <http:InternalServerError>{ body: { message: "Error updating password" } };
        }
        
        return <http:Ok>{ body: { message: "Password updated successfully" } };
    }

    // Add BMI record endpoint
    resource function post addBmiRecord(@http:Payload record {
        string userId;
        float weight;
        float height;
        string date;
        string notes;
    } bmiRecord) returns http:Created|http:BadRequest|http:InternalServerError|error {
        if globalClient is () {
            return <http:InternalServerError>{ body: { message: "Database not initialized" } };
        }
        mysql:Client dbClient = <mysql:Client>globalClient;
        
        // Convert height from centimeters to meters for BMI calculation
        float heightInMeters = bmiRecord.height / 100.0f;
        float bmi = bmiRecord.weight / (heightInMeters * heightInMeters);
        
        // Get user profile to calculate age and use growth classification
        sql:ParameterizedQuery profileQuery = `SELECT gender, date_of_birth FROM users WHERE id = ${bmiRecord.userId}`;
        stream<record {}, sql:Error?> profileStream = dbClient->query(profileQuery);
        record {}[] profiles = [];
        while true {
            record {}|sql:Error? row = profileStream.next();
            if row is record {} { profiles.push(row); } else { break; }
        }
        
        string classification = "";
        if (profiles.length() > 0) {
            record {} profile = profiles[0];
            if (profile.hasKey("value")) {
                record {} profileData = <record {}>profile["value"];
                string gender = profileData.hasKey("gender") ? profileData["gender"].toString() : "";
                string dateOfBirth = profileData.hasKey("date_of_birth") ? profileData["date_of_birth"].toString() : "";
                
                if (gender != "" && dateOfBirth != "") {
                    int ageInMonths = calculateAgeInMonths(dateOfBirth);
                    if (ageInMonths <= 24) {
                        // Use WHO growth standards for children under 2 years
                        classification = getGrowthClassification(gender, ageInMonths, bmiRecord.weight);
                    } else {
                        // Use standard BMI classification for older ages
                        if (bmi < 18.5f) {
                            classification = "underweight";
                        } else if (bmi < 25.0f) {
                            classification = "healthy";
                        } else if (bmi < 30.0f) {
                            classification = "overweight";
                        } else {
                            classification = "obese";
                        }
                    }
                } else {
                    // Fallback to standard BMI classification
                    if (bmi < 18.5f) {
                        classification = "underweight";
                    } else if (bmi < 25.0f) {
                        classification = "healthy";
                    } else if (bmi < 30.0f) {
                        classification = "overweight";
                    } else {
                        classification = "obese";
                    }
                }
            }
        } else {
            // Fallback to standard BMI classification
            if (bmi < 18.5f) {
                classification = "underweight";
            } else if (bmi < 25.0f) {
                classification = "healthy";
            } else if (bmi < 30.0f) {
                classification = "overweight";
            } else {
                classification = "obese";
            }
        }
        
        // First ensure we're using the correct database
        sql:ExecutionResult|sql:Error useDbResult = dbClient->execute(`USE railway`);
        if useDbResult is sql:Error {
            return <http:InternalServerError>{ body: { message: "Database connection error" } };
        }
        
        // Round values to avoid floating-point precision issues
        int roundedHeight = roundToInt(bmiRecord.height);
        float roundedWeight = roundTo1Decimal(bmiRecord.weight); // Round to 1 decimal place
        float roundedBmi = roundTo2Decimals(bmi); // Round to 2 decimal places
        
        // Insert the BMI record
        sql:ParameterizedQuery insertQuery;
        if (bmiRecord.notes != "") {
            insertQuery = `INSERT INTO bmi_records (user_id, weight, height, bmi, classification, notes, created_at) VALUES (${bmiRecord.userId}, ${roundedWeight}, ${roundedHeight}, ${roundedBmi}, ${classification}, ${bmiRecord.notes}, NOW())`;
        } else {
            insertQuery = `INSERT INTO bmi_records (user_id, weight, height, bmi, classification, created_at) VALUES (${bmiRecord.userId}, ${roundedWeight}, ${roundedHeight}, ${roundedBmi}, ${classification}, NOW())`;
        }
        
        sql:ExecutionResult|sql:Error insertResult = dbClient->execute(insertQuery);
        if insertResult is sql:Error {
            return <http:InternalServerError>{ body: { message: "Error adding BMI record" } };
        }
        
        return <http:Created>{ body: { message: "BMI record added successfully", bmi: bmi } };
    }

    // Update BMI record endpoint
    resource function put updateBmiRecord(@http:Payload record {
        string userId;
        string recordId;
        float weight;
        float height;
        string date;
        string? notes;
    } bmiUpdate) returns http:Ok|http:NotFound|http:InternalServerError|error {
        if globalClient is () {
            return <http:InternalServerError>{ body: { message: "Database not initialized" } };
        }
        mysql:Client dbClient = <mysql:Client>globalClient;
        
        // First, check if the BMI record exists
        sql:ParameterizedQuery checkQuery = `SELECT COUNT(*) as count FROM bmi_records WHERE id = ${bmiUpdate.recordId} AND user_id = ${bmiUpdate.userId}`;
        
        stream<record {}, sql:Error?> checkResult = dbClient->query(checkQuery);
        record {}|sql:Error? checkRow = checkResult.next();
        if checkRow is sql:Error {
            return <http:InternalServerError>{ body: { message: "Database error" } };
        }
        record {} row = <record {}>checkRow;
        record {} rowData = row;
        if row.hasKey("value") {
            rowData = <record {}>row["value"];
        }
        int count = rowData["count"] is int ? <int>rowData["count"] : 0;
        
        if count == 0 {
            return <http:NotFound>{ body: { message: "BMI record not found" } };
        }
        
        // Convert height from centimeters to meters for BMI calculation
        float heightInMeters = bmiUpdate.height / 100.0f;
        float bmi = bmiUpdate.weight / (heightInMeters * heightInMeters);
        
        // Get user profile to calculate age and use growth classification
        sql:ParameterizedQuery profileQuery = `SELECT gender, date_of_birth FROM users WHERE id = ${bmiUpdate.userId}`;
        stream<record {}, sql:Error?> profileStream = dbClient->query(profileQuery);
        record {}[] profiles = [];
        while true {
            record {}|sql:Error? profileRow = profileStream.next();
            if profileRow is record {} { profiles.push(profileRow); } else { break; }
        }
        
        string classification = "";
        if (profiles.length() > 0) {
            record {} profile = profiles[0];
            if (profile.hasKey("value")) {
                record {} profileData = <record {}>profile["value"];
                string gender = profileData.hasKey("gender") ? profileData["gender"].toString() : "";
                string dateOfBirth = profileData.hasKey("date_of_birth") ? profileData["date_of_birth"].toString() : "";
                
                if (gender != "" && dateOfBirth != "") {
                    int ageInMonths = calculateAgeInMonths(dateOfBirth);
                    if (ageInMonths <= 24) {
                        // Use WHO growth standards for children under 2 years
                        classification = getGrowthClassification(gender, ageInMonths, bmiUpdate.weight);
                    } else {
                        // Use standard BMI classification for older ages
                        if (bmi < 18.5f) {
                            classification = "underweight";
                        } else if (bmi < 25.0f) {
                            classification = "healthy";
                        } else if (bmi < 30.0f) {
                            classification = "overweight";
                        } else {
                            classification = "obese";
                        }
                    }
                } else {
                    // Fallback to standard BMI classification
                    if (bmi < 18.5f) {
                        classification = "underweight";
                    } else if (bmi < 25.0f) {
                        classification = "healthy";
                    } else if (bmi < 30.0f) {
                        classification = "overweight";
                    } else {
                        classification = "obese";
                    }
                }
            }
        } else {
            // Fallback to standard BMI classification
            if (bmi < 18.5f) {
                classification = "underweight";
            } else if (bmi < 25.0f) {
                classification = "healthy";
            } else if (bmi < 30.0f) {
                classification = "overweight";
            } else {
                classification = "obese";
            }
        }
        
        // First ensure we're using the correct database
        sql:ExecutionResult|sql:Error useDbResult = dbClient->execute(`USE railway`);
        if useDbResult is sql:Error {
            return <http:InternalServerError>{ body: { message: "Database connection error" } };
        }
        
        // Round values to avoid floating-point precision issues
        int roundedHeight = roundToInt(bmiUpdate.height);
        float roundedWeight = roundTo1Decimal(bmiUpdate.weight); // Round to 1 decimal place
        float roundedBmi = roundTo2Decimals(bmi); // Round to 2 decimal places
        
        // Update the BMI record
        sql:ParameterizedQuery updateQuery;
        if (bmiUpdate.notes is string) {
            updateQuery = `UPDATE bmi_records SET weight = ${roundedWeight}, height = ${roundedHeight}, bmi = ${roundedBmi}, classification = ${classification}, notes = ${<string>bmiUpdate.notes} WHERE id = ${bmiUpdate.recordId} AND user_id = ${bmiUpdate.userId}`;
        } else {
            updateQuery = `UPDATE bmi_records SET weight = ${roundedWeight}, height = ${roundedHeight}, bmi = ${roundedBmi}, classification = ${classification} WHERE id = ${bmiUpdate.recordId} AND user_id = ${bmiUpdate.userId}`;
        }
        
        sql:ExecutionResult|sql:Error result = dbClient->execute(updateQuery);
        if result is sql:Error {
            return <http:InternalServerError>{ body: { message: "Failed to update BMI record" } };
        }
        
        return <http:Ok>{ body: { message: "BMI record updated successfully", bmi: bmi } };
    }

    // Delete BMI record endpoint
    resource function delete deleteBmiRecord(@http:Payload record {
        string userId;
        string recordId;
    } bmiDelete) returns http:Ok|http:NotFound|http:InternalServerError|error {
        if globalClient is () {
            return <http:InternalServerError>{ body: { message: "Database not initialized" } };
        }
        mysql:Client dbClient = <mysql:Client>globalClient;
        
        // First, check if the BMI record exists
        sql:ParameterizedQuery checkQuery = `SELECT COUNT(*) as count FROM bmi_records WHERE id = ${bmiDelete.recordId} AND user_id = ${bmiDelete.userId}`;
        
        stream<record {}, sql:Error?> checkResult = dbClient->query(checkQuery);
        record {}|sql:Error? checkRow = checkResult.next();
        if checkRow is sql:Error {
            return <http:InternalServerError>{ body: { message: "Database error" } };
        }
        record {} row = <record {}>checkRow;
        record {} rowData = row;
        if row.hasKey("value") {
            rowData = <record {}>row["value"];
        }
        int count = rowData["count"] is int ? <int>rowData["count"] : 0;
        
        if count == 0 {
            return <http:NotFound>{ body: { message: "BMI record not found" } };
        }
        
        // First ensure we're using the correct database
        sql:ExecutionResult|sql:Error useDbResult = dbClient->execute(`USE railway`);
        if useDbResult is sql:Error {
            return <http:InternalServerError>{ body: { message: "Database connection error" } };
        }
        
        // Delete the BMI record
        sql:ParameterizedQuery deleteQuery = `DELETE FROM bmi_records WHERE id = ${bmiDelete.recordId} AND user_id = ${bmiDelete.userId}`;
        sql:ExecutionResult|sql:Error result = dbClient->execute(deleteQuery);
        if result is sql:Error {
            return <http:InternalServerError>{ body: { message: "Error deleting BMI record" } };
        }
        
        return <http:Ok>{ body: { message: "BMI record deleted successfully" } };
    }

    // Add special notes endpoint
    resource function post addSpecialNotes(@http:Payload record {
        string userId;
        string notes;
    } specialNotes) returns http:Created|http:BadRequest|http:InternalServerError|error {
        if globalClient is () {
            return <http:InternalServerError>{ body: { message: "Database not initialized" } };
        }
        mysql:Client dbClient = <mysql:Client>globalClient;
        
        // First ensure we're using the correct database
        sql:ExecutionResult|sql:Error useDbResult = dbClient->execute(`USE railway`);
        if useDbResult is sql:Error {
            return <http:InternalServerError>{ body: { message: "Database connection error" } };
        }
        
        sql:ParameterizedQuery updateQuery = `UPDATE users SET special_notes = ${specialNotes.notes} WHERE id = ${specialNotes.userId}`;
        sql:ExecutionResult|sql:Error updateResult = dbClient->execute(updateQuery);
        if updateResult is sql:Error {
            return <http:InternalServerError>{ body: { message: "Error adding special notes" } };
        }
        
        return <http:Created>{ body: { message: "Special notes added successfully" } };
    }

    // Get special notes endpoint
    resource function get getSpecialNotes(string userId) returns http:Ok|http:NotFound|http:InternalServerError|error {
        if globalClient is () {
            return <http:InternalServerError>{ body: { message: "Database not initialized" } };
        }
        mysql:Client dbClient = <mysql:Client>globalClient;
        
        // First check if the special_notes column exists
        sql:ParameterizedQuery checkColumnQuery = `SHOW COLUMNS FROM users LIKE 'special_notes'`;
        stream<record {}, sql:Error?> columnCheck = dbClient->query(checkColumnQuery);
        record {}[] columnResults = [];
        while true {
            record {}|sql:Error? row = columnCheck.next();
            if row is record {} { columnResults.push(row); } else { break; }
        }
        
        if (columnResults.length() == 0) {
            // Column doesn't exist, return empty notes
            return <http:Ok>{ body: { notes: "" } };
        }
        
        // First ensure we're using the correct database
        sql:ExecutionResult|sql:Error useDbResult = dbClient->execute(`USE railway`);
        if useDbResult is sql:Error {
            return <http:InternalServerError>{ body: { message: "Database connection error" } };
        }
        
        sql:ParameterizedQuery query = `SELECT special_notes FROM users WHERE id = ${userId}`;
        stream<record {}, sql:Error?> s = dbClient->query(query);
        record {}[] results = [];
        while true {
            record {}|sql:Error? row = s.next();
            if row is record {} { results.push(row); } else { break; }
        }
        
        if results.length() == 0 {
            return <http:NotFound>{ body: { message: "User not found" } };
        }
        
        // Extract notes from the nested 'value' field structure
        record {} rowData = results[0];
        if results[0].hasKey("value") {
            rowData = <record {}>results[0]["value"];
        }
        
        string notes = rowData["special_notes"] is string ? <string>rowData["special_notes"] : "";
        
        return <http:Ok>{ body: { notes: notes } };
    }

    // Add vaccine record endpoint
    resource function post addVaccineRecord(@http:Payload record {
        string userId;
        string name;
        string dose;
        boolean received;
        string? receivedDate;
        boolean isCustom;
        int? offsetMonths;
    } vaccineRecord) returns http:Created|http:BadRequest|http:InternalServerError|error {
        if globalClient is () {
            return <http:InternalServerError>{ body: { message: "Database not initialized" } };
        }
        mysql:Client dbClient = <mysql:Client>globalClient;
        
        sql:ParameterizedQuery insertQuery = `INSERT INTO vaccine_records (user_id, name, dose, received, received_date, is_custom, offset_months, created_at) VALUES (${vaccineRecord.userId}, ${vaccineRecord.name}, ${vaccineRecord.dose}, ${vaccineRecord.received}, ${vaccineRecord.receivedDate ?: ""}, ${vaccineRecord.isCustom}, ${vaccineRecord.offsetMonths ?: 0}, NOW())`;
        sql:ExecutionResult|sql:Error insertResult = dbClient->execute(insertQuery);
        if insertResult is sql:Error {
            return <http:InternalServerError>{ body: { message: "Error adding vaccine record" } };
        }
        
        return <http:Created>{ body: { message: "Vaccine record added successfully" } };
    }

    // Update appointment endpoint
    resource function put updateAppointment(@http:Payload record {
        string userId;
        string appointmentId;
        string? title;
        string? doctor;
        string? specialty;
        string? date;
        string? time;
        string? notes;
        boolean? completed;
    } appointmentUpdate) returns http:Ok|http:BadRequest|http:InternalServerError|error {
        if globalClient is () {
            return <http:InternalServerError>{ body: { message: "Database not initialized" } };
        }
        mysql:Client dbClient = <mysql:Client>globalClient;
        
        // Build dynamic update query
        string updateFields = "";
        if (appointmentUpdate.title is string) {
            updateFields += "title = '" + <string>appointmentUpdate.title + "', ";
        }
        if (appointmentUpdate.doctor is string) {
            updateFields += "doctor = '" + <string>appointmentUpdate.doctor + "', ";
        }
        if (appointmentUpdate.specialty is string) {
            updateFields += "specialty = '" + <string>appointmentUpdate.specialty + "', ";
        }
        if (appointmentUpdate.date is string) {
            updateFields += "date = '" + <string>appointmentUpdate.date + "', ";
        }
        if (appointmentUpdate.time is string) {
            updateFields += "time = '" + <string>appointmentUpdate.time + "', ";
        }
        if (appointmentUpdate.notes is string) {
            updateFields += "notes = '" + <string>appointmentUpdate.notes + "', ";
        }
        if (appointmentUpdate.completed is boolean) {
            updateFields += "completed = " + (<boolean>appointmentUpdate.completed ? "1" : "0") + ", ";
        }
        
        // Remove trailing comma and space
        if (updateFields.length() > 2) {
            updateFields = updateFields.substring(0, updateFields.length() - 2);
        }
        
        if (updateFields == "") {
            return <http:BadRequest>{ body: { message: "No fields to update" } };
        }
        
        sql:ParameterizedQuery updateQuery = `UPDATE appointments SET ${updateFields} WHERE id = ${appointmentUpdate.appointmentId} AND user_id = ${appointmentUpdate.userId}`;
        sql:ExecutionResult|sql:Error updateResult = dbClient->execute(updateQuery);
        if updateResult is sql:Error {
            return <http:InternalServerError>{ body: { message: "Error updating appointment" } };
        }
        
        return <http:Ok>{ body: { message: "Appointment updated successfully" } };
    }

    // Delete appointment endpoint
    resource function delete deleteAppointment(@http:Payload record {
        string userId;
        string appointmentId;
    } appointmentDelete) returns http:Ok|http:BadRequest|http:InternalServerError|error {
        if globalClient is () {
            return <http:InternalServerError>{ body: { message: "Database not initialized" } };
        }
        mysql:Client dbClient = <mysql:Client>globalClient;
        
        sql:ParameterizedQuery deleteQuery = `DELETE FROM appointments WHERE id = ${appointmentDelete.appointmentId} AND user_id = ${appointmentDelete.userId}`;
        sql:ExecutionResult|sql:Error deleteResult = dbClient->execute(deleteQuery);
        if deleteResult is sql:Error {
            return <http:InternalServerError>{ body: { message: "Error deleting appointment" } };
        }
        
        return <http:Ok>{ body: { message: "Appointment deleted successfully" } };
    }

    // Clear special notes endpoint
    resource function delete clearSpecialNotes(@http:Payload record {
        string userId;
    } notesClear) returns http:Ok|http:InternalServerError|error {
        if globalClient is () {
            return <http:InternalServerError>{ body: { message: "Database not initialized" } };
        }
        mysql:Client dbClient = <mysql:Client>globalClient;
        
        // First ensure we're using the correct database
        sql:ExecutionResult|sql:Error useDbResult = dbClient->execute(`USE railway`);
        if useDbResult is sql:Error {
            return <http:InternalServerError>{ body: { message: "Database connection error" } };
        }
        
        // Clear the special notes
        sql:ParameterizedQuery clearQuery = `UPDATE users SET special_notes = '' WHERE id = ${notesClear.userId}`;
        sql:ExecutionResult|sql:Error result = dbClient->execute(clearQuery);
        if result is sql:Error {
            return <http:InternalServerError>{ body: { message: "Error clearing special notes" } };
        }
        
        return <http:Ok>{ body: { message: "Special notes cleared successfully" } };
    }
}
