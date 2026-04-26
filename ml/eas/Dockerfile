FROM python:3.10-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=8080

WORKDIR /app

COPY ml/eas/requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt

COPY backend /app/backend
COPY ml/eas /app/ml/eas

EXPOSE 8080

CMD ["gunicorn", "--bind", "0.0.0.0:8080", "ml.eas.app:app"]
