// Test complet: Lead + profile + scoring + conversion
// Simule exactement ce que fait le portail

// Récupérer une offre
List<Opportunity> jobs = [SELECT Id, Name FROM Opportunity WHERE RecordType.DeveloperName = 'Job_Posting' LIMIT 1];
String jobId = jobs.isEmpty() ? null : jobs[0].Id;
System.debug('📋 Job: ' + (jobs.isEmpty() ? 'AUCUN' : jobs[0].Name));

// Créer un Lead avec un nouveau email unique (pour éviter les doublons)
String uniqueEmail = 'test.conversion.' + System.currentTimeMillis() + '@test.com';
Lead testLead = new Lead();
testLead.FirstName = 'TestConversion';
testLead.LastName = 'E2E';
testLead.Email = uniqueEmail;
testLead.Phone = '+21600000000';
testLead.Company = 'Candidat';
testLead.LeadSource = 'Talent Portal';

List<String> metadata = new List<String>();
if (jobId != null) metadata.add('JOB_ID:' + jobId);
metadata.add('PROFILE_TEXT:');
metadata.add('Expert Salesforce certifié Platform Developer II, 8 ans d\'expérience en développement Apex, LWC, Visualforce, intégration REST/SOAP. Spécialiste CPQ et Field Service Lightning. Certifié Salesforce Administrator et App Builder. Maîtrise des méthodologies Agile Scrum et DevOps avec CI/CD via SFDX.');
testLead.Description = String.join(metadata, '\n');

Database.DMLOptions dmlOpts = new Database.DMLOptions();
dmlOpts.DuplicateRuleHeader.allowSave = true;
Database.insert(testLead, dmlOpts);
System.debug('✅ Lead créé: ' + testLead.Id + ' | Email: ' + uniqueEmail);

// Appeler triggerScoring
ApplicationController.triggerScoring(testLead.Id);

Lead afterTrigger = [SELECT Id, Status FROM Lead WHERE Id = :testLead.Id];
System.debug('📊 Après triggerScoring: Status=' + afterTrigger.Status);
System.debug('⏳ Attendez 15-20 secondes puis vérifiez:');
System.debug('   sf data query --query "SELECT Id, Status, Score_Matching__c, AI_Recommendation__c, IsConverted FROM Lead WHERE Id = \'' + testLead.Id + '\'" --target-org DevOrg');
