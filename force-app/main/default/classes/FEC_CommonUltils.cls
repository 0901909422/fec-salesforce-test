public with sharing class FEC_CommonUltils {

  public static String getXmlValue(Dom.XmlNode n, String name) {
    Dom.XmlNode c = (n == null) ? null : n.getChildElement(name, null);
    return (c == null) ? null : c.getText();
  }

  public static Decimal xmlValToDecimal(Dom.XmlNode n, String name) {
    String v = getXmlValue(n, name);
    return String.isBlank(v) ? null : Decimal.valueOf(v);
  }

  public static Date xmlValToDate(Dom.XmlNode n, String name) {
    String v = getXmlValue(n, name);
    return parseDate(v);
  }

  public static Dom.XmlNode findChildByName(Dom.XmlNode parent, String nodeName) {
    if (parent == null) return null;
    for (Dom.XmlNode child : parent.getChildElements()) {
      if (child.getName() == nodeName || child.getName().endsWith(':' + nodeName)) {
        return child;
      }
    }
    return null;
  }

  public static Integer toInt(String v) {
    return String.isBlank(v) ? null : Integer.valueOf(v);
  }

  public static Date toDate(String v) {
    return String.isBlank(v) ? null : Date.valueOf(v);
  }

  public static Datetime toDatetime(String v) {
    return String.isBlank(v) ? null : Datetime.valueOf(v.replace('T', ' '));
  }

  /**
   * Mask số thẻ: hiển thị 6 số đầu và 4 số cuối, các số còn lại là '*'
   */
  public static String maskCardNumber(String cardNumber) {
    if (String.isBlank(cardNumber) || cardNumber.length() < 10) {
      return cardNumber;
    }
    String first6 = cardNumber.substring(0, 6);
    String last4 = cardNumber.substring(cardNumber.length() - 4);
    String middle = '';
    for (Integer i = 6; i < cardNumber.length() - 4; i++) {
      middle += '*';
    }
    return first6 + middle + last4;
  }
  
  /**
   * Format API trả về: yyyyMMdd (VD: 20281031) hoặc YYYY-MM-DD
   * @param dateStr - Chuỗi ngày tháng từ API
   * @return Đối tượng Date
   */
  public static Date parseDate(String dateStr) {
    if (String.isBlank(dateStr)) return null;
    
    // Loại bỏ trường hợp 00000000 (không có ngày)
    if (dateStr == '00000000' || dateStr == '0') return null;
    
    try {
      // Format API trả về: yyyyMMdd (VD: 20281031)
      if (dateStr.length() == 8 && dateStr.isNumeric()) {
        Integer year = Integer.valueOf(dateStr.substring(0, 4));
        Integer month = Integer.valueOf(dateStr.substring(4, 6));
        Integer day = Integer.valueOf(dateStr.substring(6, 8));
        return Date.newInstance(year, month, day);
      }
      
      // Fallback: Format YYYY-MM-DD
      return Date.valueOf(dateStr); 
    } catch (Exception e) {
      System.debug('convertDateSafeForOtherCard error for "' + dateStr + '": ' + e.getMessage());
      return null;
    }
  }

  public static Datetime parseDateTime(String dateTimeStr) {
    if (String.isBlank(dateTimeStr)) {
      return null;
    }
    try {
      // Format: 2025-10-31T14:00:10.491Z
      dateTimeStr = dateTimeStr.replace('T', ' ').replace('Z', '');
      if (dateTimeStr.contains('.')) {
          dateTimeStr = dateTimeStr.substringBefore('.');
      }
      return Datetime.valueOf(dateTimeStr);
    } catch (Exception e) {
      System.debug('Failed to parse datetime: ' + dateTimeStr + ', Error: ' + e.getMessage());
      return null;
    }
  }

  public static HttpResponse calloutApi(String endpoint, String method, String contentType, String soapAction, Dom.Document docBody, String body) {
    HttpRequest req = new HttpRequest();
    req.setEndpoint(endpoint);
    req.setMethod(method);
    req.setHeader('Content-Type', contentType);
    if (String.isNotBlank(soapAction)) {
      req.setHeader('SOAPAction', soapAction);
    }
    if (docBody != null) {
      req.setBodyDocument(docBody);
    } else {
      req.setBody(body);
    }
    req.setTimeout(120000); // 120 seconds timeout

    Http http = new Http();
    HttpResponse res = http.send(req);
    return res;
  }

  public static String generateTransactionId() {
    return Datetime.now().getTime() + '_' + String.valueOf(Math.abs(Crypto.getRandomInteger())).substring(0, 6);
  }

  public static String formatCurrency(Decimal amount, Integer scale) {
    if (amount == null) return '';
    return amount.setScale(scale).format();
  }

  public static String formatDate(Date d) {
    if (d == null) return '';
    return d.format();
  }

  public static String decimalToString(Decimal d) {
    return d == null ? '' : d.format();
  }
}