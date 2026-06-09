@IsTest
private class FEC_SearchByListPhonesSvcCallout_Test {

    // 1. Tạo Mock Class để giả lập phản hồi từ HTTP Callout
    public class PhoneSearchHttpMock implements HttpCalloutMock {
        private Integer statusCode;
        private String responseBody;

        public PhoneSearchHttpMock(Integer statusCode, String responseBody) {
            this.statusCode = statusCode;
            this.responseBody = responseBody;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody(this.responseBody);
            res.setStatusCode(this.statusCode);
            res.setStatus(this.statusCode == 200 ? 'OK' : 'Internal Server Error');
            return res;
        }
    }

    @TestSetup
    static void setupData() {
        // Tạo dữ liệu Custom Setting để tránh NullPointerException khi lấy Endpoint
        FEC_API_Setting__c apiSetting = new FEC_API_Setting__c(
            FEC_Endpoint__c = 'https://api.mockfecredit.com'
        );
        insert apiSetting;
    }

    @IsTest
    static void testSearchByListPhones_Success() {
        // Chuẩn bị JSON phản hồi giả lập khớp với cấu trúc Wrapper Classes
        String jsonResponse = '{' +
            '"pxObjClass": "Data-Test",' +
            '"result": [{' +
                '"agentCode": "AG001",' +
                '"buyerName": "Nguyen Van A",' +
                '"buyerPhone": "0901234567",' +
                '"collectedPremiumFee": 500000.0' +
            '}],' +
            '"sys2": {' +
                '"code2": "0",' +
                '"description2": "Success",' +
                '"transID2": "TRANS-123"' +
            '}' +
        '}';

        // Thiết lập Mock cho Callout
        Test.setMock(HttpCalloutMock.class, new PhoneSearchHttpMock(200, jsonResponse));

        List<String> listPhones = new List<String>{'0901234567'};

        Test.startTest();
        // Gọi hàm Callout
        FEC_SearchByListPhonesServiceCallout.PhonesResponse response = 
            FEC_SearchByListPhonesServiceCallout.searchByListPhones(listPhones);
        Test.stopTest();

        // Kiểm tra kết quả trả về
        System.assertNotEquals(null, response, 'Response không được null.');
        System.assertEquals('Data-Test', response.pxObjClass, 'pxObjClass phải được parse đúng.');
        
        // Kiểm tra danh sách Result
        System.assertNotEquals(null, response.result, 'Danh sách result không được null.');
        System.assertEquals(1, response.result.size(), 'Phải có 1 bản ghi result.');
        System.assertEquals('Nguyen Van A', response.result[0].buyerName, 'Tên người mua phải khớp.');
        System.assertEquals(500000.0, response.result[0].collectedPremiumFee, 'Phí bảo hiểm phải khớp.');

        // Kiểm tra phần Sys2
        System.assertNotEquals(null, response.sys2, 'Sys2 không được null.');
        System.assertEquals('0', response.sys2.code2, 'Code2 phải là 0.');
    }

    @IsTest
    static void testSearchByListPhones_HttpError() {
        // Thiết lập Mock trả về lỗi HTTP 500
        Test.setMock(HttpCalloutMock.class, new PhoneSearchHttpMock(500, 'Server Error'));

        List<String> listPhones = new List<String>{'0909999999'};

        Test.startTest();
        FEC_SearchByListPhonesServiceCallout.PhonesResponse response = 
            FEC_SearchByListPhonesServiceCallout.searchByListPhones(listPhones);
        Test.stopTest();

        // Kiểm tra logic xử lý lỗi (khi status code >= 300)
        System.assertNotEquals(null, response, 'Response không được null ngay cả khi lỗi.');
        System.assertEquals(null, response.result, 'Result list phải null do không deserialize.');
        
        // Kiểm tra Sys2 được tạo thủ công trong khối bắt lỗi
        System.assertNotEquals(null, response.sys2, 'Sys2 phải được khởi tạo để chứa thông tin lỗi.');
        System.assertEquals('500', response.sys2.code2, 'Mã lỗi HTTP phải được lưu vào code2.');
        System.assert(response.sys2.description2.contains('HTTP Error'), 'Description phải chứa chuỗi HTTP Error.');
    }
}