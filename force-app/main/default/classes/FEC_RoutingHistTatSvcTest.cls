@isTest
private class FEC_RoutingHistTatSvcTest {
    private static Integer fakeIdSeq = 1;

    private static final Datetime T0 = Datetime.newInstance(2026, 5, 20, 10, 0, 0);
    private static final Datetime T1 = Datetime.newInstance(2026, 5, 20, 11, 0, 0);
    private static final Datetime T2 = Datetime.newInstance(2026, 5, 20, 12, 0, 0);

    @isTest
    static void th222DoesNotRequireNullAssignmentOnCase() {
        Id caseId = nextId(Case.SObjectType);
        Id assignmentId = nextId(FEC_Assignment__c.SObjectType);

        FEC_Routing_Action_History__c current = buildHistory(
            null,
            caseId,
            assignmentId,
            T2
        );
        FEC_Routing_Action_History__c withAssignment = buildHistory(
            nextId(FEC_Routing_Action_History__c.SObjectType),
            caseId,
            assignmentId,
            T1
        );
        FEC_Routing_Action_History__c withoutAssignment = buildHistory(
            nextId(FEC_Routing_Action_History__c.SObjectType),
            caseId,
            null,
            T0
        );

        FEC_Routing_Action_History__c best = FEC_RoutingHistTatSvc.findBestPrior(
            new List<FEC_Routing_Action_History__c>{ withoutAssignment, withAssignment },
            current,
            caseId,
            null,
            T2,
            false,
            false
        );

        System.assertEquals(
            withAssignment,
            best,
            'TH2.2.2 không lọc FEC_Assignment__c = null — lấy prior Submitted mới nhất.'
        );
    }

    private static FEC_Routing_Action_History__c buildHistory(
        Id historyId,
        Id caseId,
        Id assignmentId,
        Datetime submittedOn
    ) {
        FEC_Routing_Action_History__c row = new FEC_Routing_Action_History__c(
            FEC_Case__c = caseId,
            FEC_Assignment__c = assignmentId,
            FEC_Submitted_On__c = submittedOn
        );
        if (historyId != null) {
            row.Id = historyId;
        }
        return row;
    }

    private static Id nextId(Schema.SObjectType soType) {
        String prefix = soType.getDescribe().getKeyPrefix();
        String suffix = String.valueOf(fakeIdSeq++);
        String id15 = (prefix + '0'.repeat(Math.max(0, 12 - suffix.length())) + suffix)
            .substring(0, 15);
        return Id.valueOf(id15);
    }
}