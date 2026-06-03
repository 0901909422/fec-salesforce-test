@IsTest
private class FEC_CMSIPPBlockWSMock_Test {

    @IsTest
    static void testMockResponseUsage() {
        // 1. Gán Mock class vào Test context
        Test.setMock(HttpCalloutMock.class, new FEC_CMSIPPBlockWSMock());

        // 2. Thực hiện gọi callout
        // Lưu ý: Thay 'FEC_CheckEligibilityIPPCallout' bằng tên lớp Service thực tế của bạn
        Test.startTest();
        
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:MyEndpoint'); // Giả lập endpoint
        req.setMethod('POST');
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        Test.stopTest();

        // 3. Xác minh Mock đã hoạt động
        System.assertEquals(200, res.getStatusCode(), 'Status code phải là 200 từ Mock.');
        System.assert(res.getBody().contains('NS1:CMSIPPBlockResponse'), 'Body phải chứa XML trả về từ Mock.');
        System.assert(res.getBody().contains('AvailableCredit'), 'Body phải chứa tag AvailableCredit.');
    }
}