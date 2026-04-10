// Simulate a full candidature flow manually
// 1. Create a test Lead
Lead testLead = new Lead(
    FirstName = 'Test',
    LastName = 'ScoringDebug',
    Email = 'test.scoring.debug@test.com',
    Phone = '+33600000000',
    Company = 'Candidat',
    LeadSource = 'Talent Portal',
    Description = 'JOB_ID:006fj00000AITvRAAX\nPROFILE_TEXT:\n3 ans DevOps, AWS, Docker, Kubernetes, CI/CD, Terraform, Jenkins'
);
Database.DMLOptions dmlOpts = new Database.DMLOptions();
dmlOpts.DuplicateRuleHeader.allowSave = true;
Database.insert(testLead, dmlOpts);
System.debug('✅ Lead créé: ' + testLead.Id);

// 2. Create a fake CV (ContentVersion)
ContentVersion cv = new ContentVersion();
cv.Title = 'TestCV_Debug';
cv.PathOnClient = 'TestCV_Debug.txt';
cv.VersionData = Blob.valueOf('Candidat: 3 ans experience DevOps. Compétences: AWS, Docker, Kubernetes, CI/CD, Terraform, Jenkins, Python, Linux. Formation: Ingénieur Informatique. Certifications: AWS Solutions Architect.');
insert cv;
System.debug('✅ ContentVersion créé: ' + cv.Id);

// 3. Get ContentDocumentId
ContentVersion cvInserted = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];

// 4. Create ContentDocumentLink to Lead (this is what triggers CVScoringTrigger)
try {
    ContentDocumentLink cdl = new ContentDocumentLink();
    cdl.ContentDocumentId = cvInserted.ContentDocumentId;
    cdl.LinkedEntityId = testLead.Id;
    cdl.ShareType = 'V';
    insert cdl;
    System.debug('✅ ContentDocumentLink créé! Trigger should fire now.');
    System.debug('Lead ID: ' + testLead.Id);
} catch (Exception e) {
    System.debug('❌ ERREUR ContentDocumentLink: ' + e.getMessage());
    System.debug('Stack: ' + e.getStackTraceString());
}
