const admin = require('firebase-admin');
const serviceAccount = require('./service-account.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

async function cleanupRatings() {
  const db = admin.firestore();
  const ratingsRef = db.collection('ratings');
  let deletedCount = 0;
  const BATCH_SIZE = 250; // Stay well under 500 operations per batch
  let batch = db.batch();
  let batchCount = 0;

  console.log('Fetching ratings...');
  const snapshot = await ratingsRef.get();
  const totalRatings = snapshot.size;
  console.log(`Found ${totalRatings} total ratings to check...`);

  for (const doc of snapshot.docs) {
    const data = doc.data();
    if (!data.appointmentId) {
      console.log(`[DELETE] Rating ID: ${doc.id} - Missing appointmentId`);
      batch.delete(doc.ref);
      deletedCount++;
      batchCount++;

      // Commit batch when we reach BATCH_SIZE
      if (batchCount >= BATCH_SIZE) {
        console.log(`Committing batch of ${batchCount} deletes...`);
        await batch.commit();
        batch = db.batch(); // Start a new batch
        batchCount = 0;
      }
    }
  }

  // Commit any remaining operations in the last batch
  if (batchCount > 0) {
    console.log(`Committing final batch of ${batchCount} deletes...`);
    await batch.commit();
  }
  
  console.log('\nCleanup complete!');
  console.log(`Total ratings checked: ${totalRatings}`);
  console.log(`Total ratings deleted: ${deletedCount}`);
  process.exit(0);
}

cleanupRatings().catch(error => {
  console.error('Error during cleanup:', error);
  process.exit(1);
});
