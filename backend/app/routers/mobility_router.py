import math
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import func
from sqlalchemy.orm import Session

from app import models
from app.auth import get_current_user
from app.database import get_db
from app.schemas import (
    RecommendationOut,
    RouteInsightRequest,
    RouteInsightResponse,
    RouteShareCreate,
    RouteShareOut,
)
from app.services import vehicle_catalog
from app.services.weather_route import fetch_weather_note

router = APIRouter(tags=["mobility"])


def _haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    r = 6371.0
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dl = math.radians(lon2 - lon1)
    a = math.sin(dphi / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * r * math.asin(math.sqrt(a))


@router.post("/route/insights", response_model=RouteInsightResponse)
async def route_insights(
    body: RouteInsightRequest,
    user: models.User = Depends(get_current_user),
):
    _ = user
    lat = body.origin_lat if body.origin_lat is not None else body.dest_lat
    lng = body.origin_lng if body.origin_lng is not None else body.dest_lng
    weather = await fetch_weather_note(lat, lng)
    dist_km = _haversine_km(lat, lng, body.dest_lat, body.dest_lng)
    summary = (
        f"Approximate great-circle distance to destination: {dist_km:.1f} km. "
        "Use this as a planning hint alongside your preferred maps app."
    )
    tip = (
        "If weather is poor or RPM is often high on similar trips, allow extra time and "
        "avoid harsh braking by anticipating traffic earlier."
    )
    return RouteInsightResponse(
        summary=summary,
        weather_note=weather or "Weather API not configured; set OPENWEATHER_API_KEY for live data.",
        driving_tip=tip,
    )


@router.post("/routes/share", response_model=RouteShareOut)
def share_route(
    body: RouteShareCreate,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    row = models.RouteShare(
        user_id=user.user_id,
        label=body.label,
        origin_lat=body.origin_lat,
        origin_lng=body.origin_lng,
        dest_lat=body.dest_lat,
        dest_lng=body.dest_lng,
        depart_window=body.depart_window,
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    return row


@router.get("/routes/matches", response_model=list[RouteShareOut])
def similar_routes(
    origin_lat: float,
    origin_lng: float,
    dest_lat: float,
    dest_lng: float,
    threshold_km: float = 5.0,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    others = db.query(models.RouteShare).filter(models.RouteShare.user_id != user.user_id).all()
    matches: list[models.RouteShare] = []
    for s in others:
        if (
            _haversine_km(origin_lat, origin_lng, s.origin_lat, s.origin_lng) <= threshold_km
            and _haversine_km(dest_lat, dest_lng, s.dest_lat, s.dest_lng) <= threshold_km
        ):
            matches.append(s)
    return matches[:20]


@router.post("/recommendations/generate", response_model=list[RecommendationOut])
def generate_vehicle_recommendations(
    vehicle_id: int,
    commute_km_estimate: float | None = None,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    v = (
        db.query(models.Vehicle)
        .filter(models.Vehicle.vehicle_id == vehicle_id, models.Vehicle.user_id == user.user_id)
        .first()
    )
    if not v:
        raise HTTPException(status_code=404, detail="Vehicle not found")

    avg_speed = db.query(func.avg(models.VehicleData.speed)).filter(
        models.VehicleData.vehicle_id == vehicle_id
    ).scalar()
    avg_speed = float(avg_speed or 0)

    last = (
        db.query(models.DrivingAnalysis)
        .filter(models.DrivingAnalysis.vehicle_id == vehicle_id)
        .order_by(models.DrivingAnalysis.report_date.desc())
        .first()
    )
    hb = last.harsh_braking_events if last else 0
    ha = last.acceleration_events if last else 0

    picks = vehicle_catalog.recommend_for_profile(
        avg_speed=avg_speed,
        harsh_brake=hb,
        harsh_accel=ha,
        commute_km_estimate=commute_km_estimate,
    )
    out: list[models.Recommendation] = []
    for p in picks:
        desc = f"{p['make_model']}: {p['summary']} Reasons: {', '.join(p.get('match_reasons', []))}"
        r = models.Recommendation(
            user_id=user.user_id,
            recommendation_type="vehicle",
            description=desc,
        )
        db.add(r)
        out.append(r)
    db.commit()
    for r in out:
        db.refresh(r)
    return out


@router.get("/recommendations", response_model=list[RecommendationOut])
def list_recommendations(db: Session = Depends(get_db), user: models.User = Depends(get_current_user)):
    return (
        db.query(models.Recommendation)
        .filter(models.Recommendation.user_id == user.user_id)
        .order_by(models.Recommendation.date_generated.desc())
        .limit(50)
        .all()
    )
