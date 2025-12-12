**Purpose:**
Build a multi-user AI-powered stock trading platform where users can trade 10 stocks using AI predictions based on historical data analysis.

**Core Features:**
- User authentication (register/login) with JWT tokens
- $10,000 starting balance per user (isolated accounts)
- 10 stocks: AAPL, GOOGL, MSFT, TSLA, AMZN, NVDA, META, NFLX, AMD, INTC
- 6 months of historical price data for accurate technical analysis
- AI-powered trading signals using Anthropic Claude
- Auto-trading: Users configure confidence thresholds and trade limits
- Manual trading: Buy/sell interface with real-time validation
- Real-time portfolio tracking with P&L calculations

**Technical Architecture:**
- **Backend:** FastAPI with async SQLAlchemy 2.0, Alembic migrations
- **Database:** PostgreSQL with proper indexes and foreign keys
- **AI Service:** Anthropic Claude API analyzing technical indicators (SMA, EMA, RSI, MACD, Bollinger Bands, Volatility)
- **Scheduler:** APScheduler generating price ticks (every 5s) and executing auto-trades (every 30s)
- **Frontend:** React 18 with Recharts for data visualization, responsive dark-themed UI
- **Deployment:** Docker Compose with 4 services (postgres, backend, scheduler, frontend)

**Timeline:** 
Complete implementation within minimal time frame

**Outcome:**
Production-ready trading platform with authentication, AI-driven decision making, real-time updates, and comprehensive user controls.


























----------------------------------------------------------------------------------------------------------------------------------------------------------------

PROMPT 1:

Generate generate_backend.sh creating FastAPI backend with JWT auth and trading services.

Models: User, Account (user_id FK, cash_balance 10000.0 default), Ticker, PriceTick, Portfolio (user_id FK), Trade (user_id FK, cash_after), AutoTradeConfig (user_id FK, enabled false, confidence_threshold 0.7, max_trade_size 5)

Auth: JWT with PyJWT, bcrypt 4.0.1 (direct, NOT passlib). Endpoints: /api/auth/register, /api/auth/login, /api/auth/me, get_current_user() dependency. Password: 8-72 chars with pydantic validators, truncate to 72 bytes before hashing with bcrypt.hashpw() and bcrypt.checkpw(). JWT: use jwt.encode() and jwt.decode() with HS256.

Services:
	•	indicators.py: SMA(20,50), EMA(12,26), RSI(14), MACD, Bollinger Bands, Volatility
	•	predictions.py: Claude API (https://api.anthropic.com/v1/messages, claude-sonnet-4-20250514), return {action, confidence, reason}, rule-based fallback
	•	trading.py: execute_buy/sell with validation, update_portfolio_prices

API: GET tickers/prices/indicators/signal/portfolio/trades, POST trade, GET/PUT auto-trading/config (protected except auth). Swagger UI with persistAuthorization, examples for all models, summaries/descriptions.

Docker: Alembic migrations (001_initial_schema.py), Dockerfile with migrations, docker-compose.yml with postgres.

Requirements: bcrypt==4.0.1, PyJWT==2.8.0, fastapi==0.104.1, uvicorn[standard]==0.24.0, sqlalchemy==2.0.23, psycopg2-binary==2.9.9, alembic==1.12.1, pydantic==2.5.0, pandas==2.1.3, numpy==1.26.2, anthropic==0.7.8

----------------------------------------------------------------------------------------------------------------------------------------------------------------

Prompt 2: Scheduler
Generate generate_scheduler.sh creating APScheduler service for price simulation and auto-trading.
Initialize: 10 tickers (AAPL $150, GOOGL $140, MSFT $380, TSLA $250, AMZN $180, NVDA $500, META $350, NFLX $450, AMD $120, INTC $45), 6 months historical data (5-min intervals, batch 1000, check if exists first)
Jobs:

Every 5s: Generate price ticks with volatility simulation
Every 30s: Loop users with enabled=true, calculate indicators, get AI signal, execute trades if confidence > threshold, respect max_trade_size

Docker: scheduler Dockerfile (wait 10s, start), requirements.txt (backend deps + apscheduler), update docker-compose.yml

----------------------------------------------------------------------------------------------------------------------------------------------------------------

Prompt 3: Frontend
Generate generate_frontend.sh creating React dashboard with auth and trading UI.
Auth: AuthContext (JWT in localStorage, axios interceptors), LoginForm, RegisterForm, ProtectedRoute
Components: PriceChart (Recharts, 50 points), IndicatorPanel (6 indicators), SignalPanel (action, confidence bar, reason), PortfolioPanel (cash/invested/value/P&L% cards + positions), TradePanel (history table), AutoTradingPanel (toggle, slider 0.5-1.0, input, save), ControlPanel (quantity, buy/sell buttons)
App.js: Routes (/login, /register, / protected), ticker selector, 7-component grid, auto-refresh 5s
Style: Dark theme (#0a0e27), glassmorphism, animations, responsive grid, green/red P&L
Docker: Multi-stage Dockerfile (node build + nginx), nginx.conf (API proxy to backend:8000), package.json (react 18, recharts, axios, react-router-dom), update docker-compose.yml