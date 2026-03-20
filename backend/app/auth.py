import base64
import json
from datetime import datetime, timedelta, timezone

from fastapi import Depends, Header, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError, jwt
from passlib.context import CryptContext
from sqlalchemy.orm import Session

from app.config import settings
from app.database import get_db
from app import models
from app.schemas import TokenData

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
http_bearer = HTTPBearer(auto_error=False)


def hash_password(password: str) -> str:
    return pwd_context.hash(password)


def verify_password(plain: str, hashed: str) -> bool:
    return pwd_context.verify(plain, hashed)


def create_access_token(subject: str) -> str:
    expire = datetime.now(timezone.utc) + timedelta(minutes=settings.access_token_expire_minutes)
    return jwt.encode(
        {"sub": subject, "exp": expire},
        settings.secret_key,
        algorithm=settings.algorithm,
    )


def _b64url_decode(segment: str) -> bytes:
    padded = segment + "=" * (-len(segment) % 4)
    return base64.urlsafe_b64decode(padded.encode("ascii"))


def _user_from_demo_header(db: Session, header_val: str) -> models.User | None:
    """Resolve an existing user created via POST /auth/demo/establish (demo browser session)."""
    if not settings.demo_header_auth or not header_val.strip():
        return None
    try:
        raw = json.loads(_b64url_decode(header_val.strip()).decode("utf-8"))
    except (json.JSONDecodeError, UnicodeDecodeError, ValueError):
        return None
    if not isinstance(raw, dict):
        return None
    name = raw.get("name")
    email = raw.get("email")
    if not isinstance(name, str) or not isinstance(email, str):
        return None
    name, email = name.strip(), email.strip()
    if not name or not email:
        return None
    user = db.query(models.User).filter(models.User.email == email).first()
    if user is None:
        return None
    if user.name != name:
        user.name = name
        db.commit()
        db.refresh(user)
    return user


def get_current_user(
    creds: HTTPAuthorizationCredentials | None = Depends(http_bearer),
    db: Session = Depends(get_db),
    x_momentum_demo_profile: str | None = Header(None, alias="X-Momentum-Demo-Profile"),
) -> models.User:
    credentials_exc = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    token = creds.credentials if creds else None
    if token:
        try:
            payload = jwt.decode(token, settings.secret_key, algorithms=[settings.algorithm])
            sub = payload.get("sub")
            if sub is None:
                raise JWTError()
            token_data = TokenData(email=sub)
            user = db.query(models.User).filter(models.User.email == token_data.email).first()
            if user is not None:
                return user
        except JWTError:
            pass
    demo_user = _user_from_demo_header(db, x_momentum_demo_profile or "")
    if demo_user is not None:
        return demo_user
    raise credentials_exc
