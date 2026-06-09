@IsTest
private class FEC_APIServiceException_Test {

    @IsTest
    static void testExceptionCanBeThrownAndCaught() {
        Boolean caught = false;
        try {
            throw new FEC_APIServiceException('API failure');
        } catch (FEC_APIServiceException e) {
            caught = true;
            System.assertEquals('API failure', e.getMessage());
        }
        System.assertEquals(true, caught);
    }
}
