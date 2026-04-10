// === DIAGNOSTIC COMPLET PORTAIL RH ===

// 1. JOB POSTINGS (test du fix deployé)
List<Opportunity> jobs = [
    SELECT Id, Name, IsClosed, RecordType.DeveloperName
    FROM Opportunity
    WHERE RecordType.DeveloperName = 'Job_Posting' AND IsClosed = false
    ORDER BY Name
];
System.debug('=== [1] JOB POSTINGS OUVERTS: ' + jobs.size() + ' (doit être 5, sans kemil/fatma) ===');
for(Opportunity o : jobs) System.debug('  OFFRE: ' + o.Name);

List<Opportunity> closedJobPostings = [
    SELECT Id, Name, IsClosed, StageName
    FROM Opportunity
    WHERE RecordType.DeveloperName = 'Job_Posting' AND IsClosed = true
];
System.debug('=== [1b] JOB POSTINGS FERMES (exclus du site): ' + closedJobPostings.size() + ' ===');
for(Opportunity o : closedJobPostings) System.debug('  EXCLU: ' + o.Name + ' | ' + o.StageName);

// 2. LEADS AVEC CV attaches — via leurs IDs
List<Lead> allLeadsForCV = [SELECT Id FROM Lead LIMIT 50];
Set<Id> allLeadIds = new Map<Id, Lead>(allLeadsForCV).keySet();
List<ContentDocumentLink> cdls = [
    SELECT LinkedEntityId, ContentDocument.Title, ContentDocument.FileType
    FROM ContentDocumentLink
    WHERE LinkedEntityId IN :allLeadIds
    LIMIT 20
];
Set<Id> leadIdsWithCV = new Set<Id>();
for(ContentDocumentLink c : cdls) leadIdsWithCV.add(c.LinkedEntityId);
System.debug('=== [2] LEADS AVEC FICHIER CV: ' + leadIdsWithCV.size() + ' ===');
for(ContentDocumentLink c : cdls) System.debug('  CV: ' + c.ContentDocument.Title + ' (' + c.ContentDocument.FileType + ')');

// 3. ETAT DES CANDIDATURES (leads)
List<Lead> allLeads = [
    SELECT Id, FirstName, LastName, Email, Status, Score_Matching__c, IsConverted, Rating
    FROM Lead
    ORDER BY CreatedDate DESC
    LIMIT 10
];
System.debug('=== [3] DERNIERES CANDIDATURES ===');
for(Lead l : allLeads) {
    System.debug('  ' + l.FirstName + ' ' + l.LastName
        + ' | Status: ' + l.Status
        + ' | Score: ' + l.Score_Matching__c
        + ' | Converted: ' + l.IsConverted
        + ' | HasCV: ' + leadIdsWithCV.contains(l.Id));
}

// 4. CONTACTS + USERS PORTAIL ACTIFS
List<User> portalUsers = [
    SELECT Id, Email, IsActive, Profile.Name
    FROM User
    WHERE Profile.Name = 'Customer Community Login User' AND IsActive = true
];
System.debug('=== [4] USERS PORTAIL ACTIFS: ' + portalUsers.size() + ' ===');
for(User u : portalUsers) System.debug('  USER: ' + u.Email);

// 5. TRIGGERS ACTIFS
List<ApexTrigger> trigs = [SELECT Name, Status FROM ApexTrigger WHERE Status = 'Active'];
System.debug('=== [5] TRIGGERS ACTIFS: ' + trigs.size() + ' ===');
for(ApexTrigger t : trigs) System.debug('  TRIGGER: ' + t.Name);

// 6. CLASSES APEX OK
List<ApexClass> classes = [
    SELECT Name, Status FROM ApexClass
    WHERE Name IN ('CVScoringService','ApplicationController','JobPostingController',
                   'CandidateChatController','RegistrationController','QrLoginController',
                   'CustomPasswordResetController')
];
System.debug('=== [6] CLASSES APEX ===');
for(ApexClass c : classes) System.debug('  CLASS: ' + c.Name + ' | Status: ' + c.Status);

// 7. REMOTE SITES — non queryable en Apex anonyme, skip
System.debug('=== [7] REMOTE SITES: voir Setup > Remote Site Settings (Groq endpoint) ===');

// 8. OPPORTUNITES CANDIDATURE (conversions réussies)
List<Opportunity> candOpps = [
    SELECT Id, Name, StageName, RecordType.DeveloperName
    FROM Opportunity
    WHERE Name LIKE '%Candidature%' AND RecordType.DeveloperName != 'Job_Posting'
    ORDER BY CreatedDate DESC
    LIMIT 5
];
System.debug('=== [8] OPPORTUNITES CANDIDATURE CONVERTIES: ' + candOpps.size() + ' ===');
for(Opportunity o : candOpps) {
    System.debug('  OPP: ' + o.Name + ' | Stage: ' + o.StageName + ' | RT: ' + (o.RecordType == null ? 'null' : o.RecordType.DeveloperName));
}

System.debug('=== FIN DIAGNOSTIC COMPLET ===');
