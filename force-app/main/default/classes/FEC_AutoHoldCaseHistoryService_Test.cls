/**
 * Unit tests for FEC_AutoHoldCaseHistoryService.
 */
@IsTest
private class FEC_AutoHoldCaseHistoryService_Test {

    private static String holdConfigStatusValue(String fieldApi, String preferred) {
        Map<String, Schema.SObjectField> fieldMap =
            FEC_Hold_Case_Config__c.SObjectType.getDescribe().fields.getMap();
        if (!fieldMap.containsKey(fieldApi)) {
            return preferred;
        }
        Schema.DescribeFieldResult d = fieldMap.get(fieldApi).getDescribe();
        if (d.getType() != Schema.DisplayType.PICKLIST) {
            return preferred;
        }
        String fallback;
        for (Schema.PicklistEntry entry : d.getPicklistValues()) {
            if (!entry.isActive()) {
                continue;
            }
            if (fallback == null) {
                fallback = entry.getValue();
            }
            if (preferred != null && entry.getValue().equalsIgnoreCase(preferred)) {
                return entry.getValue();
            }
        }
        return fallback != null ? fallback : preferred;
    }

    private static Case insertCaseRow(String subject) {
        Case c = new Case(Subject = subject, Status = 'New');
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
        return c;
    }

    private static FEC_Hold_Case_Config__c insertAutoHoldConfig(
        String releaseStatus,
        Decimal durationMinutes
    ) {
        String suffix = String.valueOf(Math.abs(Crypto.getRandomInteger())).substring(0, 6);
        FEC_Product_Type__c pt = new FEC_Product_Type__c(
            Name = 'PT Hist ' + suffix,
            FEC_Code__c = 'PTH' + suffix,
            FEC_Active__c = true
        );
        insert pt;
        FEC_Category__c cat = new FEC_Category__c(
            Name = 'Cat Hist ' + suffix,
            FEC_Code__c = 'CAH' + suffix,
            FEC_Active__c = true
        );
        insert cat;
        FEC_Sub_Category__c sub = new FEC_Sub_Category__c(
            Name = 'Sub Hist ' + suffix,
            FEC_Code__c = 'SUH' + suffix,
            FEC_Active__c = true
        );
        insert sub;
        FEC_Nature_of_Case__c noc = new FEC_Nature_of_Case__c(
            FEC_Product_Type__c = pt.Id,
            FEC_Category__c = cat.Id,
            FEC_Sub_Category__c = sub.Id
        );
        insert noc;
        FEC_Case_Stage__c stage = new FEC_Case_Stage__c(
            Name = 'Stage Hist ' + suffix,
            FEC_Code__c = 'STH' + suffix,
            FEC_Nature_of_Cases__c = noc.Id
        );
        insert stage;
        insert new FEC_Hold_Case__c(
            FEC_NFU_Code__c = 'NFUH' + suffix,
            FEC_NFU_Reason_VN__c = 'NFU hist test',
            FEC_NFU_Duration__c = 1
        );
        FEC_Hold_Case_Config__c cfg = new FEC_Hold_Case_Config__c(
            Hold_Case_Type__c = 'Auto',
            FEC_Active__c = true,
            FEC_Nature_of_Cases__c = noc.Id,
            FEC_Case_Stage__c = stage.Id,
            FEC_NFU_Code__c = 'NFUH' + suffix,
            FEC_Current_Status__c = holdConfigStatusValue('FEC_Current_Status__c', 'New'),
            FEC_Changed_Status__c = holdConfigStatusValue('FEC_Changed_Status__c', 'Pending'),
            FEC_Auto_Hold_Release_Case_Status__c = releaseStatus,
            FEC_Auto_Hold_Duration_Minutes__c = durationMinutes
        );
        insert cfg;
        return cfg;
    }

    @IsTest
    static void testCreateFromSuccessfulAutoHold_skipsInvalidInputs() {
        Case c = insertCaseRow('History Service - Skip');
        FEC_Hold_Case_Config__c cfg = insertAutoHoldConfig('Open', 30);
        cfg.FEC_Auto_Hold_Release_Case_Status__c = null;
        update cfg;

        Test.startTest();
        FEC_AutoHoldCaseHistoryService.createFromSuccessfulAutoHold(null, cfg, DateTime.now(), DateTime.now().addHours(1));
        FEC_AutoHoldCaseHistoryService.createFromSuccessfulAutoHold(c.Id, null, DateTime.now(), DateTime.now().addHours(1));
        FEC_AutoHoldCaseHistoryService.createFromSuccessfulAutoHold(c.Id, cfg, DateTime.now(), null);
        Test.stopTest();

        System.assertEquals(
            0,
            [SELECT COUNT() FROM FEC_Case_Hold_History__c WHERE FEC_Case__c = :c.Id],
            'Blank release or missing end time must not insert history.'
        );
    }

    @IsTest
    static void testCreateFromSuccessfulAutoHold_skipsWhenNoEndTimeDerivable() {
        Case c = insertCaseRow('History Service - No End');
        FEC_Hold_Case_Config__c cfg = insertAutoHoldConfig('Open', 0);

        Test.startTest();
        FEC_AutoHoldCaseHistoryService.createFromSuccessfulAutoHold(
            c.Id,
            cfg,
            DateTime.now(),
            null
        );
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM FEC_Case_Hold_History__c WHERE FEC_Case__c = :c.Id]);
    }

    @IsTest
    static void testCreateFromSuccessfulAutoHold_usesApiExpiry() {
        Case c = insertCaseRow('History Service - API Expiry');
        FEC_Hold_Case_Config__c cfg = insertAutoHoldConfig('  Open  ', null);
        DateTime started = DateTime.newInstance(2026, 6, 1, 10, 0, 0);
        DateTime expiry = started.addHours(2);

        Test.startTest();
        FEC_AutoHoldCaseHistoryService.createFromSuccessfulAutoHold(c.Id, cfg, started, expiry);
        Test.stopTest();

        FEC_Case_Hold_History__c row = [
            SELECT FEC_Status__c, FEC_Type__c, FEC_Start_Time__c, FEC_End_Time__c,
                   FEC_Release_Case_Status__c, FEC_Hold_Case_Config__c
            FROM FEC_Case_Hold_History__c
            WHERE FEC_Case__c = :c.Id
            LIMIT 1
        ];
        System.assertEquals(FEC_AutoHoldCaseHistoryService.STATUS_ACTIVE, row.FEC_Status__c);
        System.assertEquals(FEC_AutoHoldCaseHistoryService.TYPE_AUTO, row.FEC_Type__c);
        System.assertEquals(started, row.FEC_Start_Time__c);
        System.assertEquals(expiry, row.FEC_End_Time__c);
        System.assertEquals('Open', row.FEC_Release_Case_Status__c);
        System.assertEquals(cfg.Id, row.FEC_Hold_Case_Config__c);
    }

    @IsTest
    static void testCreateFromSuccessfulAutoHold_usesDurationMinutes() {
        Case c = insertCaseRow('History Service - Duration');
        FEC_Hold_Case_Config__c cfg = insertAutoHoldConfig('Pending', 45);
        DateTime started = DateTime.newInstance(2026, 6, 2, 8, 30, 0);

        Test.startTest();
        FEC_AutoHoldCaseHistoryService.createFromSuccessfulAutoHold(c.Id, cfg, started, null);
        Test.stopTest();

        FEC_Case_Hold_History__c row = [
            SELECT FEC_End_Time__c, FEC_Release_Case_Status__c
            FROM FEC_Case_Hold_History__c
            WHERE FEC_Case__c = :c.Id
            LIMIT 1
        ];
        System.assertEquals(started.addMinutes(45), row.FEC_End_Time__c);
        System.assertEquals('Pending', row.FEC_Release_Case_Status__c);
    }

    @IsTest
    static void testCreateFromSuccessfulAutoHold_nullStartedDate_defaultsToNow() {
        Case c = insertCaseRow('History Service - Default Start');
        FEC_Hold_Case_Config__c cfg = insertAutoHoldConfig('New', 10);
        DateTime before = DateTime.now().addSeconds(-2);
        DateTime expiry = DateTime.now().addHours(1);

        Test.startTest();
        FEC_AutoHoldCaseHistoryService.createFromSuccessfulAutoHold(c.Id, cfg, null, expiry);
        Test.stopTest();

        FEC_Case_Hold_History__c row = [
            SELECT FEC_Start_Time__c
            FROM FEC_Case_Hold_History__c
            WHERE FEC_Case__c = :c.Id
            LIMIT 1
        ];
        System.assert(row.FEC_Start_Time__c >= before, 'Start time should default near DateTime.now().');
    }

    @IsTest
    static void testCreateFromSuccessfulAutoHold_cancelsPriorActiveAutoRows() {
        Case c = insertCaseRow('History Service - Cancel Prior');
        FEC_Hold_Case_Config__c cfg = insertAutoHoldConfig('Open', 20);
        DateTime oldEnd = DateTime.now().addHours(1);

        insert new FEC_Case_Hold_History__c(
            FEC_Case__c = c.Id,
            FEC_Start_Time__c = DateTime.now().addHours(-2),
            FEC_End_Time__c = oldEnd,
            FEC_Status__c = FEC_AutoHoldCaseHistoryService.STATUS_ACTIVE,
            FEC_Type__c = FEC_AutoHoldCaseHistoryService.TYPE_AUTO,
            FEC_Release_Case_Status__c = 'Pending'
        );

        DateTime newExpiry = DateTime.now().addHours(3);
        Test.startTest();
        FEC_AutoHoldCaseHistoryService.createFromSuccessfulAutoHold(
            c.Id,
            cfg,
            DateTime.now(),
            newExpiry
        );
        Test.stopTest();

        List<FEC_Case_Hold_History__c> rows = [
            SELECT FEC_Status__c, FEC_End_Time__c
            FROM FEC_Case_Hold_History__c
            WHERE FEC_Case__c = :c.Id
            ORDER BY CreatedDate ASC
        ];
        System.assertEquals(2, rows.size());
        System.assertEquals(FEC_AutoHoldCaseHistoryService.STATUS_CANCELLED, rows[0].FEC_Status__c);
        System.assertEquals(FEC_AutoHoldCaseHistoryService.STATUS_ACTIVE, rows[1].FEC_Status__c);
        System.assertEquals(newExpiry, rows[1].FEC_End_Time__c);
    }

    @IsTest
    static void testConstants_exposedForBatchAndExpire() {
        System.assertEquals('Active', FEC_AutoHoldCaseHistoryService.STATUS_ACTIVE);
        System.assertEquals('Completed', FEC_AutoHoldCaseHistoryService.STATUS_COMPLETED);
        System.assertEquals('Cancelled', FEC_AutoHoldCaseHistoryService.STATUS_CANCELLED);
        System.assertEquals('Auto', FEC_AutoHoldCaseHistoryService.TYPE_AUTO);
        System.assertEquals('Manual', FEC_AutoHoldCaseHistoryService.TYPE_MANUAL);
    }
}
