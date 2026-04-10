// Vérification que tout est en place, puis test E2E complet

// 1. Vérifier Platform Event
Boolean hasPlatformEvent = false;
try {
    Lead_Convert_Request__e evt = new Lead_Convert_Request__e(Lead_Id__c = 'test', Score__c = 0);
    hasPlatformEvent = true;
    System.debug('✅ Platform Event Lead_Convert_Request__e déployé');
} catch (Exception e) {
    System.debug('❌ Platform Event ABSENT — redéployer dabord !');
}

// 2. Créer un Lead de test
Opportunity job = [SELECT Id FROM Opportunity WHERE RecordType.DeveloperName = 'Job_Posting' LIMIT 1];
if (job == null) {
    System.debug('❌ Aucune offre Job_Posting trouvée');
    return;
}

Lead testLead = new Lead(
    FirstName = 'Test',
    LastName = 'AutoConvert',
    Email = 'test.autoconvert.' + System.currentTimeMillis() + '@example.com',
    Company = 'Candidat',
    LeadSource = 'Talent Portal',
    Description = 'JOB_ID:' + job.Id + '\nPROFILE_TEXT:\nDéveloppeur Java 5 ans expérience Spring Boot Microservices'
);
Database.DMLOptions dml = new Database.DMLOptions();
dml.DuplicateRuleHeader.allowSave = true;
Database.insert(testLead, dml);
System.debug('✅ Lead créé: ' + testLead.Id + ' | Email: ' + testLead.Email);

// 3. Simuler un score > 15 directement (sans appel Groq)
testLead.Score_Matching__c = 60;
testLead.AI_Recommendation__c = 'Test automatique - bon profil';
testLead.Rating = 'Warm';
testLead.Status = 'Condidature - Validée- Email Envoyé';
update testLead;

// 4. Publier le Platform Event (si disponible)
if (hasPlatformEvent) {
    EventBus.publish(new Lead_Convert_Request__e(
        Lead_Id__c = testLead.Id,
        Score__c   = 60
    ));
    System.debug('📤 Platform Event publié — conversion asynchrone déclenchée');
    System.debug('⏳ Attendre 10-30 secondes puis vérifier avec:');
    System.debug('   sf data query --query "SELECT Id, IsConverted, Status FROM Lead WHERE Id = \'' + testLead.Id + '\'" --target-org meriem.rebhi.d6f3e18c6a1f@agentforce.com');
} else {
    // Fallback : conversion directe
    System.debug('⚠️ Platform Event absent — conversion directe (admin)');
    CVScoringService.executeFullConversion(testLead.Id, 60);
    Lead result = [SELECT IsConverted, Status FROM Lead WHERE Id = :testLead.Id];
    System.debug('Résultat: IsConverted=' + result.IsConverted + ' | Status=' + result.Status);
}
