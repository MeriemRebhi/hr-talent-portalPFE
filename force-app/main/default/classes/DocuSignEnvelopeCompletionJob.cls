public without sharing class DocuSignEnvelopeCompletionJob implements Queueable, Database.AllowsCallouts {

    private String envelopeId;

    public DocuSignEnvelopeCompletionJob(String envelopeId) {
        this.envelopeId = envelopeId;
    }

    public void execute(QueueableContext context) {
        if (String.isBlank(envelopeId)) return;

        List<DocuSign_Envelope__c> rows = [
            SELECT Id,
                   Opportunity__c,
                   Envelope_Id__c,
                   Status__c,
                   Signed_File_ContentDocumentId__c
            FROM DocuSign_Envelope__c
            WHERE Envelope_Id__c = :envelopeId
            LIMIT 1
        ];

        if (rows.isEmpty()) return;

        DocuSign_Envelope__c env = rows[0];
        if (env.Opportunity__c == null) return;

        if (String.isNotBlank(env.Signed_File_ContentDocumentId__c)) {
            return;
        }

        try {
            Blob pdf = DocuSignEnvelopeService.downloadCombinedSignedPdf(envelopeId);
            if (pdf == null || pdf.size() == 0) {
                return;
            }

            String stamp = Datetime.now().format('yyyyMMdd_HHmmss');
            ContentVersion cv = new ContentVersion(
                Title = 'Contrat_signe_' + stamp,
                PathOnClient = 'Contrat_signe_' + stamp + '.pdf',
                VersionData = pdf
            );
            insert cv;

            ContentVersion created = [
                SELECT Id, ContentDocumentId
                FROM ContentVersion
                WHERE Id = :cv.Id
                LIMIT 1
            ];

            if (created.ContentDocumentId != null) {
                ContentDocumentLink link = new ContentDocumentLink(
                    ContentDocumentId = created.ContentDocumentId,
                    LinkedEntityId = env.Opportunity__c,
                    ShareType = 'V',
                    Visibility = 'AllUsers'
                );
                insert link;

                env.Signed_File_ContentDocumentId__c = created.ContentDocumentId;
            }

            env.Status__c = 'completed';
            env.Completed_At__c = System.now();
            update env;

            Opportunity oppPatch = new Opportunity(
                Id = env.Opportunity__c,
                Contract_Status__c = 'Completed',
                Contract_Signed_At__c = System.now(),
                Contract_Error__c = null
            );
            update oppPatch;

        } catch (Exception ex) {
            env.Error_Message__c = ex.getMessage().left(32768);
            update env;
        }
    }
}
