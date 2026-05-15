/**
 * Resolve permission-set merge conflicts: true union of fieldPermissions
 * from HEAD (hoangnm107) and MERGE_HEAD (phase-3/report-dashboard).
 */
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const ROOT = path.join(__dirname, '..');

const PREFER_HEAD_FIELDS = new Set([
  'Case.FEC_Original_Category__c',
  'Case.FEC_Original_Sub_Category__c',
  'Case.FEC_Original_Sub_Code__c',
  'Case.FEC_Case_Remarks_1__c',
  'Case.FEC_Case_Remarks_2__c',
  'Case.FEC_Case_Remarks_3__c',
  'FEC_Routing_Action_History__c.FEC_Assigned_On__c',
  'FEC_Routing_Action_History__c.FEC_TAT_by_Assignment__c',
  'Case.FEC_TAT_Full_Process__c',
]);

const FP_RE = /<fieldPermissions>[\s\S]*?<\/fieldPermissions>/g;

function gitShow(rev, file) {
  return execSync(`git show ${rev}:${file.replace(/\\/g, '/')}`, {
    cwd: ROOT,
    encoding: 'utf8',
    maxBuffer: 50 * 1024 * 1024,
  });
}

function extractOrderedBlocks(content) {
  return (content.match(FP_RE) || []).map((block) => {
    const field = block.match(/<field>([^<]+)<\/field>/)[1];
    const editable = block.match(/<editable>([^<]+)<\/editable>/)[1];
    return {
      field,
      normalized: `    <fieldPermissions>
        <editable>${editable}</editable>
        <field>${field}</field>
        <readable>true</readable>
    </fieldPermissions>`,
    };
  });
}

function pickBlock(ours, theirs, field) {
  if (PREFER_HEAD_FIELDS.has(field) && ours) return ours.normalized;
  if (theirs) return theirs.normalized;
  return ours.normalized;
}

function mergeFile(relPath) {
  const oursContent = gitShow('HEAD', relPath);
  const theirsContent = gitShow('MERGE_HEAD', relPath);
  const oursBlocks = extractOrderedBlocks(oursContent);
  const theirsBlocks = extractOrderedBlocks(theirsContent);
  const oursByField = new Map(oursBlocks.map((b) => [b.field, b]));

  const marker = '    <hasActivationRequired>';
  const idx = theirsContent.indexOf(marker);
  const firstFp = theirsContent.indexOf('<fieldPermissions>');
  if (idx === -1 || firstFp === -1) throw new Error(`${relPath}: bad structure`);

  const header = theirsContent.slice(0, firstFp);
  const footer = theirsContent.slice(idx);
  const ordered = [];
  const seen = new Set();

  for (const block of theirsBlocks) {
    if (!seen.has(block.field)) {
      ordered.push(pickBlock(oursByField.get(block.field), block, block.field));
      seen.add(block.field);
    }
  }
  for (const block of oursBlocks) {
    if (!seen.has(block.field)) {
      ordered.push(block.normalized);
      seen.add(block.field);
    }
  }

  fs.writeFileSync(path.join(ROOT, relPath), header + ordered.join('\n') + '\n' + footer, 'utf8');
}

const conflicted = execSync('git diff --name-only --diff-filter=U', { cwd: ROOT, encoding: 'utf8' })
  .trim()
  .split('\n')
  .filter(Boolean);

for (const f of conflicted) {
  mergeFile(f);
  execSync(`git add "${f}"`, { cwd: ROOT });
  console.log('OK', path.basename(f), '- unique fields:', new Set(extractOrderedBlocks(fs.readFileSync(path.join(ROOT, f), 'utf8')).map(b => b.field)).size);
}
