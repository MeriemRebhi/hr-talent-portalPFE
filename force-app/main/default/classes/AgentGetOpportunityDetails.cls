public without sharing class AgentGetOpportunityDetails {

    public class Input {
        @InvocableVariable(label='Opportunity Id (optionnel)')
        public Id opportunityId;

        @InvocableVariable(label='Nom Opportunity (optionnel)')
        public String opportunityName;
    }

    public class Output {
        @InvocableVariable(label='Succes')
        public Boolean success;

        @InvocableVariable(label='Resume opportunity')
        public String resume;

        @InvocableVariable(label='Nom')
        public String name;

        @InvocableVariable(label='Stage')
        public String stage;

        @InvocableVariable(label='Date cloture')
        public Date closeDate;

        @InvocableVariable(label='Type')
        public String type;

        @InvocableVariable(label='Recommendation')
        public String recommendation;
    }

    @InvocableMethod(
        label='Obtenir details opportunity (recruteur)'
        description='Retourne les details d une opportunity (candidature ou offre) avec recommandation de prochaine action.'
        category='Recruteur RH'
    )
    public static List<Output> execute(List<Input> inputs) {
        List<Output> results = new List<Output>();
        if (inputs == null) return results;

        for (Input inp : inputs) {
            Output out = new Output();
            out.success = false;
            out.resume = 'Opportunity introuvable.';
            out.recommendation = 'Verifier l Id ou le nom.';

            try {
                Opportunity opp = resolveOpportunity(inp);
                if (opp == null) {
                    results.add(out);
                    continue;
                }

                String candidateName = resolveCandidateName(opp.Id, opp.Name);
                String oppType = isCandidateOpportunity(opp) ? 'Candidature' : 'Offre';

                String techStatus = resolveTechStatus(opp.Id);
                String archStatus = resolveArchStatus(opp.Id);
                String rhfitStatus = resolveRHFitStatus(opp.Id);

                String recommendation = buildRecommendation(opp.StageName, techStatus, archStatus, rhfitStatus);

                out.success = true;
                out.name = opp.Name;
                out.stage = opp.StageName;
                out.closeDate = opp.CloseDate;
                out.type = oppType;
                out.recommendation = recommendation;
                out.resume =
                    'Opportunity: ' + opp.Name + '\n' +
                    'Type: ' + oppType + '\n' +
                    'Candidat: ' + candidateName + '\n' +
                    'Stage actuel: ' + safe(opp.StageName) + '\n' +
                    'Date de cloture: ' + (opp.CloseDate != null ? String.valueOf(opp.CloseDate) : 'N/A') + '\n' +
                    'Owner: ' + (opp.Owner != null ? opp.Owner.Name : 'N/A') + '\n' +
                    'Score Matching: ' + (opp.Score_Matching__c != null ? String.valueOf(opp.Score_Matching__c) + '%' : 'N/A') + '\n' +
                    'Gaming Score: ' + (opp.Gaming_Test_Score__c != null ? String.valueOf(opp.Gaming_Test_Score__c) + '%' : 'N/A') + '\n' +
                    'Technique: ' + techStatus + '\n' +
                    'Architecture: ' + archStatus + '\n' +
                    'RH Fit: ' + rhfitStatus + '\n' +
                    'Recommendation: ' + recommendation;
            } catch (Exception ex) {
                out.success = false;
                out.resume = 'Erreur details opportunity: ' + ex.getMessage();
                out.recommendation = 'Verifier les permissions et les donnees.';
            }

            results.add(out);
        }
        return results;
    }

    private static Opportunity resolveOpportunity(Input inp) {
        if (inp == null) return null;

        if (inp.opportunityId != null) {
            List<Opportunity> byId = [
                SELECT Id, Name, StageName, CloseDate, Owner.Name, Is_Candidature__c,
                       RecordType.DeveloperName, Score_Matching__c, Gaming_Test_Score__c
                FROM Opportunity
                WHERE Id = :inp.opportunityId
                LIMIT 1
            ];
            if (!byId.isEmpty()) return byId[0];
        }

        if (String.isBlank(inp.opportunityName)) return null;
        String likeTerm = '%' + inp.opportunityName.trim() + '%';
        List<Opportunity> byName = [
            SELECT Id, Name, StageName, CloseDate, Owner.Name, Is_Candidature__c,
                   RecordType.DeveloperName, Score_Matching__c, Gaming_Test_Score__c
            FROM Opportunity
            WHERE Name LIKE :likeTerm
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];
        return byName.isEmpty() ? null : byName[0];
    }

    private static Boolean isCandidateOpportunity(Opportunity opp) {
        if (opp == null) return false;
        if (opp.Is_Candidature__c == true) return true;
        if (opp.RecordType != null && opp.RecordType.DeveloperName == 'Application') return true;
        return false;
    }

    private static String resolveCandidateName(Id oppId, String fallback) {
        List<Lead> leads = [
            SELECT FirstName, LastName
            FROM Lead
            WHERE ConvertedOpportunityId = :oppId
            AND IsConverted = true
            LIMIT 1
        ];
        if (!leads.isEmpty()) {
            String fullName = (
                (leads[0].FirstName != null ? leads[0].FirstName : '') + ' ' +
                (leads[0].LastName != null ? leads[0].LastName : '')
            ).trim();
            if (String.isNotBlank(fullName)) return fullName;
        }
        return String.isNotBlank(fallback) ? fallback : 'Candidat';
    }

    private static String resolveTechStatus(Id oppId) {
        List<Technical_Interview__c> rec = [
            SELECT Status__c, Score__c
            FROM Technical_Interview__c
            WHERE Opportunity__c = :oppId
            LIMIT 1
        ];
        if (rec.isEmpty()) return 'Non planifie';
        String status = String.isNotBlank(rec[0].Status__c) ? rec[0].Status__c : 'N/A';
        if (rec[0].Score__c != null) status += ' (' + String.valueOf(rec[0].Score__c) + '/100)';
        return status;
    }

    private static String resolveArchStatus(Id oppId) {
        List<Architecture_Interview__c> rec = [
            SELECT Status__c, Score__c
            FROM Architecture_Interview__c
            WHERE Opportunity__c = :oppId
            LIMIT 1
        ];
        if (rec.isEmpty()) return 'Non planifie';
        String status = String.isNotBlank(rec[0].Status__c) ? rec[0].Status__c : 'N/A';
        if (rec[0].Score__c != null) status += ' (' + String.valueOf(rec[0].Score__c) + '/100)';
        return status;
    }

    private static String resolveRHFitStatus(Id oppId) {
        List<RH_Fit_Interview__c> rec = [
            SELECT Status__c, AI_RHFit_Score__c, Recruiter_Validated_Score__c
            FROM RH_Fit_Interview__c
            WHERE Opportunity__c = :oppId
            LIMIT 1
        ];
        if (rec.isEmpty()) return 'Non planifie';
        String status = String.isNotBlank(rec[0].Status__c) ? rec[0].Status__c : 'N/A';
        if (rec[0].Recruiter_Validated_Score__c != null) {
            status += ' (valide: ' + String.valueOf(rec[0].Recruiter_Validated_Score__c) + '/100)';
        } else if (rec[0].AI_RHFit_Score__c != null) {
            status += ' (IA: ' + String.valueOf(rec[0].AI_RHFit_Score__c) + '/100)';
        }
        return status;
    }

    private static String buildRecommendation(String stageName, String techStatus, String archStatus, String rhfitStatus) {
        String stage = stageName != null ? stageName.toLowerCase() : '';
        if (stage == 'gaming') return 'Planifier ou valider l entretien Technique.';
        if (stage == 'technique') return 'Evaluer l entretien Technique puis passer en Architecture si valide.';
        if (stage == 'architecture') return 'Si Architecture validee, passer en RH Fit.';
        if (stage == 'rh fit') return 'Finaliser RH Fit puis valider vers Closed Won ou Closed Lost.';
        if (stage == 'closed won') return 'Candidat embauche. Demarrer onboarding.';
        if (stage == 'closed lost') return 'Dossier clos. Conserver feedback pour amelioration continue.';

        if (rhfitStatus.toLowerCase().contains('validated')) return 'Passage possible vers Closed Won.';
        if (archStatus.toLowerCase().contains('completed')) return 'Passage possible vers RH Fit.';
        if (techStatus.toLowerCase().contains('completed')) return 'Passage possible vers Architecture.';
        return 'Verifier les etapes precedentes avant changement de statut.';
    }

    private static String safe(String value) {
        return String.isNotBlank(value) ? value : 'N/A';
    }
}
