const fs=require('fs');
const path=require('path');
const crypto=require('crypto');
const assert=require('assert/strict');
const root='D:/reya-filling-station';
const origin='https://reya-filling-station-chatrai.web.app';
const base='https://firestore.googleapis.com/v1/projects/reya-filling-station-chatrai/databases/(default)/documents';
const version=process.argv[3], build=Number(process.argv[4]);
assert(/^\d+\.\d+\.\d+$/.test(version||'') && Number.isInteger(build) && build>0, 'Explicit migration version and build required');
const forceUpdate=process.argv.includes('--force');
const notes=(forceUpdate ? 'Required' : 'Optional')+' migration APK: enables signed silent updates. Future compatible changes download in the background and apply on the next cold launch.';
async function main(){
  const config=JSON.parse(fs.readFileSync(path.join(process.env.USERPROFILE,'.config/configstore/firebase-tools.json'),'utf8'));
  const auth=require('C:/Users/cso/AppData/Roaming/npm/node_modules/firebase-tools/lib/auth.js');
  const tokens=await auth.getAccessToken(config.tokens.refresh_token,config.tokens.scopes||['https://www.googleapis.com/auth/cloud-platform','https://www.googleapis.com/auth/firebase']);
  const headers={Authorization:'Bearer '+tokens.access_token,'Content-Type':'application/json'};
  async function request(doc,method='GET',fields){
    const mask=fields ? '?'+Object.keys(fields).map(k=>'updateMask.fieldPaths='+encodeURIComponent(k)).join('&') : '';
    const res=await fetch(base+'/'+doc+mask,{method,headers,body:fields?JSON.stringify({fields}):undefined});
    if(!res.ok) throw new Error(`${method} ${doc}: HTTP ${res.status}`);
    return res.json();
  }
  const before=await request('stations/chatrai/settings/general');
  const beforeVersion=before.fields.latestVersion?.stringValue;
  const beforeBuild=before.fields.latestBuildNumber?.integerValue;
  console.log(JSON.stringify({cloudVersion:beforeVersion,cloudBuild:beforeBuild,forceUpdate:before.fields.forceUpdate?.booleanValue}));
  if(process.argv[2]!=='--publish') return;
  const recordPath=path.join(process.env.USERPROFILE,'.reya-ota',`base-${version}+${build}.json`);
  const record=JSON.parse(fs.readFileSync(recordPath,'utf8'));
  assert.equal(record.version,version+'+'+build);
  assert.equal(record.certificate_sha256,'ac4a8e9b835d4d1f81c3891fb31c0ef6f24e4c8b14084f5fc9cd8dfe34bcbfe0');
  assert.equal(record.forceUpdate,false);
  assert(Number(beforeBuild)<=build,'Cloud already has a newer build; refusing downgrade');
  const meta=await (await fetch(origin+'/version.json?t='+Date.now())).json();
  assert.equal(meta.version,version);assert.equal(Number(meta.build_number),build);
  const apk=fs.readFileSync(root+'/build/app/outputs/flutter-apk/app-release.apk');
  assert.equal(crypto.createHash('sha256').update(apk).digest('hex'),record.apk_sha256, 'APK differs from identity-verified Shorebird base');
  const url=origin+`/static/reya-filling-station-v${version}+${build}.apk`;
  const download=await fetch(url,{cache:'no-store'});assert(download.ok);
  const published=Buffer.from(await download.arrayBuffer());
  assert.equal(crypto.createHash('sha256').update(published).digest('hex'),crypto.createHash('sha256').update(apk).digest('hex'),'Hosted APK must match the built APK before announcing update');
  const s=v=>({stringValue:v}), n=v=>({integerValue:String(v)});
  const changed={latestVersion:s(version),latestBuildNumber:n(build),updateUrl:s(url),releaseNotes:s(notes),forceUpdate:{booleanValue:forceUpdate}};
  await request('stations/chatrai/settings/general','PATCH',changed);
  const release={id:s(`release_${version}_${build}`),version:s(version),buildNumber:n(build),downloadUrl:s(url),fileName:s(`reya-filling-station-v${version}+${build}.apk`),fileSizeBytes:n(apk.length),publishedBy:s('Release deployment'),publishedAt:s(new Date().toISOString()),releaseNotes:s(notes),active:{booleanValue:true}};
  await request(`stations/chatrai/apkReleases/release_${version}_${build}`,'PATCH',release);
  const after=await request('stations/chatrai/settings/general');
  assert.equal(after.fields.latestVersion.stringValue,version);
  assert.equal(Number(after.fields.latestBuildNumber.integerValue),build);
  for(const key of Object.keys(before.fields)){
    if(!Object.hasOwn(changed,key)) assert.deepEqual(after.fields[key],before.fields[key],`Unexpected change to setting ${key}`);
  }
  assert.equal(after.fields.forceUpdate.booleanValue,forceUpdate);
  console.log(JSON.stringify({forceUpdate,published:version+'+'+build,apkBytes:apk.length,sha256:crypto.createHash('sha256').update(apk).digest('hex'),url,settingsPreserved:true}));
}
main().catch(e=>{console.error(e.message);process.exitCode=1});
