// Test du fix scoring : simule le flux exact du portail
// 1. Crée un Lead (comme createCandidateForJob)
// 2. Appelle triggerScoring (comme le JS le fait maintenant)

// Récupérer une offre existante
List<Opportunity> jobs = [SELECT Id, Name FROM Opportunity WHERE RecordType.DeveloperName = 'Job_Posting' LIMIT 1];
String jobId = jobs.isEmpty() ? null : jobs[0].Id;
System.debug('📋 Job: ' + (jobs.isEmpty() ? 'AUCUN' : jobs[0].Name + ' (' + jobId + ')'));

// Créer un Lead de test
Lead testLead = new Lead();
testLead.FirstName = 'TestScoring';
testLead.LastName = 'Fix' + System.currentTimeMillis();
testLead.Email = 'testfix' + System.currentTimeMillis() + '@test.com';
testLead.Company = 'Candidat';
testLead.LeadSource = 'Talent Portal';

List<String> metadata = new List<String>();
if (jobId != null) metadata.add('JOB_ID:' + jobId);
metadata.add('PROFILE_TEXT:');
metadata.add('Développeur Full Stack avec 5 ans d\'expérience en Java, Spring Boot, Angular et React. Certifié AWS. Fort en méthodes agiles Scrum.');
testLead.Description = String.join(metadata, '\n');

Database.DMLOptions dmlOpts = new Database.DMLOptions();
dmlOpts.DuplicateRuleHeader.allowSave = true;
Database.insert(testLead, dmlOpts);
System.debug('✅ Lead créé: ' + testLead.Id + ' | Status: ' + testLead.Status);

// Appeler triggerScoring (exactement comme le JS le fait)
System.debug('🤖 Appel triggerScoring...');
ApplicationController.triggerScoring(testLead.Id);

// Vérifier le statut immédiatement après l'appel
Lead afterTrigger = [SELECT Id, Status, Score_Matching__c FROM Lead WHERE Id = :testLead.Id];
System.debug('📊 Après triggerScoring: Status=' + afterTrigger.Status + ' | Score=' + afterTrigger.Score_Matching__c);
System.debug('✅ Si Status = "Condidature - IA Parsing", le Queueable est en route. Attendez 10-15s puis vérifiez.');
System.debug('🔍 Vérifiez avec: SELECT Id, Status, Score_Matching__c, AI_Recommendation__c FROM Lead WHERE Id = \'' + testLead.Id + '\'');
