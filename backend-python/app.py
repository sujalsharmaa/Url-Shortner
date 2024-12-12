import os
import string
import random
import time
import logging
from functools import partial
from flask import Flask, request, jsonify, redirect, Response
from sqlalchemy import Column, Integer, String, ForeignKey
from sqlalchemy.orm import relationship
from db_config import Base, engine, SessionLocal
from redis_client import redis_client
from prometheus_client import Counter, CollectorRegistry, generate_latest, CONTENT_TYPE_LATEST
from prometheus_client.exposition import REGISTRY
from datadog import initialize, statsd
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Initialize Flask app
app = Flask(__name__)

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[logging.StreamHandler(), logging.FileHandler("url_shortener.log")]
)

# Prometheus metrics registry
REQUEST_COUNT = Counter('request_count', 'App Request Count', ['endpoint', 'method'])

# StatsD configuration
STATSD_HOST = os.getenv("STATSD_HOST", "localhost")
STATSD_PORT = int(os.getenv("STATSD_PORT", 8125))

statsd_options = {
    "statsd_host": STATSD_HOST,
    "statsd_port": STATSD_PORT
}
initialize(**statsd_options)


class StatsdMiddleware:
    def __init__(self, application, app_name):
        self.__application = application
        self.__app_name = app_name

        # send service info with tags
        statsd.gauge("flask.info", 1, tags=[f"app_name:{self.__app_name}"])

    def __call__(self, environ, start_response):
        patch_info = {
            "app_name": self.__app_name, 
            "method": environ['REQUEST_METHOD'],
            "endpoint": environ['PATH_INFO']
        }

        def _start_response(status, headers, *args, **kwargs):
            # log http status code when each response start
            statsd.increment(
                "flask.request_status_total",
                tags=[
                    f"app_name:{kwargs.get('app_name', '')}",
                    f"method:{kwargs.get('method', '')}",
                    f"endpoint:{kwargs.get('endpoint', '')}",
                    f"status:{status.split()[0]}",
                ]
            )
            return start_response(status, headers, *args)

        # timing each request
        with statsd.timed(
            "flask.request_duration_seconds",
            tags=[
                f"app_name:{patch_info.get('app_name', '')}",
                f"method:{patch_info.get('method', '')}",
                f"endpoint:{patch_info.get('endpoint', '')}",
            ],
            use_ms=True
        ):
            return self.__application(environ, partial(_start_response, **patch_info))


# Add StatsD Middleware
app.wsgi_app = StatsdMiddleware(app.wsgi_app, "flask-url-shortener")


# Define the User model
class User(Base):
    __tablename__ = 'users'
    id = Column(Integer, primary_key=True)
    urls = relationship("URL", back_populates="user")  # Link to URL model


# Define the URL model
class URL(Base):
    __tablename__ = 'urls'
    id = Column(Integer, primary_key=True, index=True)
    short_url = Column(String, unique=True, index=True)
    original_url = Column(String, nullable=False)
    user_id = Column(Integer, ForeignKey('users.id'), nullable=False)

    # Relationship for SQLAlchemy ORM
    user = relationship("User", back_populates="urls")


# Initialize the database
Base.metadata.create_all(bind=engine)


# Helper function to generate a short code
def generate_short_code(length=6):
    characters = string.ascii_letters + string.digits
    return ''.join(random.choice(characters) for _ in range(length))


# Error handling utility
def handle_error(message, error=None, status=500):
    if error:
        logging.error(f"{message}: {error}")
    else:
        logging.error(message)
    return jsonify({'error': message}), status


# Endpoint to create a shortened URL
@app.route('/shorten', methods=['POST'])
def shorten_url():
    REQUEST_COUNT.labels('/shorten', request.method).inc()
    data = request.get_json()

    original_url = data.get('url')
    user_id = data.get('user_id')
    if not original_url or not user_id:
        return handle_error('Missing URL or user_id', status=400)

    session = SessionLocal()
    cached_url = redis_client.get(original_url)
    if cached_url:
        logging.info(f"Cache hit for URL: {original_url}")
        return jsonify({'short_url': cached_url.decode()}), 200

    short_code = generate_short_code()
    new_url = URL(short_url=short_code, original_url=original_url, user_id=user_id)

    try:
        session.add(new_url)
        session.commit()
        redis_client.set(original_url, short_code)
        logging.info(f"Short URL created: {short_code} for original URL: {original_url}")
        return jsonify({'short_url': short_code}), 201
    except Exception as e:
        session.rollback()
        return handle_error('Error creating short URL', error=e)
    finally:
        session.close()


# Endpoint to redirect to the original URL
@app.route('/<short_code>', methods=['GET'])
def redirect_url(short_code):
    REQUEST_COUNT.labels('/<short_code>', request.method).inc()
    session = SessionLocal()

    try:
        cached_url = redis_client.get(short_code)
        if cached_url:
            logging.info(f"Cache hit for short code: {short_code}")
            return jsonify({'original_url': cached_url.decode()}), 200

        url_entry = session.query(URL).filter(URL.short_url == short_code).first()
        if url_entry:
            redis_client.set(short_code, url_entry.original_url)
            logging.info(f"Short code {short_code} resolved to URL: {url_entry.original_url}")
            return jsonify({'original_url': url_entry.original_url}), 200
        else:
            logging.warning(f"Short code not found: {short_code}")
            return handle_error('URL not found', status=404)
    except Exception as e:
        return handle_error('Error resolving short URL', error=e)
    finally:
        session.close()


# Prometheus metrics endpoint
@app.route('/metrics', methods=['GET'])
def metrics():
    REQUEST_COUNT.labels('/metrics', request.method).inc()
    return Response(generate_latest(REGISTRY), content_type=CONTENT_TYPE_LATEST)


# Run the Flask app
if __name__ == '__main__':
    app_port = int(os.getenv('APP_PORT', 5000))
    app.run(host='0.0.0.0', port=app_port)
