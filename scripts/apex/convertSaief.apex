// Tenter la conversion manuellement pour capturer l'erreur EXACTE
Lead lead = [SELECT Id, FirstName, LastName, Email, Score_Matching__c FROM Lead WHERE Id = '00Qfj00000EBPRHEA5'];
System.debug('Lead: ' + lead.FirstName + ' ' + lead.LastName + ' | Email=' + lead.Email);

List<Contact> contacts = [SELECT Id, AccountId FROM Contact WHERE Email = :lead.Email LIMIT 1];
System.debug('Contact existant: ' + !contacts.isEmpty());

Database.LeadConvert lc = new Database.LeadConvert();
lc.setLeadId(lead.Id);

if (!contacts.isEmpty()) {
    lc.setContactId(contacts[0].Id);
    lc.setAccountId(contacts[0].AccountId);
} else {
    Account acc = new Account(Name = lead.Email);
    Database.DMLOptions dml = new Database.DMLOptions();
    dml.DuplicateRuleHeader.allowSave = true;
    Database.insert(acc, dml);
    lc.setAccountId(acc.Id);
}

LeadStatus cs = [SELECT MasterLabel FROM LeadStatus WHERE IsConverted=true LIMIT 1];
lc.setConvertedStatus(cs.MasterLabel);
lc.setOpportunityName(lead.LastName + ' - Candidature (' + lead.Score_Matching__c + '%)');
lc.setDoNotCreateOpportunity(false);

Database.LeadConvertResult lcr = Database.convertLead(lc);
if (lcr.isSuccess()) {
    System.debug('✅ CONVERTI ! Contact=' + lcr.getContactId() + ' Opp=' + lcr.getOpportunityId());
    
    // Mettre RecordType Application sur l'Opp
    List<RecordType> rt = [SELECT Id FROM RecordType WHERE SObjectType='Opportunity' AND DeveloperName='Application' LIMIT 1];
    if (!rt.isEmpty()) {
        try {
            Opportunity opp = new Opportunity(Id = lcr.getOpportunityId(), RecordTypeId = rt[0].Id, StageName = 'Gaming', Score_Matching__c = lead.Score_Matching__c);
            update opp;
            System.debug('✅ Opp mise à jour RT=Application');
        } catch (Exception e) {
            System.debug('❌ Erreur update Opp: ' + e.getMessage());
        }
    }
} else {
    for (Database.Error err : lcr.getErrors()) {
        System.debug('❌ ERREUR: ' + err.getStatusCode() + ' | ' + err.getMessage() + ' | Fields=' + err.getFields());
    }
}
