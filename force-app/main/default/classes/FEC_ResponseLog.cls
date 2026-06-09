public class FEC_ResponseLog {
    public String apiName;
    public String endpoint;
    public String method;
    public String requestBody;
    public HttpResponse response;
    public String errorMessage;

    public FEC_ResponseLog(String apiName, String endpoint, String method, String requestBody, HttpResponse response, String errorMessage) {
        this.apiName = apiName;
        this.endpoint = endpoint;
        this.method = method;
        this.requestBody = requestBody;
        this.response = response;
        this.errorMessage = errorMessage;
    }
}