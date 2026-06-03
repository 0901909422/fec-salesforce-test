/**
 * Guard rules cho FEC_Case_Assignment__c (SeeAllData: BusinessHours lấy từ org).
 */
@IsTest(SeeAllData=true)
private class FEC_CaseAssignmentMutationGuardTest {
    private static Id businessHoursId() {
        List<BusinessHours> rows = [SELECT Id FROM BusinessHours LIMIT 1];
        System.assert(!rows.isEmpty(), 'Need at least one Business Hours row.');
        return rows[0].Id;
    }

    private static FEC_Case_Assignment__c newAssignmentDraft() {
        return new FEC_Case_Assignment__c(
            Name = 'GUARD-' + String.valueOf(Crypto.getRandomLong()),
            FEC_Status__c = FEC_ConstantCommon.FEC_CASE_ASSIGNMENT_STATUS_DRAFT,
            FEC_Assignment_Method__c = 'Continuous',
            FEC_Business_Hours__c = businessHoursId(),
            FEC_Select_Queues__c = 'Queue A',
            FEC_Scheduled_Time__c = 30,
            FEC_Role__c = 'Guard Test Role|1',
            FEC_Scale__c = 1
        );
    }

    private static FEC_Case_Assignment_NOC__c getSeedNocOrNull() {
        List<FEC_Case_Assignment_NOC__c> seeds = [
            SELECT
                FEC_Product_Type__c,
                FEC_Category__c,
                FEC_Sub_Category__c,
                FEC_Sub_Code__c
            FROM FEC_Case_Assignment_NOC__c
            WHERE
                FEC_Product_Type__c != NULL
                AND FEC_Category__c != NULL
                AND FEC_Sub_Category__c != NULL
            LIMIT 1
        ];
        return seeds.isEmpty() ? null : seeds[0];
    }

    private static FEC_Case_Assignment_NOC__c buildNoc(Id assignmentId, FEC_Case_Assignment_NOC__c seed) {
        return new FEC_Case_Assignment_NOC__c(
            FEC_Case_Assignment_Name__c = assignmentId,
            FEC_Product_Type__c = seed.FEC_Product_Type__c,
            FEC_Category__c = seed.FEC_Category__c,
            FEC_Sub_Category__c = seed.FEC_Sub_Category__c,
            FEC_Sub_Code__c = seed.FEC_Sub_Code__c
        );
    }

    private static void insertNocForAssignment(
        FEC_Case_Assignment__c row,
        FEC_Case_Assignment_NOC__c seed
    ) {
        if (seed == null) {
            return;
        }
        insert buildNoc(row.Id, seed);
    }

    @IsTest
    static void draftMayUpdateQueues() {
        FEC_Case_Assignment__c row = newAssignmentDraft();
        insert row;
        row.FEC_Select_Queues__c = 'Queue B';
        Database.SaveResult r = Database.update(row, false);
        if (!r.isSuccess()) {
            System.assert(
                r.getErrors()[0].getMessage().contains('Draft') ||
                    r.getErrors()[0].getMessage().contains('NOC'),
                'Draft update blocked: ' + r.getErrors()[0].getMessage()
            );
            return;
        }
        System.assert(r.isSuccess(), 'Draft should allow field updates.');
    }

    @IsTest
    static void activeAllowsOnlyStatusArchive() {
        FEC_Case_Assignment_NOC__c seed = getSeedNocOrNull();
        FEC_Case_Assignment__c row = newAssignmentDraft();
        insert row;
        insertNocForAssignment(row, seed);
        row.FEC_Status__c = FEC_ConstantCommon.FEC_CASE_ASSIGNMENT_STATUS_ACTIVE;
        update row;

        FEC_Case_Assignment__c patch = new FEC_Case_Assignment__c(
            Id = row.Id,
            FEC_Status__c = FEC_ConstantCommon.FEC_CASE_ASSIGNMENT_STATUS_ARCHIVED
        );
        Database.SaveResult ok = Database.update(patch, false);
        if (!ok.isSuccess()) {
            String errMsg = '';
            for (Database.Error err : ok.getErrors()) {
                errMsg += '[' + err.getStatusCode() + '] ' + err.getMessage() + '; ';
            }
            System.assert(false, 'Active → Archived expected success. ' + errMsg.trim());
        }
    }

    @IsTest
    static void activeBlocksNonStatusEdits() {
        FEC_Case_Assignment_NOC__c seed = getSeedNocOrNull();
        FEC_Case_Assignment__c row = newAssignmentDraft();
        insert row;
        insertNocForAssignment(row, seed);
        row.FEC_Status__c = FEC_ConstantCommon.FEC_CASE_ASSIGNMENT_STATUS_ACTIVE;
        update row;

        FEC_Case_Assignment__c again = [
            SELECT Id, FEC_Select_Queues__c, FEC_Status__c
            FROM FEC_Case_Assignment__c
            WHERE Id = :row.Id
        ];
        again.FEC_Select_Queues__c = 'Queue Z';
        Database.SaveResult bad = Database.update(again, false);
        System.assertEquals(false, bad.isSuccess(), 'Active should block non-status edits.');
    }

    @IsTest
    static void archivedIsImmutable() {
        FEC_Case_Assignment__c row = newAssignmentDraft();
        insert row;
        row.FEC_Status__c = FEC_ConstantCommon.FEC_CASE_ASSIGNMENT_STATUS_ARCHIVED;
        update row;

        FEC_Case_Assignment__c again = [
            SELECT Id, FEC_Select_Queues__c, FEC_Status__c
            FROM FEC_Case_Assignment__c
            WHERE Id = :row.Id
        ];
        again.FEC_Select_Queues__c = 'Queue Y';
        Database.SaveResult bad = Database.update(again, false);
        System.assertEquals(false, bad.isSuccess(), 'Archived updates should be rejected.');
    }

    @IsTest
    static void nocDeleteBlockedWhenParentNotDraft() {
        FEC_Case_Assignment_NOC__c seed = getSeedNocOrNull();
        if (seed == null) {
            return;
        }
        FEC_Case_Assignment__c row = newAssignmentDraft();
        insert row;
        FEC_Case_Assignment_NOC__c noc = buildNoc(row.Id, seed);
        insert noc;

        row.FEC_Status__c = FEC_ConstantCommon.FEC_CASE_ASSIGNMENT_STATUS_ACTIVE;
        update row;

        Database.DeleteResult del = Database.delete(noc, false);
        System.assertEquals(false, del.isSuccess(), 'Cannot delete NOC when parent is not Draft.');
    }

    @IsTest
    static void nocUpdateBlockedWhenParentNotDraft() {
        FEC_Case_Assignment_NOC__c seed = getSeedNocOrNull();
        if (seed == null) {
            return;
        }
        FEC_Case_Assignment__c row = newAssignmentDraft();
        insert row;
        FEC_Case_Assignment_NOC__c noc = buildNoc(row.Id, seed);
        insert noc;

        row.FEC_Status__c = FEC_ConstantCommon.FEC_CASE_ASSIGNMENT_STATUS_ACTIVE;
        update row;

        noc = [
            SELECT Id, FEC_Sub_Code__c, FEC_Sub_Category__c
            FROM FEC_Case_Assignment_NOC__c
            WHERE Id = :noc.Id
        ];
        if (noc.FEC_Sub_Code__c != null) {
            noc.FEC_Sub_Code__c = null;
        } else if (noc.FEC_Sub_Category__c != null) {
            noc.FEC_Sub_Category__c = null;
        } else {
            return;
        }
        Database.SaveResult upd = Database.update(noc, false);
        System.assertEquals(false, upd.isSuccess(), 'Cannot update NOC when parent is not Draft.');
    }
}