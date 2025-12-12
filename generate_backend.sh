#!/bin/bash

# Script to generate FastAPI trading backend with JWT auth and trading services
set -e

echo "🚀 Generating FastAPI Trading Backend..."

# Create project structure
mkdir -p backend/{app/{api/{endpoints,dependencies},models,services,core},alembic/versions}
cd backend

# Create requirements.txt
cat > requirements.txt << 'EOF'
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
EOF

# Create .env file
cat > .env << 'EOF'
DATABASE_URL=postgresql://trading_user:trading_pass@postgres:5432/trading_db
SECRET_KEY=your-secret-key-change-in-production-min-32-chars
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30
ANTHROPIC_API_KEY=your-anthropic-api-key
EOF

# Create app/__init__.py
touch app/__init__.py

# Create app/core/__init__.py
touch app/core/__init__.py

# Create app/core/config.py
cat > app/core/config.py << 'EOF'
from pydantic_settings import BaseSettings
from typing import Optional


class Settings(BaseSettings):
    DATABASE_URL: str
    SECRET_KEY: str
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    ANTHROPIC_API_KEY: Optional[str] = None

    class Config:
        env_file = ".env"


settings = Settings()
EOF

# Create app/core/database.py
cat > app/core/database.py << 'EOF'
from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from app.core.config import settings

engine = create_engine(settings.DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
EOF

# Create app/core/security.py
cat > app/core/security.py << 'EOF'
import bcrypt
import jwt
from datetime import datetime, timedelta
from typing import Optional
from app.core.config import settings


def hash_password(password: str) -> str:
    """Hash password using bcrypt after truncating to 72 bytes"""
    password_bytes = password.encode('utf-8')[:72]
    hashed = bcrypt.hashpw(password_bytes, bcrypt.gensalt())
    return hashed.decode('utf-8')


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify password using bcrypt after truncating to 72 bytes"""
    password_bytes = plain_password.encode('utf-8')[:72]
    hashed_bytes = hashed_password.encode('utf-8')
    return bcrypt.checkpw(password_bytes, hashed_bytes)


def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    """Create JWT access token"""
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=15)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM)
    return encoded_jwt


def decode_access_token(token: str) -> dict:
    """Decode JWT access token"""
    return jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
EOF

# Create app/models/__init__.py
touch app/models/__init__.py

# Create app/models/models.py
cat > app/models/models.py << 'EOF'
from sqlalchemy import Column, Integer, String, Float, DateTime, Boolean, ForeignKey, Text
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.core.database import Base


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, unique=True, index=True, nullable=False)
    username = Column(String, unique=True, index=True, nullable=False)
    hashed_password = Column(String, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    accounts = relationship("Account", back_populates="user")
    portfolios = relationship("Portfolio", back_populates="user")
    trades = relationship("Trade", back_populates="user")
    auto_trade_config = relationship("AutoTradeConfig", back_populates="user", uselist=False)


class Account(Base):
    __tablename__ = "accounts"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    cash_balance = Column(Float, default=10000.0, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    user = relationship("User", back_populates="accounts")


class Ticker(Base):
    __tablename__ = "tickers"

    id = Column(Integer, primary_key=True, index=True)
    symbol = Column(String, unique=True, index=True, nullable=False)
    name = Column(String, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    price_ticks = relationship("PriceTick", back_populates="ticker")
    portfolios = relationship("Portfolio", back_populates="ticker")
    trades = relationship("Trade", back_populates="ticker")


class PriceTick(Base):
    __tablename__ = "price_ticks"

    id = Column(Integer, primary_key=True, index=True)
    ticker_id = Column(Integer, ForeignKey("tickers.id"), nullable=False)
    price = Column(Float, nullable=False)
    volume = Column(Integer)
    timestamp = Column(DateTime(timezone=True), server_default=func.now(), index=True)

    ticker = relationship("Ticker", back_populates="price_ticks")


class Portfolio(Base):
    __tablename__ = "portfolios"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    ticker_id = Column(Integer, ForeignKey("tickers.id"), nullable=False)
    quantity = Column(Integer, nullable=False, default=0)
    avg_price = Column(Float, nullable=False)
    current_price = Column(Float)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    user = relationship("User", back_populates="portfolios")
    ticker = relationship("Ticker", back_populates="portfolios")


class Trade(Base):
    __tablename__ = "trades"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    ticker_id = Column(Integer, ForeignKey("tickers.id"), nullable=False)
    action = Column(String, nullable=False)  # BUY or SELL
    quantity = Column(Integer, nullable=False)
    price = Column(Float, nullable=False)
    total_amount = Column(Float, nullable=False)
    cash_after = Column(Float, nullable=False)
    timestamp = Column(DateTime(timezone=True), server_default=func.now())

    user = relationship("User", back_populates="trades")
    ticker = relationship("Ticker", back_populates="trades")


class AutoTradeConfig(Base):
    __tablename__ = "auto_trade_configs"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, unique=True)
    enabled = Column(Boolean, default=False, nullable=False)
    confidence_threshold = Column(Float, default=0.7, nullable=False)
    max_trade_size = Column(Integer, default=5, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    user = relationship("User", back_populates="auto_trade_config")
EOF

# Create app/models/schemas.py
cat > app/models/schemas.py << 'EOF'
from pydantic import BaseModel, EmailStr, Field, field_validator
from datetime import datetime
from typing import Optional, List


class UserCreate(BaseModel):
    email: EmailStr = Field(..., example="user@example.com")
    username: str = Field(..., min_length=3, max_length=50, example="johndoe")
    password: str = Field(..., min_length=8, max_length=72, example="SecurePass123!")

    @field_validator('password')
    @classmethod
    def validate_password(cls, v: str) -> str:
        if len(v) < 8:
            raise ValueError('Password must be at least 8 characters')
        if len(v) > 72:
            raise ValueError('Password must not exceed 72 characters')
        return v

    model_config = {
        "json_schema_extra": {
            "examples": [{
                "email": "user@example.com",
                "username": "johndoe",
                "password": "SecurePass123!"
            }]
        }
    }


class UserLogin(BaseModel):
    username: str = Field(..., example="johndoe")
    password: str = Field(..., example="SecurePass123!")

    model_config = {
        "json_schema_extra": {
            "examples": [{
                "username": "johndoe",
                "password": "SecurePass123!"
            }]
        }
    }


class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"


class UserResponse(BaseModel):
    id: int
    email: str
    username: str
    created_at: datetime

    model_config = {"from_attributes": True}


class AccountResponse(BaseModel):
    id: int
    user_id: int
    cash_balance: float
    created_at: datetime

    model_config = {"from_attributes": True}


class TickerResponse(BaseModel):
    id: int
    symbol: str
    name: str
    created_at: datetime

    model_config = {"from_attributes": True}


class PriceTickResponse(BaseModel):
    id: int
    ticker_id: int
    price: float
    volume: Optional[int]
    timestamp: datetime

    model_config = {"from_attributes": True}


class PortfolioResponse(BaseModel):
    id: int
    user_id: int
    ticker_id: int
    ticker_symbol: Optional[str] = None
    quantity: int
    avg_price: float
    current_price: Optional[float]
    created_at: datetime
    updated_at: Optional[datetime]

    model_config = {"from_attributes": True}


class TradeCreate(BaseModel):
    ticker_symbol: str = Field(..., example="AAPL")
    action: str = Field(..., pattern="^(BUY|SELL)$", example="BUY")
    quantity: int = Field(..., gt=0, example=10)

    model_config = {
        "json_schema_extra": {
            "examples": [{
                "ticker_symbol": "AAPL",
                "action": "BUY",
                "quantity": 10
            }]
        }
    }


class TradeResponse(BaseModel):
    id: int
    user_id: int
    ticker_id: int
    ticker_symbol: Optional[str] = None
    action: str
    quantity: int
    price: float
    total_amount: float
    cash_after: float
    timestamp: datetime

    model_config = {"from_attributes": True}


class AutoTradeConfigResponse(BaseModel):
    id: int
    user_id: int
    enabled: bool
    confidence_threshold: float
    max_trade_size: int
    created_at: datetime
    updated_at: Optional[datetime]

    model_config = {"from_attributes": True}


class AutoTradeConfigUpdate(BaseModel):
    enabled: Optional[bool] = Field(None, example=True)
    confidence_threshold: Optional[float] = Field(None, ge=0.0, le=1.0, example=0.7)
    max_trade_size: Optional[int] = Field(None, gt=0, example=5)

    model_config = {
        "json_schema_extra": {
            "examples": [{
                "enabled": True,
                "confidence_threshold": 0.7,
                "max_trade_size": 5
            }]
        }
    }


class TechnicalIndicators(BaseModel):
    sma_20: Optional[float]
    sma_50: Optional[float]
    ema_12: Optional[float]
    ema_26: Optional[float]
    rsi_14: Optional[float]
    macd: Optional[float]
    macd_signal: Optional[float]
    macd_histogram: Optional[float]
    bollinger_upper: Optional[float]
    bollinger_middle: Optional[float]
    bollinger_lower: Optional[float]
    volatility: Optional[float]


class TradingSignal(BaseModel):
    action: str = Field(..., example="BUY")
    confidence: float = Field(..., example=0.75)
    reason: str = Field(..., example="Strong upward momentum with RSI indicating oversold conditions")

    model_config = {
        "json_schema_extra": {
            "examples": [{
                "action": "BUY",
                "confidence": 0.75,
                "reason": "Strong upward momentum with RSI indicating oversold conditions"
            }]
        }
    }
EOF

# Create app/services/__init__.py
touch app/services/__init__.py

# Create app/services/indicators.py
cat > app/services/indicators.py << 'EOF'
import pandas as pd
import numpy as np
from typing import Dict, Optional, List
from sqlalchemy.orm import Session
from app.models.models import PriceTick


def calculate_sma(prices: pd.Series, period: int) -> float:
    """Calculate Simple Moving Average"""
    if len(prices) < period:
        return None
    return prices.tail(period).mean()


def calculate_ema(prices: pd.Series, period: int) -> float:
    """Calculate Exponential Moving Average"""
    if len(prices) < period:
        return None
    return prices.ewm(span=period, adjust=False).mean().iloc[-1]


def calculate_rsi(prices: pd.Series, period: int = 14) -> float:
    """Calculate Relative Strength Index"""
    if len(prices) < period + 1:
        return None
    
    deltas = prices.diff()
    gains = deltas.where(deltas > 0, 0)
    losses = -deltas.where(deltas < 0, 0)
    
    avg_gain = gains.rolling(window=period).mean()
    avg_loss = losses.rolling(window=period).mean()
    
    rs = avg_gain / avg_loss
    rsi = 100 - (100 / (1 + rs))
    
    return rsi.iloc[-1]


def calculate_macd(prices: pd.Series, fast: int = 12, slow: int = 26, signal: int = 9) -> Dict[str, float]:
    """Calculate MACD (Moving Average Convergence Divergence)"""
    if len(prices) < slow:
        return {"macd": None, "signal": None, "histogram": None}
    
    ema_fast = prices.ewm(span=fast, adjust=False).mean()
    ema_slow = prices.ewm(span=slow, adjust=False).mean()
    
    macd_line = ema_fast - ema_slow
    signal_line = macd_line.ewm(span=signal, adjust=False).mean()
    histogram = macd_line - signal_line
    
    return {
        "macd": macd_line.iloc[-1],
        "signal": signal_line.iloc[-1],
        "histogram": histogram.iloc[-1]
    }


def calculate_bollinger_bands(prices: pd.Series, period: int = 20, std_dev: int = 2) -> Dict[str, float]:
    """Calculate Bollinger Bands"""
    if len(prices) < period:
        return {"upper": None, "middle": None, "lower": None}
    
    middle = prices.rolling(window=period).mean()
    std = prices.rolling(window=period).std()
    
    upper = middle + (std * std_dev)
    lower = middle - (std * std_dev)
    
    return {
        "upper": upper.iloc[-1],
        "middle": middle.iloc[-1],
        "lower": lower.iloc[-1]
    }


def calculate_volatility(prices: pd.Series, period: int = 20) -> float:
    """Calculate historical volatility (standard deviation of returns)"""
    if len(prices) < period + 1:
        return None
    
    returns = prices.pct_change()
    volatility = returns.rolling(window=period).std().iloc[-1]
    
    return volatility * np.sqrt(252)  # Annualized volatility


def get_technical_indicators(db: Session, ticker_id: int, limit: int = 100) -> Dict[str, Optional[float]]:
    """Get all technical indicators for a ticker"""
    price_ticks = db.query(PriceTick).filter(
        PriceTick.ticker_id == ticker_id
    ).order_by(PriceTick.timestamp.desc()).limit(limit).all()
    
    if not price_ticks:
        return {
            "sma_20": None, "sma_50": None,
            "ema_12": None, "ema_26": None,
            "rsi_14": None,
            "macd": None, "macd_signal": None, "macd_histogram": None,
            "bollinger_upper": None, "bollinger_middle": None, "bollinger_lower": None,
            "volatility": None
        }
    
    # Reverse to get chronological order
    price_ticks = list(reversed(price_ticks))
    prices = pd.Series([tick.price for tick in price_ticks])
    
    macd_values = calculate_macd(prices)
    bollinger = calculate_bollinger_bands(prices)
    
    return {
        "sma_20": calculate_sma(prices, 20),
        "sma_50": calculate_sma(prices, 50),
        "ema_12": calculate_ema(prices, 12),
        "ema_26": calculate_ema(prices, 26),
        "rsi_14": calculate_rsi(prices, 14),
        "macd": macd_values["macd"],
        "macd_signal": macd_values["signal"],
        "macd_histogram": macd_values["histogram"],
        "bollinger_upper": bollinger["upper"],
        "bollinger_middle": bollinger["middle"],
        "bollinger_lower": bollinger["lower"],
        "volatility": calculate_volatility(prices)
    }
EOF

# Create app/services/predictions.py
cat > app/services/predictions.py << 'EOF'
import httpx
from typing import Dict
from app.core.config import settings
from app.services.indicators import get_technical_indicators
from sqlalchemy.orm import Session


async def get_claude_prediction(indicators: Dict[str, float], ticker_symbol: str) -> Dict[str, any]:
    """Get trading prediction from Claude API"""
    if not settings.ANTHROPIC_API_KEY:
        return rule_based_fallback(indicators)
    
    try:
        prompt = f"""Analyze these technical indicators for {ticker_symbol} and provide a trading recommendation:

Technical Indicators:
- SMA(20): {indicators.get('sma_20', 'N/A')}
- SMA(50): {indicators.get('sma_50', 'N/A')}
- EMA(12): {indicators.get('ema_12', 'N/A')}
- EMA(26): {indicators.get('ema_26', 'N/A')}
- RSI(14): {indicators.get('rsi_14', 'N/A')}
- MACD: {indicators.get('macd', 'N/A')}
- MACD Signal: {indicators.get('macd_signal', 'N/A')}
- MACD Histogram: {indicators.get('macd_histogram', 'N/A')}
- Bollinger Upper: {indicators.get('bollinger_upper', 'N/A')}
- Bollinger Middle: {indicators.get('bollinger_middle', 'N/A')}
- Bollinger Lower: {indicators.get('bollinger_lower', 'N/A')}
- Volatility: {indicators.get('volatility', 'N/A')}

Provide your recommendation in exactly this JSON format:
{{"action": "BUY|SELL|HOLD", "confidence": 0.0-1.0, "reason": "brief explanation"}}"""

        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.post(
                "https://api.anthropic.com/v1/messages",
                headers={
                    "x-api-key": settings.ANTHROPIC_API_KEY,
                    "anthropic-version": "2023-06-01",
                    "content-type": "application/json"
                },
                json={
                    "model": "claude-sonnet-4-20250514",
                    "max_tokens": 1000,
                    "messages": [
                        {"role": "user", "content": prompt}
                    ]
                }
            )
            
            if response.status_code == 200:
                data = response.json()
                content = data.get("content", [])
                if content and len(content) > 0:
                    text = content[0].get("text", "")
                    # Parse JSON from response
                    import json
                    # Extract JSON from potential markdown or text
                    if "```json" in text:
                        text = text.split("```json")[1].split("```")[0].strip()
                    elif "```" in text:
                        text = text.split("```")[1].split("```")[0].strip()
                    
                    result = json.loads(text.strip())
                    return {
                        "action": result.get("action", "HOLD").upper(),
                        "confidence": float(result.get("confidence", 0.5)),
                        "reason": result.get("reason", "AI prediction")
                    }
    except Exception as e:
        print(f"Claude API error: {e}")
    
    return rule_based_fallback(indicators)


def rule_based_fallback(indicators: Dict[str, float]) -> Dict[str, any]:
    """Rule-based trading signal fallback"""
    rsi = indicators.get('rsi_14')
    macd_histogram = indicators.get('macd_histogram')
    sma_20 = indicators.get('sma_20')
    sma_50 = indicators.get('sma_50')
    
    action = "HOLD"
    confidence = 0.5
    reason = "Insufficient data for clear signal"
    
    # RSI-based signals
    if rsi is not None:
        if rsi < 30:
            action = "BUY"
            confidence = 0.7
            reason = f"RSI ({rsi:.2f}) indicates oversold conditions"
        elif rsi > 70:
            action = "SELL"
            confidence = 0.7
            reason = f"RSI ({rsi:.2f}) indicates overbought conditions"
    
    # MACD confirmation
    if macd_histogram is not None and macd_histogram > 0 and action == "BUY":
        confidence = min(0.85, confidence + 0.15)
        reason += " with positive MACD momentum"
    elif macd_histogram is not None and macd_histogram < 0 and action == "SELL":
        confidence = min(0.85, confidence + 0.15)
        reason += " with negative MACD momentum"
    
    # Moving average crossover
    if sma_20 is not None and sma_50 is not None:
        if sma_20 > sma_50 and action == "BUY":
            confidence = min(0.9, confidence + 0.1)
            reason += " and bullish MA crossover"
        elif sma_20 < sma_50 and action == "SELL":
            confidence = min(0.9, confidence + 0.1)
            reason += " and bearish MA crossover"
    
    return {
        "action": action,
        "confidence": confidence,
        "reason": reason
    }


async def get_trading_signal(db: Session, ticker_id: int, ticker_symbol: str) -> Dict[str, any]:
    """Get trading signal for a ticker"""
    indicators = get_technical_indicators(db, ticker_id)
    return await get_claude_prediction(indicators, ticker_symbol)
EOF

# Create app/services/trading.py
cat > app/services/trading.py << 'EOF'
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
EOF

# Create app/api/__init__.py
touch app/api/__init__.py

# Create app/api/dependencies/__init__.py
touch app/api/dependencies/__init__.py

# Create app/api/dependencies/auth.py
cat > app/api/dependencies/auth.py << 'EOF'
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.core.security import decode_access_token
from app.models.models import User
import jwt

security = HTTPBearer()


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db)
) -> User:
    """Dependency to get current authenticated user"""
    token = credentials.credentials
    
    try:
        payload = decode_access_token(token)
        user_id: int = payload.get("sub")
        if user_id is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Could not validate credentials"
            )
    except jwt.ExpiredSignatureError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token has expired"
        )
    except jwt.InvalidTokenError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Could not validate credentials"
        )
    
    user = db.query(User).filter(User.id == user_id).first()
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found"
        )
    
    return user
EOF

# Create app/api/endpoints/__init__.py
touch app/api/endpoints/__init__.py

# Create app/api/endpoints/auth.py
cat > app/api/endpoints/auth.py << 'EOF'
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from datetime import timedelta
from app.core.database import get_db
from app.core.security import hash_password, verify_password, create_access_token
from app.core.config import settings
from app.models.models import User, Account, AutoTradeConfig
from app.models.schemas import UserCreate, UserLogin, Token, UserResponse
from app.api.dependencies.auth import get_current_user

router = APIRouter(prefix="/api/auth", tags=["Authentication"])


@router.post("/register", response_model=UserResponse, status_code=status.HTTP_201_CREATED,
             summary="Register a new user",
             description="Create a new user account with email, username, and password")
async def register(user_data: UserCreate, db: Session = Depends(get_db)):
    """Register a new user"""
    # Check if user exists
    existing_user = db.query(User).filter(
        (User.email == user_data.email) | (User.username == user_data.username)
    ).first()
    
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email or username already registered"
        )
    
    # Create user
    hashed_password = hash_password(user_data.password)
    user = User(
        email=user_data.email,
        username=user_data.username,
        hashed_password=hashed_password
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    
    # Create account with default balance
    account = Account(user_id=user.id, cash_balance=10000.0)
    db.add(account)
    
    # Create auto trade config with defaults
    auto_config = AutoTradeConfig(
        user_id=user.id,
        enabled=False,
        confidence_threshold=0.7,
        max_trade_size=5
    )
    db.add(auto_config)
    
    db.commit()
    
    return user


@router.post("/login", response_model=Token,
             summary="Login user",
             description="Authenticate user and receive JWT access token")
async def login(user_data: UserLogin, db: Session = Depends(get_db)):
    """Login user and return JWT token"""
    user = db.query(User).filter(User.username == user_data.username).first()
    
    if not user or not verify_password(user_data.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password"
        )
    
    access_token_expires = timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"sub": user.id},
        expires_delta=access_token_expires
    )
    
    return {"access_token": access_token, "token_type": "bearer"}


@router.get("/me", response_model=UserResponse,
            summary="Get current user",
            description="Get details of the currently authenticated user")
async def get_me(current_user: User = Depends(get_current_user)):
    """Get current user details"""
    return current_user
EOF

# Create app/api/endpoints/trading.py
cat > app/api/endpoints/trading.py << 'EOF'
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
EOF

# Create app/main.py
cat > app/main.py << 'EOF'
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.api.endpoints import auth, trading
from app.core.database import engine, Base

# Create database tables
Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="Trading Platform API",
    description="""
    A comprehensive trading platform with JWT authentication, technical analysis, and AI-powered trading signals.
    
    ## Features
    * **Authentication**: JWT-based authentication with bcrypt password hashing
    * **Trading**: Execute buy/sell trades with portfolio management
    * **Technical Analysis**: SMA, EMA, RSI, MACD, Bollinger Bands, Volatility
    * **AI Predictions**: Claude-powered trading signals with rule-based fallback
    * **Auto Trading**: Configurable automated trading based on confidence thresholds
    
    ## Authentication
    All endpoints except `/api/auth/register` and `/api/auth/login` require authentication.
    Use the 'Authorize' button to set your Bearer token.
    """,
    version="1.0.0",
    swagger_ui_parameters={
        "persistAuthorization": True,
        "displayRequestDuration": True,
        "filter": True
    }
)

# CORS configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(auth.router)
app.include_router(trading.router)


@app.get("/", tags=["Health"])
async def root():
    """API health check endpoint"""
    return {
        "status": "healthy",
        "message": "Trading Platform API is running",
        "version": "1.0.0"
    }
EOF

# Create alembic.ini
cat > alembic.ini << 'EOF'
[alembic]
script_location = alembic
prepend_sys_path = .
sqlalchemy.url = postgresql://trading_user:trading_pass@postgres:5432/trading_db

[loggers]
keys = root,sqlalchemy,alembic

[handlers]
keys = console

[formatters]
keys = generic

[logger_root]
level = WARN
handlers = console
qualname =

[logger_sqlalchemy]
level = WARN
handlers =
qualname = sqlalchemy.engine

[logger_alembic]
level = INFO
handlers =
qualname = alembic

[handler_console]
class = StreamHandler
args = (sys.stderr,)
level = NOTSET
formatter = generic

[formatter_generic]
format = %(levelname)-5.5s [%(name)s] %(message)s
datefmt = %H:%M:%S
EOF

# Create alembic/env.py
cat > alembic/env.py << 'EOF'
from logging.config import fileConfig
from sqlalchemy import engine_from_config
from sqlalchemy import pool
from alembic import context
from app.core.database import Base
from app.models.models import User, Account, Ticker, PriceTick, Portfolio, Trade, AutoTradeConfig

config = context.config

if config.config_file_name is not None:
    fileConfig(config.config_file_name)

target_metadata = Base.metadata


def run_migrations_offline() -> None:
    url = config.get_main_option("sqlalchemy.url")
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )

    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    connectable = engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )

    with connectable.connect() as connection:
        context.configure(
            connection=connection, target_metadata=target_metadata
        )

        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
EOF

# Create alembic/script.py.mako
cat > alembic/script.py.mako << 'EOF'
"""${message}

Revision ID: ${up_revision}
Revises: ${down_revision | comma,n}
Create Date: ${create_date}

"""
from alembic import op
import sqlalchemy as sa
${imports if imports else ""}

# revision identifiers, used by Alembic.
revision = ${repr(up_revision)}
down_revision = ${repr(down_revision)}
branch_labels = ${repr(branch_labels)}
depends_on = ${repr(depends_on)}


def upgrade() -> None:
    ${upgrades if upgrades else "pass"}


def downgrade() -> None:
    ${downgrades if downgrades else "pass"}
EOF

# Create alembic/versions/001_initial_schema.py
cat > alembic/versions/001_initial_schema.py << 'EOF'
"""initial schema

Revision ID: 001
Revises: 
Create Date: 2024-01-01 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '001'
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Create users table
    op.create_table(
        'users',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('email', sa.String(), nullable=False),
        sa.Column('username', sa.String(), nullable=False),
        sa.Column('hashed_password', sa.String(), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=True),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_users_email'), 'users', ['email'], unique=True)
    op.create_index(op.f('ix_users_id'), 'users', ['id'], unique=False)
    op.create_index(op.f('ix_users_username'), 'users', ['username'], unique=True)

    # Create accounts table
    op.create_table(
        'accounts',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('cash_balance', sa.Float(), nullable=False, server_default='10000.0'),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=True),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_accounts_id'), 'accounts', ['id'], unique=False)

    # Create tickers table
    op.create_table(
        'tickers',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('symbol', sa.String(), nullable=False),
        sa.Column('name', sa.String(), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=True),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_tickers_id'), 'tickers', ['id'], unique=False)
    op.create_index(op.f('ix_tickers_symbol'), 'tickers', ['symbol'], unique=True)

    # Create price_ticks table
    op.create_table(
        'price_ticks',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('ticker_id', sa.Integer(), nullable=False),
        sa.Column('price', sa.Float(), nullable=False),
        sa.Column('volume', sa.Integer(), nullable=True),
        sa.Column('timestamp', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=True),
        sa.ForeignKeyConstraint(['ticker_id'], ['tickers.id'], ),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_price_ticks_id'), 'price_ticks', ['id'], unique=False)
    op.create_index(op.f('ix_price_ticks_timestamp'), 'price_ticks', ['timestamp'], unique=False)

    # Create portfolios table
    op.create_table(
        'portfolios',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('ticker_id', sa.Integer(), nullable=False),
        sa.Column('quantity', sa.Integer(), nullable=False, default=0),
        sa.Column('avg_price', sa.Float(), nullable=False),
        sa.Column('current_price', sa.Float(), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=True),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(['ticker_id'], ['tickers.id'], ),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_portfolios_id'), 'portfolios', ['id'], unique=False)

    # Create trades table
    op.create_table(
        'trades',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('ticker_id', sa.Integer(), nullable=False),
        sa.Column('action', sa.String(), nullable=False),
        sa.Column('quantity', sa.Integer(), nullable=False),
        sa.Column('price', sa.Float(), nullable=False),
        sa.Column('total_amount', sa.Float(), nullable=False),
        sa.Column('cash_after', sa.Float(), nullable=False),
        sa.Column('timestamp', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=True),
        sa.ForeignKeyConstraint(['ticker_id'], ['tickers.id'], ),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_trades_id'), 'trades', ['id'], unique=False)

    # Create auto_trade_configs table
    op.create_table(
        'auto_trade_configs',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('enabled', sa.Boolean(), nullable=False, default=False),
        sa.Column('confidence_threshold', sa.Float(), nullable=False, default=0.7),
        sa.Column('max_trade_size', sa.Integer(), nullable=False, default=5),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=True),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_auto_trade_configs_id'), 'auto_trade_configs', ['id'], unique=False)
    op.create_index(op.f('ix_auto_trade_configs_user_id'), 'auto_trade_configs', ['user_id'], unique=True)

    # Insert sample tickers
    op.execute("""
        INSERT INTO tickers (symbol, name) VALUES
        ('AAPL', 'Apple Inc.'),
        ('GOOGL', 'Alphabet Inc.'),
        ('MSFT', 'Microsoft Corporation'),
        ('AMZN', 'Amazon.com Inc.'),
        ('TSLA', 'Tesla Inc.')
    """)


def downgrade() -> None:
    op.drop_table('auto_trade_configs')
    op.drop_table('trades')
    op.drop_table('portfolios')
    op.drop_table('price_ticks')
    op.drop_table('tickers')
    op.drop_table('accounts')
    op.drop_table('users')
EOF

# Create Dockerfile
cat > Dockerfile << 'EOF'
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
alembic upgrade head\n\
echo "Migrations completed"\n\
echo "Starting application..."\n\
exec uvicorn app.main:app --host 0.0.0.0 --port 8000' > /app/entrypoint.sh \
    && chmod +x /app/entrypoint.sh

EXPOSE 8000

ENTRYPOINT ["/app/entrypoint.sh"]
EOF

# Create docker-compose.yml
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

volumes:
  postgres_data:
EOF

# Create README.md
cat > README.md << 'EOF'
# Trading Platform Backend

A FastAPI-based trading platform with JWT authentication, technical analysis, and AI-powered trading signals.

## Features

- **JWT Authentication**: Secure authentication with bcrypt password hashing
- **Trading System**: Buy/sell trades with portfolio management
- **Technical Analysis**: SMA, EMA, RSI, MACD, Bollinger Bands, Volatility
- **AI Predictions**: Claude-powered trading signals with rule-based fallback
- **Auto Trading**: Configurable automated trading
- **PostgreSQL**: Robust database with Alembic migrations
- **Swagger UI**: Interactive API documentation

## Quick Start

### Prerequisites
- Docker and Docker Compose
- Python 3.11+ (for local development)

### Setup with Docker

1. Clone and navigate to the backend directory:
```bash
cd backend
```

2. Update `.env` file with your settings:
```bash
SECRET_KEY=your-secret-key-min-32-characters
ANTHROPIC_API_KEY=your-api-key-here  # Optional
```

3. Start the services:
```bash
docker-compose up --build
```

4. Access the API:
- API: http://localhost:8000
- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

### Local Development

1. Create virtual environment:
```bash
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

2. Install dependencies:
```bash
pip install -r requirements.txt
```

3. Start PostgreSQL (or update DATABASE_URL in .env)

4. Run migrations:
```bash
alembic upgrade head
```

5. Start the server:
```bash
uvicorn app.main:app --reload
```

## API Endpoints

### Authentication
- `POST /api/auth/register` - Register new user
- `POST /api/auth/login` - Login and get JWT token
- `GET /api/auth/me` - Get current user info

### Trading
- `GET /api/tickers` - Get all available tickers
- `GET /api/tickers/{symbol}/prices` - Get price history
- `GET /api/tickers/{symbol}/indicators` - Get technical indicators
- `GET /api/tickers/{symbol}/signal` - Get trading signal
- `GET /api/account` - Get account details
- `GET /api/portfolio` - Get portfolio holdings
- `POST /api/trade` - Execute trade
- `GET /api/trades` - Get trade history
- `GET /api/auto-trading/config` - Get auto-trading config
- `PUT /api/auto-trading/config` - Update auto-trading config

## Usage Example

1. Register a user:
```bash
curl -X POST "http://localhost:8000/api/auth/register" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "trader@example.com",
    "username": "trader1",
    "password": "SecurePass123!"
  }'
```

2. Login and get token:
```bash
curl -X POST "http://localhost:8000/api/auth/login" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "trader1",
    "password": "SecurePass123!"
  }'
```

3. Use token for authenticated requests:
```bash
curl -X GET "http://localhost:8000/api/portfolio" \
  -H "Authorization: Bearer YOUR_TOKEN_HERE"
```

## Database Models

- **User**: User account with email, username, hashed password
- **Account**: User trading account with cash balance (default: $10,000)
- **Ticker**: Trading symbols (AAPL, GOOGL, MSFT, etc.)
- **PriceTick**: Historical price data
- **Portfolio**: User holdings with quantities and prices
- **Trade**: Trade history with buy/sell actions
- **AutoTradeConfig**: Auto-trading configuration per user

## Technical Indicators

- SMA (Simple Moving Average): 20-day and 50-day
- EMA (Exponential Moving Average): 12-day and 26-day
- RSI (Relative Strength Index): 14-day
- MACD (Moving Average Convergence Divergence)
- Bollinger Bands: Upper, middle, lower bands
- Volatility: Annualized historical volatility

## AI Trading Signals

The system uses Claude API for intelligent trading signals, with a rule-based fallback:
- Analyzes technical indicators
- Returns action (BUY/SELL/HOLD)
- Provides confidence score (0.0-1.0)
- Explains reasoning

## Security

- Passwords: 8-72 characters, truncated to 72 bytes before bcrypt hashing
- JWT tokens: HS256 algorithm with configurable expiration
- Password validation: Pydantic validators ensure length requirements
- Environment variables: Sensitive data stored in .env file

## Database Migrations

Create new migration:
```bash
alembic revision --autogenerate -m "description"
```

Apply migrations:
```bash
alembic upgrade head
```

Rollback:
```bash
alembic downgrade -1
```

## Development

The backend uses:
- FastAPI for REST API
- SQLAlchemy for ORM
- Alembic for migrations
- bcrypt for password hashing
- PyJWT for JWT tokens
- Pandas/NumPy for technical analysis
- Anthropic SDK for AI predictions

## License

MIT License
EOF

cd ..

echo ""
echo "✅ Backend generation complete!"
echo ""
echo "📁 Project structure:"
echo "backend/"
echo "├── app/"
echo "│   ├── api/endpoints/     # API route handlers"
echo "│   ├── core/             # Config, database, security"
echo "│   ├── models/           # SQLAlchemy models & Pydantic schemas"
echo "│   ├── services/         # Business logic (indicators, predictions, trading)"
echo "│   └── main.py           # FastAPI application"
echo "├── alembic/              # Database migrations"
echo "├── requirements.txt      # Python dependencies"
echo "├── Dockerfile           # Container configuration"
echo "├── docker-compose.yml   # Multi-container setup"
echo "└── .env                 # Environment variables"
echo ""
echo "🚀 To start the backend:"
echo "   cd backend"
echo "   docker-compose up --build"
echo ""
echo "📖 Access Swagger UI: http://localhost:8000/docs"
echo "🔧 API endpoint: http://localhost:8000"
echo ""
echo "💡 Remember to update SECRET_KEY and ANTHROPIC_API_KEY in .env file!"
echo ""
echo "✨ Features included:"
echo "   ✓ JWT Authentication with bcrypt"
echo "   ✓ Trading system (buy/sell)"
echo "   ✓ Technical indicators (SMA, EMA, RSI, MACD, Bollinger, Volatility)"
echo "   ✓ AI-powered predictions (Claude API)"
echo "   ✓ Auto-trading configuration"
echo "   ✓ Portfolio management"
echo "   ✓ PostgreSQL with Alembic migrations"
echo "   ✓ Swagger UI with examples"
echo ""