// Re-test scoring with the fixed parser
Lead testLead = new Lead(
    FirstName = 'Meriem',
    LastName = 'TestParser',
    Email = 'test.parser@test.com',
    Company = 'Candidat',
    LeadSource = 'Talent Portal',
    Description = 'JOB_ID:006fj00000AITvRAAX\nPROFILE_TEXT:\n5 ans Développeur Java/Spring Boot, microservices, Docker, Kubernetes, AWS, Angular'
);
Database.DMLOptions dmlOpts = new Database.DMLOptions();
dmlOpts.DuplicateRuleHeader.allowSave = true;
Database.insert(testLead, dmlOpts);

ContentVersion cv = new ContentVersion();
cv.Title = 'CV_TestParser';
cv.PathOnClient = 'CV_TestParser.txt';
cv.VersionData = Blob.valueOf('Meriem TestParser\n5 ans expérience Développeur Java Spring Boot\nCompétences: Java, Spring Boot, microservices, Docker, Kubernetes, AWS, CI/CD, Angular, PostgreSQL, MongoDB\nFormation: Ingénieur en Informatique ESPRIT Tunis\nCertifications: AWS Certified Developer\nExpérience: 3 ans chez Talan, 2 ans chez Sofrecom');
insert cv;

ContentVersion cvIns = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];
ContentDocumentLink cdl = new ContentDocumentLink(ContentDocumentId = cvIns.ContentDocumentId, LinkedEntityId = testLead.Id, ShareType = 'V');
insert cdl;

System.debug('✅ Lead: ' + testLead.Id + ' - Trigger fired, waiting for Queueable...');
