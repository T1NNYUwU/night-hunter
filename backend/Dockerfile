FROM python:3.12-slim
WORKDIR /srv
COPY --from=ghcr.io/astral-sh/uv:0.9 /uv /usr/local/bin/uv
COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-dev --extra postgres
COPY app ./app
ENV PATH="/srv/.venv/bin:$PATH"
EXPOSE 8000
CMD ["uvicorn", "app.main:create_app", "--factory", "--host", "0.0.0.0", "--port", "8000"]
