# redis_client.py
import redis
import os
from dotenv import load_dotenv

load_dotenv()

redis_client = redis.StrictRedis(host=os.getenv('REDIS_HOST'), port=os.getenv('REDIS_PORT'), decode_responses=True)
