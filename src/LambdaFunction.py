import json 
from aws_lambda_powertools import Logger

logger = Logger()

def lambda_handler(event, context):
    logger.info(f"Received event: {event}")