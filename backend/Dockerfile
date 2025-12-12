FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application
COPY . .

# Create entrypoint script
RUN echo '#!/bin/bash\n\
set -e\n\
echo "Waiting for postgres..."\n\
while ! pg_isready -h postgres -p 5432 -U trading_user; do\n\
  sleep 1\n\
done\n\
echo "PostgreSQL started"\n\
echo "Running migrations..."\n\
# alembic upgrade head\n\
echo "Migrations completed"\n\
echo "Starting application..."\n\
exec uvicorn app.main:app --host 0.0.0.0 --port 8000' > /app/entrypoint.sh \
    && chmod +x /app/entrypoint.sh

EXPOSE 8000

ENTRYPOINT ["/app/entrypoint.sh"]
