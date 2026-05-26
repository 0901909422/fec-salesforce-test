/**
 * Persist automatic hold windows for Case (after Mark NFU succeeds) and cancel superseded active rows.
 */
public inherited sharing class FEC_AutoHoldCaseHistoryService {
    public static final String STATUS_ACTIVE = 'Active';
    public static final String STATUS_COMPLETED = 'Completed';
    public static final String STATUS_CANCELLED = 'Cancelled';
    public static final String TYPE_AUTO = 'Auto';
    public static final String TYPE_MANUAL = 'Manual';

    /**
     * After Case NFU fields are saved, open a Case Hold History row for batch expiry processing.
     * Skips when release status is blank or end time cannot be derived.
     */
    public static void createFromSuccessfulAutoHold(
        Id caseId,
        FEC_Hold_Case_Config__c cfg,
        DateTime startedDate,
        DateTime expiryFromApi
    ) {
        if (caseId == null || cfg == null) {
            return;
        }
        String release = cfg.FEC_Auto_Hold_Release_Case_Status__c;
        if (String.isBlank(release)) {
            return;
        }

        DateTime start = startedDate != null ? startedDate : DateTime.now();
        DateTime endDt = expiryFromApi;
        if (endDt == null && cfg.FEC_Auto_Hold_Duration_Minutes__c != null) {
            Decimal mins = cfg.FEC_Auto_Hold_Duration_Minutes__c;
            if (mins > 0) {
                endDt = start.addMinutes(mins.intValue());
            }
        }
        if (endDt == null) {
            return;
        }

        new AutoHoldHistoryWriter().cancelActiveAutoForCase(caseId);

        FEC_Case_Hold_History__c row = new FEC_Case_Hold_History__c(
            FEC_Case__c = caseId,
            FEC_Start_Time__c = start,
            FEC_End_Time__c = endDt,
            FEC_Status__c = STATUS_ACTIVE,
            FEC_Type__c = TYPE_AUTO,
            FEC_Hold_Case_Config__c = cfg.Id,
            FEC_Release_Case_Status__c = release.trim()
        );
        Database.insert(
            new List<FEC_Case_Hold_History__c>{ row },
            AccessLevel.SYSTEM_MODE
        );
    }

    private without sharing class AutoHoldHistoryWriter {
        void cancelActiveAutoForCase(Id caseId) {
            List<FEC_Case_Hold_History__c> openRows = [
                SELECT Id
                FROM FEC_Case_Hold_History__c
                WHERE
                    FEC_Case__c = :caseId
                    AND FEC_Type__c = :TYPE_AUTO
                    AND FEC_Status__c = :STATUS_ACTIVE
            ];
            if (openRows.isEmpty()) {
                return;
            }
            for (FEC_Case_Hold_History__c h : openRows) {
                h.FEC_Status__c = STATUS_CANCELLED;
            }
            Database.update(openRows, AccessLevel.SYSTEM_MODE);
        }
    }
}
