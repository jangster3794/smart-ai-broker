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
