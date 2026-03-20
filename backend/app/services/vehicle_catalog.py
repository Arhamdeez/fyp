"""Static vehicle attributes for prototype recommendations (dataset-driven in production)."""

VEHICLE_CATALOG = [
    {
        "make_model": "Toyota Corolla",
        "tags": ["reliable", "fuel_efficient", "commuter"],
        "summary": "Strong daily commuter; low maintenance reputation.",
    },
    {
        "make_model": "Honda Civic",
        "tags": ["reliable", "fuel_efficient", "sporty"],
        "summary": "Balanced efficiency with a slightly sportier feel.",
    },
    {
        "make_model": "Suzuki Swift",
        "tags": ["compact", "fuel_efficient", "city"],
        "summary": "Good for dense city traffic and short commutes.",
    },
    {
        "make_model": "Hyundai Tucson",
        "tags": ["suv", "family", "comfort"],
        "summary": "Higher ride height; suits varied weather and luggage.",
    },
    {
        "make_model": "Mazda CX-5",
        "tags": ["suv", "handling", "commuter"],
        "summary": "More engaging drive for mixed highway and city use.",
    },
]


def recommend_for_profile(
    *,
    avg_speed: float,
    harsh_brake: int,
    harsh_accel: int,
    commute_km_estimate: float | None,
) -> list[dict]:
    picks: list[dict] = []
    aggressive = harsh_brake + harsh_accel > 5
    long_commute = (commute_km_estimate or 0) > 25

    for v in VEHICLE_CATALOG:
        score = 0
        reasons: list[str] = []
        tags = set(v["tags"])
        if long_commute and "fuel_efficient" in tags:
            score += 2
            reasons.append("matches longer commute / efficiency")
        if avg_speed > 70 and "suv" in tags:
            score += 1
            reasons.append("highway-biased usage")
        if avg_speed < 40 and "city" in tags:
            score += 2
            reasons.append("city-oriented driving speeds")
        if aggressive and "reliable" in tags:
            score += 1
            reasons.append("prioritizes durability under hard use")
        if score > 0:
            picks.append({**v, "match_reasons": reasons, "_score": score})

    picks.sort(key=lambda x: x["_score"], reverse=True)
    for p in picks:
        p.pop("_score", None)
    return picks[:3] or [VEHICLE_CATALOG[0]]
