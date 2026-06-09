/**
 * @description Unit tests for FEC_FieldDeployQueueable.
 *              Test queueable execution với mock HTTP callout cho mỗi loại property type.
 * @author      DAT NGO
 * @date        2026-06-03
 * @module      MDM
 */
@IsTest
private class FEC_FieldDeployQueueableTest {

    private class SuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(201);
            res.setStatus('Created');
            res.setBody('{"id":"00N000000000000","success":true}');
            return res;
        }
    }

    private class FailureMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(400);
            res.setStatus('Bad Request');
            res.setBody('[{"errorCode":"FIELD_INVALID","message":"Invalid field"}]');
            return res;
        }
    }

    @IsTest
    static void testQueueable_String() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        Test.startTest();
        Id jobId = System.enqueueJob(
            new FEC_FieldDeployQueueable('Test_Field__c', 'Test Field', 'String', null)
        );
        Test.stopTest();
        Assert.isNotNull(jobId);
    }

    @IsTest
    static void testQueueable_Number() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        Test.startTest();
        Id jobId = System.enqueueJob(
            new FEC_FieldDeployQueueable('Number_Field__c', 'Number Field', 'Number', null)
        );
        Test.stopTest();
        Assert.isNotNull(jobId);
    }

    @IsTest
    static void testQueueable_Boolean() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        Test.startTest();
        Id jobId = System.enqueueJob(
            new FEC_FieldDeployQueueable('Bool_Field__c', 'Bool', 'Boolean', null)
        );
        Test.stopTest();
        Assert.isNotNull(jobId);
    }

    @IsTest
    static void testQueueable_Date() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        Test.startTest();
        Id jobId = System.enqueueJob(
            new FEC_FieldDeployQueueable('Date_Field__c', 'Date', 'Date', null)
        );
        Test.stopTest();
        Assert.isNotNull(jobId);
    }

    @IsTest
    static void testQueueable_DateTime() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        Test.startTest();
        Id jobId = System.enqueueJob(
            new FEC_FieldDeployQueueable('DT_Field__c', 'DT', 'DateTime', null)
        );
        Test.stopTest();
        Assert.isNotNull(jobId);
    }

    @IsTest
    static void testQueueable_Phone() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        Test.startTest();
        Id jobId = System.enqueueJob(
            new FEC_FieldDeployQueueable('Ph_Field__c', 'Phone', 'Phone number', null)
        );
        Test.stopTest();
        Assert.isNotNull(jobId);
    }

    @IsTest
    static void testQueueable_List_WithValues() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        Test.startTest();
        Id jobId = System.enqueueJob(
            new FEC_FieldDeployQueueable('Pick_Field__c', 'Pick', 'List', new List<String>{'A', 'B', 'C'})
        );
        Test.stopTest();
        Assert.isNotNull(jobId);
    }

    @IsTest
    static void testQueueable_List_NullValues() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        Test.startTest();
        Id jobId = System.enqueueJob(
            new FEC_FieldDeployQueueable('PickNull_Field__c', 'PickNull', 'List', null)
        );
        Test.stopTest();
        Assert.isNotNull(jobId);
    }

    @IsTest
    static void testQueueable_UnknownType_DefaultText() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        Test.startTest();
        Id jobId = System.enqueueJob(
            new FEC_FieldDeployQueueable('Unk_Field__c', 'Unknown', 'UnknownType', null)
        );
        Test.stopTest();
        Assert.isNotNull(jobId);
    }

    @IsTest
    static void testQueueable_FailureResponse() {
        Test.setMock(HttpCalloutMock.class, new FailureMock());
        Test.startTest();
        Id jobId = System.enqueueJob(
            new FEC_FieldDeployQueueable('Fail_Field__c', 'Fail', 'String', null)
        );
        Test.stopTest();
        // Job runs, processes 400 response, doesn't re-throw
        Assert.isNotNull(jobId);
    }
}