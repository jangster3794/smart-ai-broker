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
