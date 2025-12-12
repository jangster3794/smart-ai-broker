from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
from app.core.database import get_db
from app.models.models import User, Ticker, Account, Portfolio, Trade, AutoTradeConfig, PriceTick
from app.models.schemas import (
    TickerResponse, PriceTickResponse, TechnicalIndicators, TradingSignal,
    PortfolioResponse, TradeCreate, TradeResponse, AccountResponse,
    AutoTradeConfigResponse, AutoTradeConfigUpdate
)
from app.api.dependencies.auth import get_current_user
from app.services.indicators import get_technical_indicators
from app.services.predictions import get_trading_signal
from app.services.trading import execute_buy, execute_sell, update_portfolio_prices

router = APIRouter(tags=["Trading"])


@router.get("/api/tickers", response_model=List[TickerResponse],
            summary="Get all available tickers",
            description="Retrieve list of all available trading tickers")
async def get_tickers(db: Session = Depends(get_db)):
    """Get all available tickers"""
    tickers = db.query(Ticker).all()
    return tickers


@router.get("/api/tickers/{symbol}/prices", response_model=List[PriceTickResponse],
            summary="Get price history for a ticker",
            description="Retrieve historical price data for a specific ticker symbol")
async def get_prices(symbol: str, limit: int = 100, db: Session = Depends(get_db)):
    """Get price history for a ticker"""
    ticker = db.query(Ticker).filter(Ticker.symbol == symbol).first()
    if not ticker:
        raise HTTPException(status_code=404, detail="Ticker not found")
    
    prices = db.query(PriceTick).filter(
        PriceTick.ticker_id == ticker.id
    ).order_by(PriceTick.timestamp.desc()).limit(limit).all()
    
    return prices


@router.get("/api/tickers/{symbol}/indicators", response_model=TechnicalIndicators,
            summary="Get technical indicators for a ticker",
            description="Calculate and return technical indicators (SMA, EMA, RSI, MACD, Bollinger Bands, Volatility)")
async def get_indicators(symbol: str, db: Session = Depends(get_db)):
    """Get technical indicators for a ticker"""
    ticker = db.query(Ticker).filter(Ticker.symbol == symbol).first()
    if not ticker:
        raise HTTPException(status_code=404, detail="Ticker not found")
    
    indicators = get_technical_indicators(db, ticker.id)
    return indicators


@router.get("/api/tickers/{symbol}/signal", response_model=TradingSignal,
            summary="Get trading signal for a ticker",
            description="Get AI-powered or rule-based trading recommendation (BUY/SELL/HOLD) with confidence and reasoning")
async def get_signal(symbol: str, db: Session = Depends(get_db)):
    """Get trading signal for a ticker"""
    ticker = db.query(Ticker).filter(Ticker.symbol == symbol).first()
    if not ticker:
        raise HTTPException(status_code=404, detail="Ticker not found")
    
    signal = await get_trading_signal(db, ticker.id, ticker.symbol)
    return signal


@router.get("/api/account", response_model=AccountResponse,
            summary="Get user account details",
            description="Retrieve current user's account information including cash balance")
async def get_account(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get user account details"""
    account = db.query(Account).filter(Account.user_id == current_user.id).first()
    if not account:
        raise HTTPException(status_code=404, detail="Account not found")
    
    return account


@router.get("/api/portfolio", response_model=List[PortfolioResponse],
            summary="Get user portfolio",
            description="Retrieve all current holdings in user's portfolio")
async def get_portfolio(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get user portfolio"""
    update_portfolio_prices(db, current_user.id)
    
    portfolios = db.query(Portfolio).filter(
        Portfolio.user_id == current_user.id
    ).all()
    
    # Add ticker symbol to response
    for portfolio in portfolios:
        ticker = db.query(Ticker).filter(Ticker.id == portfolio.ticker_id).first()
        portfolio.ticker_symbol = ticker.symbol if ticker else None
    
    return portfolios


@router.post("/api/trade", response_model=TradeResponse, status_code=status.HTTP_201_CREATED,
             summary="Execute a trade",
             description="Execute a buy or sell trade for a specific ticker")
async def create_trade(
    trade_data: TradeCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Execute a trade"""
    ticker = db.query(Ticker).filter(Ticker.symbol == trade_data.ticker_symbol).first()
    if not ticker:
        raise HTTPException(status_code=404, detail="Ticker not found")
    
    try:
        if trade_data.action == "BUY":
            result = execute_buy(db, current_user.id, ticker.id, trade_data.quantity)
        else:  # SELL
            result = execute_sell(db, current_user.id, ticker.id, trade_data.quantity)
        
        trade = db.query(Trade).filter(Trade.id == result["trade_id"]).first()
        trade.ticker_symbol = ticker.symbol
        
        return trade
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.get("/api/trades", response_model=List[TradeResponse],
            summary="Get trade history",
            description="Retrieve user's complete trade history")
async def get_trades(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get user trade history"""
    trades = db.query(Trade).filter(
        Trade.user_id == current_user.id
    ).order_by(Trade.timestamp.desc()).all()
    
    # Add ticker symbol to response
    for trade in trades:
        ticker = db.query(Ticker).filter(Ticker.id == trade.ticker_id).first()
        trade.ticker_symbol = ticker.symbol if ticker else None
    
    return trades


@router.get("/api/auto-trading/config", response_model=AutoTradeConfigResponse,
            summary="Get auto-trading configuration",
            description="Retrieve current auto-trading settings")
async def get_auto_config(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get auto-trading configuration"""
    config = db.query(AutoTradeConfig).filter(
        AutoTradeConfig.user_id == current_user.id
    ).first()
    
    if not config:
        raise HTTPException(status_code=404, detail="Auto-trading config not found")
    
    return config


@router.put("/api/auto-trading/config", response_model=AutoTradeConfigResponse,
            summary="Update auto-trading configuration",
            description="Update auto-trading settings (enabled status, confidence threshold, max trade size)")
async def update_auto_config(
    config_data: AutoTradeConfigUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Update auto-trading configuration"""
    config = db.query(AutoTradeConfig).filter(
        AutoTradeConfig.user_id == current_user.id
    ).first()
    
    if not config:
        raise HTTPException(status_code=404, detail="Auto-trading config not found")
    
    if config_data.enabled is not None:
        config.enabled = config_data.enabled
    if config_data.confidence_threshold is not None:
        config.confidence_threshold = config_data.confidence_threshold
    if config_data.max_trade_size is not None:
        config.max_trade_size = config_data.max_trade_size
    
    db.commit()
    db.refresh(config)
    
    return config
