# app.py
import string
import random
from flask import Flask, request, jsonify, redirect
from sqlalchemy import Column, Integer, String,ForeignKey
from db_config import Base, engine, SessionLocal
from redis_client import redis_client
from prometheus_client import Counter, generate_latest
import os
from dotenv import load_dotenv
from sqlalchemy.orm import relationship 

load_dotenv()

app = Flask(__name__)

# Define the User model first
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

# Prometheus metrics
REQUEST_COUNT = Counter('request_count', 'App Request Count', ['endpoint'])

# Helper function to generate a short code
def generate_short_code(length=6):
    characters = string.ascii_letters + string.digits
    return ''.join(random.choice(characters) for _ in range(length))

# Endpoint to create a shortened URL
@app.route('/shorten', methods=['POST'])
def shorten_url():
    REQUEST_COUNT.labels('/shorten').inc()
    data = request.get_json()

    # Validate incoming request data
    original_url = data.get('url')
    user_id = data.get('user_id')
    if not original_url or not user_id:
        return jsonify({'error': 'Missing URL or user_id'}), 400

    session = SessionLocal()
    
    # Check Redis cache for an existing short URL
    cached_url = redis_client.get(original_url)
    if cached_url:
        return jsonify({'short_url': cached_url}), 200

    # Generate a unique short URL
    short_code = generate_short_code()
    new_url = URL(short_url=short_code, original_url=original_url, user_id=user_id)

    try:
        session.add(new_url)
        session.commit()
        redis_client.set(original_url, short_code)  # Cache the short URL
        return jsonify({'short_url': short_code}), 201
    except Exception as e:
        session.rollback()
        return jsonify({'error': str(e)}), 500
    finally:
        session.close()


# Endpoint to redirect to the original URL
@app.route('/<short_code>', methods=['GET'])
def redirect_url(short_code):
    REQUEST_COUNT.labels('/<short_code>').inc()
    session = SessionLocal()

    # Check if the short URL is cached
    cached_url = redis_client.get(short_code)
   # if cached_url:
        #return (cached_url)

    url_entry = session.query(URL).filter(URL.short_url == short_code).first()
    if url_entry:
        redis_client.set(short_code, url_entry.original_url)  # Cache the original URL
        print(url_entry.original_url)
        return ({"original_url":url_entry.original_url})
    else:
        return jsonify({'error': 'URL not found'}), 404

# Prometheus metrics endpoint
@app.route('/metrics')
def metrics():
    return generate_latest()

# Run the Flask app
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=int(os.getenv('APP_PORT')))
