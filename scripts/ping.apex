System.debug('ping - check org compile status');
// Check FEC_UpdateCustomerAddress có lỗi không
try {
    Type t = Type.forName('FEC_UpdateCustomerAddress');
    System.debug('FEC_UpdateCustomerAddress type: ' + t);
} catch(Exception e) {
    System.debug('FEC_UpdateCustomerAddress error: ' + e.getMessage());
}
