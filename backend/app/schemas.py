from datetime import datetime

from pydantic import BaseModel, EmailStr, Field


class UserCreate(BaseModel):
    name: str = Field(min_length=1, max_length=255)
    email: EmailStr
    password: str = Field(min_length=6, max_length=128)


class UserLogin(BaseModel):
    email: EmailStr
    password: str


class DemoEstablish(BaseModel):
    """One-step demo sign-in: create account or verify password for existing user."""

    email: EmailStr
    password: str = Field(min_length=6, max_length=128)
    name: str | None = Field(None, max_length=255)


class UserOut(BaseModel):
    user_id: int
    name: str
    email: str
    role: str

    model_config = {"from_attributes": True}


class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"


class TokenData(BaseModel):
    email: str | None = None


class VehicleCreate(BaseModel):
    vehicle_model: str
    vehicle_type: str
    year: int | None = None


class VehicleOut(BaseModel):
    vehicle_id: int
    user_id: int
    vehicle_model: str
    vehicle_type: str
    year: int | None

    model_config = {"from_attributes": True}


class VehicleDataIn(BaseModel):
    speed: float
    rpm: float
    fuel_consumption: float | None = None


class VehicleDataOut(BaseModel):
    data_id: int
    vehicle_id: int
    speed: float
    rpm: float
    fuel_consumption: float | None
    timestamp: datetime

    model_config = {"from_attributes": True}


class DrivingAnalysisOut(BaseModel):
    analysis_id: int
    vehicle_id: int
    driving_score: int
    harsh_braking_events: int
    acceleration_events: int
    report_date: datetime

    model_config = {"from_attributes": True}


class RecommendationOut(BaseModel):
    recommendation_id: int
    user_id: int
    recommendation_type: str
    description: str
    date_generated: datetime

    model_config = {"from_attributes": True}


class RouteInsightRequest(BaseModel):
    dest_lat: float
    dest_lng: float
    origin_lat: float | None = None
    origin_lng: float | None = None


class RouteInsightResponse(BaseModel):
    summary: str
    weather_note: str | None = None
    driving_tip: str


class RouteShareCreate(BaseModel):
    label: str | None = None
    origin_lat: float
    origin_lng: float
    dest_lat: float
    dest_lng: float
    depart_window: str | None = None


class RouteShareOut(BaseModel):
    share_id: int
    user_id: int
    label: str | None
    origin_lat: float
    origin_lng: float
    dest_lat: float
    dest_lng: float
    depart_window: str | None
    created_at: datetime

    model_config = {"from_attributes": True}
