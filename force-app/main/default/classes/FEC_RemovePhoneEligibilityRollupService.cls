/**
 * Gộp FEC_Contract_List_for_Remove_Phone__c lên 3 trường Eligibility Details khi Case submit.
 * Điều kiện: FEC_Is_Submited__c false->true và Case có contract list rows — không dùng NOC.FEC_Remove_Phone__c.
 * Mỗi dòng: #<n>: Selected: ...~ Contract Number: ...~ ...
 */
public without sharing class FEC_RemovePhoneEligibilityRollupService {
    private static Set<Id> txnRollupDoneCaseIds = new Set<Id>();

    @TestVisible
    private static final Integer BUCKET_1_MAX = 256;
    @TestVisible
    private static final Integer BUCKET_2_MAX = 256;
    @TestVisible
    private static final Integer BUCKET_3_MAX = 131072;

    public static void rollup(Set<Id> caseIds) {
        if (caseIds == null || caseIds.isEmpty()) {
            return;
        }

        Set<Id> pendingCaseIds = new Set<Id>();
        for (Id caseId : caseIds) {
            if (caseId != null && !txnRollupDoneCaseIds.contains(caseId)) {
                pendingCaseIds.add(caseId);
            }
        }
        if (pendingCaseIds.isEmpty()) {
            return;
        }

        List<FEC_Contract_List_for_Remove_Phone__c> contractRows = [
            SELECT
                Id,
                FEC_Case__c,
                FEC_Check_Remove_Phone__c,
                FEC_Account_Contract_Number__c,
                FEC_Account_Contract_Status__c,
                FEC_Phone_Type__c,
                FEC_Removable__c,
                FEC_Reason__c
            FROM FEC_Contract_List_for_Remove_Phone__c
            WHERE FEC_Case__c IN :pendingCaseIds
            ORDER BY FEC_Case__c ASC, CreatedDate ASC, Id ASC
        ];

        Map<Id, List<FEC_Contract_List_for_Remove_Phone__c>> byCase =
            new Map<Id, List<FEC_Contract_List_for_Remove_Phone__c>>();
        for (Id caseId : pendingCaseIds) {
            byCase.put(caseId, new List<FEC_Contract_List_for_Remove_Phone__c>());
        }
        for (FEC_Contract_List_for_Remove_Phone__c row : contractRows) {
            if (row.FEC_Case__c != null && byCase.containsKey(row.FEC_Case__c)) {
                byCase.get(row.FEC_Case__c).add(row);
            }
        }

        List<FEC_Contract_List_for_Remove_Phone__c> toUpdate =
            new List<FEC_Contract_List_for_Remove_Phone__c>();
        for (Id caseId : pendingCaseIds) {
            List<FEC_Contract_List_for_Remove_Phone__c> rowsForCase = byCase.get(caseId);
            if (rowsForCase == null || rowsForCase.isEmpty()) {
                continue;
            }

            List<String> lines = formatNumberedLines(rowsForCase);
            BucketPack pack = packLines(lines);
            for (FEC_Contract_List_for_Remove_Phone__c row : rowsForCase) {
                toUpdate.add(
                    new FEC_Contract_List_for_Remove_Phone__c(
                        Id = row.Id,
                        FEC_Eligibility_Details_1__c = pack.part1,
                        FEC_Eligibility_Details_2__c = pack.part2,
                        FEC_Eligibility_Details_3__c = pack.part3
                    )
                );
            }
        }

        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }
        txnRollupDoneCaseIds.addAll(pendingCaseIds);
    }

    @TestVisible
    private static List<String> formatNumberedLines(
        List<FEC_Contract_List_for_Remove_Phone__c> rows
    ) {
        List<String> lines = new List<String>();
        if (rows == null || rows.isEmpty()) {
            return lines;
        }
        Integer n = 1;
        for (FEC_Contract_List_for_Remove_Phone__c row : rows) {
            lines.add('#' + String.valueOf(n) + ': ' + formatEligibilityBody(row));
            n++;
        }
        return lines;
    }

    @TestVisible
    private static String formatEligibilityBody(FEC_Contract_List_for_Remove_Phone__c row) {
        if (row == null) {
            return '';
        }
        String selected = row.FEC_Check_Remove_Phone__c == true ? 'Yes' : 'No';
        return 'Selected: ' + selected
            + '~ Contract Number: ' + safeText(row.FEC_Account_Contract_Number__c)
            + '~ Contract Status: ' + safeText(row.FEC_Account_Contract_Status__c)
            + '~ Phone Type: ' + safeText(row.FEC_Phone_Type__c)
            + '~ Removable: ' + safeText(row.FEC_Removable__c)
            + '~ Reason:' + safeText(row.FEC_Reason__c);
    }

    private static String safeText(String value) {
        if (value == null) {
            return '';
        }
        return value.replace('\r\n', ' ').replace('\r', ' ').replace('\n', ' ').trim();
    }

    @TestVisible
    private class BucketPack {
        public String part1;
        public String part2;
        public String part3;
        public Integer count1 = 0;
        public Integer count2 = 0;
        public Integer count3 = 0;
    }

    @TestVisible
    private static BucketPack packLines(List<String> lines) {
        BucketPack p = new BucketPack();
        p.part1 = null;
        p.part2 = null;
        p.part3 = null;
        if (lines == null || lines.isEmpty()) {
            return p;
        }

        Integer idx = 0;
        String b1 = '';
        while (idx < lines.size()) {
            String line = lines[idx];
            String candidate = b1.length() == 0 ? line : b1 + '\n' + line;
            if (candidate.length() <= BUCKET_1_MAX) {
                b1 = candidate;
                idx++;
            } else {
                break;
            }
        }
        p.count1 = idx;

        Integer b2Start = idx;
        String b2 = '';
        while (idx < lines.size()) {
            String line = lines[idx];
            String candidate = b2.length() == 0 ? line : b2 + '\n' + line;
            if (candidate.length() <= BUCKET_2_MAX) {
                b2 = candidate;
                idx++;
            } else {
                break;
            }
        }
        p.count2 = idx - b2Start;

        if (idx >= lines.size()) {
            p.count3 = 0;
            p.part1 = String.isBlank(b1) ? null : b1;
            p.part2 = String.isBlank(b2) ? null : b2;
            p.part3 = null;
            return p;
        }

        p.count3 = lines.size() - idx;
        List<String> tail = new List<String>();
        for (Integer j = idx; j < lines.size(); j++) {
            tail.add(lines[j]);
        }
        String b3 = String.join(tail, '\n');
        if (b3.length() > BUCKET_3_MAX) {
            b3 = b3.substring(0, BUCKET_3_MAX);
        }

        p.part1 = String.isBlank(b1) ? null : b1;
        p.part2 = String.isBlank(b2) ? null : b2;
        p.part3 = String.isBlank(b3) ? null : b3;
        return p;
    }
}
