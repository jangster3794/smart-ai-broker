from sqlalchemy.orm import Session
from app.models.models import Trade, Portfolio, Account, Ticker, PriceTick
from typing import Dict
from datetime import datetime


def get_latest_price(db: Session, ticker_id: int) -> float:
    """Get the latest price for a ticker"""
    price_tick = db.query(PriceTick).filter(
        PriceTick.ticker_id == ticker_id
    ).order_by(PriceTick.timestamp.desc()).first()
    
    if not price_tick:
        raise ValueError("No price data available for this ticker")
    
    return price_tick.price


def execute_buy(db: Session, user_id: int, ticker_id: int, quantity: int) -> Dict:
    """Execute a buy trade"""
    # Get current price
    current_price = get_latest_price(db, ticker_id)
    total_cost = current_price * quantity
    
    # Get user account
    account = db.query(Account).filter(Account.user_id == user_id).first()
    if not account:
        raise ValueError("User account not found")
    
    # Check if user has enough cash
    if account.cash_balance < total_cost:
        raise ValueError(f"Insufficient funds. Required: ${total_cost:.2f}, Available: ${account.cash_balance:.2f}")
    
    # Update cash balance
    account.cash_balance -= total_cost
    
    # Update or create portfolio entry
    portfolio = db.query(Portfolio).filter(
        Portfolio.user_id == user_id,
        Portfolio.ticker_id == ticker_id
    ).first()
    
    if portfolio:
        # Update existing position
        total_quantity = portfolio.quantity + quantity
        portfolio.avg_price = (portfolio.avg_price * portfolio.quantity + total_cost) / total_quantity
        portfolio.quantity = total_quantity
        portfolio.current_price = current_price
    else:
        # Create new position
        portfolio = Portfolio(
            user_id=user_id,
            ticker_id=ticker_id,
            quantity=quantity,
            avg_price=current_price,
            current_price=current_price
        )
        db.add(portfolio)
    
    # Create trade record
    trade = Trade(
        user_id=user_id,
        ticker_id=ticker_id,
        action="BUY",
        quantity=quantity,
        price=current_price,
        total_amount=total_cost,
        cash_after=account.cash_balance
    )
    db.add(trade)
    
    db.commit()
    db.refresh(trade)
    
    return {
        "trade_id": trade.id,
        "action": "BUY",
        "quantity": quantity,
        "price": current_price,
        "total_amount": total_cost,
        "cash_after": account.cash_balance
    }


def execute_sell(db: Session, user_id: int, ticker_id: int, quantity: int) -> Dict:
    """Execute a sell trade"""
    # Get current price
    current_price = get_latest_price(db, ticker_id)
    total_revenue = current_price * quantity
    
    # Get portfolio position
    portfolio = db.query(Portfolio).filter(
        Portfolio.user_id == user_id,
        Portfolio.ticker_id == ticker_id
    ).first()
    
    if not portfolio:
        raise ValueError("No position found for this ticker")
    
    if portfolio.quantity < quantity:
        raise ValueError(f"Insufficient shares. You have {portfolio.quantity}, trying to sell {quantity}")
    
    # Update portfolio
    portfolio.quantity -= quantity
    portfolio.current_price = current_price
    
    if portfolio.quantity == 0:
        db.delete(portfolio)
    
    # Update account cash balance
    account = db.query(Account).filter(Account.user_id == user_id).first()
    account.cash_balance += total_revenue
    
    # Create trade record
    trade = Trade(
        user_id=user_id,
        ticker_id=ticker_id,
        action="SELL",
        quantity=quantity,
        price=current_price,
        total_amount=total_revenue,
        cash_after=account.cash_balance
    )
    db.add(trade)
    
    db.commit()
    db.refresh(trade)
    
    return {
        "trade_id": trade.id,
        "action": "SELL",
        "quantity": quantity,
        "price": current_price,
        "total_amount": total_revenue,
        "cash_after": account.cash_balance
    }


def update_portfolio_prices(db: Session, user_id: int):
    """Update current prices for all portfolio positions"""
    portfolios = db.query(Portfolio).filter(Portfolio.user_id == user_id).all()
    
    for portfolio in portfolios:
        try:
            current_price = get_latest_price(db, portfolio.ticker_id)
            portfolio.current_price = current_price
        except ValueError:
            pass  # Skip if no price data
    
    db.commit()
