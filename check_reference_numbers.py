import os
import logging
from pathlib import Path
from google.cloud import firestore
from google.oauth2 import service_account

# Set up logging
log_file = Path('logs/check_reference_numbers.log')
log_file.parent.mkdir(exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(log_file, mode='w'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

def check_reference_numbers():
    logger.info("=== Checking Reference Numbers in Appointments ===")
    
    try:
        # Initialize Firestore
        creds = service_account.Credentials.from_service_account_file('service-account.json')
        db = firestore.Client(credentials=creds)
        
        # Get up to 5 random documents
        logger.info("Fetching sample of appointments...")
        docs = list(db.collection('appointments').limit(5).stream())
        
        if not docs:
            logger.warning("No appointments found in the collection")
            return
            
        logger.info(f"Found {len(docs)} appointments. Checking for reference numbers...")
        
        for doc in docs:
            data = doc.to_dict()
            ref_number = data.get('referenceNumber', 'NOT FOUND')
            logger.info(f"Document ID: {doc.id}")
            logger.info(f"  - Reference Number: {ref_number}")
            logger.info(f"  - Has referenceNumber field: {'referenceNumber' in data}")
            logger.info("-" * 50)
            
    except Exception as e:
        logger.error(f"Error checking reference numbers: {e}")
        import traceback
        logger.error(traceback.format_exc())

if __name__ == "__main__":
    check_reference_numbers()
