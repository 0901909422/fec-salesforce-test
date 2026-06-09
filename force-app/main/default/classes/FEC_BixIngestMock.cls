@isTest
public class FEC_BixIngestMock implements HttpCalloutMock {
    private Integer statusCode;
    private String responseBody;

    public FEC_BixIngestMock(Integer statusCode, String responseBody) {
        this.statusCode = statusCode;
        this.responseBody = responseBody;
    }

    public HttpResponse respond(HttpRequest req) {
        HttpResponse res = new HttpResponse();
        res.setStatusCode(statusCode);
        res.setBody(responseBody);
        return res;
    }
}
