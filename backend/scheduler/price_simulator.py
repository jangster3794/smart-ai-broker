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
