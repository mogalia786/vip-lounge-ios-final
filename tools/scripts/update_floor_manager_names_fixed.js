const admin = require('firebase-admin');
const serviceAccount = require('../../serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();
const BATCH_SIZE = 100; // Firestore batch limit is 500

async function updateAppointmentsWithFloorManager() {
  try {
    // Get floor manager first
    console.log('Fetching floor manager...');
    const floorManagersSnapshot = await db.collection('users')
      .where('role', '==', 'floorManager')
      .limit(1)
      .get();
      
    if (floorManagersSnapshot.empty) {
      console.error('No floor manager found in the system');
      return;
    }
    
    const floorManagerDoc = floorManagersSnapshot.docs[0];
    const floorManagerDocData = floorManagerDoc.data();
    const floorManagerData = {
      floorManagerId: floorManagerDoc.id,
      floorManagerName: `${floorManagerDocData.firstName || ''} ${floorManagerDocData.lastName || ''}`.trim(),
      floorManagerEmail: floorManagerDocData.email || '',
      floorManagerPhone: floorManagerDocData.phoneNumber || floorManagerDocData.phone || ''
    };
    
    console.log(`Using floor manager: ${floorManagerData.floorManagerName} (${floorManagerData.floorManagerId})`);

    // Get all appointments
    console.log('Fetching appointments...');
    const appointmentsSnapshot = await db.collection('appointments').get();
    console.log(`Found ${appointmentsSnapshot.size} appointments to process`);

    let batch = db.batch();
    let batchCount = 0;
    let updatedCount = 0;

    // Process each appointment
    for (const doc of appointmentsSnapshot.docs) {
      const data = doc.data();
      
      // Only update if floor manager info is missing
      if (!data.floorManagerId || !data.floorManagerName) {
        const updateData = {
          floorManagerId: floorManagerData.floorManagerId,
          floorManagerName: floorManagerData.floorManagerName,
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        };
        
        // Only add email and phone if they exist
        if (floorManagerData.floorManagerEmail) {
          updateData.floorManagerEmail = floorManagerData.floorManagerEmail;
        }
        if (floorManagerData.floorManagerPhone) {
          updateData.floorManagerPhone = floorManagerData.floorManagerPhone;
        }
        
        batch.update(doc.ref, updateData);
        updatedCount++;
        batchCount++;

        // Commit batch if we've reached batch size
        if (batchCount >= BATCH_SIZE) {
          console.log(`Committing batch of ${batchCount} updates...`);
          await batch.commit();
          console.log('Batch committed');
          // Start a new batch
          batch = db.batch();
          batchCount = 0;
        }
      }
    }

    // Commit any remaining updates in the last batch
    if (batchCount > 0) {
      console.log(`Committing final batch of ${batchCount} updates...`);
      await batch.commit();
      console.log('Final batch committed');
    }
    
    console.log(`Successfully updated ${updatedCount} appointments with floor manager information`);

  } catch (error) {
    console.error('Error updating appointments:', error);
  } finally {
    process.exit();
  }
}

updateAppointmentsWithFloorManager();
