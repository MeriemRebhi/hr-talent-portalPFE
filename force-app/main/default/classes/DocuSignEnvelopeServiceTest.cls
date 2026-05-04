@IsTest
private class DocuSignEnvelopeServiceTest {

    private static String lastEndpoint;
    private static String lastBody;

    private class EnvelopeCreateMock implements HttpCalloutMock {

        public HttpResponse respond(HttpRequest req) {
            DocuSignEnvelopeServiceTest.lastEndpoint = req.getEndpoint();
            DocuSignEnvelopeServiceTest.lastBody = req.getBody();

            HttpResponse res = new HttpResponse();
            res.setStatusCode(201);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"envelopeId":"env-new-001","status":"sent"}');
            return res;
        }
    }

    @IsTest
    static void testNoopWhenAlreadyActiveEnvelope() {
        Account acc = new Account(Name = 'DocuSign Service Test Account');
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'Candidature Already Sent',
            AccountId = acc.Id,
            StageName = 'Closed Won',
            CloseDate = Date.today().addDays(20),
            Is_Candidature__c = true,
            DocuSign_Envelope_Id__c = 'env-existing-001',
            Contract_Status__c = 'Sent'
        );
        insert opp;

        Test.startTest();
        DocuSignEnvelopeService.EnvelopeDispatchResult result = DocuSignEnvelopeService.sendContractForOpportunity(opp.Id);
        Test.stopTest();

        System.assertEquals(true, result.success);
        System.assertEquals('noop', result.status);
        System.assert(result.message != null && result.message.contains('already exists'));
    }

    @IsTest
    static void testNoopWhenNotCandidate() {
        Account acc = new Account(Name = 'DocuSign Non Candidate Account');
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'Regular Opportunity',
            AccountId = acc.Id,
            StageName = 'Closed Won',
            CloseDate = Date.today().addDays(20),
            Is_Candidature__c = false
        );
        insert opp;

        DocuSignEnvelopeService.EnvelopeDispatchResult result = DocuSignEnvelopeService.sendContractForOpportunity(opp.Id);

        System.assertEquals(true, result.success);
        System.assertEquals('noop', result.status);
        System.assert(result.message != null && result.message.contains('not a candidature'));
    }

    @IsTest
    static void testSendUsesVisualforceDocumentWhenNoTemplateConfigured() {
        Account acc = new Account(Name = 'DocuSign VF Account');
        insert acc;

        Contact cand = new Contact(
            LastName = 'Candidate',
            FirstName = 'Visualforce',
            Email = 'vf.candidate@example.com',
            AccountId = acc.Id
        );
        insert cand;

        Opportunity opp = new Opportunity(
            Name = 'Candidature Visualforce',
            AccountId = acc.Id,
            StageName = 'Closed Won',
            CloseDate = Date.today().addDays(30),
            Is_Candidature__c = true,
            Contract_Template_Id__c = null
        );
        insert opp;

        insert new OpportunityContactRole(
            OpportunityId = opp.Id,
            ContactId = cand.Id,
            Role = 'Decision Maker',
            IsPrimary = true
        );

        DocuSignConfigService.Config cfg = new DocuSignConfigService.Config();
        cfg.integrationKey = 'integration-key';
        cfg.userId = 'user-id';
        cfg.accountId = 'acc-001';
        cfg.baseUri = 'https://demo.docusign.net';
        cfg.oauthBaseUri = 'https://account-d.docusign.com';
        cfg.privateKeyPem = '-----BEGIN PRIVATE KEY-----abc-----END PRIVATE KEY-----';
        cfg.adminEmail = 'admin@example.com';
        cfg.defaultTemplateId = null;
        cfg.signerRoleName = 'Candidate';
        cfg.isEnabled = true;
        DocuSignConfigService.setTestConfig(cfg);

        DocuSignAuthService.AuthResult auth = new DocuSignAuthService.AuthResult();
        auth.accessToken = 'token-123';
        auth.accountId = 'acc-001';
        auth.baseUri = 'https://demo.docusign.net';
        DocuSignAuthService.setTestAuthResult(auth);

        DocuSignEnvelopeService.setTestContractPdfBlob(Blob.valueOf('%PDF-test%'));

        Test.setMock(HttpCalloutMock.class, new EnvelopeCreateMock());

        Test.startTest();
        DocuSignEnvelopeService.EnvelopeDispatchResult result = DocuSignEnvelopeService.sendContractForOpportunity(opp.Id);
        Test.stopTest();

        System.assertEquals(true, result.success);
        System.assertEquals('env-new-001', result.envelopeId);
        System.assert(DocuSignEnvelopeServiceTest.lastEndpoint != null && DocuSignEnvelopeServiceTest.lastEndpoint.endsWith('/envelopes'));
        System.assert(DocuSignEnvelopeServiceTest.lastBody != null && DocuSignEnvelopeServiceTest.lastBody.contains('"documents"'));
        System.assert(DocuSignEnvelopeServiceTest.lastBody.contains('/candidate_sign/'));
        System.assert(!DocuSignEnvelopeServiceTest.lastBody.contains('"templateId"'));

        Opportunity refreshed = [
            SELECT DocuSign_Envelope_Id__c, Contract_Status__c, Contract_Sent_At__c
            FROM Opportunity
            WHERE Id = :opp.Id
            LIMIT 1
        ];
        System.assertEquals('env-new-001', refreshed.DocuSign_Envelope_Id__c);
        System.assertEquals('Sent', refreshed.Contract_Status__c);
        System.assertNotEquals(null, refreshed.Contract_Sent_At__c);

        List<DocuSign_Envelope__c> envelopes = [
            SELECT Envelope_Id__c, Template_Id__c, Recipient_Email__c
            FROM DocuSign_Envelope__c
            WHERE Envelope_Id__c = 'env-new-001'
            LIMIT 1
        ];
        System.assertEquals(1, envelopes.size());
        System.assertEquals(null, envelopes[0].Template_Id__c);
        System.assertEquals('vf.candidate@example.com', envelopes[0].Recipient_Email__c);

        DocuSignEnvelopeService.setTestContractPdfBlob(null);
        DocuSignAuthService.setTestAuthResult(null);
        DocuSignConfigService.setTestConfig(null);
    }

    @IsTest
    static void testSendUsesTemplateWhenTemplateIdExists() {
        Account acc = new Account(Name = 'DocuSign Template Account');
        insert acc;

        Contact cand = new Contact(
            LastName = 'Candidate',
            FirstName = 'Template',
            Email = 'template.candidate@example.com',
            AccountId = acc.Id
        );
        insert cand;

        Opportunity opp = new Opportunity(
            Name = 'Candidature Template',
            AccountId = acc.Id,
            StageName = 'Closed Won',
            CloseDate = Date.today().addDays(30),
            Is_Candidature__c = true,
            Contract_Template_Id__c = 'tpl-opp-001'
        );
        insert opp;

        insert new OpportunityContactRole(
            OpportunityId = opp.Id,
            ContactId = cand.Id,
            Role = 'Decision Maker',
            IsPrimary = true
        );

        DocuSignConfigService.Config cfg = new DocuSignConfigService.Config();
        cfg.integrationKey = 'integration-key';
        cfg.userId = 'user-id';
        cfg.accountId = 'acc-001';
        cfg.baseUri = 'https://demo.docusign.net';
        cfg.oauthBaseUri = 'https://account-d.docusign.com';
        cfg.privateKeyPem = '-----BEGIN PRIVATE KEY-----abc-----END PRIVATE KEY-----';
        cfg.adminEmail = 'admin@example.com';
        cfg.defaultTemplateId = null;
        cfg.signerRoleName = 'Candidate';
        cfg.isEnabled = true;
        DocuSignConfigService.setTestConfig(cfg);

        DocuSignAuthService.AuthResult auth = new DocuSignAuthService.AuthResult();
        auth.accessToken = 'token-123';
        auth.accountId = 'acc-001';
        auth.baseUri = 'https://demo.docusign.net';
        DocuSignAuthService.setTestAuthResult(auth);

        Test.setMock(HttpCalloutMock.class, new EnvelopeCreateMock());

        Test.startTest();
        DocuSignEnvelopeService.EnvelopeDispatchResult result = DocuSignEnvelopeService.sendContractForOpportunity(opp.Id);
        Test.stopTest();

        System.assertEquals(true, result.success);
        System.assert(DocuSignEnvelopeServiceTest.lastBody != null && DocuSignEnvelopeServiceTest.lastBody.contains('"templateId":"tpl-opp-001"'));
        System.assert(DocuSignEnvelopeServiceTest.lastBody.contains('"templateRoles"'));
        System.assert(!DocuSignEnvelopeServiceTest.lastBody.contains('"documents"'));

        List<DocuSign_Envelope__c> envelopes = [
            SELECT Envelope_Id__c, Template_Id__c
            FROM DocuSign_Envelope__c
            WHERE Envelope_Id__c = 'env-new-001'
            LIMIT 1
        ];
        System.assertEquals(1, envelopes.size());
        System.assertEquals('tpl-opp-001', envelopes[0].Template_Id__c);

        DocuSignAuthService.setTestAuthResult(null);
        DocuSignConfigService.setTestConfig(null);
    }
}


