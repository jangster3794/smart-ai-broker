# AI-Powered Trading Platform

Full-stack trading platform with FastAPI backend, React dashboard, automated price simulation, and AI-powered trading signals using Claude API.

## 🚀 Quick Start

### Generate & Run
```bash
# 1. Generate all components - SKIP, this is already pushed
# ./generate_backend.sh
# ./generate_scheduler.sh
# ./generate_frontend.sh

# 2. Configure
cd backend
nano .env  # Update SECRET_KEY and ANTHROPIC_API_KEY

# 3. Start everything
docker-compose up --build
```

### Access
- **Frontend**: http://localhost:3000
- **Backend API**: http://localhost:8000
- **Swagger Docs**: http://localhost:8000/docs

## ✨ Features

### Backend (FastAPI)
- JWT authentication with bcrypt (8-72 char passwords)
- Buy/sell trading with portfolio management
- Technical indicators: SMA, EMA, RSI, MACD, Bollinger Bands, Volatility
- AI signals via Claude API with rule-based fallback
- Auto-trading configuration per user

### Scheduler (APScheduler)
- Price simulation every 5 seconds with realistic volatility
- Auto-trading every 30 seconds for enabled users
- 10 tickers: AAPL, GOOGL, MSFT, TSLA, AMZN, NVDA, META, NFLX, AMD, INTC
- 6 months historical data (5-min intervals, ~51K points/ticker)

### Frontend (React)
- 7-component dashboard: Chart, Indicators, Signal, Portfolio, Trades, Auto-Trading, Control
- Dark theme (#0a0e27) with glassmorphism
- Auto-refresh every 5 seconds
- JWT auth with protected routes
- Green/red P&L indicators

## 📊 Database Models

- **User** - Email, username, hashed password
- **Account** - Cash balance (default: $10,000)
- **Ticker** - Stock symbols and names
- **PriceTick** - Historical prices with volume
- **Portfolio** - User holdings with avg_price
- **Trade** - Buy/sell history with cash_after
- **AutoTradeConfig** - enabled, confidence_threshold (0.7), max_trade_size (5)

## 🔌 API Endpoints

```
POST   /api/auth/register              # Register user
POST   /api/auth/login                 # Get JWT token
GET    /api/auth/me                    # Current user (protected)

GET    /api/tickers                    # List tickers
GET    /api/tickers/{symbol}/prices    # Price history
GET    /api/tickers/{symbol}/indicators # Technical indicators
GET    /api/tickers/{symbol}/signal    # AI trading signal

GET    /api/account                    # Account details (protected)
GET    /api/portfolio                  # Holdings (protected)
POST   /api/trade                      # Execute trade (protected)
GET    /api/trades                     # Trade history (protected)

GET    /api/auto-trading/config        # Get config (protected)
PUT    /api/auto-trading/config        # Update config (protected)
```

## 🎯 Usage Example

```bash
# 1. Register
curl -X POST http://localhost:8000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"trader@example.com","username":"trader1","password":"SecurePass123!"}'

# 2. Login (get token)
curl -X POST http://localhost:8000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"trader1","password":"SecurePass123!"}'

# 3. Execute trade
curl -X POST http://localhost:8000/api/trade \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"ticker_symbol":"AAPL","action":"BUY","quantity":10}'

# 4. Enable auto-trading
curl -X PUT http://localhost:8000/api/auto-trading/config \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"enabled":true,"confidence_threshold":0.75,"max_trade_size":10}'
```

## 🐳 Docker Commands

```bash
docker-compose up --build           # Start all services
docker-compose up -d --build        # Start in background
docker-compose logs -f              # View all logs
docker-compose logs -f scheduler    # View scheduler logs
docker-compose down                 # Stop services
docker-compose down -v              # Stop and remove volumes
```

## 🔧 Configuration

### Backend (.env)
```env
DATABASE_URL=postgresql://trading_user:trading_pass@postgres:5432/trading_db
SECRET_KEY=your-secret-key-min-32-characters
ANTHROPIC_API_KEY=sk-ant-api03-...  # Optional
```

### Scheduler (scheduler/config.py)
```python
PRICE_UPDATE_INTERVAL_SECONDS = 5   # Price updates
AUTO_TRADE_INTERVAL_SECONDS = 30    # Auto-trading
BASE_VOLATILITY = 0.02              # 2% volatility
```

## 🧠 AI Trading Signals

Claude API analyzes indicators and returns:
```json
{
  "action": "BUY|SELL|HOLD",
  "confidence": 0.85,
  "reason": "Strong bullish momentum with RSI at 65..."
}
```

**Fallback rules** (when API unavailable):
- RSI < 30 → BUY (oversold)
- RSI > 70 → SELL (overbought)
- MACD positive → BUY
- SMA(20) > SMA(50) → BUY

## 🔍 Troubleshooting

```bash
# Database not ready
docker-compose down -v && docker-compose up --build

# Check scheduler activity
docker-compose logs scheduler | grep "Generated price ticks"

# Check backend health
curl http://localhost:8000/health

# Reset everything
docker-compose down -v
docker volume prune -f
docker-compose up --build
```

## 📁 Project Structure

```
backend/
├── app/
│   ├── api/endpoints/      # Auth, trading, portfolio routes
│   ├── core/              # Config, database, security
│   ├── models/            # SQLAlchemy models & Pydantic schemas
│   ├── services/          # Indicators, predictions, trading
│   └── main.py            # FastAPI app
├── scheduler/
│   ├── main.py            # APScheduler entry point
│   ├── price_simulator.py # Price generation
│   └── auto_trader.py     # Auto-trading logic
└── docker-compose.yml     # Full stack orchestration

frontend/
├── src/
│   ├── components/        # 7 dashboard components
│   ├── contexts/          # AuthContext with JWT
│   ├── pages/             # Login, Register, Dashboard
│   ├── utils/             # Axios with interceptors
│   └── App.js             # Routes
├── nginx/nginx.conf       # API proxy
└── Dockerfile             # Multi-stage build
```

## 🔒 Security

- **Passwords**: 8-72 chars, bcrypt hashed
- **JWT**: HS256, configurable expiration
- **Environment**: All secrets in .env
- **Production**: Use HTTPS, strong SECRET_KEY, enable CORS restrictions

## 📦 Tech Stack

**Backend**: FastAPI, SQLAlchemy, PostgreSQL, Alembic, bcrypt, PyJWT, Pandas, Anthropic SDK  
**Scheduler**: APScheduler  
**Frontend**: React 18, React Router, Axios, Recharts, Nginx

## 📝 License

MIT License

---

**Built with FastAPI, React, and Claude AI** 🚀