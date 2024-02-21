# Use the official Nim image from Docker Hub
FROM nimlang/nim:2.0.2 AS build-env

# Install PostgreSQL client library
RUN apt-get update && apt-get install -y libpq-dev

# Set the working directory
WORKDIR /app

COPY rinha.nimble rinha.nimble

# Install any Nimble dependencies
RUN nimble install -y -d

# Copy the current directory contents into the container
COPY . .

# Compile the Nim application
#RUN nimble compile --opt:size --mm:orc --threads:on -d:release src/rinha.nim -o:/app/rinha
RUN nimble compile --opt:speed --mm:orc --threads:on -d:release src/rinha.nim -o:/app/rinha
#RUN strip /app/rinha    

EXPOSE 3000

# Run the compiled Nim application
CMD ["sh", "-c", "/app/rinha"]
