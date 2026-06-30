FROM python:3.12-slim

WORKDIR /app

RUN pip install --no-cache-dir openziti

COPY entrypoint.py ./
COPY echo/ ./echo/
COPY http/ ./http/

ENV ZITI_IDENTITY=/ziti/id.json \
    SELF_LANG=py \
    PYTHONUNBUFFERED=1

# APP (echo|http) and ROLE (server|client) are passed as args.
ENTRYPOINT ["python", "entrypoint.py"]
