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
