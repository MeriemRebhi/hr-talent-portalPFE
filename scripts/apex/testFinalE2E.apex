// Test E2E avec le même email (m.rebhi24292@pi.tn) — simule le portail
// Doit fonctionner maintenant que:
// 1. Duplicate rules = désactivées
// 2. Recursion guard = actif (trigger ne re-fire pas pendant conversion)

List<Opportunity> jobs = [SELECT Id, Name FROM Opportunity WHERE RecordType.DeveloperName = 'Job_Posting' LIMIT 1];
String jobId = jobs.isEmpty() ? null : jobs[0].Id;

Lead testLead = new Lead();
testLead.FirstName = 'TestFinal';
testLead.LastName = 'E2EFix';
testLead.Email = 'm.rebhi24292@pi.tn'; // Même email que les tests précédents !
testLead.Phone = '+21600000000';
testLead.Company = 'Candidat';
testLead.LeadSource = 'Talent Portal';

List<String> metadata = new List<String>();
if (jobId != null) metadata.add('JOB_ID:' + jobId);
metadata.add('PROFILE_TEXT:');
metadata.add('Expert Salesforce avec 5 ans Apex, LWC, SOQL. Certifié Admin et PD1.');
testLead.Description = String.join(metadata, '\n');

Database.DMLOptions dmlOpts = new Database.DMLOptions();
dmlOpts.DuplicateRuleHeader.allowSave = true;
Database.insert(testLead, dmlOpts);
System.debug('✅ Lead créé: ' + testLead.Id);

// Déclencher le scoring (comme le JS le fait)
ApplicationController.triggerScoring(testLead.Id);

Lead after = [SELECT Id, Status FROM Lead WHERE Id = :testLead.Id];
System.debug('📊 Status après triggerScoring: ' + after.Status);
System.debug('⏳ ID pour vérification: ' + testLead.Id);
