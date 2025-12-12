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
