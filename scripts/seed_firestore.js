const fs = require('fs');
const path = require('path');

// Read Firebase CLI token
const configPath = path.join(process.env.USERPROFILE, '.config', 'configstore', 'firebase-tools.json');
const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
const token = config.tokens.access_token;
const projectId = 'reya-filling-station-chatrai';
const baseUrl = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents`;

async function patchDoc(docPath, fields) {
  const url = `${baseUrl}/${docPath}`;
  const res = await fetch(url, {
    method: 'PATCH',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({ fields })
  });

  if (!res.ok) {
    const errText = await res.text();
    throw new Error(`Failed to write ${docPath} (${res.status}): ${errText}`);
  }
  console.log(`✅ Written: ${docPath}`);
}

async function seed() {
  console.log('🚀 Starting Authoritative Firestore Seeding for reya-filling-station-chatrai...\n');

  // 1. Station Root Document
  await patchDoc('stations/chatrai', {
    stationName: { stringValue: 'Reya Filling Station' },
    village: { stringValue: 'Chatrai' },
    district: { stringValue: 'Eluru' },
    state: { stringValue: 'Andhra Pradesh' },
    latitude: { doubleValue: 16.5062 },
    longitude: { doubleValue: 80.6480 },
    radiusMeters: { doubleValue: 150.0 },
    updatedAt: { stringValue: new Date().toISOString() }
  });

  // 2. Station Settings (General)
  await patchDoc('stations/chatrai/settings/general', {
    stationName: { stringValue: 'Reya Filling Station (Chatrai)' },
    latitude: { doubleValue: 16.5062 },
    longitude: { doubleValue: 80.6480 },
    radiusMeters: { doubleValue: 150.0 },
    checkLocationBeforeScan: { booleanValue: true },
    allowStaffTotaliserCameraScan: { booleanValue: true },
    defaultLanguage: { stringValue: 'te' },
    latestVersion: { stringValue: '1.0.32' },
    latestBuildNumber: { integerValue: '33' },
    updateUrl: { stringValue: 'https://reya-filling-station-chatrai.web.app/static/reya-filling-station-v1.0.32+33.apk' },
    forceUpdate: { booleanValue: true },
    releaseNotes: { stringValue: 'v1.0.32: Removed duplicate owner top navigation, hamburger drawer and desktop sidebar. Footer is now the main navigation on all devices; More retains Shifts, Credit, Users, Pumps and Settings. Overview section tabs remain available.' },
    deletedEntryIds: {
      arrayValue: {
        values: [
          { stringValue: 'entry_1791680675746' }
        ]
      }
    },
    shiftTimings: {
      mapValue: {
        fields: {
          Morning: { stringValue: '9:00 AM - 9:00 PM' },
          Night: { stringValue: '9:00 PM - 9:00 AM' }
        }
      }
    },
    categories: {
      arrayValue: {
        values: [
          { mapValue: { fields: { id: { stringValue: 'phonePe' }, name: { stringValue: 'PhonePe' }, subtitle: { stringValue: 'Required number: 10 digits' }, enabled: { booleanValue: true }, isDefault: { booleanValue: true } } } },
          { mapValue: { fields: { id: { stringValue: 'cash' }, name: { stringValue: 'Cash' }, subtitle: { stringValue: '' }, enabled: { booleanValue: true }, isDefault: { booleanValue: true } } } },
          { mapValue: { fields: { id: { stringValue: 'card' }, name: { stringValue: 'Card' }, subtitle: { stringValue: '' }, enabled: { booleanValue: true }, isDefault: { booleanValue: true } } } },
          { mapValue: { fields: { id: { stringValue: 'credit' }, name: { stringValue: 'Credit' }, subtitle: { stringValue: '' }, enabled: { booleanValue: true }, isDefault: { booleanValue: true } } } },
          { mapValue: { fields: { id: { stringValue: 'expenses' }, name: { stringValue: 'Expenses' }, subtitle: { stringValue: '' }, enabled: { booleanValue: true }, isDefault: { booleanValue: true } } } },
          { mapValue: { fields: { id: { stringValue: 'salary' }, name: { stringValue: 'Salary' }, subtitle: { stringValue: '' }, enabled: { booleanValue: true }, isDefault: { booleanValue: true } } } },
          { mapValue: { fields: { id: { stringValue: 'cashToOwner' }, name: { stringValue: 'Cash to owner' }, subtitle: { stringValue: '' }, enabled: { booleanValue: true }, isDefault: { booleanValue: true } } } }
        ]
      }
    }
  });

  // 3. Authoritative Members (Kalyan, Ranjit, Abhilash owners; Srinivas shift staff)
  await patchDoc('stations/chatrai/members/owner_kalyan', {
    id: { stringValue: 'owner_kalyan' },
    name: { stringValue: 'Kalyan' },
    email: { stringValue: 'kalyan@rfs.com' },
    phoneNumber: { stringValue: '+91 98480 11111' },
    role: { stringValue: 'owner' },
    assignedShift: { nullValue: null },
    village: { stringValue: 'Chatrai' },
    address: { stringValue: 'Main Road, Chatrai' },
    preferredLanguage: { stringValue: 'en' },
    active: { booleanValue: true },
    isOnline: { booleanValue: false }
  });

  await patchDoc('stations/chatrai/members/owner_ranjit', {
    id: { stringValue: 'owner_ranjit' },
    name: { stringValue: 'Ranjit' },
    email: { stringValue: 'ranjit@rfs.com' },
    phoneNumber: { stringValue: '+91 98480 22222' },
    role: { stringValue: 'owner' },
    assignedShift: { nullValue: null },
    village: { stringValue: 'Chatrai' },
    address: { stringValue: 'Bypass Road, Chatrai' },
    preferredLanguage: { stringValue: 'en' },
    active: { booleanValue: true },
    isOnline: { booleanValue: false }
  });

  await patchDoc('stations/chatrai/members/user_1791651818556', {
    id: { stringValue: 'user_1791651818556' },
    name: { stringValue: 'Abhilash' },
    email: { stringValue: 'abhi@rfs.com' },
    phoneNumber: { stringValue: '9492757943' },
    role: { stringValue: 'owner' },
    assignedShift: { nullValue: null },
    village: { stringValue: 'Chatrai' },
    address: { stringValue: 'Chatrai, Andhra Pradesh' },
    preferredLanguage: { stringValue: 'te' },
    active: { booleanValue: true },
    isOnline: { booleanValue: false }
  });

  await patchDoc('stations/chatrai/members/user_1791642830525', {
    id: { stringValue: 'user_1791642830525' },
    name: { stringValue: 'Srinivas' },
    email: { stringValue: 'srinivas@rfs.com' },
    phoneNumber: { stringValue: '9533677647' },
    role: { stringValue: 'shiftStaff' },
    assignedShift: { stringValue: 'Morning' },
    village: { stringValue: 'Chatrai' },
    address: { stringValue: 'Chatrai, Andhra Pradesh' },
    preferredLanguage: { stringValue: 'te' },
    active: { booleanValue: true },
    isOnline: { booleanValue: false }
  });

  // 4. Dispensers & Pumps
  await patchDoc('stations/chatrai/pumps/pump_1', {
    id: { stringValue: 'pump_1' },
    name: { stringValue: 'Pump 1' },
    serialNumber: { stringValue: '202501001272' },
    nozzles: {
      arrayValue: {
        values: [
          {
            mapValue: {
              fields: {
                id: { stringValue: 'p1_n1' },
                pumpId: { stringValue: 'pump_1' },
                nozzleNumber: { integerValue: '1' },
                fuelType: { stringValue: 'Petrol' },
                ratePaisePerLitre: { integerValue: '11752' },
                currentTotaliserMl: { integerValue: '169923720' },
                previousAcceptedReadingMl: { integerValue: '168676720' }
              }
            }
          },
          {
            mapValue: {
              fields: {
                id: { stringValue: 'p1_n2' },
                pumpId: { stringValue: 'pump_1' },
                nozzleNumber: { integerValue: '2' },
                fuelType: { stringValue: 'Diesel' },
                ratePaisePerLitre: { integerValue: '10521' },
                currentTotaliserMl: { integerValue: '274487190' },
                previousAcceptedReadingMl: { integerValue: '273287210' }
              }
            }
          }
        ]
      }
    }
  });

  await patchDoc('stations/chatrai/pumps/pump_2', {
    id: { stringValue: 'pump_2' },
    name: { stringValue: 'Pump 2' },
    serialNumber: { stringValue: '202501001289' },
    nozzles: {
      arrayValue: {
        values: [
          {
            mapValue: {
              fields: {
                id: { stringValue: 'p2_n1' },
                pumpId: { stringValue: 'pump_2' },
                nozzleNumber: { integerValue: '1' },
                fuelType: { stringValue: 'Petrol' },
                ratePaisePerLitre: { integerValue: '11752' },
                currentTotaliserMl: { integerValue: '84520100' },
                previousAcceptedReadingMl: { integerValue: '84120000' }
              }
            }
          },
          {
            mapValue: {
              fields: {
                id: { stringValue: 'p2_n2' },
                pumpId: { stringValue: 'pump_2' },
                nozzleNumber: { integerValue: '2' },
                fuelType: { stringValue: 'Diesel' },
                ratePaisePerLitre: { integerValue: '10521' },
                currentTotaliserMl: { integerValue: '135400200' },
                previousAcceptedReadingMl: { integerValue: '134800000' }
              }
            }
          }
        ]
      }
    }
  });

  console.log('\n🎉 Successfully seeded all authoritative collections to Firestore:');
  console.log('   - stations/chatrai');
  console.log('   - stations/chatrai/settings/general');
  console.log('   - stations/chatrai/members (Kalyan, Ranjit, Srikanth, Kishore)');
  console.log('   - stations/chatrai/pumps (Pump 1, Pump 2)');
}

seed().catch(err => {
  console.error('\n❌ Seeding error:', err.message);
  process.exit(1);
});
