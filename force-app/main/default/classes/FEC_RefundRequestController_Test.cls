@IsTest
private class FEC_RefundRequestController_Test {

    private static Case insertCase() {
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            Case c = new Case(
                Subject = 'RefundRequest Test',
                Status = 'New',
                FEC_ID_Search__c = 'RR-' + String.valueOf(System.currentTimeMillis())
            );
            insert c;
            return c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
    }

    private static FEC_RefundRequestController.ReceiptLineDTO newLine(
        String dateIso,
        Decimal amount,
        String txn,
        String channel
    ) {
        return newLine(dateIso, amount, txn, channel, null);
    }

    private static FEC_RefundRequestController.ReceiptLineDTO newLine(
        String dateIso,
        Decimal amount,
        String txn,
        String channel,
        String detailId
    ) {
        FEC_RefundRequestController.ReceiptLineDTO line =
            new FEC_RefundRequestController.ReceiptLineDTO();
        line.receiptDateIso = dateIso;
        line.receiptAmount = amount;
        line.transactionNo = txn;
        line.paymentChannel = channel;
        line.detailId = detailId;
        return line;
    }

    private static void expectAuraHandledException() {
        System.assert(false, 'Expected AuraHandledException');
    }

    @TestSetup
    static void setupData() {
        insertCase();
    }

    @IsTest
    static void testGetRefundRequestData_FromDraft() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        List<FEC_RefundRequestController.ReceiptLineDTO> lines =
            new List<FEC_RefundRequestController.ReceiptLineDTO>{
                newLine(String.valueOf(Date.today()), 1000, 'TX1', 'Bank')
            };

        FEC_RefundRequestController.saveRefundRequestDraft(c.Id, 100000, lines);

        Test.startTest();
        FEC_RefundRequestController.RefundRequestDataDTO result =
            FEC_RefundRequestController.getRefundRequestData(c.Id);
        Test.stopTest();

        System.assertEquals(100000, result.refundAmount);
        System.assertEquals(1, result.receiptLines.size());
        System.assertEquals('TX1', result.receiptLines[0].transactionNo);
    }

    @IsTest
    static void testGetRefundRequestData_FromDetailsAndAmount() {
        Case c = [SELECT Id FROM Case LIMIT 1];

        insert new FEC_Case_Refund_Details__c(
            FEC_Case__c = c.Id,
            FEC_Receipt_Date__c = Date.today(),
            FEC_Receipt_Amount__c = 25000,
            FEC_Transaction_Number__c = 'EXIST-TXN',
            FEC_Payment_Channel__c = 'Cash'
        );

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            update new Case(Id = c.Id, FEC_Refund_Amount__c = 75000);
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        Test.startTest();
        FEC_RefundRequestController.RefundRequestDataDTO result =
            FEC_RefundRequestController.getRefundRequestData(c.Id);
        Test.stopTest();

        System.assertEquals(75000, result.refundAmount);
        System.assertEquals(1, result.receiptLines.size());
        System.assertEquals('EXIST-TXN', result.receiptLines[0].transactionNo);
    }

    @IsTest
    static void testGetRefundRequestData_EdgeCases() {
        Test.startTest();
        FEC_RefundRequestController.RefundRequestDataDTO nullId =
            FEC_RefundRequestController.getRefundRequestData(null);
        FEC_RefundRequestController.RefundRequestDataDTO missingCase =
            FEC_RefundRequestController.getRefundRequestData(
                '500000000000000AAA'
            );
        Test.stopTest();

        System.assertNotEquals(null, nullId);
        System.assertEquals(0, nullId.receiptLines.size());
        System.assertNotEquals(null, missingCase);

        Case c = [SELECT Id FROM Case LIMIT 1];
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            update new Case(
                Id = c.Id,
                FEC_Refund_Request_Draft__c = '{not-valid-json'
            );
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        FEC_RefundRequestController.RefundRequestDataDTO badDraft =
            FEC_RefundRequestController.getRefundRequestData(c.Id);
        System.assertNotEquals(null, badDraft);
    }

    @IsTest
    static void testSaveRefundRequest_Success() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        List<FEC_RefundRequestController.ReceiptLineDTO> lines =
            new List<FEC_RefundRequestController.ReceiptLineDTO>{
                newLine(String.valueOf(Date.today()), 50000, 'TXN123', 'Bank')
            };

        Test.startTest();
        FEC_RefundRequestController.saveRefundRequest(c.Id, 50000, lines);
        Test.stopTest();

        Case updated = [
            SELECT FEC_Refund_Amount__c, FEC_Refund_Request_Draft__c
            FROM Case
            WHERE Id = :c.Id
        ];
        System.assertEquals(50000, updated.FEC_Refund_Amount__c);
        System.assertEquals(null, updated.FEC_Refund_Request_Draft__c);
        System.assertEquals(
            1,
            [SELECT COUNT() FROM FEC_Case_Refund_Details__c WHERE FEC_Case__c = :c.Id]
        );
    }

    @IsTest
    static void testSaveRefundRequest_MergeUpdateAndDelete() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        FEC_Case_Refund_Details__c keep = new FEC_Case_Refund_Details__c(
            FEC_Case__c = c.Id,
            FEC_Receipt_Date__c = Date.today().addDays(-2),
            FEC_Receipt_Amount__c = 100,
            FEC_Transaction_Number__c = 'OLD-KEEP',
            FEC_Payment_Channel__c = 'Bank'
        );
        FEC_Case_Refund_Details__c remove = new FEC_Case_Refund_Details__c(
            FEC_Case__c = c.Id,
            FEC_Receipt_Date__c = Date.today().addDays(-3),
            FEC_Receipt_Amount__c = 200,
            FEC_Transaction_Number__c = 'OLD-DEL',
            FEC_Payment_Channel__c = 'Cash'
        );
        insert new List<FEC_Case_Refund_Details__c>{ keep, remove };

        List<FEC_RefundRequestController.ReceiptLineDTO> lines =
            new List<FEC_RefundRequestController.ReceiptLineDTO>{
                newLine(
                    String.valueOf(Date.today()),
                    999,
                    'UPDATED',
                    'Wire',
                    String.valueOf(keep.Id)
                ),
                newLine(String.valueOf(Date.today()), 111, 'NEW-LINE', 'Bank')
            };

        Test.startTest();
        FEC_RefundRequestController.saveRefundRequest(c.Id, 1110, lines);
        Test.stopTest();

        Map<String, FEC_Case_Refund_Details__c> byTxn = new Map<String, FEC_Case_Refund_Details__c>();
        for (FEC_Case_Refund_Details__c row : [
            SELECT FEC_Transaction_Number__c, FEC_Receipt_Amount__c
            FROM FEC_Case_Refund_Details__c
            WHERE FEC_Case__c = :c.Id
        ]) {
            byTxn.put(row.FEC_Transaction_Number__c, row);
        }
        System.assertEquals(2, byTxn.size());
        System.assert(byTxn.containsKey('UPDATED'));
        System.assert(byTxn.containsKey('NEW-LINE'));
        System.assert(!byTxn.containsKey('OLD-DEL'));
        System.assertEquals(999, byTxn.get('UPDATED').FEC_Receipt_Amount__c);
    }

    @IsTest
    static void testValidation_ErrorCases() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        List<FEC_RefundRequestController.ReceiptLineDTO> validLine =
            new List<FEC_RefundRequestController.ReceiptLineDTO>{
                newLine(String.valueOf(Date.today()), 100, 'T', 'C')
            };

        try {
            FEC_RefundRequestController.saveRefundRequest(
                null,
                100,
                validLine
            );
            expectAuraHandledException();
        } catch (AuraHandledException e) {
            System.assert(true);
        }

        try {
            FEC_RefundRequestController.saveRefundRequest(c.Id, null, validLine);
            expectAuraHandledException();
        } catch (AuraHandledException e) {
            System.assert(true);
        }

        try {
            FEC_RefundRequestController.saveRefundRequest(
                c.Id,
                0,
                new List<FEC_RefundRequestController.ReceiptLineDTO>()
            );
            expectAuraHandledException();
        } catch (AuraHandledException e) {
            System.assert(true);
        }

        try {
            FEC_RefundRequestController.saveRefundRequest(
                c.Id,
                100,
                new List<FEC_RefundRequestController.ReceiptLineDTO>()
            );
            expectAuraHandledException();
        } catch (AuraHandledException e) {
            System.assert(true);
        }

        try {
            FEC_RefundRequestController.saveRefundRequest(
                c.Id,
                100,
                new List<FEC_RefundRequestController.ReceiptLineDTO>{
                    newLine(String.valueOf(Date.today().addDays(1)), 100, 'T', 'C')
                }
            );
            expectAuraHandledException();
        } catch (AuraHandledException e) {
            System.assert(true);
        }

        try {
            FEC_RefundRequestController.saveRefundRequest(
                c.Id,
                100,
                new List<FEC_RefundRequestController.ReceiptLineDTO>{
                    newLine('not-a-date', 100, 'T', 'C')
                }
            );
            expectAuraHandledException();
        } catch (AuraHandledException e) {
            System.assert(true);
        }

        try {
            FEC_RefundRequestController.saveRefundRequest(
                c.Id,
                100,
                new List<FEC_RefundRequestController.ReceiptLineDTO>{
                    newLine(String.valueOf(Date.today()), 100, '', 'C')
                }
            );
            expectAuraHandledException();
        } catch (AuraHandledException e) {
            System.assert(true);
        }

        try {
            FEC_RefundRequestController.saveRefundRequest(
                c.Id,
                100,
                new List<FEC_RefundRequestController.ReceiptLineDTO>{
                    null,
                    new FEC_RefundRequestController.ReceiptLineDTO()
                }
            );
            expectAuraHandledException();
        } catch (AuraHandledException e) {
            System.assert(true);
        }

        try {
            FEC_RefundRequestController.saveRefundRequestDraft(null, 50, null);
            expectAuraHandledException();
        } catch (AuraHandledException e) {
            System.assert(true);
        }

        try {
            FEC_RefundRequestController.saveRefundRequest(
                '500000000000000AAA',
                100,
                validLine
            );
            expectAuraHandledException();
        } catch (AuraHandledException e) {
            System.assert(true);
        }
    }

    @IsTest
    static void testSaveDraft_Success() {
        Case c = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        FEC_RefundRequestController.saveRefundRequestDraft(
            c.Id,
            50000,
            new List<FEC_RefundRequestController.ReceiptLineDTO>{
                newLine(String.valueOf(Date.today()), 100, 'DRAFT', 'Bank')
            }
        );
        Test.stopTest();

        Case cUpdated = [
            SELECT FEC_Refund_Request_Draft__c
            FROM Case
            WHERE Id = :c.Id
        ];
        System.assertNotEquals(null, cUpdated.FEC_Refund_Request_Draft__c);
        System.assert(cUpdated.FEC_Refund_Request_Draft__c.contains('DRAFT'));
    }

    @IsTest
    static void testSaveRefundRequest_InvalidDetailIdInsertsNew() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        List<FEC_RefundRequestController.ReceiptLineDTO> lines =
            new List<FEC_RefundRequestController.ReceiptLineDTO>{
                newLine(
                    String.valueOf(Date.today()),
                    300,
                    'BAD-ID-ROW',
                    'Bank',
                    'not-a-valid-id'
                )
            };

        Test.startTest();
        FEC_RefundRequestController.saveRefundRequest(c.Id, 300, lines);
        Test.stopTest();

        System.assertEquals(
            1,
            [
                SELECT COUNT()
                FROM FEC_Case_Refund_Details__c
                WHERE FEC_Case__c = :c.Id AND FEC_Transaction_Number__c = 'BAD-ID-ROW'
            ]
        );
    }
}
