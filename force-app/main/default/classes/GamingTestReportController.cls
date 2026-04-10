public without sharing class GamingTestReportController {

    // ═══════════════════════════════════════
    //  VF Page Properties (for PDF rendering)
    // ═══════════════════════════════════════
    public String candidateName { get; set; }
    public String candidateEmail { get; set; }
    public String jobTitle { get; set; }
    public String currentStage { get; set; }
    public String oppId { get; set; }
    public String testDate { get; set; }
    public String reportDate { get; set; }
    public String reportRef { get; set; }
    public String scoreDisplay { get; set; }
    public Integer correctCount { get; set; }
    public Integer totalQuestions { get; set; }
    public String timeFormatted { get; set; }
    public Boolean passed { get; set; }
    public String recommendation { get; set; }
    public String portalUrl { get; set; }

    private static final String SITE_URL = 'https://orgfarm-3ed211f8bb-dev-ed.develop.my.site.com/home2/s/loginp';

    public GamingTestReportController() {
        oppId = ApexPages.currentPage().getParameters().get('id');
        if (String.isBlank(oppId)) return;

        Opportunity opp = [
            SELECT Id, Name, StageName, Gaming_Test_Score__c, Gaming_Test_Status__c, Gaming_Test_DateTime__c
            FROM Opportunity WHERE Id = :oppId LIMIT 1
        ];

        // Candidate info via 3-level fallback
        String email = '';
        String prenom = '';
        String nom = '';

        List<Lead> leads = [
            SELECT FirstName, LastName, Email FROM Lead
            WHERE ConvertedOpportunityId = :oppId AND IsConverted = true LIMIT 1
        ];
        if (!leads.isEmpty() && String.isNotBlank(leads[0].Email)) {
            email = leads[0].Email;
            prenom = leads[0].FirstName != null ? leads[0].FirstName : '';
            nom = leads[0].LastName != null ? leads[0].LastName : '';
        }
        if (String.isBlank(email)) {
            List<OpportunityContactRole> ocrs = [
                SELECT Contact.FirstName, Contact.LastName, Contact.Email
                FROM OpportunityContactRole
                WHERE OpportunityId = :oppId AND Contact.Email != null LIMIT 1
            ];
            if (!ocrs.isEmpty()) {
                email = ocrs[0].Contact.Email;
                prenom = ocrs[0].Contact.FirstName != null ? ocrs[0].Contact.FirstName : '';
                nom = ocrs[0].Contact.LastName != null ? ocrs[0].Contact.LastName : '';
            }
        }
        if (String.isBlank(email) && opp.AccountId != null) {
            List<Contact> contacts = [
                SELECT FirstName, LastName, Email FROM Contact
                WHERE AccountId = :opp.AccountId AND Email != null LIMIT 1
            ];
            if (!contacts.isEmpty()) {
                email = contacts[0].Email;
                prenom = contacts[0].FirstName != null ? contacts[0].FirstName : '';
                nom = contacts[0].LastName != null ? contacts[0].LastName : '';
            }
        }

        // Job title from Lead description
        String jTitle = opp.Name;
        if (!leads.isEmpty() && !String.isBlank(leads[0].Description)) {
            for (String line : leads[0].Description.split('\n')) {
                if (line.startsWith('JOB_ID:')) {
                    try {
                        Id jobOppId = (Id) line.replace('JOB_ID:', '').trim();
                        List<Opportunity> jobs = [SELECT Name FROM Opportunity WHERE Id = :jobOppId LIMIT 1];
                        if (!jobs.isEmpty()) jTitle = jobs[0].Name;
                    } catch (Exception e) { /* ignore */ }
                    break;
                }
            }
        }

        this.candidateName = prenom + ' ' + nom;
        this.candidateEmail = email;
        this.jobTitle = jTitle;
        this.currentStage = opp.StageName;
        this.oppId = opp.Id;
        Decimal sc = opp.Gaming_Test_Score__c != null ? opp.Gaming_Test_Score__c : 0;
        this.scoreDisplay = String.valueOf(sc.intValue());
        this.passed = sc >= 60;
        this.recommendation = this.passed
            ? 'Félicitations ! Votre performance au test Gaming démontre des compétences solides. Votre candidature est retenue et avancée à l\'étape suivante du processus de recrutement.'
            : 'Malheureusement, votre score n\'a pas atteint le seuil requis. Le recruteur examinera néanmoins votre dossier complet avant de prendre une décision finale.';
        this.portalUrl = SITE_URL;
        this.reportDate = Datetime.now().format('dd/MM/yyyy HH:mm');
        this.reportRef = 'ATS-' + String.valueOf(Datetime.now().format('yyyyMMdd')) + '-' + opp.Id.to15();
        this.testDate = opp.Gaming_Test_DateTime__c != null
            ? opp.Gaming_Test_DateTime__c.format('dd/MM/yyyy HH:mm')
            : this.reportDate;

        // Default stats (overridden when called from sendReport)
        this.correctCount = 0;
        this.totalQuestions = 10;
        this.timeFormatted = '—';
    }

    // ═══════════════════════════════════════
    //  SEND REPORT — called after test submit (async to avoid callout-after-DML)
    // ═══════════════════════════════════════
    public static void sendReportAsync(Id oppId, Decimal score, Integer correctCount,
                                        Integer totalQuestions, Integer timeSpentSeconds, Boolean passed) {
        sendReportFuture(oppId, score, correctCount, totalQuestions, timeSpentSeconds, passed);
    }

    @future(callout=true)
    public static void sendReportFuture(Id oppId, Decimal score, Integer correctCount,
                                         Integer totalQuestions, Integer timeSpentSeconds, Boolean passed) {

        Opportunity opp = [
            SELECT Id, Name, StageName, AccountId, Gaming_Test_Score__c, Gaming_Test_DateTime__c
            FROM Opportunity WHERE Id = :oppId LIMIT 1
        ];

        // 3-level email fallback
        String candidatEmail = '';
        String prenom = '';
        String nom = '';

        List<Lead> leads = [
            SELECT FirstName, LastName, Email, Description FROM Lead
            WHERE ConvertedOpportunityId = :oppId AND IsConverted = true LIMIT 1
        ];
        if (!leads.isEmpty() && String.isNotBlank(leads[0].Email)) {
            candidatEmail = leads[0].Email;
            prenom = leads[0].FirstName != null ? leads[0].FirstName : '';
            nom = leads[0].LastName != null ? leads[0].LastName : '';
        }
        if (String.isBlank(candidatEmail)) {
            List<OpportunityContactRole> ocrs = [
                SELECT Contact.FirstName, Contact.LastName, Contact.Email
                FROM OpportunityContactRole
                WHERE OpportunityId = :oppId AND Contact.Email != null LIMIT 1
            ];
            if (!ocrs.isEmpty()) {
                candidatEmail = ocrs[0].Contact.Email;
                prenom = ocrs[0].Contact.FirstName != null ? ocrs[0].Contact.FirstName : '';
                nom = ocrs[0].Contact.LastName != null ? ocrs[0].Contact.LastName : '';
            }
        }
        if (String.isBlank(candidatEmail) && opp.AccountId != null) {
            List<Contact> contacts = [
                SELECT FirstName, LastName, Email FROM Contact
                WHERE AccountId = :opp.AccountId AND Email != null LIMIT 1
            ];
            if (!contacts.isEmpty()) {
                candidatEmail = contacts[0].Email;
                prenom = contacts[0].FirstName != null ? contacts[0].FirstName : '';
                nom = contacts[0].LastName != null ? contacts[0].LastName : '';
            }
        }

        if (String.isBlank(candidatEmail)) return; // No email found

        // Job title
        String jobTitle = opp.Name;
        if (!leads.isEmpty() && leads[0].Description != null) {
            for (String line : leads[0].Description.split('\n')) {
                if (line.startsWith('JOB_ID:')) {
                    try {
                        Id jobOppId = (Id) line.replace('JOB_ID:', '').trim();
                        List<Opportunity> jobs = [SELECT Name FROM Opportunity WHERE Id = :jobOppId LIMIT 1];
                        if (!jobs.isEmpty()) jobTitle = jobs[0].Name;
                    } catch (Exception e) { /* ignore */ }
                    break;
                }
            }
        }

        String fullName = (prenom + ' ' + nom).trim();
        String reportRef = 'ATS-' + Datetime.now().format('yyyyMMdd') + '-' + opp.Id.to15();
        String dateFmt = Datetime.now().format('dd/MM/yyyy HH:mm');
        Integer mins = timeSpentSeconds / 60;
        Integer secs = Math.mod(timeSpentSeconds, 60);
        String timeFmt = mins + 'min ' + secs + 's';
        Integer scoreInt = score.intValue();

        String statusColor = passed ? '#22c55e' : '#ef4444';
        String statusBg = passed ? '#f0fdf4' : '#fef2f2';
        String statusIcon = passed ? '✓' : '✗';
        String statusLabel = passed ? 'TEST RÉUSSI' : 'TEST NON RÉUSSI';
        String recoText = passed
            ? 'Félicitations ! Votre candidature est retenue et avancée au stage <strong>' + opp.StageName + '</strong>. Le recruteur vous contactera pour la suite.'
            : 'Votre score n\'a pas atteint le seuil requis. Le recruteur examinera votre dossier complet avant de prendre une décision finale.';

        String stepsHtml = passed
            ? '<li>Votre candidature a été avancée au stage <strong>' + opp.StageName + '</strong></li>'
              + '<li>Le recruteur vous contactera pour planifier la prochaine évaluation</li>'
              + '<li>Suivez votre progression sur le portail candidat</li>'
            : '<li>Le recruteur examinera votre dossier complet (CV + score IA)</li>'
              + '<li>Vous serez notifié de la décision finale par email</li>'
              + '<li>N\'hésitez pas à postuler à d\'autres offres sur le portail</li>';

        // Build HTML email (rich ATS report)
        String html = '<!DOCTYPE html><html><head><meta charset="utf-8"/></head><body style="margin:0;padding:0;background:#f1f5f9;font-family:Arial,Helvetica,sans-serif;">'
            + '<div style="max-width:640px;margin:0 auto;background:#ffffff;border-radius:12px;overflow:hidden;margin-top:20px;margin-bottom:20px;box-shadow:0 4px 24px rgba(0,0,0,0.08);">'

            // Header
            + '<div style="background:linear-gradient(135deg,#667eea 0%,#5a67d8 100%);padding:28px 32px;color:#fff;">'
            + '<div style="font-size:22px;font-weight:bold;">TALAN Tunisie</div>'
            + '<div style="font-size:12px;opacity:0.85;margin-top:4px;">HR Talent Portal — Rapport ATS</div>'
            + '<div style="font-size:11px;opacity:0.7;margin-top:8px;">Réf: ' + reportRef + ' | ' + dateFmt + '</div>'
            + '</div>'

            // Status Banner
            + '<div style="margin:24px;padding:20px;background:' + statusBg + ';border:2px solid ' + statusColor + ';border-radius:10px;text-align:center;">'
            + '<div style="font-size:20px;font-weight:bold;color:' + statusColor + ';">' + statusIcon + ' ' + statusLabel + '</div>'
            + '<div style="font-size:12px;color:#64748b;margin-top:4px;">Test Gaming — Score : ' + scoreInt + '%</div>'
            + '</div>'

            // Candidate Info
            + '<div style="margin:0 24px 20px;padding:0;">'
            + '<div style="font-size:12px;font-weight:bold;color:#667eea;text-transform:uppercase;letter-spacing:0.5px;border-bottom:1px solid #e2e8f0;padding-bottom:6px;margin-bottom:12px;">Informations du candidat</div>'
            + '<table style="width:100%;border-collapse:collapse;font-size:12px;">'
            + '<tr><td style="padding:8px 12px;background:#f8fafc;font-weight:bold;color:#475569;border:1px solid #e2e8f0;width:30%;">Nom</td><td style="padding:8px 12px;border:1px solid #e2e8f0;">' + fullName + '</td></tr>'
            + '<tr><td style="padding:8px 12px;background:#f8fafc;font-weight:bold;color:#475569;border:1px solid #e2e8f0;">Email</td><td style="padding:8px 12px;border:1px solid #e2e8f0;">' + candidatEmail + '</td></tr>'
            + '<tr><td style="padding:8px 12px;background:#f8fafc;font-weight:bold;color:#475569;border:1px solid #e2e8f0;">Poste visé</td><td style="padding:8px 12px;border:1px solid #e2e8f0;">' + jobTitle + '</td></tr>'
            + '<tr><td style="padding:8px 12px;background:#f8fafc;font-weight:bold;color:#475569;border:1px solid #e2e8f0;">Étape actuelle</td><td style="padding:8px 12px;border:1px solid #e2e8f0;">' + opp.StageName + '</td></tr>'
            + '</table></div>'

            // Score Section
            + '<div style="margin:0 24px 20px;">'
            + '<div style="font-size:12px;font-weight:bold;color:#667eea;text-transform:uppercase;letter-spacing:0.5px;border-bottom:1px solid #e2e8f0;padding-bottom:6px;margin-bottom:12px;">Résultats détaillés</div>'
            + '<div style="text-align:center;padding:20px;background:#f8fafc;border:2px solid #e2e8f0;border-radius:10px;margin-bottom:12px;">'
            + '<div style="font-size:48px;font-weight:bold;color:' + statusColor + ';">' + scoreInt + '%</div>'
            + '<div style="font-size:11px;color:#94a3b8;text-transform:uppercase;letter-spacing:1px;">Score Gaming Test</div>'
            + '</div>'
            + '<table style="width:100%;border-collapse:collapse;font-size:12px;">'
            + '<tr>'
            + '<td style="width:33%;text-align:center;padding:12px;border:1px solid #e2e8f0;"><div style="font-size:16px;font-weight:bold;">' + correctCount + '/' + totalQuestions + '</div><div style="font-size:10px;color:#94a3b8;">Bonnes réponses</div></td>'
            + '<td style="width:33%;text-align:center;padding:12px;border:1px solid #e2e8f0;"><div style="font-size:16px;font-weight:bold;">' + timeFmt + '</div><div style="font-size:10px;color:#94a3b8;">Temps total</div></td>'
            + '<td style="width:34%;text-align:center;padding:12px;border:1px solid #e2e8f0;"><div style="font-size:16px;font-weight:bold;color:' + statusColor + ';">' + (passed ? 'Réussi' : 'Échoué') + '</div><div style="font-size:10px;color:#94a3b8;">Résultat</div></td>'
            + '</tr></table></div>'

            // Recommendation
            + '<div style="margin:0 24px 20px;">'
            + '<div style="font-size:12px;font-weight:bold;color:#667eea;text-transform:uppercase;letter-spacing:0.5px;border-bottom:1px solid #e2e8f0;padding-bottom:6px;margin-bottom:12px;">Recommandation</div>'
            + '<div style="padding:14px 18px;background:' + statusBg + ';border-left:4px solid ' + statusColor + ';border-radius:8px;font-size:12px;line-height:1.6;color:#1e293b;">'
            + recoText + '</div></div>'

            // Portal Access
            + '<div style="margin:0 24px 20px;">'
            + '<div style="font-size:12px;font-weight:bold;color:#667eea;text-transform:uppercase;letter-spacing:0.5px;border-bottom:1px solid #e2e8f0;padding-bottom:6px;margin-bottom:12px;">Accès au portail</div>'
            + '<div style="padding:16px 20px;background:#eef2ff;border:1px solid #c7d2fe;border-radius:10px;">'
            + '<div style="font-size:12px;font-weight:bold;color:#4338ca;margin-bottom:8px;">Votre espace candidat HR Talent Portal</div>'
            + '<a href="' + SITE_URL + '" style="display:inline-block;padding:10px 24px;background:linear-gradient(135deg,#667eea,#5a67d8);color:#fff;text-decoration:none;border-radius:8px;font-size:13px;font-weight:bold;">Se connecter au portail</a>'
            + '<div style="font-size:10px;color:#64748b;margin-top:8px;">Suivez l\'avancement de votre candidature en temps réel.</div>'
            + '</div></div>'

            // Next Steps
            + '<div style="margin:0 24px 24px;">'
            + '<div style="font-size:12px;font-weight:bold;color:#667eea;text-transform:uppercase;letter-spacing:0.5px;border-bottom:1px solid #e2e8f0;padding-bottom:6px;margin-bottom:12px;">Prochaines étapes</div>'
            + '<ol style="padding-left:20px;font-size:12px;color:#475569;line-height:1.8;">' + stepsHtml + '</ol></div>'

            // Footer
            + '<div style="background:#f8fafc;padding:16px 24px;text-align:center;font-size:10px;color:#94a3b8;border-top:1px solid #e2e8f0;">'
            + '<div>TALAN Tunisie — HR Talent Portal</div>'
            + '<div style="margin-top:4px;font-size:9px;">Ce document est confidentiel et destiné uniquement au candidat mentionné.</div>'
            + '</div>'

            + '</div></body></html>';

        // Generate PDF attachment from VF page (may fail for Community users without VF access)
        Messaging.EmailFileAttachment attach;
        try {
            PageReference pdfPage = Page.GamingTestReport;
            pdfPage.getParameters().put('id', oppId);
            Blob pdfBlob;
            if (!Test.isRunningTest()) {
                pdfBlob = pdfPage.getContentAsPDF();
            } else {
                pdfBlob = Blob.valueOf('Test PDF');
            }
            attach = new Messaging.EmailFileAttachment();
            attach.setFileName('Rapport_ATS_' + fullName.replace(' ', '_') + '_' + Datetime.now().format('yyyyMMdd') + '.pdf');
            attach.setBody(pdfBlob);
            attach.setContentType('application/pdf');
        } catch (Exception pdfEx) {
            System.debug(LoggingLevel.ERROR, 'PDF generation failed (user may lack VF page access): ' + pdfEx.getMessage());
            attach = null;
        }

        // Send email (with or without PDF attachment)
        try {
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new List<String>{ candidatEmail });
            mail.setSubject('Rapport ATS — Résultats de votre test Gaming | Talan Tunisie');
            mail.setHtmlBody(html);
            if (attach != null) {
                mail.setFileAttachments(new List<Messaging.EmailFileAttachment>{ attach });
            }
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
            System.debug('ATS Report email sent successfully to: ' + candidatEmail + (attach != null ? ' (with PDF)' : ' (without PDF)'));
        } catch (Exception emailEx) {
            System.debug(LoggingLevel.ERROR, 'ATS Report email send failed: ' + emailEx.getMessage());
        }
    }
}
