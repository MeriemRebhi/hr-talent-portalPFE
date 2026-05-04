@IsTest
private class DocuSignWebhookRestTest {

    @IsTest
    static void testExtractEventFromJson() {
        String payload = '{"event":"envelope-completed","data":{"envelopeId":"env-001","status":"completed"}}';
        Map<String, String> parsed = DocuSignWebhookRest.extractEvent(payload);

        System.assertEquals('env-001', parsed.get('envelopeId'));
        System.assertEquals('envelope-completed', parsed.get('eventType'));
        System.assertEquals('completed', parsed.get('status'));
    }

    @IsTest
    static void testExtractEventFromXml() {
        String payload =
            '<DocuSignEnvelopeInformation>' +
                '<envelopeStatus>' +
                    '<envelopeID>env-xml-123</envelopeID>' +
                    '<status>sent</status>' +
                '</envelopeStatus>' +
            '</DocuSignEnvelopeInformation>';

        Map<String, String> parsed = DocuSignWebhookRest.extractEvent(payload);

        System.assertEquals('env-xml-123', parsed.get('envelopeId'));
        System.assertEquals('sent', parsed.get('status'));
    }

    @IsTest
    static void testVerifyHmac() {
        String payload = '{"envelopeId":"env-123"}';
        String secret = 'super-secret';

        Blob mac = Crypto.generateMac('HmacSHA256', Blob.valueOf(payload), Blob.valueOf(secret));
        String signature = EncodingUtil.base64Encode(mac);

        System.assertEquals(true, DocuSignWebhookRest.verifyHmac(payload, signature, secret));
        System.assertEquals(false, DocuSignWebhookRest.verifyHmac(payload, 'bad-signature', secret));
    }

    @IsTest
    static void testProcessWebhookSentUpdatesOpportunityAndEnvelope() {
        Account acc = new Account(Name = 'DocuSign Webhook Test Account');
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'Candidature QA Webhook',
            AccountId = acc.Id,
            StageName = 'Closed Won',
            CloseDate = Date.today().addDays(15),
            Is_Candidature__c = true,
            DocuSign_Envelope_Id__c = 'env-hook-001',
            Contract_Status__c = 'Sent'
        );
        insert opp;

        DocuSign_Envelope__c env = new DocuSign_Envelope__c(
            Envelope_Id__c = 'env-hook-001',
            Opportunity__c = opp.Id,
            Status__c = 'sent'
        );
        insert env;

        DocuSignWebhookRest.processWebhook(
            'env-hook-001',
            'sent',
            '{"event":"envelope-sent","data":{"envelopeId":"env-hook-001","status":"sent"}}'
        );

        Opportunity refreshed = [
            SELECT Contract_Status__c, Contract_Sent_At__c
            FROM Opportunity
            WHERE Id = :opp.Id
            LIMIT 1
        ];
        System.assertEquals('Sent', refreshed.Contract_Status__c);
        System.assertNotEquals(null, refreshed.Contract_Sent_At__c);

        DocuSign_Envelope__c envRefreshed = [
            SELECT Status__c, Last_Webhook_At__c
            FROM DocuSign_Envelope__c
            WHERE Id = :env.Id
            LIMIT 1
        ];
        System.assertEquals('sent', envRefreshed.Status__c);
        System.assertNotEquals(null, envRefreshed.Last_Webhook_At__c);
    }
}
