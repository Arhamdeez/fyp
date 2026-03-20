from app.config import settings


async def fetch_weather_note(lat: float, lng: float) -> str | None:
    key = settings.openweather_api_key
    if not key:
        return None
    try:
        import httpx

        url = "https://api.openweathermap.org/data/2.5/weather"
        params = {"lat": lat, "lon": lng, "appid": key, "units": "metric"}
        async with httpx.AsyncClient(timeout=8.0) as client:
            r = await client.get(url, params=params)
            r.raise_for_status()
            data = r.json()
        desc = data.get("weather", [{}])[0].get("description", "conditions")
        temp = data.get("main", {}).get("temp")
        wind = data.get("wind", {}).get("speed")
        parts = [f"{desc}"]
        if temp is not None:
            parts.append(f"~{temp:.0f}°C")
        if wind is not None:
            parts.append(f"wind ~{wind:.1f} m/s")
        return ", ".join(parts)
    except Exception:
        return None
