const admin = require('firebase-admin');
const serviceAccount = require('../../serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function updateAppointmentsWithFloorManager() {
  try {
    // Get all appointments
    const appointmentsSnapshot = await db.collection('appointments').get();
    console.log(`Found ${appointmentsSnapshot.size} appointments to process`);
    
    // Get floor manager
    const floorManagersSnapshot = await db.collection('users')
      .where('role', '==', 'floorManager')
      .limit(1)
      .get();
      
    if (floorManagersSnapshot.empty) {
      console.error('No floor manager found in the system');
      return;
    }
    
    const floorManagerDoc = floorManagersSnapshot.docs[0];
    const floorManagerData = {
      floorManagerId: floorManagerDoc.id,
      floorManagerName: `${floorManagerDoc.data().firstName || ''} ${floorManagerDoc.data().lastName || ''}`.trim()
    };
    
    console.log(`Using floor manager: ${floorManagerData.floorManagerName} (${floorManagerData.floorManagerId})`);
    
    // Update each appointment
    const batch = db.batch();
    let batchCount = 0;
    const batchSize = 100; // Firestore batch limit is 500
    
    for (const doc of appointmentsSnapshot.docs) {
      const data = doc.data();
      
      // Only update if floor manager info is missing
      if (!data.floorManagerId || !data.floorManagerName) {
        batch.update(doc.ref, {
          floorManagerId: floorManagerData.floorManagerId,
          floorManagerName: floorManagerData.floorManagerName,
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
        batchCount++;
        
        // Commit batch if we've reached batch size
        if (batchCount % batchSize === 0) {
          console.log(`Committing batch of ${batchCount} updates...`);
          await batch.commit();
          console.log('Batch committed');
        }
      }
    }
    
    // Commit any remaining updates
    if (batchCount % batchSize !== 0) {
      console.log(`Committing final batch of ${batchCount % batchSize} updates...`);
      await batch.commit();
    }
    
    console.log(`Successfully updated ${batchCount} appointments with floor manager information`);
    
  } catch (error) {
    console.error('Error updating appointments:', error);
  } finally {
    process.exit();
  }
}

updateAppointmentsWithFloorManager();
