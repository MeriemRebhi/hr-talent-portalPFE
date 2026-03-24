// Full end-to-end scoring diagnostic for CVScoringService.
// Usage (CLI): sf apex run --file scripts/apex/runFullScoringTest.apex --target-org <alias>

// Optional: set a specific Lead Id (example: '00Qxxxxxxxxxxxx').
String TARGET_LEAD_ID = '';

Lead lead;
if (String.isNotBlank(TARGET_LEAD_ID)) {
    lead = [
        SELECT Id, FirstName, LastName, Email, Phone, Description,
               IsConverted, Rating, Score_Matching__c,
               AI_Recommendation__c, AI_Points_Forts__c, AI_Points_Faibles__c,
               LastModifiedDate
        FROM Lead
        WHERE Id = :TARGET_LEAD_ID
        LIMIT 1
    ];
} else {
    lead = [
        SELECT Id, FirstName, LastName, Email, Phone, Description,
               IsConverted, Rating, Score_Matching__c,
               AI_Recommendation__c, AI_Points_Forts__c, AI_Points_Faibles__c,
               LastModifiedDate
        FROM Lead
        WHERE IsConverted = false
        ORDER BY CreatedDate DESC
        LIMIT 1
    ];
}

System.debug('=== INPUT LEAD ===');
System.debug('Lead Id: ' + lead.Id);
System.debug('Name: ' + lead.FirstName + ' ' + lead.LastName);
System.debug('Email: ' + lead.Email);
System.debug('Initial Rating: ' + lead.Rating + ' | Initial Score: ' + lead.Score_Matching__c);

if (String.isBlank(lead.Description) || !lead.Description.contains('JOB_ID:')) {
    System.debug('WARN: Lead.Description does not contain JOB_ID:. Job context may be generic.');
}
if (String.isBlank(lead.Description) || !lead.Description.contains('PROFILE_TEXT:')) {
    System.debug('INFO: PROFILE_TEXT not found in Description. Scoring will rely mostly on CV text.');
}

List<ContentDocumentLink> links = [
    SELECT ContentDocumentId
    FROM ContentDocumentLink
    WHERE LinkedEntityId = :lead.Id
    LIMIT 5
];
System.debug('Attached files count on Lead: ' + links.size());
if (links.isEmpty()) {
    System.debug('WARN: No attached files found. Scoring may fail unless PROFILE_TEXT is present.');
}

System.debug('=== RUN SCORING (SYNC) ===');
CVScoringService.scoreCVForLeadNow(lead.Id);

Lead afterLead = [
    SELECT Id, FirstName, LastName, Email,
           IsConverted, Rating, Status, Score_Matching__c,
           AI_Recommendation__c, AI_Points_Forts__c, AI_Points_Faibles__c,
           Description, LastModifiedDate
    FROM Lead
    WHERE Id = :lead.Id
    LIMIT 1
];

System.debug('=== LEAD AFTER SCORING ===');
System.debug('IsConverted: ' + afterLead.IsConverted + ' | Status: ' + afterLead.Status);
System.debug('Rating: ' + afterLead.Rating + ' | Score_Matching__c: ' + afterLead.Score_Matching__c);
System.debug('AI_Recommendation__c: ' + afterLead.AI_Recommendation__c);
System.debug('AI_Points_Forts__c length: ' + (afterLead.AI_Points_Forts__c == null ? 0 : afterLead.AI_Points_Forts__c.length()));
System.debug('AI_Points_Faibles__c length: ' + (afterLead.AI_Points_Faibles__c == null ? 0 : afterLead.AI_Points_Faibles__c.length()));

Boolean hasAtsBlock = afterLead.Description != null
    && afterLead.Description.contains('[ATS_REPORT_START]')
    && afterLead.Description.contains('[ATS_REPORT_END]');
System.debug('ATS report block present in Description: ' + hasAtsBlock);

List<Contact> contacts = new List<Contact>();
if (String.isNotBlank(afterLead.Email)) {
    contacts = [
        SELECT Id, Name, Email, AccountId, LastModifiedDate
        FROM Contact
        WHERE Email = :afterLead.Email
        ORDER BY LastModifiedDate DESC
        LIMIT 5
    ];
}
System.debug('Contacts by lead email: ' + contacts.size());
for (Contact c : contacts) {
    System.debug('Contact -> ' + c.Id + ' | ' + c.Name + ' | AccountId=' + c.AccountId);
}

List<User> users = new List<User>();
if (String.isNotBlank(afterLead.Email)) {
    users = [
        SELECT Id, Username, Email, ContactId, IsActive, Profile.Name
        FROM User
        WHERE Email = :afterLead.Email
        ORDER BY LastModifiedDate DESC
        LIMIT 5
    ];
}
System.debug('Portal users by lead email: ' + users.size());
for (User u : users) {
    System.debug('User -> ' + u.Id + ' | ' + u.Username + ' | Active=' + u.IsActive + ' | Profile=' + u.Profile.Name);
}

String oppPrefix = (afterLead.FirstName == null ? '' : afterLead.FirstName)
    + ' '
    + (afterLead.LastName == null ? '' : afterLead.LastName)
    + ' - Candidature (';

List<Opportunity> opps = [
    SELECT Id, Name, StageName, RecordType.DeveloperName, CreatedDate, AccountId
    FROM Opportunity
    WHERE Name LIKE :('%' + oppPrefix + '%')
    ORDER BY CreatedDate DESC
    LIMIT 5
];
System.debug('Application opportunities found: ' + opps.size());
for (Opportunity o : opps) {
    System.debug('Opp -> ' + o.Id + ' | ' + o.Name + ' | Stage=' + o.StageName
        + ' | RT=' + (o.RecordType == null ? null : o.RecordType.DeveloperName));
}

System.debug('=== END OF FULL SCORING TEST ===');
