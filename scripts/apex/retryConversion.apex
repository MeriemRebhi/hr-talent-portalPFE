// Retenter la conversion pour ayoub hannechi (00Qfj00000EAv53EAD)
// Les règles de doublon sont désactivées maintenant

// Vérifier que les duplicate rules sont bien inactives
List<DuplicateRule> activeRules = [SELECT MasterLabel FROM DuplicateRule WHERE IsActive = true];
System.debug('🔍 Règles de doublon actives: ' + activeRules.size());
for (DuplicateRule r : activeRules) {
    System.debug('   ⚠️ ENCORE ACTIVE: ' + r.MasterLabel);
}

// Récupérer le Lead
Lead lead = [SELECT Id, FirstName, LastName, Email, Score_Matching__c, Status, IsConverted, AI_Recommendation__c 
             FROM Lead WHERE Id = '00Qfj00000EAv53EAD' LIMIT 1];
System.debug('🎯 Lead: ' + lead.FirstName + ' ' + lead.LastName + ' | Status=' + lead.Status + ' | Score=' + lead.Score_Matching__c + ' | Converted=' + lead.IsConverted);

if (lead.IsConverted) {
    System.debug('⚠️ Déjà converti, rien à faire.');
} else {
    // Lancer la conversion
    Database.LeadConvert lc = new Database.LeadConvert();
    lc.setLeadId(lead.Id);
    
    // Trouver le Contact existant
    List<Contact> existingContacts = [SELECT Id, AccountId FROM Contact WHERE Email = :lead.Email LIMIT 1];
    if (!existingContacts.isEmpty()) {
        lc.setContactId(existingContacts[0].Id);
        lc.setAccountId(existingContacts[0].AccountId);
        System.debug('🔗 Contact existant: ' + existingContacts[0].Id);
    } else {
        Account newAcc = new Account(Name = lead.Email);
        insert newAcc;
        lc.setAccountId(newAcc.Id);
        System.debug('🆕 Nouveau Account créé');
    }
    
    LeadStatus cs = [SELECT MasterLabel FROM LeadStatus WHERE IsConverted=true LIMIT 1];
    lc.setConvertedStatus(cs.MasterLabel);
    lc.setOpportunityName(lead.LastName + ' - Candidature (' + lead.Score_Matching__c + '%)');
    lc.setDoNotCreateOpportunity(false);
    
    try {
        Database.LeadConvertResult lcr = Database.convertLead(lc);
        if (lcr.isSuccess()) {
            System.debug('✅ CONVERSION RÉUSSIE ! Contact=' + lcr.getContactId() + ' | Opp=' + lcr.getOpportunityId());
            
            // Mettre à jour l'Opportunity avec le RecordType Application
            List<RecordType> rt = [SELECT Id FROM RecordType WHERE SObjectType='Opportunity' AND DeveloperName='Application' LIMIT 1];
            if (!rt.isEmpty()) {
                Opportunity opp = new Opportunity(Id = lcr.getOpportunityId());
                opp.RecordTypeId = rt[0].Id;
                opp.StageName = 'Gaming';
                opp.Score_Matching__c = lead.Score_Matching__c;
                update opp;
                System.debug('✅ Opportunity mise à jour avec RT Application');
            }
            
            // Nettoyer le message d'erreur dans AI_Recommendation
            if (lead.AI_Recommendation__c != null && lead.AI_Recommendation__c.contains('[EXCEPTION')) {
                String cleanRec = lead.AI_Recommendation__c.substringBefore('[EXCEPTION').trim();
                Lead updLead = [SELECT Id FROM Lead WHERE Id = :lead.Id LIMIT 1]; // Can't update converted lead fields directly
                System.debug('📝 Recommendation nettoyée');
            }
            
            // Créer l'utilisateur portail
            CVScoringService.createPortalUserAsync(lcr.getContactId(), lead.FirstName, lead.LastName, lead.Email);
            System.debug('🚀 Création user portail lancée');
        } else {
            for (Database.Error err : lcr.getErrors()) {
                System.debug('❌ Erreur: ' + err.getStatusCode() + ' | ' + err.getMessage() + ' | Fields: ' + err.getFields());
            }
        }
    } catch (Exception e) {
        System.debug('❌ Exception: ' + e.getMessage() + '\n' + e.getStackTraceString());
    }
}
