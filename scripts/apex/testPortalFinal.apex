// Test FINAL — simule exactement le portail avec le même email
// Capture toutes les erreurs possibles

Lead testLead = new Lead();
testLead.FirstName = 'TestPortail';
testLead.LastName = 'Final';
testLead.Email = 'm.rebhi24292@pi.tn';
testLead.Company = 'Candidat';
testLead.LeadSource = 'Talent Portal';
testLead.Description = 'JOB_ID:006fj00000AISXxAAP\nPROFILE_TEXT:\nExpert Salesforce PD2 certifié, 5 ans Apex LWC';

Database.DMLOptions dmlOpts = new Database.DMLOptions();
dmlOpts.DuplicateRuleHeader.allowSave = true;
Database.insert(testLead, dmlOpts);
System.debug('✅ Lead: ' + testLead.Id);

// Simuler triggerScoring
CVScoringService.scoreCVForLeads(new Set<String>{ (String)testLead.Id });

Lead after = [SELECT Id, Status FROM Lead WHERE Id = :testLead.Id];
System.debug('📊 Status: ' + after.Status);
System.debug('⏳ Vérif dans 20s: ' + testLead.Id);
