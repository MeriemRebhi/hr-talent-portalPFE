public without sharing class AgentFindBestCandidateForJob {

    public class Input {
        @InvocableVariable(label='Job Opportunity Id (optionnel)')
        public Id jobOpportunityId;

        @InvocableVariable(label='Mot-cle poste (optionnel)')
        public String jobKeyword;

        @InvocableVariable(label='Nombre max candidats (optionnel)')
        public Integer topN;
    }

    public class Output {
        @InvocableVariable(label='Succes')
        public Boolean success;

        @InvocableVariable(label='Resume candidats')
        public String resume;

        @InvocableVariable(label='Meilleur candidat')
        public String bestCandidate;

        @InvocableVariable(label='Score meilleur candidat')
        public Decimal bestScore;
    }

    @InvocableMethod(
        label='Trouver meilleur candidat pour un poste'
        description='Retourne le meilleur candidat et le top candidats selon le score IA pour un poste donne.'
        category='Recruteur RH'
    )
    public static List<Output> execute(List<Input> inputs) {
        List<Output> results = new List<Output>();
        if (inputs == null) return results;

        for (Input inp : inputs) {
            Output out = new Output();
            out.success = false;
            out.resume = 'Aucun resultat.';

            try {
                Opportunity job = resolveJobPosting(inp);
                if (job == null) {
                    out.resume = 'Offre introuvable. Fournissez jobOpportunityId ou un mot-cle de poste.';
                    results.add(out);
                    continue;
                }

                Integer maxRows = inp != null && inp.topN != null && inp.topN > 0 ? inp.topN : 5;
                if (maxRows > 10) maxRows = 10;

                String jobIdTag = 'JOB_ID:' + String.valueOf(job.Id);
                List<Lead> candidatePool = [
                    SELECT Id, FirstName, LastName, Score_Matching__c, ConvertedOpportunityId, Description, CreatedDate
                    FROM Lead
                    WHERE IsConverted = true
                    AND ConvertedOpportunityId != null
                    AND Score_Matching__c != null
                    ORDER BY Score_Matching__c DESC, CreatedDate DESC
                    LIMIT 200
                ];

                List<Lead> leads = new List<Lead>();
                for (Lead candidate : candidatePool) {
                    if (String.isNotBlank(candidate.Description) && candidate.Description.contains(jobIdTag)) {
                        leads.add(candidate);
                        if (leads.size() >= maxRows) break;
                    }
                }

                if (leads.isEmpty()) {
                    out.resume = 'Aucun candidat converti trouve pour l offre "' + job.Name + '".';
                    results.add(out);
                    continue;
                }

                Set<Id> oppIds = new Set<Id>();
                for (Lead l : leads) {
                    if (l.ConvertedOpportunityId != null) oppIds.add(l.ConvertedOpportunityId);
                }
                Map<Id, Opportunity> appById = new Map<Id, Opportunity>();
                if (!oppIds.isEmpty()) {
                    for (Opportunity app : [
                        SELECT Id, Name, StageName
                        FROM Opportunity
                        WHERE Id IN :oppIds
                    ]) {
                        appById.put(app.Id, app);
                    }
                }

                String summary =
                    'Offre: ' + job.Name + '\n' +
                    'Top ' + String.valueOf(leads.size()) + ' candidat(s):\n';

                Integer idx = 1;
                for (Lead l : leads) {
                    Opportunity app = appById.get(l.ConvertedOpportunityId);
                    String name = fullName(l.FirstName, l.LastName, app != null ? app.Name : 'Candidat');
                    String stage = app != null ? app.StageName : 'N/A';
                    summary +=
                        idx + '. ' + name +
                        ' | Score ' + String.valueOf(l.Score_Matching__c) + '%' +
                        ' | Stage ' + stage + '\n';
                    idx++;
                }

                Lead best = leads[0];
                Opportunity bestApp = appById.get(best.ConvertedOpportunityId);
                out.success = true;
                out.bestCandidate = fullName(best.FirstName, best.LastName, bestApp != null ? bestApp.Name : 'Candidat');
                out.bestScore = best.Score_Matching__c;
                out.resume = summary + '\nRecommendation: prioriser ' + out.bestCandidate + '.';
            } catch (Exception ex) {
                out.success = false;
                out.resume = 'Erreur recherche meilleur candidat: ' + ex.getMessage();
            }

            results.add(out);
        }

        return results;
    }

    private static Opportunity resolveJobPosting(Input inp) {
        if (inp != null && inp.jobOpportunityId != null) {
            List<Opportunity> jobsById = [
                SELECT Id, Name, Is_Candidature__c, RecordType.DeveloperName
                FROM Opportunity
                WHERE Id = :inp.jobOpportunityId
                LIMIT 1
            ];
            if (!jobsById.isEmpty()) return jobsById[0];
        }

        if (inp == null || String.isBlank(inp.jobKeyword)) return null;
        String term = '%' + inp.jobKeyword.trim() + '%';
        List<Opportunity> jobsByName = [
            SELECT Id, Name, Is_Candidature__c, RecordType.DeveloperName
            FROM Opportunity
            WHERE Name LIKE :term
              AND (Is_Candidature__c = false OR Is_Candidature__c = null)
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];
        return jobsByName.isEmpty() ? null : jobsByName[0];
    }

    private static String fullName(String firstName, String lastName, String fallback) {
        String value = ((firstName != null ? firstName : '') + ' ' + (lastName != null ? lastName : '')).trim();
        return String.isNotBlank(value) ? value : fallback;
    }
}
