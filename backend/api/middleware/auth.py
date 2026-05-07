"""
JWT authentication middleware.
"""
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel
from typing import Optional
import jwt

from config.settings import settings

security = HTTPBearer(auto_error=False)


class UserContext(BaseModel):
    id: str
    email: Optional[str] = None
    display_name: Optional[str] = None


async def get_current_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security),
) -> UserContext:
    """
    Validate JWT bearer token and return user context.
    In development, accepts any token and returns a mock user.
    """
    if not credentials:
        if settings.DEBUG:
            return UserContext(id="dev_user_001", email="dev@arobjectscanner.com", display_name="Developer")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication required",
            headers={"WWW-Authenticate": "Bearer"},
        )

    token = credentials.credentials
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.JWT_ALGORITHM])
        user_id = payload.get("sub")
        if not user_id:
            raise ValueError("Missing subject")
        return UserContext(
            id=user_id,
            email=payload.get("email"),
            display_name=payload.get("name"),
        )
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token expired")
    except (jwt.InvalidTokenError, ValueError):
        if settings.DEBUG:
            return UserContext(id="dev_user_001", email="dev@arobjectscanner.com")
        raise HTTPException(status_code=401, detail="Invalid token")
