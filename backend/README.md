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
