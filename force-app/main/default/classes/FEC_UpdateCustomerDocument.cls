public with sharing class FEC_UpdateCustomerDocument {
  //@thangtv update FEC_UpdateCustomerDocument API endpoint
  public static final String API_CONFIG_NAME = 'FEC_Update_Customer_Document';
  public static FEC_ResponseLog responseLog;
  public class UpdateDocumentRequest {
    public String CIFNumber;
    public String DocumentID;
    public String DocumentType;
    public String IssueDate;
    public String IDDocumentNumber;
    public String ExpirationDate;
    public String IssuePlace;
    public String OmnidocsLink;
  }

  public class UpdateDocumentResult {
    public String transId;
    public String dateTimeStr;
    public String code;
    public String description;
    public Integer httpStatus;
    public String rawResponse;
    public Boolean success;
    public String errorMessage;
  }

  
  private static final String REQUESTOR_ID = 'APS';

  public static String generateTransId() {
    return String.valueOf(UUID.randomUUID());
  }

  public static String formatTimestamp() {
    return Datetime.now().formatGMT('yyyy-MM-dd\'T\'HH:mm:ss');
  }

  private static String escapeXml(String s) {
    if (s == null)
      return '';
    return s.replace('&', '&amp;')
      .replace('<', '&lt;')
      .replace('>', '&gt;')
      .replace('"', '&quot;')
      .replace('\'', '&apos;');
  }

  public static String buildEnvelope(
    UpdateDocumentRequest r,
    String transId,
    String timestamp
  ) {
    validate(r, transId, timestamp);

    String env = '';
    env += '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:cif="http://fecredit.com.vn/CIF_CustomerInfoUpdate">';
    env += '<soapenv:Header/>';
    env += '<soapenv:Body>';
    env += '<cif:UpdateCustomerDocument>';
    env += '<Sys>';
    env += '<TransID>' + escapeXml(transId) + '</TransID>';
    env += '<RequestorID>' + escapeXml(REQUESTOR_ID) + '</RequestorID>';
    env += '<DateTime>' + escapeXml(timestamp) + '</DateTime>';
    env += '</Sys>';
    env += '<CIFNumber>' + escapeXml(r.CIFNumber) + '</CIFNumber>';
    env += '<Document>';
    env += '<DocumentID>' + escapeXml(r.DocumentID) + '</DocumentID>';
    env += '<DocumentType>' + escapeXml(r.DocumentType) + '</DocumentType>';
    if (r.IssueDate != null)
      env += '<IssueDate>' + escapeXml(r.IssueDate) + '</IssueDate>';
    if (r.IDDocumentNumber != null)
      env +=
        '<IDDocumentNumber>' +
        escapeXml(r.IDDocumentNumber) +
        '</IDDocumentNumber>';
    if (r.ExpirationDate != null)
      env +=
        '<ExpirationDate>' +
        escapeXml(r.ExpirationDate) +
        '</ExpirationDate>';
    if (r.IssuePlace != null)
      env += '<IssuePlace>' + escapeXml(r.IssuePlace) + '</IssuePlace>';
    if (r.OmnidocsLink != null)
      env += '<OmnidocsLink>' + escapeXml(r.OmnidocsLink) + '</OmnidocsLink>';
    env += '</Document>';
    env += '</cif:UpdateCustomerDocument>';
    env += '</soapenv:Body>';
    env += '</soapenv:Envelope>';
    return env;
  }

  public static HttpResponse sendRequest(String envelope) {

    FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
    FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance(API_CONFIG_NAME);

    // ✅ build endpoint from metadata
    String endpoint =
        (String.isNotBlank(apiSetting?.FEC_Endpoint__c) ? apiSetting.FEC_Endpoint__c : '') +
        (String.isNotBlank(apiConfig?.FEC_Endpoint__c) ? apiConfig.FEC_Endpoint__c : '');

    System.debug('FINAL endpoint = ' + endpoint);

    if (String.isBlank(endpoint)) {
        throw new CalloutException(System.Label.FEC_MSG_Endpoint_Null);
    }

    HttpRequest req = new HttpRequest();
    req.setEndpoint(endpoint);
    req.setMethod('POST');
    req.setHeader('Content-Type', 'text/xml; charset=utf-8');
    req.setBody(envelope);

    Http http = new Http();
    return http.send(req);
  }

  public static UpdateDocumentResult parseResponse(
    String xml,
    Integer httpStatus
  ) {
    UpdateDocumentResult res = new UpdateDocumentResult();
    res.httpStatus = httpStatus;
    res.rawResponse = xml;
    if (xml == null) {
      res.errorMessage = 'Empty response body';
      res.success = false;
      return res;
    }
    try {
      Dom.Document doc = new Dom.Document();
      doc.load(xml);
      Dom.XmlNode envelope = doc.getRootElement();
      Dom.XmlNode body = envelope.getChildElement(
        'Body',
        'http://schemas.xmlsoap.org/soap/envelope/'
      );
      if (body == null) {
        res.errorMessage = 'No SOAP Body';
        res.success = false;
        return res;
      }
      Dom.XmlNode responseNode = body.getChildElement(
        'UpdateCustomerDocumentResponse',
        'http://fecredit.com.vn/CIF_CustomerInfoUpdate'
      );
      if (responseNode == null) {
        for (Dom.XmlNode n : body.getChildElements()) {
          if (n.getName().endsWith('UpdateCustomerDocumentResponse')) {
            responseNode = n;
            break;
          }
        }
      }
      if (responseNode == null) {
        res.errorMessage = 'No UpdateCustomerDocumentResponse found';
        res.success = false;
        return res;
      }
      Dom.XmlNode sys = responseNode.getChildElement('Sys', null);
      if (sys == null) {
        res.errorMessage = 'No Sys node in response';
        res.success = false;
        return res;
      }
      Dom.XmlNode t = sys.getChildElement('TransID', null);
      Dom.XmlNode dt = sys.getChildElement('DateTime', null);
      Dom.XmlNode c = sys.getChildElement('Code', null);
      Dom.XmlNode d = sys.getChildElement('Description', null);
      res.transId = (t != null) ? t.getText() : null;
      res.dateTimeStr = (dt != null) ? dt.getText() : null;
      res.code = (c != null) ? c.getText() : null;
      res.description = (d != null) ? d.getText() : null;
      res.success = (res.code == '0' || res.code == '4');
    } catch (Exception ex) {
      res.errorMessage = 'XML parse error: ' + ex.getMessage();
      res.success = false;
    }
    return res;
  }

  public static UpdateDocumentResult updateCustomerDocument(
    UpdateDocumentRequest req
  ) {
    UpdateDocumentResult finalRes = new UpdateDocumentResult();
    String transId = generateTransId();
    String timestamp = formatTimestamp();
    String envelope = buildEnvelope(req, transId, timestamp);

    HttpResponse httpRes;
    Integer status;

    try {
        httpRes = sendRequest(envelope);

        status = (httpRes == null) ? null : httpRes.getStatusCode();
        String body = (httpRes == null) ? null : httpRes.getBody();

        finalRes = parseResponse(body, status);

        if (finalRes.transId == null)
            finalRes.transId = transId;

        if (finalRes.httpStatus == null)
            finalRes.httpStatus = status;

        if (finalRes.rawResponse == null)
            finalRes.rawResponse = body;

        // ✅ LOG SUCCESS
        logApiFull(
            API_CONFIG_NAME,
            'POST',
            req,
            body,
            finalRes.success,
            String.valueOf(status),
            null,
            finalRes.transId
        );

    } catch (Exception ex) {

        finalRes.errorMessage = 'Callout error: ' + ex.getMessage();
        finalRes.success = false;

        // ✅ derive status properly
        String statusCode = status != null ? String.valueOf(status) : null;

        logApiFull(
            API_CONFIG_NAME,
            'POST',
            req,
            null,
            false,
            statusCode,
            ex.getMessage(),
            transId
        );

        System.debug('ERROR: ' + ex.getMessage());
        System.debug('STACK: ' + ex.getStackTraceString());
    }

    return finalRes;
  }

  private static void validate(
    UpdateDocumentRequest req,
    String transId,
    String timestamp
  ) {
    if (String.isBlank(transId)) {
      throw new FEC_APIServiceException('Transaction ID is required.');
    }

    if (String.isBlank(timestamp)) {
      throw new FEC_APIServiceException('DateTime is required.');
    }

    if (String.isBlank(REQUESTOR_ID)) {
      throw new FEC_APIServiceException('RequestorID ID is required.');
    }

    if (String.isEmpty(req.CIFNumber)) {
      throw new FEC_APIServiceException('CIFNumber is required.');
    } else if (!FEC_CommonUltils.isLengthValid(req.CIFNumber, 255)) {
      throw new FEC_APIServiceException(
        'CIFNumber exceeds maximum length of 255 characters.'
      );
    }

    if (
      req.IssueDate != null &&
      !FEC_CommonUltils.isValidDateByFormat(req.IssueDate)
    ) {
      throw new FEC_APIServiceException(
        'IssueDate must be in the format YYYY-MM-DD.'
      );
    }

    if (
      req.ExpirationDate != null &&
      !FEC_CommonUltils.isValidDateByFormat(req.ExpirationDate)
    ) {
      throw new FEC_APIServiceException(
        'ExpirationDate must be in the format YYYY-MM-DD.'
      );
    }

    if (String.isEmpty(req.DocumentID)) {
      throw new FEC_APIServiceException('DocumentID is required.');
    }

    if (String.isEmpty(req.DocumentType)) {
      throw new FEC_APIServiceException('DocumentType is required.');
    }

    if (String.isEmpty(req.IssueDate)) {
      throw new FEC_APIServiceException('IssueDate is required.');
    }
  }
  private static void logApiFull(
    String endpoint,
    String method,
    Object requestObj,
    Object responseObj,
    Boolean isSuccess,
    String statusCode,
    String errorMessage,
    String transactionId
  ) {
    try {
        HttpResponse apiResponse = new HttpResponse();
        apiResponse.setStatusCode(isSuccess ? 200 : 500);
        apiResponse.setBody(FEC_CommonUltils.serializeSafe(responseObj));

        FEC_CommonUltils.logApi(
            API_CONFIG_NAME,
            endpoint,
            method,
            FEC_CommonUltils.serializeSafe(requestObj),
            apiResponse,
            errorMessage
        );

    } catch (Exception e) {
        System.debug('LOG_API_ERROR: ' + e.getMessage());
    }
  }
}