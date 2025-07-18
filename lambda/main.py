import json
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    # TODO implement

    for record in event["Records"]:
        logger.info(f"{record["Sns"]["Subject"]}: {record["Sns"]["Message"]}")
    
    print("yuh bludclaat eeeediat")

    return {
        'statusCode': 200,
        'body': json.dumps('Hello from Lambda!')
    }
