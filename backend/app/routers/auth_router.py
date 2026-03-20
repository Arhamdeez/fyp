from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app import models
from app.auth import create_access_token, get_current_user, hash_password, verify_password
from app.database import get_db
from app.schemas import DemoEstablish, Token, UserCreate, UserLogin, UserOut

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/register", response_model=UserOut)
def register(payload: UserCreate, db: Session = Depends(get_db)):
    if db.query(models.User).filter(models.User.email == payload.email).first():
        raise HTTPException(status_code=400, detail="Email already registered")
    user = models.User(
        name=payload.name,
        email=payload.email,
        password=hash_password(payload.password),
        role="driver",
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


@router.post("/login", response_model=Token)
def login(payload: UserLogin, db: Session = Depends(get_db)):
    user = db.query(models.User).filter(models.User.email == payload.email).first()
    if not user or not verify_password(payload.password, user.password):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials")
    token = create_access_token(subject=user.email)
    return Token(access_token=token)


@router.get("/me", response_model=UserOut)
def me(current: models.User = Depends(get_current_user)):
    return current


@router.post("/demo/establish", response_model=UserOut)
def demo_establish(payload: DemoEstablish, db: Session = Depends(get_db)):
    """Preferred entry for the web demo: register or log in in one call."""
    u = db.query(models.User).filter(models.User.email == payload.email).first()
    if u:
        if not verify_password(payload.password, u.password):
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials")
        if payload.name and payload.name.strip():
            u.name = payload.name.strip()
            db.commit()
            db.refresh(u)
        return u
    if not payload.name or not payload.name.strip():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Name is required when creating a new account",
        )
    u = models.User(
        name=payload.name.strip(),
        email=payload.email,
        password=hash_password(payload.password),
        role="driver",
    )
    db.add(u)
    db.commit()
    db.refresh(u)
    return u
