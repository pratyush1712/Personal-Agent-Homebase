FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

# Build Mem0 API from local source instead of depending on the upstream image,
# which does not always publish linux/amd64 manifests.
RUN pip install --upgrade pip && pip install \
    "fastapi==0.115.8" \
    "uvicorn==0.34.0" \
    "python-dotenv==1.0.1" \
    "pydantic==2.10.4" \
    "mem0ai>=0.1.48" \
    "openai>=1.52.0,<2.0.0" \
    "qdrant-client>=1.11.1,<2.0.0" \
    "psycopg[binary,pool]>=3.2.8,<4.0.0" \
    "rank-bm25>=0.2.2,<1.0.0"

COPY main.py /app/main.py

EXPOSE 8000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]