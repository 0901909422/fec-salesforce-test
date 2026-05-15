/**
 * Sync field permissions from SB03 (sb03_field_perms.json) into Interaction Case permission sets.
 * Appends new fieldPermissions blocks before <hasActivationRequired>, preserving existing entries.
 */
const fs = require('fs');
const path = require('path');

const PERM_DIR = path.join(
  __dirname,
  '../force-app/main/default/permissionsets'
);
const SB03 = require(path.join(__dirname, '../sb03_field_perms.json'));

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

const DEFAULTS = {
  'Case.FEC_Original_Category__c': { read: true, edit: true },
  'Case.FEC_Original_Sub_Category__c': { read: true, edit: true },
  'Case.FEC_Original_Sub_Code__c': { read: true, edit: true },
  'Case.FEC_Case_Remarks_1__c': { read: true, edit: false },
  'Case.FEC_Case_Remarks_2__c': { read: true, edit: false },
  'Case.FEC_Case_Remarks_3__c': { read: true, edit: false },
  'FEC_Routing_Action_History__c.FEC_Assigned_On__c': { read: true, edit: false },
  'FEC_Routing_Action_History__c.FEC_TAT_by_Assignment__c': { read: true, edit: false },
  'Case.FEC_TAT_Full_Process__c': { read: true, edit: false },
};

function buildOrgMap() {
  const map = {};
  for (const r of SB03.records) {
    map[r.Parent.Name] = map[r.Parent.Name] || {};
    map[r.Parent.Name][r.Field] = {
      read: r.PermissionsRead,
      edit: r.PermissionsEdit,
    };
  }
  return map;
}

function permSetNameFromFile(filename) {
  return filename.replace(/\.permissionset-meta\.xml$/, '');
}

function block(field, editable) {
  return `    <fieldPermissions>
        <editable>${editable}</editable>
        <field>${field}</field>
        <readable>true</readable>
    </fieldPermissions>`;
}

function resolvePerms(psName, field, orgMap) {
  if (orgMap[psName]?.[field]) {
    return orgMap[psName][field];
  }
  return DEFAULTS[field];
}

function updateFile(filePath, orgMap) {
  const filename = path.basename(filePath);
  const psName = permSetNameFromFile(filename);
  let content = fs.readFileSync(filePath, 'utf8');

  const toAdd = [];
  for (const field of FIELD_ORDER) {
    if (content.includes(`<field>${field}</field>`)) {
      continue;
    }
    const { edit } = resolvePerms(psName, field, orgMap);
    toAdd.push(block(field, edit));
  }

  if (toAdd.length === 0) {
    return { psName, added: 0 };
  }

  const insertion = toAdd.join('\n') + '\n';
  const marker = '    <hasActivationRequired>';

  if (!content.includes(marker)) {
    throw new Error(`${filename}: missing ${marker}`);
  }

  content = content.replace(marker, insertion + marker);
  fs.writeFileSync(filePath, content, 'utf8');
  return { psName, added: toAdd.length };
}

const orgMap = buildOrgMap();
const files = fs
  .readdirSync(PERM_DIR)
  .filter(
    (f) =>
      f.includes('Interaction_Case_Service_Case') &&
      f.endsWith('.permissionset-meta.xml')
  )
  .map((f) => path.join(PERM_DIR, f));

let totalAdded = 0;
const results = [];

for (const file of files.sort()) {
  const r = updateFile(file, orgMap);
  results.push(r);
  totalAdded += r.added;
}

console.log(`Updated ${results.length} permission sets, ${totalAdded} field blocks added.`);
for (const r of results.filter((x) => x.added > 0)) {
  console.log(`  ${r.psName}: +${r.added}`);
}
