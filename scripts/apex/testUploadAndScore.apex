// Test upload CV directement en tant qu'admin pour vérifier le flux

// Trouver le dernier lead sans score
Lead testLead = [
    SELECT Id, Email, Description 
    FROM Lead 
    WHERE LeadSource = 'Talent Portal' AND IsConverted = false AND Score_Matching__c = null
    ORDER BY CreatedDate DESC LIMIT 1
];
System.debug('Test Lead: ' + testLead.Email + ' (' + testLead.Id + ')');

// Créer un faux CV texte
ContentVersion cv = new ContentVersion();
cv.Title = 'TestCV_' + System.now().getTime();
cv.PathOnClient = 'TestCV.txt';
cv.VersionData = Blob.valueOf('Développeur Full Stack Java, 3 ans experience, Spring Boot, Angular, Docker, AWS, CI/CD, Agile Scrum');
cv.IsMajorVersion = true;
insert cv;
System.debug('ContentVersion créé: ' + cv.Id);

// Récupérer le ContentDocumentId
ContentVersion inserted = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];
System.debug('ContentDocumentId: ' + inserted.ContentDocumentId);

// Lier au Lead — c'est ici que le trigger CVScoringTrigger devrait fire
ContentDocumentLink cdl = new ContentDocumentLink();
cdl.ContentDocumentId = inserted.ContentDocumentId;
cdl.LinkedEntityId = testLead.Id;
cdl.ShareType = 'V';
insert cdl;
System.debug('ContentDocumentLink créé ! Trigger should fire now.');
System.debug('Attendre ~5 secondes puis vérifier le score du lead...');
