public without sharing class JobPostingController {

    @AuraEnabled(cacheable=true)
    public static List<Opportunity> getJobPostings() {
        return [
            SELECT 
                Id, Name, StageName, CloseDate,
                Localisation__c,
                Type_de_Contrat__c,
                Salaire_Propos__c,
                Description_Poste__c,
                Departement__c
            FROM Opportunity
            WHERE RecordType.DeveloperName = 'Job_Posting'
            AND IsClosed = false
            ORDER BY CreatedDate DESC
            LIMIT 50
        ];
    }

    @AuraEnabled(cacheable=true)
    public static Opportunity getJobPosting(String jobId) {
        List<Opportunity> jobs = [
            SELECT 
                Id, Name, StageName, CloseDate,
                Localisation__c,
                Type_de_Contrat__c,
                Salaire_Propos__c,
                Description_Poste__c,
                Departement__c
            FROM Opportunity
            WHERE Id = :jobId
            AND RecordType.DeveloperName = 'Job_Posting'
            AND IsClosed = false
            LIMIT 1
        ];
        return jobs.isEmpty() ? null : jobs[0];
    }
}