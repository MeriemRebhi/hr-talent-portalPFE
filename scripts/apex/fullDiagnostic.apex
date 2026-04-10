// === DIAGNOSTIC COMPLET SCORING ===

// 1. Derniers Leads
System.debug('=== 1. DERNIERS LEADS ===');
List<Lead> leads = [
    SELECT Id, Email, Status, Score_Matching__c, IsConverted, Description, CreatedDate
    FROM Lead WHERE LeadSource = 'Talent Portal'
    ORDER BY CreatedDate DESC LIMIT 5
];
for (Lead l : leads) {
    System.debug('Lead ' + l.Id + ' | ' + l.Email + ' | Status: ' + l.Status + ' | Score: ' + l.Score_Matching__c + ' | Converted: ' + l.IsConverted);
}

// 2. Derniers Async Jobs
System.debug('=== 2. ASYNC JOBS (CVScoring) ===');
List<AsyncApexJob> jobs = [
    SELECT Id, Status, ExtendedStatus, ApexClass.Name, CreatedDate, NumberOfErrors
    FROM AsyncApexJob WHERE ApexClass.Name LIKE '%CVScoring%'
    ORDER BY CreatedDate DESC LIMIT 5
];
for (AsyncApexJob j : jobs) {
    System.debug('Job ' + j.Id + ' | ' + j.ApexClass.Name + ' | Status: ' + j.Status + ' | Errors: ' + j.NumberOfErrors + ' | Error: ' + j.ExtendedStatus + ' | Created: ' + j.CreatedDate);
}

// 3. ContentDocumentLinks sur les leads récents
System.debug('=== 3. CV ATTACHMENTS SUR LEADS RÉCENTS ===');
for (Lead l : leads) {
    if (!l.IsConverted) {
        List<ContentDocumentLink> cdls = [SELECT ContentDocumentId, ContentDocument.Title FROM ContentDocumentLink WHERE LinkedEntityId = :l.Id];
        System.debug('Lead ' + l.Email + ' (' + l.Id + ') -> ' + cdls.size() + ' fichiers');
        for (ContentDocumentLink c : cdls) {
            System.debug('   File: ' + c.ContentDocument.Title);
        }
    }
}

// 4. API Key
List<AI_Configuration__c> configs = [SELECT Groq_API_Key__c FROM AI_Configuration__c LIMIT 1];
System.debug('=== 4. API KEY ===');
if (configs.isEmpty()) {
    System.debug('ERREUR: Pas de AI_Configuration__c !');
} else {
    String k = configs[0].Groq_API_Key__c;
    System.debug('Key: ' + (String.isNotBlank(k) ? k.substring(0, 8) + '... (' + k.length() + ' chars)' : 'VIDE!'));
}

// 5. Remote Site Setting - try a callout
System.debug('=== 5. TEST CALLOUT GROQ ===');
try {
    HttpRequest req = new HttpRequest();
    req.setEndpoint('https://api.groq.com/openai/v1/models');
    req.setMethod('GET');
    req.setHeader('Authorization', 'Bearer ' + configs[0].Groq_API_Key__c);
    req.setTimeout(10000);
    HttpResponse res = new Http().send(req);
    System.debug('Groq API Response: ' + res.getStatusCode() + ' ' + res.getStatus());
} catch (Exception e) {
    System.debug('ERREUR CALLOUT: ' + e.getMessage());
}

// 6. Test le scoring manuellement sur le dernier lead non-converti
System.debug('=== 6. TEST SCORING MANUEL ===');
Lead testLead = null;
for (Lead l : leads) {
    if (!l.IsConverted && l.Score_Matching__c == null) {
        testLead = l;
        break;
    }
}
if (testLead != null) {
    System.debug('Test sur: ' + testLead.Email + ' (' + testLead.Id + ')');
    try {
        CVScoringService.scoreCVForLeadNow(testLead.Id);
        // Re-query
        Lead after = [SELECT Id, Score_Matching__c, Status, AI_Recommendation__c FROM Lead WHERE Id = :testLead.Id];
        System.debug('APRÈS scoring: Score=' + after.Score_Matching__c + ' | Status=' + after.Status + ' | Reco=' + after.AI_Recommendation__c);
    } catch (Exception e) {
        System.debug('ERREUR SCORING: ' + e.getMessage() + '\n' + e.getStackTraceString());
    }
} else {
    System.debug('Aucun lead non-converti sans score trouvé');
}
