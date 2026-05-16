/**
 * Append-only: add report-dashboard Case remarks/status fieldPermissions if missing.
 * Does NOT modify any existing content in permission set files.
 */
const fs = require('fs');
const path = require('path');

const PERM_DIR = path.join(__dirname, '../force-app/main/default/permissionsets');

const FIELD_ORDER = [
  'Case.FEC_Case_Remarks_Entered_By_1__c',
  'Case.FEC_Case_Remarks_Entered_By_2__c',
  'Case.FEC_Case_Remarks_Entered_By_3__c',
  'Case.FEC_Case_Remarks_Entered_By_Role_1__c',
  'Case.FEC_Case_Remarks_Entered_By_Role_2__c',
  'Case.FEC_Case_Remarks_Entered_By_Role_3__c',
  'Case.FEC_Case_Remarks_Entered_On_1__c',
  'Case.FEC_Case_Remarks_Entered_On_2__c',
  'Case.FEC_Case_Remarks_Entered_On_3__c',
  'Case.FEC_Case_Status_History_1__c',
  'Case.FEC_Case_Status_History_2__c',
  'Case.FEC_Case_Status_History_3__c',
];

function block(field) {
  return `    <fieldPermissions>
        <editable>false</editable>
        <field>${field}</field>
        <readable>true</readable>
    </fieldPermissions>`;
}

function appendMissing(filePath) {
  const psName = path.basename(filePath).replace(/\.permissionset-meta\.xml$/, '');
  let content = fs.readFileSync(filePath, 'utf8');
  const marker = '    <hasActivationRequired>';
  if (!content.includes(marker)) {
    throw new Error(`${psName}: missing hasActivationRequired`);
  }

  const toAdd = [];
  for (const field of FIELD_ORDER) {
    if (!content.includes(`<field>${field}</field>`)) {
      toAdd.push(block(field));
    }
  }
  if (toAdd.length === 0) return { psName, added: 0 };

  content = content.replace(marker, toAdd.join('\n') + '\n' + marker);
  fs.writeFileSync(filePath, content, 'utf8');
  return { psName, added: toAdd.length };
}

const files = fs
  .readdirSync(PERM_DIR)
  .filter(
    (f) =>
      (f.includes('Interaction_Case_Service_Case') ||
        f.includes('Interaction_Case_Service_Cas.')) &&
      f.endsWith('.permissionset-meta.xml')
  )
  .map((f) => path.join(PERM_DIR, f));

let total = 0;
for (const f of files.sort()) {
  const r = appendMissing(f);
  if (r.added > 0) {
    console.log(`+${r.added} ${r.psName}`);
    total += r.added;
  }
}
console.log(`Done: ${total} blocks appended across ${files.length} files.`);
