from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    app_name: str = "Momentum API"
    secret_key: str = "change-me-in-production-use-openssl-rand-hex-32"
    algorithm: str = "HS256"
    access_token_expire_minutes: int = 60 * 24 * 7
    database_url: str = "sqlite:///./momentum.db"
    openweather_api_key: str | None = None
    # When True, requests may authenticate via X-Momentum-Demo-Profile (local demo only).
    demo_header_auth: bool = True


settings = Settings()
