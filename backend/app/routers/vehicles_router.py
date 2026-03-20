from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app import models
from app.auth import get_current_user
from app.database import get_db
from app.schemas import (
    DrivingAnalysisOut,
    VehicleCreate,
    VehicleDataIn,
    VehicleDataOut,
    VehicleOut,
)
from app.services.driving_analysis import analyze_samples

router = APIRouter(prefix="/vehicles", tags=["vehicles"])


def _vehicle_for_user(db: Session, user: models.User, vehicle_id: int) -> models.Vehicle:
    v = (
        db.query(models.Vehicle)
        .filter(models.Vehicle.vehicle_id == vehicle_id, models.Vehicle.user_id == user.user_id)
        .first()
    )
    if not v:
        raise HTTPException(status_code=404, detail="Vehicle not found")
    return v


@router.post("", response_model=VehicleOut)
def create_vehicle(
    payload: VehicleCreate,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    v = models.Vehicle(
        user_id=user.user_id,
        vehicle_model=payload.vehicle_model,
        vehicle_type=payload.vehicle_type,
        year=payload.year,
    )
    db.add(v)
    db.commit()
    db.refresh(v)
    return v


@router.get("", response_model=list[VehicleOut])
def list_vehicles(db: Session = Depends(get_db), user: models.User = Depends(get_current_user)):
    return db.query(models.Vehicle).filter(models.Vehicle.user_id == user.user_id).all()


@router.post("/{vehicle_id}/data", response_model=VehicleDataOut)
def ingest_data(
    vehicle_id: int,
    payload: VehicleDataIn,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    _vehicle_for_user(db, user, vehicle_id)
    row = models.VehicleData(
        vehicle_id=vehicle_id,
        speed=payload.speed,
        rpm=payload.rpm,
        fuel_consumption=payload.fuel_consumption,
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    return row


@router.get("/{vehicle_id}/data", response_model=list[VehicleDataOut])
def list_data(
    vehicle_id: int,
    limit: int = 200,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    _vehicle_for_user(db, user, vehicle_id)
    q = (
        db.query(models.VehicleData)
        .filter(models.VehicleData.vehicle_id == vehicle_id)
        .order_by(models.VehicleData.timestamp.desc())
        .limit(min(limit, 2000))
    )
    return list(reversed(q.all()))


@router.post("/{vehicle_id}/analyze", response_model=DrivingAnalysisOut)
def run_analysis(
    vehicle_id: int,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    _vehicle_for_user(db, user, vehicle_id)
    samples = (
        db.query(models.VehicleData)
        .filter(models.VehicleData.vehicle_id == vehicle_id)
        .order_by(models.VehicleData.timestamp.asc())
        .limit(5000)
        .all()
    )
    if len(samples) < 2:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Need at least two OBD samples to analyze driving behavior.",
        )
    score, hb, ha = analyze_samples(samples)
    report = models.DrivingAnalysis(
        vehicle_id=vehicle_id,
        driving_score=score,
        harsh_braking_events=hb,
        acceleration_events=ha,
    )
    db.add(report)
    db.commit()
    db.refresh(report)
    return report


@router.get("/{vehicle_id}/analysis", response_model=list[DrivingAnalysisOut])
def list_analysis(
    vehicle_id: int,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    _vehicle_for_user(db, user, vehicle_id)
    return (
        db.query(models.DrivingAnalysis)
        .filter(models.DrivingAnalysis.vehicle_id == vehicle_id)
        .order_by(models.DrivingAnalysis.report_date.desc())
        .limit(50)
        .all()
    )
