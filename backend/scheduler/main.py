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
