import ballerina/http;
import ballerina/io;
import ballerina/time;
import ballerina/uuid;
import ballerina/crypto;
import ballerina/env;
import ballerinax/mongodb;
import ballerina/lang.'string as strings;
// ints langlib not needed

// Database configuration
final string DATABASE_NAME = "babadb";
final string[] COLLECTIONS = ["users", "diseases", "appointments", "bmi_records", "vaccine_records", "doc_appointments"];

// Initialize MongoDB client
final mongodb:Client mongoClient = check new ({
    connection: check env:get("MONGODB_URI") ?: "mongodb://localhost:27017/babadb"
});

// Function to hash password - simplified version
function hashPassword(string password) returns string {
    byte[] hashedBytes = crypto:hashSha256(password.toBytes());
    // Convert to a more reliable string representation
    string result = "";
    foreach int i in 0..<hashedBytes.length() {
        result = result + hashedBytes[i].toString();
    }
    return result;
}

// Compute due date (yyyy-MM-dd) from DOB (yyyy-MM-dd) and offset months
function computeDueDateFromDOB(string dobISO, int offsetMonths) returns string {
    string base = dobISO;
    if !strings:includes(base, "T") { base = base + "T00:00:00Z"; }
    else if !strings:includes(base, "Z") && !strings:includes(base, "+") && !strings:includes(base, "-") { base = base + "Z"; }
    time:Utc|error dobUtc = time:utcFromString(base);
    if dobUtc is error {
        // Fallback: just return original dobISO if parsing fails
        return dobISO;
    }
    time:Civil dob = time:utcToCivil(dobUtc);
    int totalMonths = dob.year * 12 + (dob.month - 1) + offsetMonths;
    int newYear = totalMonths / 12;
    int newMonth = (totalMonths % 12) + 1;
    int day = dob.day;
    string mm = newMonth < 10 ? "0" + newMonth.toString() : newMonth.toString();
    string dd = day < 10 ? "0" + day.toString() : day.toString();
    return newYear.toString() + "-" + mm + "-" + dd;
}

// Update the verify password function with debugging
function verifyPassword(string password, string hashedPassword) returns boolean {
    string hashedInput = hashPassword(password);
    boolean matches = hashedInput == hashedPassword;
    return matches;
}

// Function to initialize database and collections
function initializeDatabase() returns error? {
    io:println("Initializing database and collections...");
    
    mongodb:Database db = check mongoClient->getDatabase(DATABASE_NAME);
    
    // Create collections if they don't exist
    foreach string collectionName in COLLECTIONS {
        error? result = createCollectionIfNotExists(db, collectionName);
        if result is error {
            return result;
        }
    }
    
    io:println("Database initialization completed successfully");
}

// Function to create collection if it doesn't exist
function createCollectionIfNotExists(mongodb:Database db, string collectionName) returns error? {
    // Try to get the collection - if it doesn't exist, create it
    mongodb:Collection collection = check db->getCollection(collectionName);
    
    // Insert a dummy document and immediately delete it to ensure collection exists
    record {} dummyDoc = { "_temp": true, "created_at": time:utcNow().toString() };
    error? insertResult = collection->insertOne(dummyDoc);
    if insertResult is error {
        return insertResult;
    }
    
    io:println("Collection '", collectionName, "' is ready");
    return;
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

    if strings:toLowerAscii(gender) == "female" {
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

// Helper: fetch inner user map (the actual user doc under value.value)
function getUserInnerMap(string userId) returns map<anydata>|()|error {
    mongodb:Database db = check mongoClient->getDatabase(DATABASE_NAME);
    mongodb:Collection usersCollection = check db->getCollection("users");

    // Support both shapes: { value: { id, ... } } and { value: { value: { id, ... } } }
    map<json> filter = {
        "$or": [
            { "value.id": userId },
            { "value.value.id": userId }
        ]
    };

    stream<record {}, error?> resultStream = check usersCollection->find(filter);

    record {}|error? result = check resultStream.next();
    if result is record {} {
        anydata outerValue = result["value"];
        if outerValue is record {} {
            anydata innerValue = outerValue["value"];
            if innerValue is record {} {
                return <map<anydata>>innerValue;
            }
        }
    }
    return ();
}

// Helper: write back vaccines array using typed update to avoid modifier issues
function setUserVaccines(string userId, json vaccinesJson) returns error? {
    mongodb:Database db = check mongoClient->getDatabase(DATABASE_NAME);
    mongodb:Collection usersCollection = check db->getCollection("users");
    // Try single-nested first
    mongodb:Update updateOp1 = { set: { "value.vaccines": vaccinesJson } };
    mongodb:UpdateResult|error res1 = usersCollection->updateOne({ "value.id": userId }, updateOp1);
    if res1 is mongodb:UpdateResult {
        if res1.matchedCount > 0 {
            return;
        }
    } else if res1 is error {
        // If the driver returns an error, try the fallback path too
        // proceed to fallback below
    }
    // Fallback: double-nested
    mongodb:Update updateOp2 = { set: { "value.value.vaccines": vaccinesJson } };
    mongodb:UpdateResult|error res2 = usersCollection->updateOne({ "value.value.id": userId }, updateOp2);
    if res2 is error {
        return res2;
    }
}

// Health service definition
@http:ServiceConfig {
    cors: {
        allowOrigins: ["http://localhost:5173", "http://127.0.0.1:5173", "https://your-frontend-name.vercel.app"],
        allowCredentials: false,
        allowHeaders: ["content-type", "accept", "authorization"],
        allowMethods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
    }
}
service /health on new http:Listener(9090) {

    // Database health check endpoint
    resource function get health() returns http:Ok|http:InternalServerError {
        return <http:Ok>{
            headers: {
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "*",
                "Access-Control-Allow-Headers": "*"
            },
            body: {
                status: "healthy",
                database: DATABASE_NAME,
                collections: COLLECTIONS,
                timestamp: time:utcNow().toString()
            }
        };
    }

    

    

    // Update the signup resource to handle phone number
    resource function post signup(@http:Payload record {
        string firstName;
        string lastName;
        string email;
        string password;
        string gender;
        string dateOfBirth;
        string phoneNumber?;
        VaccineRecord[] vaccines?;
    } newUser) returns http:Created|http:BadRequest|http:InternalServerError|error {
        io:println("Signup request received for: ", newUser.email);
        
        mongodb:Database db = check mongoClient->getDatabase(DATABASE_NAME);
        mongodb:Collection usersCollection = check db->getCollection("users");

        // Create the full user record
        Signup fullUser = {
            id: uuid:createType1AsString(),
            firstName: newUser.firstName,
            lastName: newUser.lastName,
            email: newUser.email,
            password: hashPassword(newUser.password),
            gender: newUser.gender,
            dateOfBirth: newUser.dateOfBirth,
            phoneNumber: newUser.phoneNumber ?: "",
            vaccines: newUser.vaccines ?: getDefaultVaccines(newUser.gender)
        };

        // Create document with proper structure
        record {| Signup value; |} mongoDoc = { value: fullUser };
        error? insertResult = usersCollection->insertOne(mongoDoc);
        if insertResult is error {
            return <http:InternalServerError>{
                headers: {
                    "Access-Control-Allow-Origin": "*",
                    "Access-Control-Allow-Methods": "*",
                    "Access-Control-Allow-Headers": "*"
                },
                body: { message: "Failed to create user" }
            };
        }

        return <http:Created>{
            headers: {
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "*",
                "Access-Control-Allow-Headers": "*"
            },
            body: {
                message: "User created successfully",
                userId: fullUser.id,
                name: fullUser.firstName + " " + fullUser.lastName,
                email: fullUser.email,
                vaccineCount: (fullUser.vaccines ?: []).length()
            }
        };
    }

    // OPTIONS handler for signup
    resource function options signup() returns http:Response {
        http:Response response = new;
        response.setHeader("Access-Control-Allow-Origin", "*");
        response.setHeader("Access-Control-Allow-Methods", "POST, OPTIONS");
        response.setHeader("Access-Control-Allow-Headers", "*");
        return response;
    }

    // Fix the login resource to use a simpler query approach
    resource function post login(@http:Payload record {string email; string password;} credentials) 
        returns http:Ok|http:Unauthorized|http:InternalServerError|error {
    

    mongodb:Database db = check mongoClient->getDatabase(DATABASE_NAME);
    mongodb:Collection usersCollection = check db->getCollection("users");

    // Find all users and filter by email in code (like we did before)
    stream<record {}, error?> resultStream = check usersCollection->find({});
    
    // Get all documents and find the one with matching email
    while true {
        record {}|error? result = check resultStream.next();
        if result is record {} {
            // Check if this document has the matching email
            anydata outerValue = result["value"];
            if outerValue is record {} {
                anydata innerValue = outerValue["value"];
                if innerValue is record {} {
                    map<anydata> userMap = <map<anydata>>innerValue;
                    string userEmail = userMap["email"] is string ? <string>userMap["email"] : "";
                    
                    if userEmail == credentials.email {
                        // Found the user, now verify password
                        string firstName = userMap["firstName"] is string ? <string>userMap["firstName"] : "";
                        string lastName = userMap["lastName"] is string ? <string>userMap["lastName"] : "";
                        string userId = userMap["id"] is string ? <string>userMap["id"] : "";
                        string storedPassword = userMap["password"] is string ? <string>userMap["password"] : "";

                        // Verify password
                        if verifyPassword(credentials.password, storedPassword) {
                            return <http:Ok>{
                                headers: {
                                    "Access-Control-Allow-Origin": "*",
                                    "Access-Control-Allow-Methods": "*",
                                    "Access-Control-Allow-Headers": "*"
                                },
                                body: {
                                    message: "Login successful",
                                    userId: userId,
                                    name: firstName + " " + lastName,
                                    email: credentials.email
                                }
                            };
                        } else {
                            return <http:Unauthorized>{
                                headers: {
                                    "Access-Control-Allow-Origin": "*",
                                    "Access-Control-Allow-Methods": "*",
                                    "Access-Control-Allow-Headers": "*"
                                },
                                body: {message: "Invalid credentials"}
                            };
                        }
                    }
                }
            }
        } else {
            break;
        }
    }
    
    // If we get here, no user was found
    return <http:Unauthorized>{
        headers: {
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Methods": "*",
            "Access-Control-Allow-Headers": "*"
        },
        body: {message: "Invalid credentials"}
    };
}

    // Update the OPTIONS handler for login to use consistent CORS headers
    resource function options login() returns http:Response {
        http:Response response = new;
        response.setHeader("Access-Control-Allow-Origin", "*");
        response.setHeader("Access-Control-Allow-Methods", "POST, OPTIONS");
        response.setHeader("Access-Control-Allow-Headers", "*");
        return response;
    }

    resource function post addDisease(@http:Payload DiseaseRecord disease)
            returns http:Created|http:InternalServerError|error {
        mongodb:Database db = check mongoClient->getDatabase(DATABASE_NAME);
        mongodb:Collection diseaseCollection = check db->getCollection("diseases");

        // Add timestamp
        disease.date = time:utcNow().toString();
        
        error? insertResult = diseaseCollection->insertOne(disease);
        if insertResult is error {
            return <http:InternalServerError>{
                body: { message: "Failed to save disease record" }
            };
        }
        return <http:Created>{ body: { message: "Disease record saved" } };
    }

    resource function get getDiseases(@http:Query string userId)
            returns http:Ok|http:InternalServerError|error {
        mongodb:Database db = check mongoClient->getDatabase(DATABASE_NAME);
        mongodb:Collection diseaseCollection = check db->getCollection("diseases");

        stream<record {}, error?> resultStream = check diseaseCollection->find({ userId: userId });
        DiseaseRecord[] diseases = [];

        while true {
            record {}|error? result = check resultStream.next();
            if result is record {} {
                // Convert record to DiseaseRecord
                map<anydata> diseaseMap = <map<anydata>>result;
                DiseaseRecord disease = {
                    userId: diseaseMap["userId"] is string ? <string>diseaseMap["userId"] : "",
                    diseaseName: diseaseMap["diseaseName"] is string ? <string>diseaseMap["diseaseName"] : "",
                    symptoms: diseaseMap["symptoms"] is string ? <string>diseaseMap["symptoms"] : (),
                    date: diseaseMap["date"] is string ? <string>diseaseMap["date"] : ""
                };
                diseases.push(disease);
            } else {
                break;
            }
        }

        return <http:Ok>{ body: diseases };
    }

    // Add custom vaccine (robust to different document nesting)
    resource function post addCustomVaccine(@http:Payload record {
        string userId;
        VaccineRecord vaccine;
    } payload) returns http:Ok|http:NotFound|http:InternalServerError|error {
        io:println("addCustomVaccine called with userId: ", payload.userId);
        io:println("Vaccine data: ", payload.vaccine);

        map<anydata>|()|error innerOrErr = getUserInnerMap(payload.userId);
        if innerOrErr is error {
            return <http:InternalServerError>{ body: { message: "Failed to load user" } };
        }
        if innerOrErr is () {
            return <http:NotFound>{ body: { message: "User not found" } };
        }
        map<anydata> inner = <map<anydata>>innerOrErr;

        // Read current vaccines
        VaccineRecord[] current = [];
        anydata vaccinesField = inner.hasKey("vaccines") ? inner["vaccines"] : ();
        if vaccinesField is VaccineRecord[] {
            current = vaccinesField;
        } else if vaccinesField is anydata[] {
            anydata[] arr = <anydata[]>vaccinesField;
            foreach anydata item in arr {
                if item is record {} {
                    map<anydata> v = <map<anydata>>item;
                    VaccineRecord rec = {
                        name: v.hasKey("name") && v["name"] is string ? <string>v["name"] : "",
                        dose: v.hasKey("dose") && v["dose"] is string ? <string>v["dose"] : "",
                        received: v.hasKey("received") && v["received"] is boolean ? <boolean>v["received"] : false,
                        receivedDate: v.hasKey("receivedDate") && v["receivedDate"] is string ? <string>v["receivedDate"] : (),
                        isCustom: v.hasKey("isCustom") && v["isCustom"] is boolean ? <boolean>v["isCustom"] : true
                    };
                    current.push(rec);
                }
            }
        }

        // Append new vaccine (force flags for custom entry)
        VaccineRecord toAdd = payload.vaccine;
        toAdd.isCustom = true;
        toAdd.received = false;
        current.push(toAdd);

        // Persist back to embedded user doc
        check setUserVaccines(payload.userId, <json>current);

        // Mirror to vaccine_records collection for visibility
        mongodb:Database db = check mongoClient->getDatabase(DATABASE_NAME);
        mongodb:Collection vaccineCollection = check db->getCollection("vaccine_records");
        map<json> mirrorDoc1 = {
            "userId": payload.userId,
            "name": toAdd.name,
            "dose": toAdd.dose,
            "received": false,
            "isCustom": true,
            "created_at": time:utcNow().toString()
        };
        error? insErr1 = vaccineCollection->insertOne(mirrorDoc1);
        if insErr1 is error { return <http:InternalServerError>{ body: { message: insErr1.message() } }; }

        return <http:Ok>{
            headers: {
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "*",
                "Access-Control-Allow-Headers": "*"
            },
            body: { message: "Custom vaccine added successfully", count: current.length() }
        };
    }
    
    // OPTIONS handler for addCustomVaccine endpoint
    resource function options addCustomVaccine() returns http:Response {
        http:Response response = new;
        response.setHeader("Access-Control-Allow-Origin", "*");
        response.setHeader("Access-Control-Allow-Methods", "*");
        response.setHeader("Access-Control-Allow-Headers", "*");
        return response;
    }
    
    // Delete custom vaccine (read-modify-write)
    resource function delete deleteVaccine(@http:Payload record {
        string userId;
        string name;
        string dose;
    } payload) returns http:Ok|http:NotFound|http:InternalServerError|error {
        map<anydata>|()|error innerOrErr = getUserInnerMap(payload.userId);
        if innerOrErr is error {
            return <http:InternalServerError>{ body: { message: "Failed to load user" } };
        }
        if innerOrErr is () {
            return <http:NotFound>{ body: { message: "User not found" } };
        }
        map<anydata> inner = <map<anydata>>innerOrErr;

        VaccineRecord[] current = [];
        anydata vaccinesField = inner.hasKey("vaccines") ? inner["vaccines"] : ();
        if vaccinesField is VaccineRecord[] {
            current = vaccinesField;
        } else if vaccinesField is anydata[] {
            anydata[] arr = <anydata[]>vaccinesField;
            foreach anydata item in arr {
                if item is record {} {
                    map<anydata> v = <map<anydata>>item;
                    VaccineRecord rec = {
                        name: v.hasKey("name") && v["name"] is string ? <string>v["name"] : "",
                        dose: v.hasKey("dose") && v["dose"] is string ? <string>v["dose"] : "",
                        received: v.hasKey("received") && v["received"] is boolean ? <boolean>v["received"] : false,
                        receivedDate: v.hasKey("receivedDate") && v["receivedDate"] is string ? <string>v["receivedDate"] : (),
                        isCustom: v.hasKey("isCustom") && v["isCustom"] is boolean ? <boolean>v["isCustom"] : false
                    };
                    current.push(rec);
                }
            }
        }

        VaccineRecord[] filtered = from var rec in current
            where !(rec.isCustom is boolean && rec.isCustom == true && rec.name == payload.name && rec.dose == payload.dose)
            select rec;

        // Persist back to embedded user doc
        check setUserVaccines(payload.userId, <json>filtered);

        // Mirror delete in vaccine_records
        mongodb:Database db = check mongoClient->getDatabase(DATABASE_NAME);
        mongodb:Collection vaccineCollection = check db->getCollection("vaccine_records");
        map<json> delFilter = { userId: payload.userId, name: payload.name, dose: payload.dose, isCustom: true };
        mongodb:DeleteResult|error delRes = vaccineCollection->deleteOne(delFilter);
        if delRes is error { return <http:InternalServerError>{ body: { message: delRes.message() } }; }

        return <http:Ok>{
            headers: {
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "*",
                "Access-Control-Allow-Headers": "*"
            },
            body: { message: "Custom vaccine deleted successfully" }
        };
    }
    
    // OPTIONS handler for deleteVaccine endpoint
    resource function options deleteVaccine() returns http:Response {
        http:Response response = new;
        response.setHeader("Access-Control-Allow-Origin", "*");
        response.setHeader("Access-Control-Allow-Methods", "*");
        response.setHeader("Access-Control-Allow-Headers", "*");
        return response;
    }
    
    // Update custom vaccine (read-modify-write)
    resource function put updateVaccine(@http:Payload record {
        string userId;
        string name;
        string dose;
        string newName;
        string newDose;
    } payload) returns http:Ok|http:NotFound|http:InternalServerError|error {
        map<anydata>|()|error innerOrErr = getUserInnerMap(payload.userId);
        if innerOrErr is error {
            return <http:InternalServerError>{ body: { message: "Failed to load user" } };
        }
        if innerOrErr is () {
            return <http:NotFound>{ body: { message: "User not found" } };
        }
        map<anydata> inner = <map<anydata>>innerOrErr;

        VaccineRecord[] current = [];
        anydata vaccinesField = inner.hasKey("vaccines") ? inner["vaccines"] : ();
        if vaccinesField is VaccineRecord[] {
            current = vaccinesField;
        } else if vaccinesField is anydata[] {
            anydata[] arr = <anydata[]>vaccinesField;
            foreach anydata item in arr {
                if item is record {} {
                    map<anydata> v = <map<anydata>>item;
                    VaccineRecord rec = {
                        name: v.hasKey("name") && v["name"] is string ? <string>v["name"] : "",
                        dose: v.hasKey("dose") && v["dose"] is string ? <string>v["dose"] : "",
                        received: v.hasKey("received") && v["received"] is boolean ? <boolean>v["received"] : false,
                        receivedDate: v.hasKey("receivedDate") && v["receivedDate"] is string ? <string>v["receivedDate"] : (),
                        isCustom: v.hasKey("isCustom") && v["isCustom"] is boolean ? <boolean>v["isCustom"] : false
                    };
                    current.push(rec);
                }
            }
        }

        boolean matched = false;
        VaccineRecord[] updated = [];
        foreach var rec in current {
            if rec.isCustom is boolean && rec.isCustom == true && rec.name == payload.name && rec.dose == payload.dose {
                VaccineRecord newRec = { name: payload.newName, dose: payload.newDose, received: false, isCustom: true };
                updated.push(newRec);
                matched = true;
            } else {
                updated.push(rec);
            }
        }

        if !matched {
            return <http:NotFound>{ body: { message: "Custom vaccine not found or not a custom vaccine" } };
        }

        // Persist back to embedded user doc
        check setUserVaccines(payload.userId, <json>updated);

        // Mirror update in vaccine_records
        mongodb:Database db = check mongoClient->getDatabase(DATABASE_NAME);
        mongodb:Collection vaccineCollection = check db->getCollection("vaccine_records");
        map<json> upFilter = { userId: payload.userId, name: payload.name, dose: payload.dose, isCustom: true };
        mongodb:Update up = { set: { name: payload.newName, dose: payload.newDose } };
        mongodb:UpdateResult|error upRes = vaccineCollection->updateOne(upFilter, up);
        if upRes is mongodb:UpdateResult {
            if upRes.matchedCount == 0 {
                // Insert if no existing mirror record found
                map<json> mirrorDoc2 = {
                    "userId": payload.userId,
                    "name": payload.newName,
                    "dose": payload.newDose,
                    "received": false,
                    "isCustom": true,
                    "created_at": time:utcNow().toString()
                };
                error? insErr2 = vaccineCollection->insertOne(mirrorDoc2);
                if insErr2 is error { return <http:InternalServerError>{ body: { message: insErr2.message() } }; }
            }
        }

        return <http:Ok>{
            headers: {
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "*",
                "Access-Control-Allow-Headers": "*"
            },
            body: { message: "Custom vaccine updated successfully" }
        };
    }
    
    // OPTIONS handler for updateVaccine endpoint
    resource function options updateVaccine() returns http:Response {
        http:Response response = new;
        response.setHeader("Access-Control-Allow-Origin", "*");
        response.setHeader("Access-Control-Allow-Methods", "*");
        response.setHeader("Access-Control-Allow-Headers", "*");
        return response;
    }

    // Get recommended vaccines based on gender
    resource function get getRecommendedVaccines(@http:Query string gender) 
            returns http:Ok|http:BadRequest {
        return <http:Ok>{ body: getDefaultVaccines(gender) };
    }

    // Add BMI record
    resource function post addBmiRecord(@http:Payload record {
        string userId;
        float weight;
        float height;
        string date?; // Optional client-provided date in YYYY-MM-DD
    } payload) returns http:Created|http:InternalServerError|error {
        mongodb:Database db = check mongoClient->getDatabase(DATABASE_NAME);
        mongodb:Collection bmiCollection = check db->getCollection("bmi_records");

        string createdAt;
        if payload.date is string && payload.date != "" {
            createdAt = <string>payload.date + "T00:00:00Z";
        } else {
            createdAt = time:utcNow().toString();
        }

        record {
            string userId;
            float weight;
            float height;
            float bmi;
            string created_at;
        } bmiRecord = {
            userId: payload.userId,
            weight: payload.weight,
            height: payload.height,
            bmi: payload.weight / (payload.height * payload.height),
            created_at: createdAt
        };

        error? insertResult = bmiCollection->insertOne(bmiRecord);
        if insertResult is error {
            return <http:InternalServerError>{
                body: { message: "Failed to save BMI record" }
            };
        }
        return <http:Created>{ 
            body: { 
                message: "BMI record saved",
                bmi: bmiRecord.bmi
            } 
        };
    }

    // Get BMI records for a user
    resource function get getBmiRecords(@http:Query string userId)
            returns http:Ok|http:InternalServerError|error {
        mongodb:Database db = check mongoClient->getDatabase(DATABASE_NAME);
        mongodb:Collection bmiCollection = check db->getCollection("bmi_records");

        stream<record {}, error?> resultStream = check bmiCollection->find({ userId: userId });
        record {}[] bmiRecords = [];

        while true {
            record {}|error? result = check resultStream.next();
            if result is record {} {
                bmiRecords.push(result);
            } else {
                break;
            }
        }

        return <http:Ok>{ body: bmiRecords };
    }

    // Growth/BMI classification based on reference tables
    resource function post checkGrowth(@http:Payload record {
        string userId;
        float weight;
        float height; // in cm
    } payload) returns http:Ok|http:NotFound|http:BadRequest|error {
        mongodb:Database db = check mongoClient->getDatabase(DATABASE_NAME);
        mongodb:Collection usersCollection = check db->getCollection("users");

        record {}? userDoc = check usersCollection->findOne({ "id": payload.userId });
        if userDoc is () {
            return <http:NotFound>{ body: { message: "User not found" } };
        }

        string gender = userDoc["gender"] is string ? <string>userDoc["gender"] : "unknown";
        gender = strings:toLowerAscii(gender);
        string dobStr = userDoc["dateOfBirth"] is string ? <string>userDoc["dateOfBirth"] : "";

        if dobStr == "" { return <http:BadRequest>{ body: { message: "Date of birth is required" } }; }

        string formattedDobStr = dobStr;
        if !strings:includes(dobStr, "T") { formattedDobStr = dobStr + "T00:00:00"; }

        time:Civil dobCivil = check time:civilFromString(formattedDobStr);
        time:Civil nowCivil = time:utcToCivil(time:utcNow());
        int totalMonths = (nowCivil.year - dobCivil.year) * 12 + (nowCivil.month - dobCivil.month);
        if nowCivil.day < dobCivil.day { totalMonths = totalMonths - 1; }
        int ageInMonths = totalMonths < 0 ? 0 : totalMonths;

        if ageInMonths < 24 {
            string classification = "Unknown";
            map<GrowthRange>? genderTable = weightTables[gender];
            if genderTable is map<GrowthRange> {
                GrowthRange? range = genderTable[ageInMonths.toString()];
                if range is GrowthRange {
                    if payload.weight < range.under { classification = "Underweight"; }
                    else if payload.weight > range.over { classification = "Overweight"; }
                    else if payload.weight >= range.min && payload.weight <= range.max { classification = "Normal"; }
                    else { classification = "Borderline"; }
                    return <http:Ok>{ body: { userId: payload.userId, gender, ageInMonths, weight: payload.weight, height: payload.height, growthRange: range, weightStatus: classification } };
                }
            }
            return <http:Ok>{ body: { userId: payload.userId, gender, ageInMonths, weight: payload.weight, height: payload.height, message: "No growth data available for this age/gender" } };
        }

        float heightM = payload.height / 100.0;
        float bmi = payload.weight / (heightM * heightM);
        string bmiStatus = (bmi < 18.5) ? "Underweight" : (bmi < 24.9) ? "Normal" : (bmi < 29.9) ? "Overweight" : "Obese";
        return <http:Ok>{ body: { userId: payload.userId, gender, ageInMonths, weight: payload.weight, height: payload.height, bmi, bmiStatus } };
    }

    // Add appointment
    resource function post addAppointment(@http:Payload record {
        string userId;
        string title;
        string doctor;
        string specialty?;
        string date;
        string time?;
        string notes?;
    } payload) returns http:Created|http:InternalServerError|error {
        mongodb:Database db = check mongoClient->getDatabase(DATABASE_NAME);
        mongodb:Collection appointmentCollection = check db->getCollection("appointments");

        record {
            string id;
            string userId;
            string title;
            string doctor;
            string specialty;
            string date;
            string time;
            string notes;
            boolean completed;
            string created_at;
        } appointment = {
            id: uuid:createType1AsString(),
            userId: payload.userId,
            title: payload.title,
            doctor: payload.doctor,
            specialty: payload.specialty ?: "",
            date: payload.date,
            time: payload.time ?: "",
            notes: payload.notes ?: "",
            completed: false,
            created_at: time:utcNow().toString()
        };

        error? insertResult = appointmentCollection->insertOne(appointment);
        if insertResult is error {
            return <http:InternalServerError>{
                headers: {
                    "Access-Control-Allow-Origin": "*",
                    "Access-Control-Allow-Methods": "POST, OPTIONS",
                    "Access-Control-Allow-Headers": "*"
                },
                body: { message: "Failed to save appointment" }
            };
        }
        return <http:Created>{ 
            headers: {
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "POST, OPTIONS",
                "Access-Control-Allow-Headers": "*"
            },
            body: appointment
        };
    }

    // OPTIONS handler for appointments endpoints
    resource function options getAppointments() returns http:Response {
        http:Response response = new;
        response.setHeader("Access-Control-Allow-Origin", "*");
        response.setHeader("Access-Control-Allow-Methods", "GET, OPTIONS");
        response.setHeader("Access-Control-Allow-Headers", "*");
        return response;
    }

    resource function options addAppointment() returns http:Response {
        http:Response response = new;
        response.setHeader("Access-Control-Allow-Origin", "*");
        response.setHeader("Access-Control-Allow-Methods", "POST, OPTIONS");
        response.setHeader("Access-Control-Allow-Headers", "*");
        return response;
    }

    resource function options updateAppointment() returns http:Response {
        http:Response response = new;
        response.setHeader("Access-Control-Allow-Origin", "*");
        response.setHeader("Access-Control-Allow-Methods", "PUT, OPTIONS");
        response.setHeader("Access-Control-Allow-Headers", "*");
        return response;
    }

    resource function options deleteAppointment() returns http:Response {
        http:Response response = new;
        response.setHeader("Access-Control-Allow-Origin", "*");
        response.setHeader("Access-Control-Allow-Methods", "DELETE, OPTIONS");
        response.setHeader("Access-Control-Allow-Headers", "*");
        return response;
    }

    // Get appointments for a user
    resource function get getAppointments(@http:Query string userId)
            returns http:Ok|http:InternalServerError|error {
        mongodb:Database db = check mongoClient->getDatabase(DATABASE_NAME);
        mongodb:Collection appointmentCollection = check db->getCollection("appointments");

        stream<record {}, error?> resultStream = check appointmentCollection->find({ userId: userId });
        record {}[] appointments = [];

        while true {
            record {}|error? result = check resultStream.next();
            if result is record {} {
                appointments.push(result);
            } else {
                break;
            }
        }

        return <http:Ok>{
            headers: {
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "GET, OPTIONS",
                "Access-Control-Allow-Headers": "*"
            },
            body: appointments
        };
    }
    
    // OPTIONS handler for markVaccineReceived endpoint
    resource function options markVaccineReceived() returns http:Response {
        http:Response response = new;
        response.setHeader("Access-Control-Allow-Origin", "*");
        response.setHeader("Access-Control-Allow-Methods", "PUT, OPTIONS");
        response.setHeader("Access-Control-Allow-Headers", "Content-Type");
        response.setHeader("Access-Control-Max-Age", "86400");
        return response;
    }

    // Add these new endpoints to your service

    // Get vaccines for a user (returns existing or default by gender)
    resource function get getVaccines(@http:Query string userId)
            returns http:Ok|http:InternalServerError|error {
        map<anydata>|()|error innerOrErr = getUserInnerMap(userId);
        if innerOrErr is error {
            return <http:InternalServerError>{ body: { message: "Failed to load user" } };
        }
        if innerOrErr is map<anydata> {
            map<anydata> inner = innerOrErr;
            string gender = inner.hasKey("gender") && inner["gender"] is string ? <string>inner["gender"] : "male";
            string dobISO = inner.hasKey("dateOfBirth") && inner["dateOfBirth"] is string ? <string>inner["dateOfBirth"] : "";
            anydata vaccinesField = inner.hasKey("vaccines") ? inner["vaccines"] : ();

            // Build default name -> offsetMonths map for enrichment
            VaccineRecord[] defaultsForGender = getDefaultVaccines(gender);
            map<int> defaultOffsets = {};
            foreach VaccineRecord d in defaultsForGender {
                if d.offsetMonths is int { defaultOffsets[d.name] = <int>d.offsetMonths; }
            }

            VaccineRecord[] toReturn = [];
            boolean seededDefaults = false;
            if vaccinesField is VaccineRecord[] {
                // Enrich missing offsetMonths using defaults
                foreach VaccineRecord rec in vaccinesField {
                    int|() om = rec.offsetMonths is int ? <int>rec.offsetMonths : ();
                    if om is () && defaultOffsets.hasKey(rec.name) { om = defaultOffsets[rec.name]; }
                    string|() due = (dobISO != "" && om is int) ? computeDueDateFromDOB(dobISO, <int>om) : ();
                    VaccineRecord newRec = { name: rec.name, dose: rec.dose, received: rec.received, receivedDate: rec.receivedDate, isCustom: rec.isCustom, offsetMonths: om, dueDate: due };
                    toReturn.push(newRec);
                }
            } else if vaccinesField is anydata[] {
                anydata[] arr = <anydata[]>vaccinesField;
                foreach anydata item in arr {
                    if item is record {} {
                        map<anydata> v = <map<anydata>>item;
                        int|() om = v.hasKey("offsetMonths") && v["offsetMonths"] is int ? <int>v["offsetMonths"] : ();
                        if om is () {
                            string nm = v.hasKey("name") && v["name"] is string ? <string>v["name"] : "";
                            if defaultOffsets.hasKey(nm) { om = defaultOffsets[nm]; }
                        }
                        string|() due = (dobISO != "" && om is int) ? computeDueDateFromDOB(dobISO, <int>om) : ();
                        VaccineRecord rec = {
                            name: v.hasKey("name") && v["name"] is string ? <string>v["name"] : "",
                            dose: v.hasKey("dose") && v["dose"] is string ? <string>v["dose"] : "",
                            received: v.hasKey("received") && v["received"] is boolean ? <boolean>v["received"] : false,
                            receivedDate: v.hasKey("receivedDate") && v["receivedDate"] is string ? <string>v["receivedDate"] : (),
                            isCustom: v.hasKey("isCustom") && v["isCustom"] is boolean ? <boolean>v["isCustom"] : false,
                            offsetMonths: om,
                            dueDate: due
                        };
                        toReturn.push(rec);
                    }
                }
            } else {
                // No vaccines yet → compute defaults based on gender if present
                foreach VaccineRecord rec in defaultsForGender {
                    if rec.offsetMonths is int && dobISO != "" {
                        string due = computeDueDateFromDOB(dobISO, <int>rec.offsetMonths);
                        VaccineRecord newRec = { name: rec.name, dose: rec.dose, received: rec.received, receivedDate: rec.receivedDate, isCustom: rec.isCustom, offsetMonths: rec.offsetMonths, dueDate: due };
                        toReturn.push(newRec);
                    } else {
                        toReturn.push(rec);
                    }
                }
                seededDefaults = true;
            }

            return <http:Ok>{
                headers: {
                    "Access-Control-Allow-Origin": "*",
                    "Access-Control-Allow-Methods": "*",
                    "Access-Control-Allow-Headers": "*"
                },
                body: toReturn
            };
        }
        // User missing → generic defaults
        VaccineRecord[] fallback = getDefaultVaccines("male");
        return <http:Ok>{
            headers: {
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "*",
                "Access-Control-Allow-Headers": "*"
            },
            body: fallback
        };
    }

    // Mark vaccine as received
    resource function put markVaccineReceived(@http:Payload record {
        string userId;
        string name;
        string dose;
        boolean received;
        string receivedDate;
    } payload) returns http:Ok|http:InternalServerError|error {
        io:println("[markVaccineReceived] payload: ", payload);
        map<anydata>|()|error innerOrErr = getUserInnerMap(payload.userId);
        if innerOrErr is error {
            io:println("[markVaccineReceived] failed to load user: ", innerOrErr.message());
            return <http:InternalServerError>{
                headers: {
                    "Access-Control-Allow-Origin": "*",
                    "Access-Control-Allow-Methods": "PUT, OPTIONS",
                    "Access-Control-Allow-Headers": "*"
                },
                body: { message: "Failed to load user" }
            };
        }
        if innerOrErr is () {
            io:println("[markVaccineReceived] user not found: ", payload.userId);
            return <http:InternalServerError>{
                headers: {
                    "Access-Control-Allow-Origin": "*",
                    "Access-Control-Allow-Methods": "PUT, OPTIONS",
                    "Access-Control-Allow-Headers": "*"
                },
                body: { message: "User not found" }
            };
        }
        map<anydata> inner = <map<anydata>>innerOrErr;
        anydata vaccinesField = inner.hasKey("vaccines") ? inner["vaccines"] : ();
        anydata[] vaccinesArray = vaccinesField is anydata[] ? <anydata[]>vaccinesField : [];

        boolean updated = false;
        foreach int i in 0..<vaccinesArray.length() {
            anydata item = vaccinesArray[i];
            if item is record {} {
                map<anydata> v = <map<anydata>>item;
                string vName = v.hasKey("name") && v["name"] is string ? <string>v["name"] : "";
                string vDose = v.hasKey("dose") && v["dose"] is string ? <string>v["dose"] : "";
                if vName == payload.name && vDose == payload.dose {
                    io:println("[markVaccineReceived] match found at index ", i, ": ", vName, " / ", vDose);
                    v["received"] = payload.received;
                    if payload.received {
                        v["receivedDate"] = payload.receivedDate;
                    } else {
                        // clear date when unmarking
                        if v.hasKey("receivedDate") {
                            v["receivedDate"] = ();
                        }
                    }
                    vaccinesArray[i] = v;
                    updated = true;
                    break;
                }
            }
        }
        if !updated {
            io:println("[markVaccineReceived] vaccine not found, inserting: ", payload.name, " / ", payload.dose);
            // Insert a new vaccine entry if not found
            map<anydata> newRec = {
                name: payload.name,
                dose: payload.dose,
                received: payload.received,
                receivedDate: payload.received ? payload.receivedDate : (),
                isCustom: false
            };
            vaccinesArray.push(newRec);
            updated = true;
        }

        json vaccinesJson = vaccinesArray.toJson();
        error? setErr = setUserVaccines(payload.userId, vaccinesJson);
        if setErr is error {
            io:println("[markVaccineReceived] persist failed: ", setErr.message());
            return <http:InternalServerError>{
                headers: {
                    "Access-Control-Allow-Origin": "*",
                    "Access-Control-Allow-Methods": "PUT, OPTIONS",
                    "Access-Control-Allow-Headers": "*"
                },
                body: { message: "Failed to update vaccine" }
            };
        }
        io:println("[markVaccineReceived] success for user: ", payload.userId);
        return <http:Ok>{
            headers: {
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "PUT, OPTIONS",
                "Access-Control-Allow-Headers": "*"
            },
            body: { message: "Vaccine marked as received" }
        };
    }

    // Add these new endpoints to your service

    // Add debugging to the getUserProfile endpoint
    resource function get getUserProfile(@http:Query string userId)
            returns http:Ok|http:NotFound|http:InternalServerError|error {
        
        mongodb:Database db = check mongoClient->getDatabase(DATABASE_NAME);
        mongodb:Collection usersCollection = check db->getCollection("users");

        // Find user
        stream<record {}, error?> resultStream = check usersCollection->find({
            "value.id": userId
        });
        
        record {}|error? result = check resultStream.next();
        
        if result is record {} {
            anydata outerValue = result["value"];
            if outerValue is record {} {
                anydata innerValue = outerValue["value"];
                if innerValue is record {} {
                    map<anydata> userMap = <map<anydata>>innerValue;
                    
                    // Extract user profile data
                    string firstName = userMap["firstName"] is string ? <string>userMap["firstName"] : "";
                    string lastName = userMap["lastName"] is string ? <string>userMap["lastName"] : "";
                    string email = userMap["email"] is string ? <string>userMap["email"] : "";
                    string gender = userMap["gender"] is string ? <string>userMap["gender"] : "";
                    string dateOfBirth = userMap["dateOfBirth"] is string ? <string>userMap["dateOfBirth"] : "";
                    string phoneNumber = userMap["phoneNumber"] is string ? <string>userMap["phoneNumber"] : "";
                    string photoDataUrl = userMap["photoDataUrl"] is string ? <string>userMap["photoDataUrl"] : "";
                    
                    return <http:Ok>{
                        headers: {
                            "Access-Control-Allow-Origin": "*",
                            "Access-Control-Allow-Methods": "*",
                            "Access-Control-Allow-Headers": "*"
                        },
                        body: {
                            id: userId,
                            firstName: firstName,
                            lastName: lastName,
                            email: email,
                            gender: gender,
                            dateOfBirth: dateOfBirth,
                            phoneNumber: phoneNumber,
                            photoDataUrl: photoDataUrl
                        }
                    };
                }
            }
        }
        
        return <http:NotFound>{
            headers: {
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "*",
                "Access-Control-Allow-Headers": "*"
            },
            body: { message: "User not found" }
        };
    }
    
    // OPTIONS handler for getUserProfile endpoint
    resource function options getUserProfile() returns http:Response {
        http:Response response = new;
        response.setHeader("Access-Control-Allow-Origin", "*");
        response.setHeader("Access-Control-Allow-Methods", "GET, OPTIONS");
        response.setHeader("Access-Control-Allow-Headers", "*");
        return response;
    }

    // Fix the updateUserProfile endpoint with correct Ballerina syntax
    resource function put updateUserProfile(@http:Payload record {
        string userId;
        string firstName?;
        string lastName?;
        string email?;
        string gender?;
        string dateOfBirth?;
        string phoneNumber?;
        string photoDataUrl?;
    } payload) returns http:Ok|http:InternalServerError|error {
        mongodb:Database db = check mongoClient->getDatabase(DATABASE_NAME);
        mongodb:Collection usersCollection = check db->getCollection("users");

        // Create a value object to update the nested structure
        map<json> valueFields = {};
        if (payload.firstName is string) {
            valueFields["firstName"] = payload.firstName;
        }
        if (payload.lastName is string) {
            valueFields["lastName"] = payload.lastName;
        }
        if (payload.email is string) {
            valueFields["email"] = payload.email;
        }
        if (payload.gender is string) {
            valueFields["gender"] = payload.gender;
        }
        if (payload.dateOfBirth is string) {
            valueFields["dateOfBirth"] = payload.dateOfBirth;
        }
        if (payload.phoneNumber is string) {
            valueFields["phoneNumber"] = payload.phoneNumber;
        }
        if (payload.photoDataUrl is string) {
            valueFields["photoDataUrl"] = payload.photoDataUrl;
        }

        io:println("Updating user with ID: ", payload.userId);
        io:println("Update fields: ", valueFields);
        
        // Try a simpler approach with direct update
        map<json> updateFields = {};
        
        // Set each field individually with the correct dot notation
        foreach var [fieldName, fieldValue] in valueFields.entries() {
            updateFields["value." + fieldName] = fieldValue;
        }
        
        io:println("Update fields with dot notation: ", updateFields);
        
        // Try a different approach - find the document first to confirm it exists
        stream<record {}, error?> resultStream = check usersCollection->find({
            "value.id": payload.userId
        });
        
        record {}|error? result = check resultStream.next();
        io:println("Found document: ", result);
        
        if result is record {} {
            // Document exists, proceed with update
            io:println("Document found, proceeding with update");
            
            // Create a properly typed update operation
            mongodb:Update updateOp = {
                set: updateFields
            };
            
            // Use the correct filter to match the document
            mongodb:UpdateResult|error updateResult = usersCollection->updateOne(
                { "value.id": payload.userId },
                updateOp
            );
            
            io:println("Update result: ", updateResult);
            
            if updateResult is error {
                io:println("Error updating profile: ", updateResult.message());
                return <http:InternalServerError>{
                    headers: {
                        "Access-Control-Allow-Origin": "*",
                        "Access-Control-Allow-Methods": "*",
                        "Access-Control-Allow-Headers": "*"
                    },
                    body: { message: "Failed to update profile" }
                };
            }
            
            // We already checked for error, so updateResult must be mongodb:UpdateResult
            if updateResult.modifiedCount > 0 {
                // Return the updated profile data
                return <http:Ok>{
                    headers: {
                        "Access-Control-Allow-Origin": "*",
                        "Access-Control-Allow-Methods": "*",
                        "Access-Control-Allow-Headers": "*"
                    },
                    body: {
                        id: payload.userId,
                        firstName: payload.firstName is string ? payload.firstName : "",
                        lastName: payload.lastName is string ? payload.lastName : "",
                        email: payload.email is string ? payload.email : "",
                        gender: payload.gender is string ? payload.gender : "",
                        dateOfBirth: payload.dateOfBirth is string ? payload.dateOfBirth : "",
                        phoneNumber: payload.phoneNumber is string ? payload.phoneNumber : "",
                        photoDataUrl: payload.photoDataUrl is string ? payload.photoDataUrl : "",
                        message: "Profile updated successfully"
                    }
                };
            }
                 
                 // If we get here, the document was found but not modified
                 return <http:Ok>{
                     headers: {
                         "Access-Control-Allow-Origin": "*",
                         "Access-Control-Allow-Methods": "*",
                         "Access-Control-Allow-Headers": "*"
                     },
                     body: {
                         message: "No changes were made to the profile"
                     }
                 };
         } else {
             return <http:InternalServerError>{
                 headers: {
                     "Access-Control-Allow-Origin": "*",
                     "Access-Control-Allow-Methods": "*",
                     "Access-Control-Allow-Headers": "*"
                 },
                 body: { message: "User not found" }
             };
        }
    }

    // OPTIONS handler for updateUserProfile endpoint
    resource function options updateUserProfile() returns http:Response {
        http:Response response = new;
        response.setHeader("Access-Control-Allow-Origin", "*");
        response.setHeader("Access-Control-Allow-Methods", "PUT, OPTIONS");
        response.setHeader("Access-Control-Allow-Headers", "*");
        return response;
    }

    // Add a test endpoint to verify the service is working
    resource function get test() returns http:Ok {
        return <http:Ok>{
            headers: {
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "*",
                "Access-Control-Allow-Headers": "*"
            },
            body: { message: "Backend is working", timestamp: time:utcNow().toString() }
        };
    }

    // Add these new endpoints for appointments

    // Update appointment
    resource function put updateAppointment(@http:Payload record {
        string userId;
        string appointmentId;
        boolean completed?;
        string title?;
        string doctor?;
        string specialty?;
        string date?;
        string time?;
        string notes?;
    } payload) returns http:Ok|http:InternalServerError|error {
        mongodb:Database db = check mongoClient->getDatabase(DATABASE_NAME);
        mongodb:Collection appointmentCollection = check db->getCollection("appointments");

        // Build update object with only provided fields
        map<json> updateFields = {};
        if (payload.completed is boolean) {
            updateFields["completed"] = payload.completed;
        }
        if (payload.title is string) {
            updateFields["title"] = payload.title;
        }
        if (payload.doctor is string) {
            updateFields["doctor"] = payload.doctor;
        }
        if (payload.specialty is string) {
            updateFields["specialty"] = payload.specialty;
        }
        if (payload.date is string) {
            updateFields["date"] = payload.date;
        }
        if (payload.time is string) {
            updateFields["time"] = payload.time;
        }
        if (payload.notes is string) {
            updateFields["notes"] = payload.notes;
        }

        // Update appointment using the id field
        mongodb:UpdateResult|error updateResult = appointmentCollection->updateOne(
            { "userId": payload.userId, "id": payload.appointmentId },
            { "$set": updateFields }
        );
        
        if updateResult is error {
            return <http:InternalServerError>{
                headers: {
                    "Access-Control-Allow-Origin": "*",
                    "Access-Control-Allow-Methods": "PUT, OPTIONS",
                    "Access-Control-Allow-Headers": "*"
                },
                body: { message: "Failed to update appointment" }
            };
        }
        
        // Get the updated appointment
        stream<record {}, error?> resultStream = check appointmentCollection->find({
            "userId": payload.userId,
            "id": payload.appointmentId
        });
        record {}|error? result = check resultStream.next();
        
        if result is record {} {
            return <http:Ok>{
                headers: {
                    "Access-Control-Allow-Origin": "*",
                    "Access-Control-Allow-Methods": "PUT, OPTIONS",
                    "Access-Control-Allow-Headers": "*"
                },
                body: result
            };
        }
        
        return <http:InternalServerError>{
            headers: {
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "PUT, OPTIONS",
                "Access-Control-Allow-Headers": "*"
            },
            body: { message: "Failed to fetch updated appointment" }
        };
    }

    // Delete appointment
    resource function delete deleteAppointment(@http:Payload record {
        string userId;
        string appointmentId;
    } payload) returns http:Ok|http:InternalServerError|error {
        mongodb:Database db = check mongoClient->getDatabase(DATABASE_NAME);
        mongodb:Collection appointmentCollection = check db->getCollection("appointments");

        // Delete appointment using the id field
        mongodb:DeleteResult|error deleteResult = appointmentCollection->deleteOne({
            "userId": payload.userId,
            "id": payload.appointmentId
        });
        
        if deleteResult is error {
            return <http:InternalServerError>{
                headers: {
                    "Access-Control-Allow-Origin": "*",
                    "Access-Control-Allow-Methods": "DELETE, OPTIONS",
                    "Access-Control-Allow-Headers": "*"
                },
                body: { message: "Failed to delete appointment" }
            };
        }
        
        return <http:Ok>{
            headers: {
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "DELETE, OPTIONS",
                "Access-Control-Allow-Headers": "*"
            },
            body: { message: "Appointment deleted successfully" }
        };
    }
    

    
    // Add doctor appointment
    resource function post addDocAppointment(@http:Payload record {
        string userId;
        string date;
        string time;
        string place;
        string disease;
    } payload) returns http:Created|http:InternalServerError|error {
        mongodb:Database db = check mongoClient->getDatabase(DATABASE_NAME);
        mongodb:Collection docAppointmentCollection = check db->getCollection("doc_appointments");

        time:Utc|error dateUtc = time:utcFromString(payload.date + "T00:00:00Z");
        if dateUtc is error {
            return <http:InternalServerError>{
                headers: {
                    "Access-Control-Allow-Origin": "*",
                    "Access-Control-Allow-Methods": "POST, OPTIONS",
                    "Access-Control-Allow-Headers": "*"
                },
                body: { message: "Invalid date format. Please use YYYY-MM-DD format." }
            };
        }
        
        DocApoinment docAppointment = {
            id: uuid:createType1AsString(),
            date: dateUtc,
            time: payload.time,
            place: payload.place,
            disease: payload.disease
        };

        // Create document with proper structure
        record {
            string userId;
            DocApoinment appointment;
        } docAppointmentRecord = {
            userId: payload.userId,
            appointment: docAppointment
        };

        error? insertResult = docAppointmentCollection->insertOne(docAppointmentRecord);
        if insertResult is error {
            return <http:InternalServerError>{
                headers: {
                    "Access-Control-Allow-Origin": "*",
                    "Access-Control-Allow-Methods": "POST, OPTIONS",
                    "Access-Control-Allow-Headers": "*"
                },
                body: { message: "Failed to save doctor appointment" }
            };
        }
        return <http:Created>{ 
            headers: {
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "POST, OPTIONS",
                "Access-Control-Allow-Headers": "*"
            },
            body: docAppointmentRecord
        };
    }

    // Get doctor appointments for a user
    resource function get getDocAppointments(@http:Query string userId)
            returns http:Ok|http:InternalServerError|error {
        mongodb:Database db = check mongoClient->getDatabase(DATABASE_NAME);
        mongodb:Collection docAppointmentCollection = check db->getCollection("doc_appointments");

        stream<record {}, error?> resultStream = check docAppointmentCollection->find({ userId: userId });
        record {}[] docAppointments = [];

        while true {
            record {}|error? result = check resultStream.next();
            if result is record {} {
                docAppointments.push(result);
            } else {
                break;
            }
        }

        return <http:Ok>{
            headers: {
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "GET, OPTIONS",
                "Access-Control-Allow-Headers": "*"
            },
            body: docAppointments
        };
    }
    
    // Update doctor appointment
    resource function put updateDocAppointment(@http:Payload record {
        string userId;
        string appointmentId;
        string? date;
        string? time;
        string? place;
        string? disease;
        boolean? completed;
    } payload) returns http:Ok|http:NotFound|http:InternalServerError|error {
        mongodb:Database db = check mongoClient->getDatabase(DATABASE_NAME);
        mongodb:Collection docAppointmentCollection = check db->getCollection("doc_appointments");
        
        // Check if the appointment exists
        stream<record {}, error?> resultStream = check docAppointmentCollection->find({
            "userId": payload.userId,
            "appointment.id": payload.appointmentId
        });
        
        record {}|error? result = check resultStream.next();
        if result is error || result is () {
            return <http:NotFound>{
                headers: {
                    "Access-Control-Allow-Origin": "*",
                    "Access-Control-Allow-Methods": "PUT, OPTIONS",
                    "Access-Control-Allow-Headers": "*"
                },
                body: { message: "Doctor appointment not found" }
            };
        }
        
        // Create a new appointment record with updated fields
         DocApoinment updatedAppointment = {
             id: payload.appointmentId,
             date: time:utcNow(), // Default to current time if not provided
             time: "",
             place: "",
             disease: "",
             completed: false
         };
        
        // Extract existing data from the result
        record {} existingData = <record {}>result;
        io:println("Existing data: ", existingData.toString());
        
        // Try to get the existing appointment data
        json? appointmentJson = ();
        
        // Check if the data has a 'value' field (nested structure from MongoDB)
        if existingData.hasKey("value") {
            record {} valueData = <record {}>existingData.get("value");
            if valueData.hasKey("appointment") {
                // Handle the type conversion safely
                any appointmentData = valueData.get("appointment");
                if appointmentData is map<anydata> {
                    // Convert map<anydata> to json
                    json|error jsonData = appointmentData.toJson();
                    if jsonData is json {
                        appointmentJson = jsonData;
                        io:println("Found appointment data in value: ", appointmentJson.toString());
                    } else {
                        io:println("Error converting appointment data to JSON: ", jsonData.message());
                    }
                } else if appointmentData is json {
                    appointmentJson = appointmentData;
                    io:println("Found appointment data in value: ", appointmentJson.toString());
                } else {
                    io:println("Appointment data is not in expected format: ", typeof appointmentData);
                }
            }
        } else if existingData.hasKey("appointment") {
            // Direct structure
            any appointmentData = existingData.get("appointment");
            if appointmentData is map<anydata> {
                // Convert map<anydata> to json
                json|error jsonData = appointmentData.toJson();
                if jsonData is json {
                    appointmentJson = jsonData;
                    io:println("Found appointment data directly: ", appointmentJson.toString());
                } else {
                    io:println("Error converting appointment data to JSON: ", jsonData.message());
                }
            } else if appointmentData is json {
                appointmentJson = appointmentData;
                io:println("Found appointment data directly: ", appointmentJson.toString());
            } else {
                io:println("Appointment data is not in expected format: ", typeof appointmentData);
            }
        }
        
        if appointmentJson == () {
            io:println("No appointment key found in existing data");
            return <http:InternalServerError>{
                headers: {
                    "Access-Control-Allow-Origin": "*",
                    "Access-Control-Allow-Methods": "PUT, OPTIONS",
                    "Access-Control-Allow-Headers": "*"
                },
                body: { message: "Error accessing appointment data" }
            };
        }
         if appointmentJson is map<json> {
             // Extract existing values
             map<json> appointmentMap = <map<json>>appointmentJson;
             if appointmentMap.hasKey("time") {
                 json timeValue = appointmentMap.get("time");
                 if timeValue is string {
                     updatedAppointment.time = timeValue;
                 }
             }
             
             if appointmentMap.hasKey("place") {
                 json placeValue = appointmentMap.get("place");
                 if placeValue is string {
                     updatedAppointment.place = placeValue;
                 }
             }
             
             if appointmentMap.hasKey("disease") {
                 json diseaseValue = appointmentMap.get("disease");
                 if diseaseValue is string {
                     updatedAppointment.disease = diseaseValue;
                 }
             }
             
             if appointmentMap.hasKey("completed") {
                 json completedValue = appointmentMap.get("completed");
                 io:println("Found completed value in existing appointment: ", completedValue);
                 if completedValue is boolean {
                     updatedAppointment.completed = completedValue;
                     io:println("Set completed from existing data: ", updatedAppointment.completed);
                 }
             }
         }
        
        // Update with new values from payload
         if payload.date is string {
             string dateStr = <string>payload.date;
             if dateStr.length() > 0 {
                 time:Utc|error dateUtc = time:utcFromString(dateStr + "T00:00:00Z");
                 if dateUtc is error {
                     return <http:InternalServerError>{
                         headers: {
                             "Access-Control-Allow-Origin": "*",
                             "Access-Control-Allow-Methods": "PUT, OPTIONS",
                             "Access-Control-Allow-Headers": "*"
                         },
                         body: { message: "Invalid date format. Please use YYYY-MM-DD format." }
                     };
                 }
                 updatedAppointment.date = dateUtc;
             }
         }
         
         if payload.time is string {
             updatedAppointment.time = <string>payload.time;
         }
         
         if payload.place is string {
             updatedAppointment.place = <string>payload.place;
         }
         
         if payload.disease is string {
             updatedAppointment.disease = <string>payload.disease;
         }
         
         // Always set the completed field from the payload if it exists
         if payload.completed is boolean {
             updatedAppointment.completed = <boolean>payload.completed;
             io:println("Setting completed to: ", updatedAppointment.completed);
         } else {
             // If completed is not provided in the payload, keep the existing value
             // This ensures we don't overwrite the completed status if it's not explicitly changed
             io:println("No completed field in payload, keeping existing value: ", updatedAppointment.completed);
         }
        
        // Create the updated document
        record {
            string userId;
            DocApoinment appointment;
        } updatedDoc = {
            userId: payload.userId,
            appointment: updatedAppointment
        };
        
        // Delete the old document
        mongodb:DeleteResult|error deleteResult = docAppointmentCollection->deleteOne({
            "userId": payload.userId,
            "appointment.id": payload.appointmentId
        });
        
        if deleteResult is error || (deleteResult is mongodb:DeleteResult && deleteResult.deletedCount == 0) {
            return <http:InternalServerError>{
                headers: {
                    "Access-Control-Allow-Origin": "*",
                    "Access-Control-Allow-Methods": "PUT, OPTIONS",
                    "Access-Control-Allow-Headers": "*"
                },
                body: { message: "Failed to update doctor appointment" }
            };
        }
        
        // Insert the updated document
        error? insertResult = docAppointmentCollection->insertOne(updatedDoc);
        if insertResult is error {
            return <http:InternalServerError>{
                headers: {
                    "Access-Control-Allow-Origin": "*",
                    "Access-Control-Allow-Methods": "PUT, OPTIONS",
                    "Access-Control-Allow-Headers": "*"
                },
                body: { message: "Failed to update doctor appointment" }
            };
        }
        
        return <http:Ok>{
            headers: {
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "PUT, OPTIONS",
                "Access-Control-Allow-Headers": "*"
            },
            body: updatedDoc
        };
    }
    
    // Delete doctor appointment
    resource function delete deleteDocAppointment(@http:Payload record {
        string userId;
        string appointmentId;
    } payload) returns http:Ok|http:NotFound|http:InternalServerError|error {
        mongodb:Database db = check mongoClient->getDatabase(DATABASE_NAME);
        mongodb:Collection docAppointmentCollection = check db->getCollection("doc_appointments");
        
        // Delete the appointment
        mongodb:DeleteResult|error deleteResult = docAppointmentCollection->deleteOne({
            "userId": payload.userId,
            "appointment.id": payload.appointmentId
        });
        
        if deleteResult is error {
            return <http:InternalServerError>{
                headers: {
                    "Access-Control-Allow-Origin": "*",
                    "Access-Control-Allow-Methods": "DELETE, OPTIONS",
                    "Access-Control-Allow-Headers": "*"
                },
                body: { message: "Failed to delete doctor appointment" }
            };
        }
        
        // Check if any document was deleted
        if deleteResult.deletedCount == 0 {
            return <http:NotFound>{
                headers: {
                    "Access-Control-Allow-Origin": "*",
                    "Access-Control-Allow-Methods": "DELETE, OPTIONS",
                    "Access-Control-Allow-Headers": "*"
                },
                body: { message: "Doctor appointment not found" }
            };
        }
        
        return <http:Ok>{
            headers: {
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "DELETE, OPTIONS",
                "Access-Control-Allow-Headers": "*"
            },
            body: { message: "Doctor appointment deleted successfully" }
        };
    }

    // OPTIONS handler for doctor appointments endpoints
    resource function options getDocAppointments() returns http:Response {
        http:Response response = new;
        response.setHeader("Access-Control-Allow-Origin", "*");
        response.setHeader("Access-Control-Allow-Methods", "GET, OPTIONS");
        response.setHeader("Access-Control-Allow-Headers", "*");
        return response;
    }

    resource function options addDocAppointment() returns http:Response {
        http:Response response = new;
        response.setHeader("Access-Control-Allow-Origin", "*");
        response.setHeader("Access-Control-Allow-Methods", "POST, OPTIONS");
        response.setHeader("Access-Control-Allow-Headers", "*");
        return response;
    }

    resource function options updateDocAppointment() returns http:Response {
        http:Response response = new;
        response.setHeader("Access-Control-Allow-Origin", "*");
        response.setHeader("Access-Control-Allow-Methods", "PUT, OPTIONS");
        response.setHeader("Access-Control-Allow-Headers", "*");
        return response;
    }

    resource function options deleteDocAppointment() returns http:Response {
        http:Response response = new;
        response.setHeader("Access-Control-Allow-Origin", "*");
        response.setHeader("Access-Control-Allow-Methods", "DELETE, OPTIONS");
        response.setHeader("Access-Control-Allow-Headers", "*");
        return response;
    }
    
    // Delete user profile
    resource function delete deleteProfile(@http:Payload record {
        string userId;
    } payload) returns http:Ok|http:NotFound|http:InternalServerError|error {
        io:println("deleteProfile called with userId: ", payload.userId);
        
        mongodb:Database db = check mongoClient->getDatabase(DATABASE_NAME);
        mongodb:Collection usersCollection = check db->getCollection("users");
        
        // Delete the user
        mongodb:DeleteResult|error deleteResult = usersCollection->deleteOne({
            "value.id": payload.userId
        });
        
        if deleteResult is error {
            io:println("Error deleting user: ", deleteResult.message());
            return <http:InternalServerError>{
                headers: {
                    "Access-Control-Allow-Origin": "*",
                    "Access-Control-Allow-Methods": "DELETE, OPTIONS",
                    "Access-Control-Allow-Headers": "*"
                },
                body: { message: "Failed to delete user profile" }
            };
        }
        
        // Check if any document was deleted
        if deleteResult.deletedCount == 0 {
            io:println("No user found with userId: ", payload.userId);
            return <http:NotFound>{
                headers: {
                    "Access-Control-Allow-Origin": "*",
                    "Access-Control-Allow-Methods": "DELETE, OPTIONS",
                    "Access-Control-Allow-Headers": "*"
                },
                body: { message: "User not found" }
            };
        }
        
        io:println("User profile deleted successfully for userId: ", payload.userId);
        return <http:Ok>{
            headers: {
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "DELETE, OPTIONS",
                "Access-Control-Allow-Headers": "*"
            },
            body: { message: "User profile deleted successfully" }
        };
    }
    
    // OPTIONS handler for deleteProfile endpoint
    resource function options deleteProfile() returns http:Response {
        http:Response response = new;
        response.setHeader("Access-Control-Allow-Origin", "*");
        response.setHeader("Access-Control-Allow-Methods", "DELETE, OPTIONS");
        response.setHeader("Access-Control-Allow-Headers", "*");
        return response;
    }

    // Get special notes for a user
    resource function get getSpecialNotes(@http:Query string userId)
            returns http:Ok|http:NotFound|http:InternalServerError|error {
        mongodb:Database db = check mongoClient->getDatabase(DATABASE_NAME);
        mongodb:Collection usersCollection = check db->getCollection("users");

        // Find user
        stream<record {}, error?> resultStream = check usersCollection->find({
            "value.id": userId
        });
        
        record {}|error? result = check resultStream.next();
        
        if result is record {} {
            anydata outerValue = result["value"];
            if outerValue is record {} {
                anydata innerValue = outerValue["value"];
                if innerValue is record {} {
                    map<anydata> userMap = <map<anydata>>innerValue;
                    string specialNotes = userMap["specialNotes"] is string ? <string>userMap["specialNotes"] : "";
                    
                    return <http:Ok>{
                        headers: {
                            "Access-Control-Allow-Origin": "*",
                            "Access-Control-Allow-Methods": "*",
                            "Access-Control-Allow-Headers": "*"
                        },
                        body: { specialNotes: specialNotes }
                    };
                }
            }
        }
        
        return <http:NotFound>{
            headers: {
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "*",
                "Access-Control-Allow-Headers": "*"
            },
            body: { message: "User not found" }
        };
    }

    // Update special notes for a user
    resource function put updateSpecialNotes(@http:Payload record {
        string userId;
        string specialNotes;
    } payload) returns http:Ok|http:InternalServerError|error {
        mongodb:Database db = check mongoClient->getDatabase(DATABASE_NAME);
        mongodb:Collection usersCollection = check db->getCollection("users");

        // Create update operation
        mongodb:Update updateOp = {
            set: { "value.specialNotes": payload.specialNotes }
        };

        // Update the user document
        mongodb:UpdateResult|error updateResult = usersCollection->updateOne(
            { "value.id": payload.userId },
            updateOp
        );

        if updateResult is error {
            return <http:InternalServerError>{
                headers: {
                    "Access-Control-Allow-Origin": "*",
                    "Access-Control-Allow-Methods": "*",
                    "Access-Control-Allow-Headers": "*"
                },
                body: { message: "Failed to update special notes" }
            };
        }

        return <http:Ok>{
            headers: {
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "*",
                "Access-Control-Allow-Headers": "*"
            },
            body: { message: "Special notes updated successfully" }
        };
    }

    // OPTIONS handlers for special notes endpoints
    resource function options getSpecialNotes() returns http:Response {
        http:Response response = new;
        response.setHeader("Access-Control-Allow-Origin", "*");
        response.setHeader("Access-Control-Allow-Methods", "GET, OPTIONS");
        response.setHeader("Access-Control-Allow-Headers", "*");
        return response;
    }

    resource function options updateSpecialNotes() returns http:Response {
        http:Response response = new;
        response.setHeader("Access-Control-Allow-Origin", "*");
        response.setHeader("Access-Control-Allow-Methods", "PUT, OPTIONS");
        response.setHeader("Access-Control-Allow-Headers", "*");
        return response;
    }
}

// Initialize database when the service starts
public function main() {
    error? initResult = initializeDatabase();
    if initResult is error {
        io:println("Database initialization failed: ", initResult.message());
    } else {
        io:println("Database initialized successfully");
    }
}

