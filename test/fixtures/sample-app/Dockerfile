FROM python:3.11-slim

WORKDIR /app

# CM-7 PASS: non-root user, minimal image
RUN addgroup --system app && adduser --system --ingroup app app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app/ .

# SC-39 PASS: run as non-root
USER app

EXPOSE 8080

CMD ["python", "main.py"]
