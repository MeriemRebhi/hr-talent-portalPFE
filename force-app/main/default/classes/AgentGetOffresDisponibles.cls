public without sharing class AgentGetOffresDisponibles {

    public class Input {
        @InvocableVariable(label='Filtre département (optionnel)')
        public String departement;
    }

    public class Output {
        @InvocableVariable(label='Liste des offres')
        public String offres;
        @InvocableVariable(label='Nombre d\'offres')
        public Integer nombre;
    }

    @InvocableMethod(
        label='Lister les offres Talan disponibles'
        description='Retourne les offres d\'emploi disponibles chez Talan.'
        category='Candidat RH'
    )
    public static List<Output> execute(List<Input> inputs) {
        List<Output> results = new List<Output>();
        for (Input inp : inputs) {
            Output out = new Output();
            List<Opportunity> offres = [
                SELECT Name, Localisation__c, Type_de_Contrat__c, Departement__c
                FROM Opportunity
                WHERE Is_Candidature__c = false AND IsClosed = false
                ORDER BY CreatedDate DESC LIMIT 10
            ];
            if (offres.isEmpty()) {
                out.nombre = 0;
                out.offres = 'Aucune offre disponible actuellement.';
            } else {
                out.nombre = offres.size();
                String txt = offres.size() + ' offre(s) disponible(s) :\n';
                Integer n = 1;
                for (Opportunity o : offres) {
                    txt += n + '. ' + o.Name;
                    if (o.Localisation__c != null)    txt += ' — ' + o.Localisation__c;
                    if (o.Type_de_Contrat__c != null) txt += ' (' + o.Type_de_Contrat__c + ')';
                    txt += '\n';
                    n++;
                }
                out.offres = txt;
            }
            results.add(out);
        }
        return results;
    }
}
