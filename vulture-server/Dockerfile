# Use official Python runtime as base image
FROM python:3.12-slim

# Set working directory in container
WORKDIR /app

# Install system dependencies (for audio processing if needed)
RUN apt-get update && apt-get install -y \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first (for better layer caching)
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of the app
COPY . .

# Expose port
EXPOSE 8080

# Run with uvicorn, listening on 0.0.0.0:8080
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]
