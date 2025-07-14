import os
import sys
import random
import string
import traceback
import logging
from pathlib import Path
from datetime import datetime
from google.cloud import firestore
from google.oauth2 import service_account

# Set up logging to both console and file
log_file = Path('logs/update_appointments.log')
log_file.parent.mkdir(exist_ok=True)  # Create logs directory if it doesn't exist

logging.basicConfig(
    level=logging.DEBUG,  # More verbose logging
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(log_file, mode='w'),  # Overwrite log file each run
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# Log script start
logger.info("=" * 80)
logger.info("STARTING APPOINTMENT REFERENCE NUMBER UPDATE SCRIPT")
logger.info("=" * 80)

# Configuration
SERVICE_ACCOUNT_PATH = 'service-account.json'  # Path to your service account JSON
COLLECTION_NAME = 'appointments'  # Name of your appointments collection
BATCH_SIZE = 10  # Smaller batch size for testing, can be increased later

def generate_reference_number():
    """Generate a 5-character alphanumeric reference number"""
    chars = string.ascii_uppercase + string.digits  # A-Z and 0-9
    return ''.join(random.choices(chars, k=5))

def update_appointments():
    logger.info("=== Starting Appointment Reference Number Update ===")
    logger.info(f"Python version: {sys.version}")
    logger.info(f"Working directory: {os.getcwd()}")
    
    # Verify service account file exists
    if not os.path.exists(SERVICE_ACCOUNT_PATH):
        logger.error(f"Service account file not found at: {os.path.abspath(SERVICE_ACCOUNT_PATH)}")
        logger.info(f"Directory contents: {os.listdir('.')}")
        return

    try:
        # Initialize Firestore client
        logger.info("Initializing Firestore client...")
        creds = service_account.Credentials.from_service_account_file(SERVICE_ACCOUNT_PATH)
        db = firestore.Client(credentials=creds)
        logger.info("Successfully connected to Firestore")
        
        # First, let's test a simple query to verify access
        logger.info("Testing collection access...")
        test_docs = list(db.collection(COLLECTION_NAME).limit(1).stream())
        logger.info(f"Successfully accessed collection. Found {len(test_docs)} test document(s)")
        
        # Create query for all documents, we'll filter in code
        logger.info("Querying all appointments...")
        query = db.collection(COLLECTION_NAME).limit(BATCH_SIZE)
        
        updated_count = 0
        batch = db.batch()
        
        logger.info("Starting to process appointments...")
        
        # Process all documents in batches using pagination
        batch_count = 0
        total_processed = 0
        last_doc = None
        
        while True:
            # Get next batch of documents
            if last_doc:
                docs = query.start_after(last_doc).stream()
            else:
                docs = query.stream()
            
            # Process current batch
            batch_updated = 0
            batch_processed = 0
            
            for doc in docs:
                try:
                    doc_data = doc.to_dict()
                    # Only update if referenceNumber is missing or null
                    if 'referenceNumber' not in doc_data or not doc_data.get('referenceNumber'):
                        ref = db.collection(COLLECTION_NAME).document(doc.id)
                        ref_number = generate_reference_number()
                        batch.update(ref, {
                            'referenceNumber': ref_number,
                            'updatedAt': firestore.SERVER_TIMESTAMP
                        })
                        logger.debug(f"Prepared update for {doc.id} with ref: {ref_number}")
                        batch_count += 1
                        batch_updated += 1
                        updated_count += 1
                        
                        # Commit batch when we reach batch size
                        if batch_count >= BATCH_SIZE:
                            logger.info(f"Committing batch of {batch_count} updates...")
                            batch.commit()
                            logger.info(f"Successfully updated {updated_count} documents so far")
                            batch = db.batch()  # Start a new batch
                            batch_count = 0
                    
                    batch_processed += 1
                    total_processed += 1
                    last_doc = doc  # Save the last document for pagination
                    
                    # Log progress
                    if total_processed % 100 == 0:
                        logger.info(f"Processed {total_processed} documents, updated {updated_count} so far...")
                    
                except Exception as e:
                    logger.error(f"Error processing document {doc.id}: {e}")
                    logger.error(traceback.format_exc())
            
            # Log batch completion
            logger.info(f"Batch complete - Processed: {batch_processed}, Updated: {batch_updated}")
            
            # If we got fewer documents than the batch size, we're done
            if batch_processed < BATCH_SIZE:
                break
        
        # Commit any remaining updates in the final batch
        if batch_count > 0:
            try:
                logger.info(f"Committing final batch of {batch_count} updates...")
                batch.commit()
                logger.info(f"Successfully updated {updated_count} documents in total")
            except Exception as e:
                logger.error(f"Error committing final batch: {e}")
                logger.error(traceback.format_exc())
        
        logger.info(f"=== Update Complete ===")
        logger.info(f"Total appointments updated: {updated_count}")
        
    except Exception as e:
        logger.error(f"Fatal error: {e}")
        logger.error(traceback.format_exc())
        return False
    
    return True

if __name__ == "__main__":
    # Install required packages if not already installed
    try:
        import google.cloud.firestore
    except ImportError:
        logger.info("Installing required packages...")
        os.system("pip install google-cloud-firestore")
    
    success = update_appointments()
    if success:
        print("\n✅ Update completed successfully! Check update_appointments.log for details.")
    else:
        print("\n❌ Update failed. Check update_appointments.log for error details.")
