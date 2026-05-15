/**
 * Append-only: add report-dashboard fieldPermissions if missing.
 * Does NOT modify any existing content in permission set files.
 */
const fs = require('fs');
const path = require('path');

const PERM_DIR = path.join(__dirname, '../force-app/main/default/permissionsets');

const FIELD_ORDER = [
  'Case.FEC_Original_Category__c',
  'Case.FEC_Original_Sub_Category__c',
  'Case.FEC_Original_Sub_Code__c',
  'Case.FEC_Case_Remarks_1__c',
  'Case.FEC_Case_Remarks_2__c',
  'Case.FEC_Case_Remarks_3__c',
  'FEC_Routing_Action_History__c.FEC_Assigned_On__c',
  'FEC_Routing_Action_History__c.FEC_TAT_by_Assignment__c',
  'Case.FEC_TAT_Full_Process__c',
];

function editableFor(psName, field) {
  const isRdIt = psName === 'RD_IT_User_Interaction_Case_Service_Case';
  if (isRdIt) return true;
  if (
    field.startsWith('Case.FEC_Original_') ||
    field === 'Case.FEC_Original_Sub_Code__c'
  ) {
    return true;
  }
  return false;
}

function block(field, editable) {
  return `    <fieldPermissions>
        <editable>${editable}</editable>
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
      toAdd.push(block(field, editableFor(psName, field)));
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
