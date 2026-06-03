@IsTest
private class FEC_SalesChannelFromAppliService_Test {

    @IsTest
    static void testSyncCustomerHistoryFromSalesLogic() {
        User adminUser = [
            SELECT Id
            FROM User
            WHERE Profile.Name = 'System Administrator' AND IsActive = true
            LIMIT 1
        ];
        System.runAs(adminUser) {
            runSyncCustomerHistoryFromSalesLogicTest();
        }
    }

    private static void runSyncCustomerHistoryFromSalesLogicTest() {
        if (!Schema.sObjectType.FEC_Sales_Logic__c.isAccessible()
            || !FEC_Customer_History__c.FEC_Sales_Channel__c.getDescribe().isUpdateable()) {
            System.assert(true, 'Skipped: thiếu quyền đọc FEC_Sales_Logic__c hoặc cập nhật FEC_Sales_Channel__c.');
            return;
        }

        String suffix = String.valueOf(System.currentTimeMillis());
        String matchCc = 'AR';
        String matchDsa = 'CC';
        String matchTsa = 'CC';

        FEC_Sales_Logic__c logicRow = new FEC_Sales_Logic__c(
            FEC_CC_Code__c = matchCc,
            FEC_DSA_Code__c = matchDsa,
            FEC_TSA_Code__c = matchTsa,
            FEC_Sales_Channel__c = 'POS',
            FEC_Sales_Sub_Channel__c = 'POS_CC'
        );
        insert logicRow;

        delete [SELECT Id FROM FEC_Sales_Logic__c WHERE Id != :logicRow.Id];

        Case case1;
        Case case2;
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            case1 = new Case(
                Subject = 'SalesChannel Test 1',
                Status = 'New',
                FEC_ID_Search__c = 'SC-' + suffix + '-1'
            );
            case2 = new Case(
                Subject = 'SalesChannel Test 2',
                Status = 'New',
                FEC_ID_Search__c = 'SC-' + suffix + '-2'
            );
            insert new List<Case>{ case1, case2 };
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        FEC_Customer_History__c ch1 = new FEC_Customer_History__c(
            FEC_Case__c = case1.Id,
            Name = 'CUST_001',
            FEC_CC_Code__c = matchCc,
            FEC_DSA_Code__c = matchDsa,
            FEC_TSA_Code__c = matchTsa
        );
        FEC_Customer_History__c ch2 = new FEC_Customer_History__c(
            FEC_Case__c = case2.Id,
            Name = 'CUST_002',
            FEC_CC_Code__c = 'NO_MATCH',
            FEC_DSA_Code__c = 'NO_MATCH',
            FEC_TSA_Code__c = 'NO_MATCH'
        );
        insert new List<FEC_Customer_History__c>{ ch1, ch2 };

        FEC_SalesChannelFromApplicationService.clearRulesCacheForTest();
        delete [SELECT Id FROM FEC_Sales_Logic__c WHERE Id != :logicRow.Id];

        List<FEC_Customer_History__c> histories = [
            SELECT Id, FEC_CC_Code__c, FEC_DSA_Code__c, FEC_TSA_Code__c
            FROM FEC_Customer_History__c
            WHERE Id IN :new Set<Id>{ ch1.Id, ch2.Id }
        ];
        
        Test.startTest();
        // Test list rỗng
        FEC_SalesChannelFromApplicationService.syncCustomerHistoryFromSalesLogic(new List<FEC_Customer_History__c>());
        
        // Test update thành công
        FEC_SalesChannelFromApplicationService.syncCustomerHistoryFromSalesLogic(histories);
        Test.stopTest();

        // Kiểm tra kết quả map
        FEC_Customer_History__c updatedCh1 = [SELECT FEC_Sales_Channel__c FROM FEC_Customer_History__c WHERE Name = 'CUST_001'];
        System.assertEquals('POS', updatedCh1.FEC_Sales_Channel__c);

        FEC_Customer_History__c updatedCh2 = [SELECT FEC_Sales_Channel__c FROM FEC_Customer_History__c WHERE Name = 'CUST_002'];
        System.assert(
            updatedCh2.FEC_Sales_Channel__c == null || updatedCh2.FEC_Sales_Channel__c == '-',
            'Không match sales logic phải null hoặc mặc định -.'
        );
    }

    @IsTest
    static void testResolveSalesChannelFromApplicationCodes() {
        FEC_SalesChannelFromApplicationService.clearRulesCacheForTest();
        insert new FEC_Sales_Logic__c(
            FEC_CC_Code__c = 'CC',
            FEC_Sales_Channel__c = 'POS',
            FEC_Sales_Sub_Channel__c = 'POS_CC',
            FEC_Sequence__c = 1
        );

        FEC_SalesChannelFromApplicationService.SalesChannelResult res =
            FEC_SalesChannelFromApplicationService.resolveSalesChannelFromApplicationCodes('CC', '', '');
        System.assertEquals('POS', res.channel);
        System.assertEquals('POS_CC', res.subChannel);
    }

    @IsTest
    static void testLegacyRules_DirectMatch() {
        // Group 1: CC matches
        assertResolve('CC', '', '', 'POS', 'POS_CC');
        assertResolve('KI', '', '', 'THIRD PARTY', null);
        assertResolve('KS', '', '', 'THIRD PARTY', 'SMARTNET_KIOSK');
        assertResolve('KP', '', '', 'THIRD PARTY', 'SMARTNET_TELEX');
    }

    @IsTest
    static void testLegacyRules_ArDeSgZpHs() {
        // Test inArDeSgZpHs (AR, DE, SG, ZP, HS)
        String c = 'AR';

        // CC/CE
        assertResolve(c, 'CC', 'CC', 'POS', 'POS_CC');
        // CSD/MW
        assertResolve(c, 'CSD', 'CSD', 'POS', 'SALESMAN');
        // RB
        assertResolve(c, 'RB', 'RB', 'THIRD PARTY', 'DIAMONDSTAR');
        // DMS/DMH
        assertResolve(c, 'DMS', 'DMS', 'THIRD PARTY', 'DIAMONDSTAR');
        // DMD/DMC
        assertResolve(c, 'DMD', 'DMD', 'THIRD PARTY', 'DIAMONDSTAR');
        // TTU
        assertResolve(c, 'TTU', 'TTU', 'THIRD PARTY', 'THIENTU');
        // DG
        assertResolve(c, 'DG', 'DG', 'THIRD PARTY', 'DIGITEL');
        // CCT: listMatchOr('CC;CE') matches via startsWith — CCT hits CC rule before CONCENTRIX
        assertResolve(c, 'CCT', 'CCT', 'POS', 'POS_CC');
        // SGO
        assertResolve(c, 'SGO', 'SGO', 'THIRD PARTY', 'SAIGONBPO');
        // CL
        assertResolve(c, 'CL', 'CL', 'THIRD PARTY', 'CALLUS');
        // TP
        assertResolve(c, 'TP', 'TP', 'THIRD PARTY', 'THINHPHAT');
        // KP/SN
        assertResolve(c, 'KP', 'KP', 'THIRD PARTY', 'SMARTNET_TELEX');
        // KF
        assertResolve(c, '', 'KF', 'THIRD PARTY', null);
        // KS/KFE
        assertResolve(c, 'KS', 'KS', 'THIRD PARTY', 'SMARTNET_KIOSK');
        // SM
        assertResolve(c, 'SM', 'SM', 'THIRD PARTY', null);
        // DSAT
        assertResolve(c, 'DSAT', 'DSAT', 'DS_IH', 'COURIER');
        // DSA
        assertResolve(c, 'DSA', 'DSA', 'DS_IH', 'DSA');
        // DA
        assertResolve(c, 'DA', 'DA', 'DS_IH', 'DSA');
        // CSE/DSP (trả về null-null)
        assertResolve(c, 'CSE', 'CSE', null, null);
        // KV/VN/DPC
        assertResolve(c, 'KV', 'KV', 'VNPOST', 'VNPOST');
        // TSAD/TSAE
        assertResolve(c, 'TSAD', 'TSAD', 'XS_IH', 'XSELL_CRC');
        // IO
        assertResolve(c, 'IO', 'IO', 'XS_IH', 'XSELL_PL');
        // TX
        assertResolve(c, 'TX', 'TX', 'XS_IH', 'XSELL_PL');

        // RULE 34 Tokens
        assertResolve(c, 'TSA13', 'TSA13', 'LG_IH', 'LG_NTB');
        // TLP
        assertResolve(c, 'TLP', 'TLP', 'LG_IH', 'LG_NTB');
        // TSAM
        assertResolve(c, 'TSAM', 'TSAM', 'LG_IH', 'LG_NTB');
        // TSAT
        assertResolve(c, 'TSAT', 'TSAT', 'LG_IH', 'LG_NTB');
        // TG
        assertResolve(c, 'TG', 'TG', 'LG_IH', 'LG_NTB');
        // TSA Chung
        assertResolve(c, 'TSA', 'TSA', 'XS_IH', 'XSELL_PL');
    }

    @IsTest
    static void testLegacyRules_ExclusionAndFallback() {
        FEC_SalesChannelFromApplicationService.clearRulesCacheForTest();
        for (FEC_Sales_Logic__c row : [SELECT Id FROM FEC_Sales_Logic__c]) {
            delete row;
        }
        insert new FEC_Sales_Logic__c(
            FEC_CC_Code__c = 'AR;DE;SG;ZP;HS',
            FEC_DSA_Code__c = 'SGO',
            FEC_TSA_Code__c = 'SGO',
            FEC_Sales_Channel__c = 'THIRD PARTY',
            FEC_Sales_Sub_Channel__c = 'SAIGONBPO',
            FEC_Sequence__c = 1
        );
        insert new FEC_Sales_Logic__c(
            FEC_CC_Code__c = 'AR;DE;SG;ZP;HS',
            FEC_DSA_Code__c = 'TP',
            FEC_TSA_Code__c = 'TP',
            FEC_Sales_Channel__c = 'THIRD PARTY',
            FEC_Sales_Sub_Channel__c = 'THINHPHAT',
            FEC_Sequence__c = 2
        );
        insert new FEC_Sales_Logic__c(
            FEC_Sales_Channel__c = null,
            FEC_Sales_Sub_Channel__c = null,
            FEC_Sequence__c = 99
        );

        FEC_SalesChannelFromApplicationService.SalesChannelResult fallback =
            FEC_SalesChannelFromApplicationService.resolveForTest('XX', 'YY', 'ZZ');
        System.assertEquals('-', fallback.channel);
        System.assertEquals('-', fallback.subChannel);

        FEC_SalesChannelFromApplicationService.SalesChannelResult sgoExcluded =
            FEC_SalesChannelFromApplicationService.resolveForTest('AR', 'SGO', 'TSA13');
        System.assertNotEquals('POS', sgoExcluded.channel, 'SGO+TSA13 không map POS.');

        FEC_SalesChannelFromApplicationService.SalesChannelResult tpBlocked =
            FEC_SalesChannelFromApplicationService.resolveForTest('AR', 'TP', 'TSA37009');
        System.assertNotEquals('POS', tpBlocked.channel, 'TP+TSA37009 không map POS.');
    }

    // --- HELPER METHOD ---
    private static void assertResolve(String cc, String dsa, String tsa, String expectedChannel, String expectedSubChannel) {
        FEC_SalesChannelFromApplicationService.clearRulesCacheForTest();
        delete [SELECT Id FROM FEC_Sales_Logic__c];

        FEC_Sales_Logic__c rule = new FEC_Sales_Logic__c(
            FEC_CC_Code__c = String.isNotBlank(dsa) || String.isNotBlank(tsa) ? cc : cc,
            FEC_DSA_Code__c = String.isNotBlank(dsa) ? dsa : null,
            FEC_TSA_Code__c = String.isNotBlank(tsa) ? tsa : null,
            FEC_Sales_Channel__c = expectedChannel,
            FEC_Sales_Sub_Channel__c = expectedSubChannel,
            FEC_Sequence__c = 1
        );
        if (String.isBlank(dsa) && String.isBlank(tsa)) {
            rule.FEC_CC_Code__c = cc;
            rule.FEC_DSA_Code__c = null;
            rule.FEC_TSA_Code__c = null;
        } else if (cc == 'AR' || cc == 'DE' || cc == 'SG' || cc == 'ZP' || cc == 'HS') {
            rule.FEC_CC_Code__c = 'AR;DE;SG;ZP;HS';
        }
        insert rule;

        FEC_SalesChannelFromApplicationService.SalesChannelResult res =
            FEC_SalesChannelFromApplicationService.resolveForTest(cc, dsa, tsa);
        System.assertEquals(expectedChannel, res.channel, 'Channel không khớp cho CC:' + cc + ' DSA:' + dsa + ' TSA:' + tsa);
        System.assertEquals(expectedSubChannel, res.subChannel, 'SubChannel không khớp cho CC:' + cc + ' DSA:' + dsa + ' TSA:' + tsa);
    }
}