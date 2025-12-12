#!/bin/bash

# Script to generate APScheduler service for price simulation and auto-trading
set -e

echo "🚀 Generating APScheduler Service..."

# Navigate to backend directory
cd backend

# Create scheduler directory structure
mkdir -p scheduler

# Create scheduler/__init__.py
touch scheduler/__init__.py

# Create scheduler/config.py
cat > scheduler/config.py << 'EOF'
from datetime import datetime, timedelta
from typing import Dict, List

# Ticker initialization data
TICKERS_INIT = [
    {"symbol": "AAPL", "name": "Apple Inc.", "initial_price": 150.0},
    {"symbol": "GOOGL", "name": "Alphabet Inc.", "initial_price": 140.0},
    {"symbol": "MSFT", "name": "Microsoft Corporation", "initial_price": 380.0},
    {"symbol": "TSLA", "name": "Tesla Inc.", "initial_price": 250.0},
    {"symbol": "AMZN", "name": "Amazon.com Inc.", "initial_price": 180.0},
    {"symbol": "NVDA", "name": "NVIDIA Corporation", "initial_price": 500.0},
    {"symbol": "META", "name": "Meta Platforms Inc.", "initial_price": 350.0},
    {"symbol": "NFLX", "name": "Netflix Inc.", "initial_price": 450.0},
    {"symbol": "AMD", "name": "Advanced Micro Devices Inc.", "initial_price": 120.0},
    {"symbol": "INTC", "name": "Intel Corporation", "initial_price": 45.0},
]

# Historical data configuration
HISTORICAL_MONTHS = 6
HISTORICAL_INTERVAL_MINUTES = 5
BATCH_SIZE = 1000

# Job intervals
PRICE_UPDATE_INTERVAL_SECONDS = 5
AUTO_TRADE_INTERVAL_SECONDS = 30

# Volatility configuration
BASE_VOLATILITY = 0.02  # 2% base volatility
VOLATILITY_RANGE = 0.005  # +/- 0.5% random component
EOF

# Create scheduler/price_simulator.py
cat > scheduler/price_simulator.py << 'EOF'
import random
import numpy as np
from datetime import datetime, timedelta
from sqlalchemy.orm import Session
from app.models.models import Ticker, PriceTick
from scheduler.config import TICKERS_INIT, HISTORICAL_MONTHS, HISTORICAL_INTERVAL_MINUTES, BATCH_SIZE
from scheduler.config import BASE_VOLATILITY, VOLATILITY_RANGE


def initialize_tickers(db: Session):
    """Initialize tickers if they don't exist"""
    print("Initializing tickers...")
    
    for ticker_data in TICKERS_INIT:
        existing = db.query(Ticker).filter(Ticker.symbol == ticker_data["symbol"]).first()
        if not existing:
            ticker = Ticker(
                symbol=ticker_data["symbol"],
                name=ticker_data["name"]
            )
            db.add(ticker)
            print(f"  Created ticker: {ticker_data['symbol']}")
        else:
            print(f"  Ticker already exists: {ticker_data['symbol']}")
    
    db.commit()
    print("Tickers initialized!")


def generate_historical_data(db: Session):
    """Generate 6 months of historical price data"""
    print("Generating historical data...")
    
    tickers = db.query(Ticker).all()
    end_time = datetime.utcnow()
    start_time = end_time - timedelta(days=HISTORICAL_MONTHS * 30)
    
    for ticker in tickers:
        # Check if historical data already exists
        existing_count = db.query(PriceTick).filter(
            PriceTick.ticker_id == ticker.id
        ).count()
        
        if existing_count > 0:
            print(f"  Skipping {ticker.symbol} - already has {existing_count} price ticks")
            continue
        
        print(f"  Generating historical data for {ticker.symbol}...")
        
        # Find initial price for this ticker
        initial_price = next(
            (t["initial_price"] for t in TICKERS_INIT if t["symbol"] == ticker.symbol),
            100.0
        )
        
        current_price = initial_price
        current_time = start_time
        batch = []
        total_ticks = 0
        
        while current_time <= end_time:
            # Simulate price movement with volatility
            volatility = BASE_VOLATILITY + random.uniform(-VOLATILITY_RANGE, VOLATILITY_RANGE)
            price_change = current_price * volatility * random.uniform(-1, 1)
            current_price = max(current_price + price_change, 1.0)  # Ensure price stays positive
            
            # Generate random volume
            volume = random.randint(100000, 10000000)
            
            price_tick = PriceTick(
                ticker_id=ticker.id,
                price=round(current_price, 2),
                volume=volume,
                timestamp=current_time
            )
            batch.append(price_tick)
            
            # Batch insert for performance
            if len(batch) >= BATCH_SIZE:
                db.bulk_save_objects(batch)
                db.commit()
                total_ticks += len(batch)
                print(f"    {ticker.symbol}: {total_ticks} ticks generated...")
                batch = []
            
            current_time += timedelta(minutes=HISTORICAL_INTERVAL_MINUTES)
        
        # Insert remaining batch
        if batch:
            db.bulk_save_objects(batch)
            db.commit()
            total_ticks += len(batch)
        
        print(f"  ✓ {ticker.symbol}: Generated {total_ticks} historical price ticks")
    
    print("Historical data generation complete!")


def simulate_price_tick(db: Session):
    """Generate new price tick for all tickers with volatility simulation"""
    tickers = db.query(Ticker).all()
    
    for ticker in tickers:
        # Get the last price
        last_tick = db.query(PriceTick).filter(
            PriceTick.ticker_id == ticker.id
        ).order_by(PriceTick.timestamp.desc()).first()
        
        if last_tick:
            last_price = last_tick.price
        else:
            # Use initial price if no history
            last_price = next(
                (t["initial_price"] for t in TICKERS_INIT if t["symbol"] == ticker.symbol),
                100.0
            )
        
        # Simulate price movement with realistic volatility
        volatility = BASE_VOLATILITY + random.uniform(-VOLATILITY_RANGE, VOLATILITY_RANGE)
        price_change = last_price * volatility * random.uniform(-1, 1)
        new_price = max(last_price + price_change, 1.0)  # Ensure price stays positive
        
        # Add some momentum (trend continuation)
        if random.random() < 0.3:  # 30% chance of momentum
            trend = 1 if price_change > 0 else -1
            new_price += last_price * 0.001 * trend
        
        # Generate random volume
        volume = random.randint(100000, 10000000)
        
        # Create new price tick
        price_tick = PriceTick(
            ticker_id=ticker.id,
            price=round(new_price, 2),
            volume=volume,
            timestamp=datetime.utcnow()
        )
        db.add(price_tick)
    
    db.commit()
    print(f"[{datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S')}] Generated price ticks for {len(tickers)} tickers")
EOF

# Create scheduler/auto_trader.py
cat > scheduler/auto_trader.py << 'EOF'
from datetime import datetime
from sqlalchemy.orm import Session
from app.models.models import User, AutoTradeConfig, Ticker, Account
from app.services.indicators import get_technical_indicators
from app.services.predictions import get_trading_signal
from app.services.trading import execute_buy, execute_sell, get_latest_price
import asyncio


async def process_auto_trading(db: Session):
    """Process auto-trading for all enabled users"""
    # Get all users with auto-trading enabled
    configs = db.query(AutoTradeConfig).filter(
        AutoTradeConfig.enabled == True
    ).all()
    
    if not configs:
        return
    
    print(f"[{datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S')}] Processing auto-trading for {len(configs)} users...")
    
    tickers = db.query(Ticker).all()
    
    for config in configs:
        user = db.query(User).filter(User.id == config.user_id).first()
        if not user:
            continue
        
        account = db.query(Account).filter(Account.user_id == user.id).first()
        if not account:
            continue
        
        print(f"  Processing user: {user.username} (Cash: ${account.cash_balance:.2f})")
        
        for ticker in tickers:
            try:
                # Get technical indicators
                indicators = get_technical_indicators(db, ticker.id)
                
                # Get trading signal (AI or rule-based)
                signal = await get_trading_signal(db, ticker.id, ticker.symbol)
                
                action = signal["action"]
                confidence = signal["confidence"]
                reason = signal["reason"]
                
                # Check if confidence meets threshold
                if confidence < config.confidence_threshold:
                    continue
                
                print(f"    {ticker.symbol}: {action} (confidence: {confidence:.2f}) - {reason}")
                
                # Execute trade based on signal
                if action == "BUY":
                    # Check if user has enough cash
                    current_price = get_latest_price(db, ticker.id)
                    max_quantity = min(
                        config.max_trade_size,
                        int(account.cash_balance / current_price)
                    )
                    
                    if max_quantity > 0:
                        result = execute_buy(db, user.id, ticker.id, max_quantity)
                        print(f"      ✓ BUY {max_quantity} shares at ${current_price:.2f} (Total: ${result['total_amount']:.2f})")
                        # Refresh account balance
                        db.refresh(account)
                    else:
                        print(f"      ✗ Insufficient funds for {ticker.symbol}")
                
                elif action == "SELL":
                    # Check if user has shares to sell
                    from app.models.models import Portfolio
                    portfolio = db.query(Portfolio).filter(
                        Portfolio.user_id == user.id,
                        Portfolio.ticker_id == ticker.id
                    ).first()
                    
                    if portfolio and portfolio.quantity > 0:
                        sell_quantity = min(config.max_trade_size, portfolio.quantity)
                        current_price = get_latest_price(db, ticker.id)
                        result = execute_sell(db, user.id, ticker.id, sell_quantity)
                        print(f"      ✓ SELL {sell_quantity} shares at ${current_price:.2f} (Total: ${result['total_amount']:.2f})")
                        # Refresh account balance
                        db.refresh(account)
                    else:
                        print(f"      ✗ No shares to sell for {ticker.symbol}")
                
            except Exception as e:
                print(f"      ✗ Error processing {ticker.symbol} for {user.username}: {e}")
                continue
    
    print(f"[{datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S')}] Auto-trading cycle complete")


def run_auto_trading(db: Session):
    """Synchronous wrapper for async auto-trading"""
    try:
        asyncio.run(process_auto_trading(db))
    except Exception as e:
        print(f"Error in auto-trading: {e}")
EOF

# Create scheduler/main.py
cat > scheduler/main.py << 'EOF'
import time
from apscheduler.schedulers.blocking import BlockingScheduler
from apscheduler.triggers.interval import IntervalTrigger
from app.core.database import SessionLocal, engine, Base
from scheduler.price_simulator import initialize_tickers, generate_historical_data, simulate_price_tick
from scheduler.auto_trader import run_auto_trading
from scheduler.config import PRICE_UPDATE_INTERVAL_SECONDS, AUTO_TRADE_INTERVAL_SECONDS

# Create database tables
Base.metadata.create_all(bind=engine)

def init_data():
    """Initialize tickers and historical data"""
    db = SessionLocal()
    try:
        initialize_tickers(db)
        generate_historical_data(db)
    finally:
        db.close()

def price_tick_job():
    """Job to generate price ticks"""
    db = SessionLocal()
    try:
        simulate_price_tick(db)
    except Exception as e:
        print(f"Error in price tick job: {e}")
    finally:
        db.close()

def auto_trade_job():
    """Job to process auto-trading"""
    db = SessionLocal()
    try:
        run_auto_trading(db)
    except Exception as e:
        print(f"Error in auto-trade job: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    print("=" * 60)
    print("🤖 Trading Scheduler Service Starting...")
    print("=" * 60)
    
    # Wait for database to be ready
    print("Waiting 10 seconds for database initialization...")
    time.sleep(10)
    
    # Initialize data
    print("\nInitializing data...")
    init_data()
    
    # Create scheduler
    scheduler = BlockingScheduler()
    
    # Add jobs
    print("\nScheduling jobs...")
    
    # Price simulation every 5 seconds
    scheduler.add_job(
        price_tick_job,
        trigger=IntervalTrigger(seconds=PRICE_UPDATE_INTERVAL_SECONDS),
        id='price_tick_job',
        name='Generate price ticks with volatility simulation',
        replace_existing=True
    )
    print(f"  ✓ Price tick generation: every {PRICE_UPDATE_INTERVAL_SECONDS} seconds")
    
    # Auto-trading every 30 seconds
    scheduler.add_job(
        auto_trade_job,
        trigger=IntervalTrigger(seconds=AUTO_TRADE_INTERVAL_SECONDS),
        id='auto_trade_job',
        name='Process auto-trading for enabled users',
        replace_existing=True
    )
    print(f"  ✓ Auto-trading: every {AUTO_TRADE_INTERVAL_SECONDS} seconds")
    
    print("\n" + "=" * 60)
    print("✅ Scheduler started successfully!")
    print("=" * 60)
    print(f"Price updates: Every {PRICE_UPDATE_INTERVAL_SECONDS}s")
    print(f"Auto-trading: Every {AUTO_TRADE_INTERVAL_SECONDS}s")
    print("=" * 60 + "\n")
    
    # Start scheduler
    try:
        scheduler.start()
    except (KeyboardInterrupt, SystemExit):
        print("\n🛑 Shutting down scheduler...")
        scheduler.shutdown()
        print("✓ Scheduler stopped")
EOF

# Create scheduler requirements.txt
cat > scheduler/requirements.txt << 'EOF'
# Backend dependencies
bcrypt==4.0.1
PyJWT==2.8.0
fastapi==0.104.1
uvicorn[standard]==0.24.0
sqlalchemy==2.0.23
psycopg2-binary==2.9.9
alembic==1.12.1
pydantic==2.5.0
pydantic-settings==2.1.0
pandas==2.1.3
numpy==1.26.2
anthropic==0.7.8
python-multipart==0.0.6
httpx==0.25.2

# Scheduler specific
apscheduler==3.10.4
EOF

# Create Dockerfile for scheduler
cat > Dockerfile.scheduler << 'EOF'
FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements
COPY scheduler/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY app/ ./app/
COPY scheduler/ ./scheduler/

# Create entrypoint script
RUN echo '#!/bin/bash\n\
set -e\n\
echo "Waiting for backend and database..."\n\
sleep 10\n\
echo "Starting scheduler service..."\n\
exec python -m scheduler.main' > /app/entrypoint.sh \
    && chmod +x /app/entrypoint.sh

ENTRYPOINT ["/app/entrypoint.sh"]
EOF

# Update docker-compose.yml
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  postgres:
    image: postgres:15-alpine
    environment:
      POSTGRES_USER: trading_user
      POSTGRES_PASSWORD: trading_pass
      POSTGRES_DB: trading_db
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U trading_user"]
      interval: 5s
      timeout: 5s
      retries: 5

  backend:
    build: .
    ports:
      - "8000:8000"
    environment:
      DATABASE_URL: postgresql://trading_user:trading_pass@postgres:5432/trading_db
      SECRET_KEY: ${SECRET_KEY:-your-secret-key-change-in-production-min-32-chars}
      ANTHROPIC_API_KEY: ${ANTHROPIC_API_KEY:-}
    depends_on:
      postgres:
        condition: service_healthy
    volumes:
      - ./app:/app/app
      - ./alembic:/app/alembic

  scheduler:
    build:
      context: .
      dockerfile: Dockerfile.scheduler
    environment:
      DATABASE_URL: postgresql://trading_user:trading_pass@postgres:5432/trading_db
      SECRET_KEY: ${SECRET_KEY:-your-secret-key-change-in-production-min-32-chars}
      ANTHROPIC_API_KEY: ${ANTHROPIC_API_KEY:-}
    depends_on:
      postgres:
        condition: service_healthy
      backend:
        condition: service_started
    volumes:
      - ./app:/app/app
      - ./scheduler:/app/scheduler

volumes:
  postgres_data:
EOF

# Update README.md with scheduler information
cat >> README.md << 'EOF'

## Scheduler Service

The scheduler service handles automated tasks:

### Price Simulation
- Runs every 5 seconds
- Generates realistic price ticks with volatility simulation
- Includes momentum and trend continuation
- Volume simulation

### Auto-Trading
- Runs every 30 seconds
- Processes users with `enabled=true` in auto-trading config
- Calculates technical indicators for each ticker
- Gets AI-powered or rule-based trading signals
- Executes trades when confidence exceeds threshold
- Respects `max_trade_size` limit

### Initial Data Setup
- 10 tickers: AAPL, GOOGL, MSFT, TSLA, AMZN, NVDA, META, NFLX, AMD, INTC
- 6 months of historical data (5-minute intervals)
- Checks if data exists before generation
- Batch processing (1000 records) for performance

### Starting the Scheduler

With Docker:
```bash
docker-compose up --build
```

The scheduler service will:
1. Wait 10 seconds for database initialization
2. Initialize tickers if they don't exist
3. Generate historical data if not present
4. Start price simulation (every 5s)
5. Start auto-trading (every 30s)

### Monitoring

View scheduler logs:
```bash
docker-compose logs -f scheduler
```

View all services:
```bash
docker-compose ps
```

### Configuration

Edit `scheduler/config.py` to customize:
- Ticker initial prices
- Historical data period
- Job intervals
- Volatility parameters
EOF

echo ""
echo "✅ Scheduler generation complete!"
echo ""
echo "📁 New structure:"
echo "backend/"
echo "├── scheduler/"
echo "│   ├── __init__.py"
echo "│   ├── main.py              # Scheduler entry point"
echo "│   ├── config.py            # Configuration"
echo "│   ├── price_simulator.py   # Price tick generation"
echo "│   ├── auto_trader.py       # Auto-trading logic"
echo "│   └── requirements.txt     # Dependencies"
echo "├── Dockerfile.scheduler     # Scheduler container"
echo "└── docker-compose.yml       # Updated with scheduler service"
echo ""
echo "🚀 To start all services:"
echo "   cd backend"
echo "   docker-compose up --build"
echo ""
echo "📊 Scheduler features:"
echo "   ✓ Price simulation every 5 seconds"
echo "   ✓ Auto-trading every 30 seconds"
echo "   ✓ 10 tickers initialized with historical data"
echo "   ✓ 6 months of 5-minute interval data"
echo "   ✓ Realistic volatility simulation"
echo "   ✓ AI-powered trading decisions"
echo ""
echo "💡 Monitor logs: docker-compose logs -f scheduler"
echo ""