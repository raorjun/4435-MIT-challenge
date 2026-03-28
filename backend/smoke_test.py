from app import app


def main() -> int:
    with app.test_client() as client:
        health = client.get("/health")
        print("/health", health.status_code, health.get_json())

        vision_missing = client.post("/vision/navigate", data={})
        print("/vision/navigate (missing image)", vision_missing.status_code, vision_missing.get_json())

        venue_missing = client.post("/venue/enter", json={})
        print("/venue/enter (missing lat/lng)", venue_missing.status_code, venue_missing.get_json())

        nav_missing = client.post("/venue/navigate", json={})
        print("/venue/navigate (missing image)", nav_missing.status_code, nav_missing.get_json())

    return 0


if __name__ == "__main__":
    raise SystemExit(main())

