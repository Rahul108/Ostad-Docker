# Ostad Docker Project

This project contains Docker configuration for running a full-stack application with Node.js backend, React frontend, MongoDB, and Mongo Express.

## Project Structure

- `Dockerfile-server`: Docker configuration for the backend server
- `Dockerfile-UI`: Docker configuration for the frontend UI
- `docker-compose.yaml`: Orchestrates all services
- `.env`: Environment variables for database credentials and connection strings
- `.env.example`: Example environment file
- `OstadServer/`: Backend code directory
- `OstadUI/`: Frontend code directory

## Setup

1. Make sure Docker and Docker Compose are installed on your system
2. Clone this repository: `git clone https://github.com/mdarifahammedreza/Ostad-Docker.git`
3. Navigate to the project directory: `cd Ostad-Docker`
4. Copy the environment variables file: `cp .env.example .env`
5. Customize the values in `.env` as needed
6. Build and start the containers: `docker compose up -d`

## Accessing Services

- Frontend (React): http://localhost:5173
- Backend API: http://localhost:5050
- MongoDB: mongodb://localhost:27017
- Mongo Express (Database UI): http://localhost:8081

## Architecture

The application uses a bridge network to connect all services:

| Service      | Purpose                  | Ports     |
|--------------|---------------------------|-----------|
| mongo        | MongoDB database          | 27017:27017 |
| mongo-express| MongoDB web UI            | 8081:8081 |
| ostad-server | Backend Node.js API       | 5050:5050 |
| ostad-ui     | Frontend React app (Vite) | 5173:5173 |

## Environment Variables

The following environment variables can be configured in the `.env` file:

- `MONGO_ROOT_USERNAME`: MongoDB admin username
- `MONGO_ROOT_PASSWORD`: MongoDB admin password
- `MONGO_DATABASE`: MongoDB database name
- `MONGO_URI`: MongoDB connection string
- `ME_CONFIG_MONGODB_ADMINUSERNAME`: Mongo Express admin username
- `ME_CONFIG_MONGODB_ADMINPASSWORD`: Mongo Express admin password

## Stopping the Application

```
docker compose down
```

To remove volumes (data) when stopping:
```
docker compose down -v
```
