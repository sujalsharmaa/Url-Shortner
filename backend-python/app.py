import string
import random
from flask import Flask, request, jsonify, redirect, Response
from sqlalchemy import Column, Integer, String, ForeignKey
from sqlalchemy.orm import relationship
from db_config import Base, engine, SessionLocal
from redis_client import redis_client
from prometheus_client import Counter, CollectorRegistry, generate_latest, CONTENT_TYPE_LATEST
from prometheus_client.exposition import REGISTRY
from dotenv import load_dotenv
import logging
import os

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

    # Validate incoming request data
    original_url = data.get('url')
    user_id = data.get('user_id')
    if not original_url or not user_id:
        return handle_error('Missing URL or user_id', status=400)

    session = SessionLocal()
    
    # Check Redis cache for an existing short URL
    cached_url = redis_client.get(original_url)
    if cached_url:
        logging.info(f"Cache hit for URL: {original_url}")
        return jsonify({'short_url': cached_url.decode()}), 200

    # Generate a unique short URL
    short_code = generate_short_code()
    new_url = URL(short_url=short_code, original_url=original_url, user_id=user_id)

    try:
        session.add(new_url)
        session.commit()
        redis_client.set(original_url, short_code)  # Cache the short URL
        logging.info(f"Short URL created: {short_code} for original URL: {original_url}")
        return jsonify({'short_url': short_code}), 201
    except Exception as e:
        session.rollback()
        return handle_error('Error creating short URL', error=e)
    finally:
        session.close()
 
# Endpoint to redirect to the original URL
@app.route('/', methods=['GET'])
def main():
    return jsonify({'message': 'hello python backend works'}), 200

@app.route('/<short_code>', methods=['GET'])
def redirect_url(short_code):
    REQUEST_COUNT.labels('/<short_code>', request.method).inc()
    session = SessionLocal()

    try:
        # Check if the short URL is cached
        cached_url = redis_client.get(short_code)
        if cached_url:
            logging.info(f"Cache hit for short code: {short_code}")
            return jsonify({'original_url': cached_url.decode()}), 200

        # Query the database if not in cache
        url_entry = session.query(URL).filter(URL.short_url == short_code).first()
        if url_entry:
            redis_client.set(short_code, url_entry.original_url)  # Cache the original URL
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
    # Serve Prometheus metrics on the '/metrics' route
    return Response(generate_latest(REGISTRY), content_type=CONTENT_TYPE_LATEST)

# Run the Flask app
if __name__ == '__main__':
    app_port = int(os.getenv('APP_PORT', 5000))
    app.run(host='0.0.0.0', port=app_port)
