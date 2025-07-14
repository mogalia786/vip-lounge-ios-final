import os
import sys
import logging
from google.cloud import firestore
from google.oauth2 import service_account

# Set up logging to both console and file
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('firestore_test.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# Log the start of the script
logger.info("=== Starting Firestore Test Script ===")
logger.info(f"Python version: {sys.version}")
logger.info(f"Working directory: {os.getcwd()}")
logger.info(f"Environment variables: {os.environ.get('GOOGLE_APPLICATION_CREDENTIALS', 'Not set')}")

SERVICE_ACCOUNT_PATH = 'service-account.json'
COLLECTION_NAME = 'appointments'

def test_connection():
    try:
        # Verify service account file exists
        if not os.path.exists(SERVICE_ACCOUNT_PATH):
            logger.error(f"Service account file not found at: {os.path.abspath(SERVICE_ACCOUNT_PATH)}")
            logger.info(f"Current working directory: {os.getcwd()}")
            logger.info(f"Directory contents: {os.listdir('.')}")
            return False
        
        # Initialize Firestore client
        logger.info("Initializing Firestore client...")
        creds = service_account.Credentials.from_service_account_file(SERVICE_ACCOUNT_PATH)
        db = firestore.Client(credentials=creds)
        logger.info("Successfully connected to Firestore")
        
        # Test a simple query
        logger.info("Testing a simple query...")
        docs = list(db.collection(COLLECTION_NAME).limit(1).stream())
        logger.info(f"Successfully retrieved {len(docs)} documents")
        
        if docs:
            doc = docs[0]
            logger.info(f"Sample document ID: {doc.id}")
            logger.info(f"Document data: {doc.to_dict()}")
        
        return True
        
    except Exception as e:
        logger.error(f"Error: {e}", exc_info=True)
        return False

if __name__ == "__main__":
    print("=== Firestore Connection Test ===")
    if test_connection():
        print("\n✅ Test completed successfully!")
    else:
        print("\n❌ Test failed. Check the logs above for details.")
