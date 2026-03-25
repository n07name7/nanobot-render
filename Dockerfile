FROM python:3.12-slim

# Install uv
RUN pip install uv --no-cache-dir

# Install nanobot-ai
RUN uv pip install --system --no-cache nanobot-ai

# Copy startup script
COPY start.sh /start.sh
RUN chmod +x /start.sh

# Create config dir
RUN mkdir -p /root/.nanobot

EXPOSE 10000

CMD ["/start.sh"]
