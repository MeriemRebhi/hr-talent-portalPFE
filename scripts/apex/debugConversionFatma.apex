// Debug: Forcer la conversion du Lead "Rebhi fatma" et afficher l'erreur exacte
List<Lead> leads = [
    SELECT Id, FirstName, LastName, Email, Status, IsConverted, Score_Matching__c, Description
    FROM Lead 
    WHERE LastName = 'fatma' AND IsConverted = false
    LIMIT 5
];

if (leads.isEmpty()) {
    System.debug('❌ Aucun Lead "fatma" non converti trouvé');
} else {
    for (Lead lead : leads) {
        System.debug('🔍 Lead: ' + lead.Id + ' | ' + lead.FirstName + ' ' + lead.LastName + ' | Status=' + lead.Status + ' | Score=' + lead.Score_Matching__c + ' | Converted=' + lead.IsConverted);
    }
    
    Lead lead = leads[0];
    
    // Tenter la conversion
    try {
        Database.LeadConvert lc = new Database.LeadConvert();
        lc.setLeadId(lead.Id);
        
        // Chercher contact existant
        List<Contact> existingContacts = [SELECT Id, AccountId FROM Contact WHERE Email = :lead.Email LIMIT 1];
        if (!existingContacts.isEmpty()) {
            lc.setContactId(existingContacts[0].Id);
            lc.setAccountId(existingContacts[0].AccountId);
            System.debug('🔗 Contact existant: ' + existingContacts[0].Id);
        } else {
            Account newAcc = new Account(Name = lead.Email);
            Database.DMLOptions dml = new Database.DMLOptions();
            dml.DuplicateRuleHeader.allowSave = true;
            Database.insert(newAcc, dml);
            lc.setAccountId(newAcc.Id);
            System.debug('🏢 Nouveau compte créé: ' + newAcc.Id);
        }
        
        LeadStatus convertStatus = [SELECT MasterLabel FROM LeadStatus WHERE IsConverted=true LIMIT 1];
        System.debug('📋 Statut de conversion: ' + convertStatus.MasterLabel);
        lc.setConvertedStatus(convertStatus.MasterLabel);
        lc.setOpportunityName(lead.LastName + ' - Candidature (' + lead.Score_Matching__c + '%)');
        lc.setDoNotCreateOpportunity(false);
        
        Database.LeadConvertResult lcr = Database.convertLead(lc);
        
        if (lcr.isSuccess()) {
            System.debug('✅ Conversion réussie !');
            System.debug('   Contact: ' + lcr.getContactId());
            System.debug('   Opportunity: ' + lcr.getOpportunityId());
            System.debug('   Account: ' + lcr.getAccountId());
            
            // Marquer Score
            if (lcr.getOpportunityId() != null) {
                update new Opportunity(Id = lcr.getOpportunityId(), Score_Matching__c = lead.Score_Matching__c);
                System.debug('✅ Opportunity score mis à jour');
            }
        } else {
            System.debug('❌ Conversion échouée:');
            for (Database.Error err : lcr.getErrors()) {
                System.debug('   Code: ' + err.getStatusCode());
                System.debug('   Message: ' + err.getMessage());
                System.debug('   Fields: ' + err.getFields());
            }
        }
    } catch (Exception e) {
        System.debug('❌ Exception: ' + e.getMessage());
        System.debug('   Stack: ' + e.getStackTraceString());
    }
}
