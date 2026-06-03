@IsTest
private class FEC_InlineImageUtil_Test {
    private class InlineImageMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            String endpoint = req.getEndpoint();
            HttpResponse res = new HttpResponse();

            if (endpoint.contains('rtaImage-ok')) {
                res.setStatusCode(200);
                res.setHeader('Content-Type', 'image/jpeg; charset=utf-8');
                res.setBodyAsBlob(Blob.valueOf('jpeg-bytes'));
                return res;
            }
            if (endpoint.contains('rtaImage-redirect')) {
                res.setStatusCode(302);
                res.setHeader('Location', 'https://cdn.example.com/rtaImage-gif');
                return res;
            }
            if (endpoint.contains('rtaImage-gif')) {
                res.setStatusCode(200);
                res.setHeader('Content-Type', 'image/gif');
                res.setBodyAsBlob(Blob.valueOf('gif-bytes'));
                return res;
            }
            if (endpoint.contains('rtaImage-nocontenttype')) {
                res.setStatusCode(200);
                res.setBodyAsBlob(Blob.valueOf('png-bytes'));
                return res;
            }
            if (endpoint.contains('rtaImage-fail')) {
                res.setStatusCode(500);
                res.setBody('error');
                return res;
            }
            if (endpoint.contains('rtaImage-throw')) {
                // Simulate network/runtime error branch
                Integer x = 1 / 0;
            }

            res.setStatusCode(404);
            res.setBody('not found');
            return res;
        }
    }

    @IsTest
    static void testConvertRtaImagesToCid_blankHtml() {
        FEC_InlineImageUtil.InlineImageResult out = FEC_InlineImageUtil.convertRtaImagesToCid(null);
        System.assertEquals(null, out.htmlBody);
        System.assertEquals(0, out.attachments.size());
    }

    @IsTest
    static void testConvertRtaImagesToCid_successDuplicateAndFallbackType() {
        Test.setMock(HttpCalloutMock.class, new InlineImageMock());
        String html =
            '<p>A</p>' +
            '<img src="https://img.example.com/rtaImage-ok?id=1" />' +
            '<img src="https://img.example.com/rtaImage-ok?id=1" />' +
            '<img src="https://img.example.com/rtaImage-nocontenttype?id=2&amp;x=1" />';

        Test.startTest();
        FEC_InlineImageUtil.InlineImageResult out = FEC_InlineImageUtil.convertRtaImagesToCid(html);
        Test.stopTest();

        System.assertNotEquals(null, out);
        System.assertEquals(2, out.attachments.size(), 'Duplicate URL should reuse CID and avoid new attachment.');
        System.assert(out.htmlBody.contains('cid:inline_image_1.jpg'));
        System.assert(out.htmlBody.contains('cid:inline_image_2.png'));
    }

    @IsTest
    static void testConvertRtaImagesToCid_redirectAndErrorBranches() {
        Test.setMock(HttpCalloutMock.class, new InlineImageMock());
        String html =
            '<img src="https://img.example.com/rtaImage-redirect?id=3" />' +
            '<img src="https://img.example.com/rtaImage-fail?id=4" />' +
            '<img src="https://img.example.com/rtaImage-throw?id=5" />';

        Test.startTest();
        FEC_InlineImageUtil.InlineImageResult out = FEC_InlineImageUtil.convertRtaImagesToCid(html);
        Test.stopTest();

        System.assertEquals(1, out.attachments.size(), 'Only redirect->200 image should be attached.');
        System.assert(out.htmlBody.contains('cid:inline_image_1.gif'));
        System.assert(out.htmlBody.contains('rtaImage-fail'), 'Failed URL should remain unchanged.');
        System.assert(out.htmlBody.contains('rtaImage-throw'), 'Exception URL should remain unchanged.');
    }
}
