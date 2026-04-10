// Check recent Apex Jobs (Queueable) status
List<AsyncApexJob> jobs = [
    SELECT Id, Status, JobType, CompletedDate, ExtendedStatus, MethodName, ApexClass.Name, CreatedDate
    FROM AsyncApexJob 
    WHERE ApexClass.Name LIKE '%CVScoring%'
    ORDER BY CreatedDate DESC 
    LIMIT 10
];
System.debug('=== RECENT CV SCORING JOBS ===');
for (AsyncApexJob j : jobs) {
    System.debug('Job: ' + j.ApexClass.Name + ' | Status: ' + j.Status + ' | Created: ' + j.CreatedDate + ' | Error: ' + j.ExtendedStatus);
}

// Check recent Leads and their scores
List<Lead> leads = [
    SELECT Id, FirstName, LastName, Email, Status, Score_Matching__c, AI_Recommendation__c, 
           Description, IsConverted, CreatedDate
    FROM Lead 
    WHERE LeadSource = 'Talent Portal'
    ORDER BY CreatedDate DESC 
    LIMIT 10
];
System.debug('=== RECENT LEADS ===');
for (Lead l : leads) {
    System.debug('Lead: ' + l.Email + ' | Status: ' + l.Status + ' | Score: ' + l.Score_Matching__c + ' | Converted: ' + l.IsConverted + ' | Created: ' + l.CreatedDate);
}

// Check if AI_Configuration exists with API key
List<AI_Configuration__c> configs = [SELECT Id, Groq_API_Key__c FROM AI_Configuration__c LIMIT 1];
if (configs.isEmpty()) {
    System.debug('❌ AI_Configuration__c is EMPTY - no API key configured!');
} else {
    String key = configs[0].Groq_API_Key__c;
    System.debug('✅ AI_Configuration__c exists. Key starts with: ' + (String.isNotBlank(key) ? key.substring(0, Math.min(10, key.length())) + '...' : 'EMPTY'));
}

// Check if ContentDocumentLink exists for recent leads  
for (Lead l : leads) {
    List<ContentDocumentLink> cdls = [SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId = :l.Id];
    System.debug('Lead ' + l.Email + ' has ' + cdls.size() + ' CV attachments');
}
