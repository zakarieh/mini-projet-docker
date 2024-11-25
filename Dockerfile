# Dockerfile for the API
FROM amazoncorretto:17-alpine
LABEL maintainer="zakarieh"

# Copy Python script and install dependencies
COPY target/paymybuddy.jar paymybuddy.jar

# Expose port 8080 
EXPOSE 8080

# Run the java script
ENTRYPOINT ["java","-jar","paymybuddy.jar"]                           
