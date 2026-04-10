/**
 * Test Classes pour CVScoringService
 * Utilise HttpCalloutMock pour simuler l'API Groq
 */
@isTest
private class CVScoringServiceTest {

    // ─── Mock HTTP pour Groq API ───
    private class GroqMockHighScore implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"choices":[{"message":{"content":"{\\"score\\":75,\\"recommendation\\":\\"Bon profil technique\\",\\"points_forts\\":\\"- Java\\\\n- Salesforce\\",\\"points_faibles\\":\\"- Manque expérience management\\"}"}}]}');
            return res;
        }
    }

    private class GroqMockLowScore implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"choices":[{"message":{"content":"{\\"score\\":25,\\"recommendation\\":\\"Profil peu adapté\\",\\"points_forts\\":\\"- Motivation\\",\\"points_faibles\\":\\"- Pas d\'expérience technique\\"}"}}]}');
            return res;
        }
    }

    private class GroqMockError implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('{"error":"Internal Server Error"}');
            return res;
        }
    }

    @testSetup
    static void setup() {
        // Créer la config AI avec une clé fictive
        AI_Configuration__c config = new AI_Configuration__c(
            Groq_API_Key__c = 'test-api-key-for-unit-tests'
        );
        insert config;

        // Créer un Job Posting (Opportunity)
        Account acc = new Account(Name = 'Talan Tunisie Test');
        insert acc;

        Opportunity job = new Opportunity(
            Name = 'Développeur Salesforce Senior',
            AccountId = acc.Id,
            StageName = 'Gaming',
            CloseDate = Date.today().addDays(30),
            Description_Poste__c = 'Recherche développeur Salesforce 3+ ans expérience, LWC, Apex, SOQL',
            Departement__c = 'Salesforce',
            Localisation__c = 'Tunis',
            Type_de_Contrat__c = 'CDI'
        );
        insert job;
    }

    @isTest
    static void testScoreAboveThreshold_ShouldSetStatusAndScore() {
        Opportunity job = [SELECT Id FROM Opportunity LIMIT 1];

        Lead testLead = new Lead(
            FirstName = 'Ahmed',
            LastName = 'Ben Ali',
            Email = 'ahmed.benali.test@example.com',
            Company = 'Candidat',
            LeadSource = 'Talent Portal',
            Description = 'JOB_ID:' + job.Id + '\nPROFILE_TEXT:\nDéveloppeur Salesforce certifié avec 5 ans d\'expérience en Apex, LWC et intégrations API.'
        );
        insert testLead;

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new GroqMockHighScore());
        CVScoringService.scoreCVForLeads(new Set<String>{ testLead.Id });
        Test.stopTest();

        Lead updatedLead = [SELECT IsConverted, Score_Matching__c, Rating, Status FROM Lead WHERE Id = :testLead.Id];
        System.assertEquals(75, updatedLead.Score_Matching__c, 'Score doit être 75');
        System.assertEquals('Warm', updatedLead.Rating, 'Rating doit être Warm pour score 15-79');
        System.assertEquals(true, updatedLead.IsConverted, 'Lead doit être converti (score 75 > seuil 15)');
    }

    @isTest
    static void testScoreLowButAboveThreshold_ShouldSetStatusAndScore() {
        Opportunity job = [SELECT Id FROM Opportunity LIMIT 1];

        Lead testLead = new Lead(
            FirstName = 'Sara',
            LastName = 'Trabelsi',
            Email = 'sara.trabelsi.test@example.com',
            Company = 'Candidat',
            LeadSource = 'Talent Portal',
            Description = 'JOB_ID:' + job.Id + '\nPROFILE_TEXT:\nÉtudiante en marketing, pas d\'expérience technique.'
        );
        insert testLead;

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new GroqMockLowScore());
        CVScoringService.scoreCVForLeads(new Set<String>{ testLead.Id });
        Test.stopTest();

        Lead updatedLead = [SELECT IsConverted, Score_Matching__c, Rating, Status FROM Lead WHERE Id = :testLead.Id];
        System.assertEquals(25, updatedLead.Score_Matching__c, 'Score doit être 25');
        System.assertEquals('Warm', updatedLead.Rating, 'Rating Warm (score 25 > seuil 15)');
        System.assertEquals(true, updatedLead.IsConverted, 'Lead doit être converti (score 25 > seuil 15)');
    }

    @isTest
    static void testExecuteFullConversion_ShouldConvert() {
        Lead testLead = new Lead(
            FirstName = 'Convert',
            LastName  = 'Test',
            Email     = 'convert.test.direct@example.com',
            Company   = 'Candidat'
        );
        insert testLead;

        Test.startTest();
        CVScoringService.executeFullConversion(testLead.Id, 60);
        Test.stopTest();

        Lead updated = [SELECT IsConverted FROM Lead WHERE Id = :testLead.Id];
        System.assertEquals(true, updated.IsConverted, 'La conversion directe doit fonctionner');
    }

    @isTest
    static void testApiError_ShouldSetScoreZero() {
        Lead testLead = new Lead(
            FirstName = 'Test',
            LastName = 'Error',
            Email = 'test.error@example.com',
            Company = 'Candidat',
            LeadSource = 'Talent Portal',
            Description = 'PROFILE_TEXT:\nTest profil'
        );
        insert testLead;

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new GroqMockError());
        CVScoringService.scoreCVForLeads(new Set<String>{ testLead.Id });
        Test.stopTest();

        Lead updatedLead = [SELECT IsConverted, Score_Matching__c, Rating FROM Lead WHERE Id = :testLead.Id];
        System.assertEquals(false, updatedLead.IsConverted, 'Lead ne doit pas être converti en cas d\'erreur API');
        System.assertEquals(0, updatedLead.Score_Matching__c, 'Score doit être 0 en cas d\'erreur');
    }

    @isTest
    static void testEmptyLeadIds_ShouldNotFail() {
        Test.startTest();
        CVScoringService.scoreCVForLeads(null);
        CVScoringService.scoreCVForLeads(new Set<String>());
        Test.stopTest();
        // Pas d'erreur = succès
    }

    @isTest
    static void testAlreadyConvertedLead_ShouldSkip() {
        // Créer et convertir un Lead manuellement
        Lead testLead = new Lead(
            FirstName = 'Converti',
            LastName = 'Déjà',
            Email = 'converti.deja@example.com',
            Company = 'Candidat'
        );
        insert testLead;

        // Convertir manuellement
        Database.LeadConvert lc = new Database.LeadConvert();
        lc.setLeadId(testLead.Id);
        LeadStatus convertStatus = [SELECT MasterLabel FROM LeadStatus WHERE IsConverted=true LIMIT 1];
        lc.setConvertedStatus(convertStatus.MasterLabel);
        Database.convertLead(lc);

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new GroqMockHighScore());
        CVScoringService.scoreCVForLeads(new Set<String>{ testLead.Id });
        Test.stopTest();

        // Le Lead était déjà converti, donc aucune erreur et pas de re-traitement
        Lead reloaded = [SELECT IsConverted FROM Lead WHERE Id = :testLead.Id];
        System.assertEquals(true, reloaded.IsConverted);
    }
}
