# Multi-stage build for better compatibility
FROM openjdk:21-jdk-slim AS builder

# Install necessary packages
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Download and install Ballerina
RUN wget https://dist.ballerina.io/downloads/2201.12.8/ballerina-2201.12.8-swan-lake-linux-x64.deb \
    && dpkg -i ballerina-2201.12.8-swan-lake-linux-x64.deb \
    && rm ballerina-2201.12.8-swan-lake-linux-x64.deb

# Add Ballerina to PATH
ENV PATH="/usr/lib/ballerina/bin:${PATH}"

# Copy Ballerina configuration files first (for better caching)
COPY Ballerina.toml .
COPY Dependencies.toml* ./

# Copy source files
COPY *.bal ./

# Build the Ballerina application
RUN bal build

# Runtime stage
FROM openjdk:21-jdk-slim


# Install Ballerina runtime
RUN apt-get update && apt-get install -y \
    wget \
    && wget https://dist.ballerina.io/downloads/2201.12.8/ballerina-2201.12.8-swan-lake-linux-x64.deb \
    && dpkg -i ballerina-2201.12.8-swan-lake-linux-x64.deb \
    && rm ballerina-2201.12.8-swan-lake-linux-x64.deb \
    && rm -rf /var/lib/apt/lists/*

# Add Ballerina to PATH
ENV PATH="/usr/lib/ballerina/bin:${PATH}"

# Set working directory
WORKDIR /app

# Copy built application from builder stage
COPY --from=builder /app/target/bin/healthRecords.jar .

# Expose the port that the application will run on
EXPOSE 9090

# Set environment variables
ENV PORT=9090

# Run the application
CMD ["java", "-jar", "healthRecords.jar"]
