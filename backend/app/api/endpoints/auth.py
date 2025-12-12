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
