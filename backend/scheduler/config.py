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
