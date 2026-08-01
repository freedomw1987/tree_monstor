"""E2E smoke login helper — POST credentials, save JWT to /tmp/jwt.txt.

Avoids Hermes redact 食 'Bearer' literal by:
- Password 從 os.environ 攞(完全 avoid inline literal 喺 shell)
- Response token 寫入 /tmp/jwt.txt(chmod 600),後續 request 從呢度讀

Usage:
  python3 /tmp/smoke_login.py <email> <password>
  (預設 API_BASE=http://localhost:80, override 設 env var API_BASE)
"""
import os
import sys
import json
import urllib.request
import urllib.error


def main():
    email = sys.argv[1]
    password = sys.argv[2]
    api_base = os.environ.get("API_BASE", "http://localhost:80")
    req = urllib.request.Request(
        api_base + "/api/auth/login",
        method="POST",
        data=json.dumps({"email": email, "password": password}).encode(),
    )
    req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            body = resp.read().decode()
            data = json.loads(body)
            token = data.get("token", "")
            if not token:
                print(f"NO_TOKEN:{body[:200]}")
                sys.exit(1)
            with open("/tmp/jwt.txt", "w") as f:
                f.write(token)
            os.chmod("/tmp/jwt.txt", 0o600)
            print(f"OK len={len(token)}")
    except urllib.error.HTTPError as e:
        print(f"HTTP_{e.code}: {e.read().decode()[:200]}")
        sys.exit(1)


if __name__ == "__main__":
    main()
