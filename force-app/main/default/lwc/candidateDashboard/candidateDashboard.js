import { LightningElement, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from 'lightning/uiRecordApi';
import getCandidateDashboard from '@salesforce/apex/ApplicationController.getCandidateDashboard';
import updateCandidateProfile from '@salesforce/apex/ApplicationController.updateCandidateProfile';
import uploadCvForContact from '@salesforce/apex/ApplicationController.uploadCvForContact';
import getCvBase64 from '@salesforce/apex/ApplicationController.getCvBase64';
import getJobPostings from '@salesforce/apex/JobPostingController.getJobPostings';
import requestReschedule from '@salesforce/apex/TechnicalInterviewController.requestReschedule';
import WORLD_JOB_MAP from '@salesforce/resourceUrl/worldJobMap';

export default class CandidateDashboard extends NavigationMixin(LightningElement) {
    @track isLoading = true;
    @track isGuest = false;
    @track profile = {};
    @track candidatures = [];
    @track cv = null;
    @track totalCandidatures = 0;
    @track errorMessage = '';
    @track activeTab = 'overview';
    @track isEditingProfile = false;
    @track editPhone = '';
    @track editAddress = '';
    @track editCity = '';
    @track editPostalCode = '';
    @track isSaving = false;
    @track selectedCandidature = null;
    @track isUploadingCv = false;
    @track cvUploadError = '';
    @track cvUploadSuccess = false;
    @track isProfileMenuOpen = false;
    @track jobPostings = [];
    @track filterSearch = '';
    @track filterStage = '';
    @track filterScore = '';
    @track offersDisplayMode = 'all';
    @track savedJobsCount = 0;
    @track activeDetailSection = 'gaming';

    // Reschedule
    @track showRescheduleModal = false;
    @track rescheduleReason = '';
    @track isRescheduling = false;
    @track rescheduleSuccess = false;
    @track rescheduleOppId = '';
    @track filterSort = 'recent';
    _wiredResult;
    _mapReady = false;
    _mapSent = false;

    connectedCallback() {
        this.syncSavedJobsCount();
    }

    @wire(getJobPostings)
    wiredJobs({ data }) {
        if (data) {
            this.jobPostings = data;
            this._sendMapData();
        }
    }

    @wire(getCandidateDashboard)
    wiredDashboard(result) {
        this._wiredResult = result;
        const { data, error } = result;
        this.isLoading = false;
        if (data) {
            if (data.isGuest) {
                this.isGuest = true;
                return;
            }
            this.profile = data.profile || {};
            this.totalCandidatures = data.totalCandidatures || 0;
            this.cv = data.cv || null;

            this.candidatures = (data.candidatures || []).map(c => {
                const gamingScheduled = !!c.gamingDateTime;
                let gamingDateFmt = '';
                let gamingDurationLabel = '';
                if (gamingScheduled) {
                    const dt = new Date(c.gamingDateTime);
                    gamingDateFmt = dt.toLocaleDateString('fr-FR', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' })
                        + ' a ' + dt.toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' });
                    gamingDurationLabel = c.gamingDuration === '30' ? '30 min'
                        : c.gamingDuration === '60' ? '1 heure'
                        : c.gamingDuration === '90' ? '1h30'
                        : c.gamingDuration === '120' ? '2 heures'
                        : (c.gamingDuration || '') + ' min';
                }

                const normalizedStage = this._normalizeStage(c.stage);
                const normalizedContractStatus = this._normalizeContractStatus(c.contractStatus);
                const contractSentAtFmt = c.contractSentAt ? this._formatDateFr(c.contractSentAt) : '';
                const contractSignedAtFmt = c.contractSignedAt ? this._formatDateFr(c.contractSignedAt) : '';
                const contractDocUrl = c.signedContractDocumentId
                    ? '/sfc/servlet.shepherd/document/download/' + c.signedContractDocumentId + '?operationContext=S1'
                    : '';
                const rhfitCompleted = this._isRhfitCompleted(c.rhfitStatus);
                const rhfitScore = c.rhfitRecruiterScore != null
                    ? Math.round(c.rhfitRecruiterScore)
                    : (c.rhfitAiScore != null ? Math.round(c.rhfitAiScore) : null);
                const notifications = this._buildCandidateNotifications({
                    stage: normalizedStage,
                    contractStatus: normalizedContractStatus,
                    contractSentAtFmt,
                    contractSignedAtFmt
                });
                const progressIndex = this._computeProgressIndex({
                    stage: normalizedStage,
                    score: c.score,
                    gamingStatus: c.gamingStatus,
                    techStatus: c.techStatus,
                    archStatus: c.archStatus,
                    rhfitStatus: c.rhfitStatus,
                    contractStatus: normalizedContractStatus
                });

                return {
                    ...c,
                    stageNormalized: normalizedStage,
                    formattedDate: c.date ? new Date(c.date).toLocaleDateString('fr-FR') : '',
                    closeDateFormatted: c.closeDate ? new Date(c.closeDate).toLocaleDateString('fr-FR') : '-',
                    badgeClass: this.getStageBadgeClass(normalizedStage),
                    stageLabel: this.getStageLabel(normalizedStage),
                    scoreClass: this.getScoreClass(c.score),
                    scoreLabel: this.getScoreLabel(c.score),
                    hasScore: c.score != null,
                    scoreBarClass: this.getScoreBarClass(c.score),
                    progressIndex,
                    gamingScheduled,
                    gamingDateFmt,
                    gamingDurationLabel,
                    gamingMeetLink: c.gamingMeetLink || '',
                    gamingPassed: this._isStageAfter(normalizedStage, 'Gaming'),
                    gamingScore: c.gamingScore != null ? Math.round(c.gamingScore) : null,
                    gamingCompleted: c.gamingStatus === 'Completed',
                    gamingScoreLabel: c.gamingScore != null ? Math.round(c.gamingScore) + '%' : '',
                    gamingScoreClass: c.gamingScore >= 80 ? 'score-high' : c.gamingScore >= 60 ? 'score-medium' : c.gamingScore >= 40 ? 'score-medium' : 'score-low',
                    gamingBadgeLabel: c.gamingScore >= 80 ? 'Excellent' : c.gamingScore >= 60 ? 'Bon' : c.gamingScore >= 40 ? 'Moyen' : c.gamingScore != null ? 'Insuffisant' : '',
                    // Technical interview data
                    hasTechInterview: !!(c.techDate || c.techScore || c.techMeetLink),
                    techScore: c.techScore,
                    techCompleted: c.techStatus === 'Completed',
                    techMeetLink: c.techMeetLink || '',
                    techDateFmt: c.techDate ? this._formatDateFr(c.techDate) : '',
                    managerValidatedScore: c.managerValidatedScore != null ? Math.round(c.managerValidatedScore) : null,
                    hasManagerScore: c.managerValidatedScore != null,
                    techDurationLabel: this._formatDuration(c.techDuration),
                    techScoreClass: this.getScoreClass(c.techScore),
                    techExerciseLink: c.techMeetLink ? '' :
                        (c.techDate ? 'https://orgfarm-3ed211f8bb-dev-ed.develop.my.site.com/home2/s/entretientechnique1?id=' + c.id : ''),
                    techRescheduleRequested: c.techRescheduleRequested || false,
                    // Architecture interview data
                    hasArchInterview: !!(c.archDate || c.archScore || c.archMeetLink),
                    archScore: c.archScore != null ? Math.round(c.archScore) : null,
                    hasArchScore: c.archScore != null,
                    archCompleted: c.archStatus === 'Completed',
                    archDateFmt: c.archDate ? this._formatDateFr(c.archDate) : '',
                    archDurationLabel: this._formatDuration(c.archDuration),
                    archMeetLink: c.archMeetLink || '',
                    archJitsiRoom: c.archJitsiRoom || '',
                    archRescheduleRequested: c.archRescheduleRequested || false,
                    archFeedback: c.archFeedback || '',
                    archScoreClass: this.getScoreClass(c.archScore),
                    archInterviewLink: c.archDate ? 'https://orgfarm-3ed211f8bb-dev-ed.develop.my.site.com/home2/s/architectureinterview?id=' + c.id : '',

                    // RH Fit interview data
                    hasRHFitInterview: !!(c.rhfitDate || c.rhfitStatus || c.rhfitRecruiterScore != null || c.rhfitAiScore != null),
                    rhfitDateFmt: c.rhfitDate ? this._formatDateFr(c.rhfitDate) : '',
                    rhfitDurationLabel: this._formatDuration(c.rhfitDuration),
                    rhfitStatus: c.rhfitStatus || '',
                    rhfitCompleted,
                    rhfitScore,
                    rhfitScoreClass: this.getScoreClass(rhfitScore),
                    rhfitMeetLink: c.rhfitMeetLink || '',
                    rhfitJitsiRoom: c.rhfitJitsiRoom || '',
                    rhfitNotes: c.rhfitNotes || '',

                    // Contract data
                    contractStatus: normalizedContractStatus,
                    contractStatusLabel: this.getContractStatusLabel(normalizedContractStatus),
                    contractStatusClass: this.getContractStatusClass(normalizedContractStatus),
                    contractSentAtFmt,
                    contractSignedAtFmt,
                    docusignEnvelopeId: c.docusignEnvelopeId || '',
                    hasSignedContract: !!c.signedContractDocumentId,
                    signedContractDocumentId: c.signedContractDocumentId || '',
                    signedContractFileName: c.signedContractFileName || 'Contrat_signe.pdf',
                    signedContractUrl: contractDocUrl,
                    isHired: normalizedStage === 'Closed Won',
                    isRejected: normalizedStage === 'Closed Lost',
                    candidateNotifications: notifications,
                    hasCandidateNotifications: notifications.length > 0,

                    // Step result classes
                    stepResultClass1: this._timelineStepClass(progressIndex, 0),
                    stepResultClass2: this._timelineStepClass(progressIndex, 1),
                    stepResultClass3: this._timelineStepClass(progressIndex, 2),
                    stepResultClass4: this._timelineStepClass(progressIndex, 3),
                    stepResultClass5: this._timelineStepClass(progressIndex, 4),
                    stepResultClass6: this._timelineStepClass(progressIndex, 5)
                };
            });
        } else if (error) {
            this.errorMessage = error.body ? error.body.message : 'Erreur de chargement.';
        }
    }

    // Tabs
    get isOverview() { return this.activeTab === 'overview'; }
    get isOffers() { return this.activeTab === 'offers'; }
    get isCandidatures() { return this.activeTab === 'candidatures'; }
    get isProfile() { return this.activeTab === 'profile'; }

    get overviewTabClass() { return 'tab' + (this.activeTab === 'overview' ? ' active' : ''); }
    get offersTabClass() { return 'tab' + (this.activeTab === 'offers' ? ' active' : ''); }
    get candidaturesTabClass() { return 'tab' + (this.activeTab === 'candidatures' ? ' active' : ''); }
    get profileTabClass() { return 'tab' + (this.activeTab === 'profile' ? ' active' : ''); }
    get navHomeClass() { return 'nav-link-btn' + (this.activeTab === 'overview' ? ' active-nav' : ''); }
    get navOffersClass() { return 'nav-link-btn' + (this.activeTab === 'offers' ? ' active-nav' : ''); }
    get navSpaceClass() {
        return 'nav-link-btn' + (['candidatures', 'profile'].includes(this.activeTab) ? ' active-nav' : '');
    }
    get navSavedClass() {
        return 'nav-saved-btn' + (this.activeTab === 'offers' && this.offersDisplayMode === 'saved' ? ' active' : '');
    }
    get showSavedOffersList() {
        return this.activeTab === 'offers' && this.offersDisplayMode === 'saved';
    }

    handleTab(event) {
        this.activeTab = event.currentTarget.dataset.tab;
        this.selectedCandidature = null;
        this.isProfileMenuOpen = false;
    }

    goToLogin() {
        const baseUrl = window.location.origin;
        const communityPath = window.location.pathname.split('/s/')[0];
        window.location.href = baseUrl + communityPath + '/s/loginp';
    }

    // Map
    get mapUrl() { return WORLD_JOB_MAP; }

    handleMapLoad() {
        this._mapReady = false;
        // give the iframe time to parse before posting
        setTimeout(() => this._sendMapData(), 400);
    }

    _sendMapData() {
        const iframe = this.template.querySelector('.map-iframe');
        if (!iframe || !iframe.contentWindow) return;
        const payload = {
            type: 'INIT_MAP',
            jobPostings: (this.jobPostings || []).map(j => ({
                id: j.Id,
                name: j.Name,
                location: j.Localisation__c || '',
                department: j.Departement__c || '',
                contractType: j.Type_de_Contrat__c || '',
                closeDate: j.CloseDate || null
            })),
            candidateCity: (this.profile || {}).city || null
        };
        iframe.contentWindow.postMessage(payload, '*');
    }

    // Profile Menu
    get profileMenuChevron() {
        return this.isProfileMenuOpen ? '^' : 'v';
    }
    get profileBtnClass() {
        return 'profile-avatar-btn' + (this.isProfileMenuOpen ? ' open' : '');
    }

    toggleProfileMenu() {
        this.isProfileMenuOpen = !this.isProfileMenuOpen;
    }

    goToProfileTab() {
        this.isProfileMenuOpen = false;
        this.activeTab = 'profile';
        this.selectedCandidature = null;
    }

    handleLogout() {
        const baseUrl = window.location.origin;
        const communityPath = window.location.pathname.split('/s/')[0];
        const loginUrl = baseUrl + communityPath + '/s/loginp';
        window.location.href = baseUrl + communityPath + '/secur/logout.jsp?retUrl=' + encodeURIComponent(loginUrl);
    }

    goToHome() {
        this.isProfileMenuOpen = false;
        this.activeTab = 'overview';
        this.offersDisplayMode = 'all';
        this.selectedCandidature = null;
    }

    goToCandidateSpace() {
        this.isProfileMenuOpen = false;
        this.activeTab = 'candidatures';
        this.offersDisplayMode = 'all';
        this.selectedCandidature = null;
    }

    viewCandidatureFromSidebar(event) {
        const id = event.currentTarget.dataset.id;
        this.selectedCandidature = this.candidatures.find(c => c.id === id);
        this.activeDetailSection = this._getDefaultDetailSection(this.selectedCandidature);
        this.activeTab = 'candidatures';
    }

    // Profile
    get initials() {
        const f = (this.profile.firstName || '').charAt(0).toUpperCase();
        const l = (this.profile.lastName || '').charAt(0).toUpperCase();
        return f + l;
    }

    get capitalizedFirstName() {
        const n = (this.profile.firstName || '').trim();
        if (!n) return '';
        return n.charAt(0).toUpperCase() + n.slice(1).toLowerCase();
    }

    get fullName() {
        const f = (this.profile.firstName || '').trim();
        const l = (this.profile.lastName || '').trim();
        const cap = s => s ? s.charAt(0).toUpperCase() + s.slice(1).toLowerCase() : '';
        return (cap(f) + ' ' + cap(l)).trim();
    }

    get memberSinceFormatted() {
        if (!this.profile.memberSince) return '';
        return new Date(this.profile.memberSince).toLocaleDateString('fr-FR', { year: 'numeric', month: 'long' });
    }

    get profilePhoneDisplay() {
        return (this.profile.phone || '').trim() || 'Non renseigne';
    }

    get profileAddressDisplay() {
        const parts = [
            (this.profile.address || '').trim(),
            (this.profile.city || '').trim(),
            (this.profile.postalCode || '').trim()
        ].filter(Boolean);
        return parts.length ? parts.join(', ') : 'Adresse non renseignee';
    }

    get profileCompletionLabel() {
        const fields = [
            (this.profile.email || '').trim(),
            (this.profile.phone || '').trim(),
            (this.profile.address || '').trim(),
            (this.profile.city || '').trim(),
            (this.profile.postalCode || '').trim()
        ];
        const completed = fields.filter(Boolean).length;
        if (completed >= 5) return 'Profil complet';
        if (completed >= 3) return 'Profil presque complet';
        return 'Profil a completer';
    }

    get cvSizeFormatted() {
        if (!this.cv || !this.cv.size) return '';
        const kb = this.cv.size / 1024;
        return kb > 1024 ? (kb / 1024).toFixed(1) + ' MB' : Math.round(kb) + ' KB';
    }

    get cvDateFormatted() {
        if (!this.cv || !this.cv.uploadDate) return '';
        return new Date(this.cv.uploadDate).toLocaleDateString('fr-FR');
    }

    get cvDownloadUrl() {
        if (!this.cv || !this.cv.documentId) return null;
        return '/sfc/servlet.shepherd/document/download/' + this.cv.documentId + '?operationContext=S1';
    }

    viewCv() {
        if (!this.cv || !this.cv.documentId) return;
        getCvBase64({ documentId: this.cv.documentId })
            .then(res => {
                const ext = (this.cv.extension || 'pdf').toLowerCase();
                const mimeMap = {
                    pdf: 'application/pdf',
                    doc: 'application/msword',
                    docx: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
                };
                const mime = mimeMap[ext] || 'application/octet-stream';
                const byteChars = atob(res.base64);
                const byteNums = new Uint8Array(byteChars.length);
                for (let i = 0; i < byteChars.length; i++) {
                    byteNums[i] = byteChars.charCodeAt(i);
                }
                const blob = new Blob([byteNums], { type: mime });
                const url = URL.createObjectURL(blob);
                window.open(url, '_blank');
            })
            .catch(() => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Erreur',
                    message: 'Impossible d\'ouvrir le CV.',
                    variant: 'error'
                }));
            });
    }

    downloadCv() {
        if (!this.cv || !this.cv.documentId) return;
        getCvBase64({ documentId: this.cv.documentId })
            .then(res => {
                const ext = (this.cv.extension || 'pdf').toLowerCase();
                const mimeMap = {
                    pdf: 'application/pdf',
                    doc: 'application/msword',
                    docx: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
                };
                const mime = mimeMap[ext] || 'application/octet-stream';
                const byteChars = atob(res.base64);
                const byteNums = new Uint8Array(byteChars.length);
                for (let i = 0; i < byteChars.length; i++) {
                    byteNums[i] = byteChars.charCodeAt(i);
                }
                const blob = new Blob([byteNums], { type: mime });
                const url = URL.createObjectURL(blob);
                const a = document.createElement('a');
                a.href = url;
                a.download = (this.cv.title || 'CV') + '.' + ext;
                document.body.appendChild(a);
                a.click();
                document.body.removeChild(a);
                URL.revokeObjectURL(url);
            })
            .catch(() => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Erreur',
                    message: 'Impossible de telecharger le CV.',
                    variant: 'error'
                }));
            });
    }

    downloadSignedContract() {
        if (!this.selectedCandidature || !this.selectedCandidature.signedContractDocumentId) return;

        getCvBase64({ documentId: this.selectedCandidature.signedContractDocumentId })
            .then(res => {
                const providedFileName = (this.selectedCandidature.signedContractFileName || '').trim();
                let ext = '';

                if (providedFileName.includes('.')) {
                    ext = providedFileName.substring(providedFileName.lastIndexOf('.') + 1).toLowerCase();
                }
                if (!ext && res && res.fileType) {
                    ext = String(res.fileType).toLowerCase();
                }
                if (!ext) {
                    ext = 'pdf';
                }

                const mimeMap = {
                    pdf: 'application/pdf',
                    doc: 'application/msword',
                    docx: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
                };
                const mime = mimeMap[ext] || 'application/octet-stream';

                const byteChars = atob(res.base64);
                const byteNums = new Uint8Array(byteChars.length);
                for (let i = 0; i < byteChars.length; i++) {
                    byteNums[i] = byteChars.charCodeAt(i);
                }

                const blob = new Blob([byteNums], { type: mime });
                const url = URL.createObjectURL(blob);
                const a = document.createElement('a');

                let finalName = providedFileName;
                if (!finalName) {
                    const baseTitle = (res && res.title) ? res.title : 'Contrat_signe';
                    finalName = baseTitle.endsWith('.' + ext) ? baseTitle : (baseTitle + '.' + ext);
                }

                a.href = url;
                a.download = finalName;
                document.body.appendChild(a);
                a.click();
                document.body.removeChild(a);
                URL.revokeObjectURL(url);
            })
            .catch(() => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Erreur',
                    message: 'Impossible de telecharger le contrat signe.',
                    variant: 'error'
                }));
            });
    }

    get hasCandidatures() {
        return this.candidatures.length > 0;
    }

    get bestScore() {
        if (this.candidatures.length === 0) return null;
        let max = 0;
        this.candidatures.forEach(c => { if (c.score > max) max = c.score; });
        return max > 0 ? max : null;
    }

    get activeCount() {
        return this.candidatures.filter(c => 
            c.stage && !c.stage.toLowerCase().includes('rejet') && !c.stage.toLowerCase().includes('closed')
        ).length;
    }

    // Edit Profile
    startEditProfile() {
        this.editPhone = this.profile.phone || '';
        this.editAddress = this.profile.address || '';
        this.editCity = this.profile.city || '';
        this.editPostalCode = this.profile.postalCode || '';
        this.isEditingProfile = true;
    }

    cancelEditProfile() {
        this.isEditingProfile = false;
    }

    handleEditPhone(e) { this.editPhone = e.target.value; }
    handleEditAddress(e) { this.editAddress = e.target.value; }
    handleEditCity(e) { this.editCity = e.target.value; }
    handleEditPostalCode(e) { this.editPostalCode = e.target.value; }

    saveProfile() {
        this.isSaving = true;
        updateCandidateProfile({
            phone: this.editPhone,
            address: this.editAddress,
            city: this.editCity,
            postalCode: this.editPostalCode
        })
        .then(() => {
            this.profile = {
                ...this.profile,
                phone: this.editPhone,
                address: this.editAddress,
                city: this.editCity,
                postalCode: this.editPostalCode
            };
            this.isEditingProfile = false;
            this.isSaving = false;
            this.dispatchEvent(new ShowToastEvent({
                title: 'Succes',
                message: 'Profil mis a jour avec succes.',
                variant: 'success'
            }));
            return refreshApex(this._wiredResult);
        })
        .catch(err => {
            this.isSaving = false;
            this.dispatchEvent(new ShowToastEvent({
                title: 'Erreur',
                message: err.body ? err.body.message : 'Erreur lors de la sauvegarde.',
                variant: 'error'
            }));
        });
    }

    // Pipeline step classes
    get saveButtonLabel() { return this.isSaving ? 'Enregistrement...' : 'Enregistrer'; }

    // Candidature Detail
    viewCandidature(event) {
        const id = event.currentTarget.dataset.id;
        this.selectedCandidature = this.candidatures.find(c => c.id === id);
        this.activeDetailSection = this._getDefaultDetailSection(this.selectedCandidature);
    }

    closeCandidatureDetail() {
        this.selectedCandidature = null;
        this.activeDetailSection = 'gaming';
    }

    handleDetailSectionSelect(event) {
        const target = event ? event.currentTarget : null;
        const section = target && target.dataset ? target.dataset.section : null;
        if (!section) return;
        this.activeDetailSection = section;

        if (!this.selectedCandidature) {
            this.selectedCandidature = this._pickDefaultCandidature();
        }
        if (this.selectedCandidature) {
            this.activeTab = 'candidatures';
        }
    }

    _detailSectionClass(section) {
        return 'detail-section-btn' + (this.activeDetailSection === section ? ' active' : '');
    }

    _getDefaultDetailSection(candidature) {
        if (!candidature) return 'gaming';
        const stage = this._normalizeStage(candidature.stageNormalized || candidature.stage);
        if (stage === 'Closed Won') return 'contract';
        if (stage === 'RH Fit') return 'rhfit';
        if (stage === 'Architecture') return 'architecture';
        if (stage === 'Technique') return 'technical';
        return 'gaming';
    }

    get sectionGamingClass() { return this._detailSectionClass('gaming'); }
    get sectionTechnicalClass() { return this._detailSectionClass('technical'); }
    get sectionArchitectureClass() { return this._detailSectionClass('architecture'); }
    get sectionRhfitClass() { return this._detailSectionClass('rhfit'); }
    get sectionHiredClass() { return this._detailSectionClass('hired'); }
    get sectionContractClass() { return this._detailSectionClass('contract'); }
    get sectionGuideClass() { return this._detailSectionClass('guide'); }
    get sectionDocumentationClass() { return this._detailSectionClass('documentation'); }
    get sectionMeetingsClass() { return this._detailSectionClass('meetings'); }
    get sectionFaqClass() { return this._detailSectionClass('faq'); }
    get sectionSupportClass() { return this._detailSectionClass('support'); }

    get isSectionGaming() { return this.activeDetailSection === 'gaming'; }
    get isSectionTechnical() { return this.activeDetailSection === 'technical'; }
    get isSectionArchitecture() { return this.activeDetailSection === 'architecture'; }
    get isSectionRhfit() { return this.activeDetailSection === 'rhfit'; }
    get isSectionHired() { return this.activeDetailSection === 'hired'; }
    get isSectionContract() { return this.activeDetailSection === 'contract'; }
    get isSectionGuide() { return this.activeDetailSection === 'guide'; }
    get isSectionDocumentation() { return this.activeDetailSection === 'documentation'; }
    get isSectionMeetings() { return this.activeDetailSection === 'meetings'; }
    get isSectionFaq() { return this.activeDetailSection === 'faq'; }
    get isSectionSupport() { return this.activeDetailSection === 'support'; }
    get showSidebarDetailNav() { return this.hasCandidatures && this.activeTab !== 'offers'; }

    _pickDefaultCandidature() {
        if (!this.candidatures || this.candidatures.length === 0) return null;
        const sorted = [...this.candidatures].sort((a, b) => new Date(b.date || 0) - new Date(a.date || 0));
        return sorted[0] || this.candidatures[0];
    }

    // Upload CV
    handleCvFileChange(event) {
        const file = event.target.files[0];
        if (!file) return;

        const maxSize = 5 * 1024 * 1024; // 5 MB
        if (file.size > maxSize) {
            this.cvUploadError = 'Fichier trop volumineux. Maximum 5 MB.';
            return;
        }
        const allowed = ['application/pdf', 'application/msword',
            'application/vnd.openxmlformats-officedocument.wordprocessingml.document'];
        if (!allowed.includes(file.type)) {
            this.cvUploadError = 'Format non supporte. Utilisez PDF ou Word (.doc, .docx).';
            return;
        }

        this.cvUploadError = '';
        this.cvUploadSuccess = false;
        this.isUploadingCv = true;

        const reader = new FileReader();
        reader.onload = () => {
            const base64 = reader.result.split(',')[1];
            uploadCvForContact({ fileName: file.name, base64Data: base64 })
                .then(() => {
                    this.cvUploadSuccess = true;
                    this.isUploadingCv = false;
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'CV mis a jour',
                        message: 'Votre CV a ete upload avec succes.',
                        variant: 'success'
                    }));
                    return refreshApex(this._wiredResult);
                })
                .catch(err => {
                    this.cvUploadError = err.body ? err.body.message : 'Erreur lors de l\'upload.';
                    this.isUploadingCv = false;
                });
        };
        reader.readAsDataURL(file);
    }

    // Navigate
    goToOffers() {
        this.isProfileMenuOpen = false;
        this.activeTab = 'offers';
        this.offersDisplayMode = 'all';
        this.selectedCandidature = null;
    }

    goToSavedOffers() {
        this.isProfileMenuOpen = false;
        this.activeTab = 'offers';
        this.offersDisplayMode = 'saved';
        this.selectedCandidature = null;
    }

    handleSavedJobsChange(event) {
        const count = event.detail && typeof event.detail.count === 'number'
            ? event.detail.count
            : 0;
        this.savedJobsCount = count;
    }

    syncSavedJobsCount() {
        try {
            const raw = window.localStorage.getItem('candidateSavedJobs');
            const parsed = raw ? JSON.parse(raw) : [];
            this.savedJobsCount = Array.isArray(parsed) ? parsed.length : 0;
        } catch (e) {
            this.savedJobsCount = 0;
        }
    }

    get hasJobPostings() {
        return (this.jobPostings || []).length > 0;
    }

    get openJobsCount() {
        return (this.jobPostings || []).length;
    }

    get offersViewTitle() {
        return this.openJobsCount + ' offre' + (this.openJobsCount > 1 ? 's' : '') + ' disponible' + (this.openJobsCount > 1 ? 's' : '');
    }

    get jobPostingCards() {
        return (this.jobPostings || []).map(job => {
            const description = job.Description_Poste__c || 'Consultez les details de cette opportunite.';
            return {
                id: job.Id,
                title: job.Name,
                department: job.Departement__c || 'General',
                location: job.Localisation__c || 'Tunisie',
                contractType: job.Type_de_Contrat__c || 'Contrat a definir',
                salary: job.Salaire_Propos__c != null ? job.Salaire_Propos__c + ' TND' : 'Salaire a definir',
                closeDateFormatted: job.CloseDate ? new Date(job.CloseDate).toLocaleDateString('fr-FR') : 'Date a confirmer',
                descriptionExcerpt: this._truncateText(description, 180)
            };
        });
    }

    // Helpers
    getScoreClass(score) {
        if (score == null) return '';
        if (score >= 60) return 'score-high';
        if (score >= 40) return 'score-medium';
        return 'score-low';
    }

    getScoreBarClass(score) {
        if (score == null) return 'score-bar-fill sw-0';
        if (score >= 80) return 'score-bar-fill sw-100 bar-green';
        if (score >= 60) return 'score-bar-fill sw-75 bar-green';
        if (score >= 40) return 'score-bar-fill sw-50 bar-yellow';
        if (score >= 20) return 'score-bar-fill sw-25 bar-red';
        return 'score-bar-fill sw-10 bar-red';
    }

    getScoreLabel(score) {
        if (score == null) return 'En attente';
        if (score >= 80) return 'Excellent';
        if (score >= 60) return 'Bon';
        if (score >= 40) return 'Moyen';
        return 'Insuffisant';
    }

    // GLOBAL PIPELINE
    _globalStepClass(stepIdx) {
        if (stepIdx === 5 && this._hasCompletedContract) {
            return 'pipeline-step done';
        }
        const idx = this._globalStageIndex;
        if (idx > stepIdx) return 'pipeline-step done';
        if (idx === stepIdx) return 'pipeline-step active';
        return 'pipeline-step';
    }

    // FILTERS
    handleFilterSearch(e) { this.filterSearch = e.target.value; }
    handleFilterStage(e) { this.filterStage = e.target.value; }
    handleFilterScore(e) { this.filterScore = e.target.value; }
    handleFilterSort(e) { this.filterSort = e.target.value; }

    get hasActiveFilters() {
        return this.filterSearch || this.filterStage || this.filterScore || this.filterSort !== 'recent';
    }
    clearFilters() {
        this.filterSearch = '';
        this.filterStage = '';
        this.filterScore = '';
        this.filterSort = 'recent';
    }

    get filteredCandidatures() {
        let list = [...this.candidatures];
        if (this.filterSearch) {
            const q = this.filterSearch.toLowerCase();
            list = list.filter(c => (c.name || '').toLowerCase().includes(q) || (c.jobTitle || '').toLowerCase().includes(q));
        }
        if (this.filterStage) {
            if (this.filterStage === 'Closed') {
                list = list.filter(c => c.stage && (c.stage.toLowerCase().includes('closed') || c.stage.toLowerCase().includes('reject') || c.stage.toLowerCase().includes('hired')));
            } else if (this.filterStage === 'ClosedWon') {
                list = list.filter(c => this._normalizeStage(c.stage) === 'Closed Won');
            } else if (this.filterStage === 'ClosedLost') {
                list = list.filter(c => this._normalizeStage(c.stage) === 'Closed Lost');
            } else {
                list = list.filter(c => this._normalizeStage(c.stage) === this.filterStage);
            }
        }
        if (this.filterScore === 'high') list = list.filter(c => c.score >= 60);
        else if (this.filterScore === 'medium') list = list.filter(c => c.score >= 40 && c.score < 60);
        else if (this.filterScore === 'low') list = list.filter(c => c.score != null && c.score < 40);

        if (this.filterSort === 'recent') list.sort((a, b) => new Date(b.date || 0) - new Date(a.date || 0));
        else if (this.filterSort === 'oldest') list.sort((a, b) => new Date(a.date || 0) - new Date(b.date || 0));
        else if (this.filterSort === 'score-desc') list.sort((a, b) => (b.score || 0) - (a.score || 0));
        else if (this.filterSort === 'score-asc') list.sort((a, b) => (a.score || 0) - (b.score || 0));
        else if (this.filterSort === 'alpha') list.sort((a, b) => (a.name || '').localeCompare(b.name || ''));
        return list;
    }
    get filteredCount() { return this.filteredCandidatures.length; }
    get hasFilteredCandidatures() { return this.filteredCandidatures.length > 0; }

    // RESCHEDULE
    openRescheduleModal() {
        if (!this.selectedCandidature) return;
        this.rescheduleOppId = this.selectedCandidature.id;
        this.rescheduleReason = '';
        this.rescheduleSuccess = false;
        this.showRescheduleModal = true;
    }

    closeRescheduleModal() {
        this.showRescheduleModal = false;
    }

    handleRescheduleReason(e) {
        this.rescheduleReason = e.target.value;
    }

    stopReschedulePropagation(e) { e.stopPropagation(); }

    async confirmReschedule() {
        this.isRescheduling = true;
        try {
            await requestReschedule({
                oppId: this.rescheduleOppId,
                reason: this.rescheduleReason || 'Aucune raison precisee'
            });
            this.rescheduleSuccess = true;
            // Update local data
            this.candidatures = this.candidatures.map(c => {
                if (c.id === this.rescheduleOppId) {
                    return { ...c, techRescheduleRequested: true };
                }
                return c;
            });
            if (this.selectedCandidature && this.selectedCandidature.id === this.rescheduleOppId) {
                this.selectedCandidature = { ...this.selectedCandidature, techRescheduleRequested: true };
            }
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            setTimeout(() => { this.showRescheduleModal = false; }, 2000);
        } catch (err) {
            this.errorMessage = err.body ? err.body.message : 'Erreur lors de la demande de report.';
        } finally {
            this.isRescheduling = false;
        }
    }

    // HELPERS
    _formatDateFr(dateStr) {
        if (!dateStr) return '';
        const d = new Date(dateStr);
        return d.toLocaleDateString('fr-FR', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' })
            + ' a ' + d.toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' });
    }

    _formatDuration(dur) {
        if (!dur) return '';
        if (dur === '30') return '30 minutes';
        if (dur === '45') return '45 minutes';
        if (dur === '60') return '1 heure';
        if (dur === '90') return '1h30';
        return dur + ' min';
    }

    _truncateText(value, maxLength) {
        if (!value) return '';
        if (value.length <= maxLength) return value;
        return value.slice(0, maxLength).trim() + '...';
    }

    // MAP (always visible at bottom)
    // ====== PROCESS OVERRIDES (real hiring flow) ======
    getStageBadgeClass(stage) {
        const normalized = this._normalizeStage(stage);
        if (!normalized) return 'badge badge-gray';
        if (normalized === 'Gaming') return 'badge badge-blue';
        if (normalized === 'Technique' || normalized === 'Architecture' || normalized === 'RH Fit') return 'badge badge-yellow';
        if (normalized === 'Closed Won') return 'badge badge-green';
        if (normalized === 'Closed Lost') return 'badge badge-red';
        return 'badge badge-gray';
    }

    getStageLabel(stage) {
        const normalized = this._normalizeStage(stage);
        if (!normalized) return 'En attente';
        const map = {
            Gaming: 'Screening IA',
            Technique: 'Entretien Technique',
            Architecture: 'Entretien Architecture',
            'RH Fit': 'Entretien RH Fit',
            'Closed Won': 'Embauche validee',
            'Closed Lost': 'Non retenu'
        };
        return map[normalized] || normalized;
    }

    _normalizeStage(stage) {
        if (!stage) return '';
        const s = String(stage).trim().toLowerCase();
        if (s === 'gaming' || s.includes('gaming')) return 'Gaming';
        if (s === 'technique' || s.includes('tech')) return 'Technique';
        if (s === 'architecture' || s.includes('arch')) return 'Architecture';
        if (s === 'rh fit' || s === 'rhfit' || (s.includes('rh') && s.includes('fit'))) return 'RH Fit';
        if (s === 'closed won' || s.includes('won') || s.includes('embauch')) return 'Closed Won';
        if (s === 'closed lost' || s.includes('lost') || s.includes('reject') || s.includes('non retenu')) return 'Closed Lost';
        return stage;
    }

    _normalizeContractStatus(contractStatus) {
        if (!contractStatus) return '';
        const s = String(contractStatus).trim().toLowerCase();
        if (s === 'sent' || s === 'created' || s === 'delivered') return 'Sent';
        if (s === 'completed' || s === 'signed') return 'Completed';
        if (s === 'declined') return 'Declined';
        if (s === 'voided') return 'Voided';
        if (s === 'failed' || s === 'error') return 'Failed';
        return contractStatus;
    }

    getContractStatusLabel(contractStatus) {
        const s = this._normalizeContractStatus(contractStatus);
        if (!s) return 'Non envoye';
        const map = {
            Sent: 'Envoye pour signature',
            Completed: 'Signe',
            Declined: 'Refuse',
            Voided: 'Annule',
            Failed: 'Erreur'
        };
        return map[s] || s;
    }

    getContractStatusClass(contractStatus) {
        const s = this._normalizeContractStatus(contractStatus);
        if (s === 'Completed') return 'badge badge-green';
        if (s === 'Sent') return 'badge badge-blue';
        if (s === 'Declined' || s === 'Voided' || s === 'Failed') return 'badge badge-red';
        return 'badge badge-gray';
    }

    _isRhfitCompleted(status) {
        if (!status) return false;
        const s = String(status).toLowerCase();
        return s.includes('validated') || s.includes('complete');
    }

    _stageRank(stage) {
        const normalized = this._normalizeStage(stage);
        const map = {
            Gaming: 1,
            Technique: 2,
            Architecture: 3,
            'RH Fit': 4,
            'Closed Won': 5,
            'Closed Lost': 5
        };
        return map[normalized] || 0;
    }

    _computeProgressIndex(ctx) {
        let idx = -1;
        if (ctx.score != null) idx = Math.max(idx, 0); // Screening IA
        if (ctx.gamingStatus === 'Completed' || this._stageRank(ctx.stage) >= 2) idx = Math.max(idx, 1);
        if (ctx.techStatus === 'Completed' || this._stageRank(ctx.stage) >= 3) idx = Math.max(idx, 2);
        if (ctx.archStatus === 'Completed' || this._stageRank(ctx.stage) >= 4) idx = Math.max(idx, 3);
        if (this._isRhfitCompleted(ctx.rhfitStatus) || this._stageRank(ctx.stage) >= 5) idx = Math.max(idx, 4);
        if (this._normalizeStage(ctx.stage) === 'Closed Won' || this._normalizeContractStatus(ctx.contractStatus)) idx = Math.max(idx, 5);
        return idx;
    }

    _timelineStepClass(progressIndex, stepIndex) {
        if (progressIndex > stepIndex) return 'tl-step tl-done';
        if (progressIndex === stepIndex) return 'tl-step tl-active';
        return 'tl-step';
    }

    _buildCandidateNotifications(ctx) {
        const out = [];
        const stage = this._normalizeStage(ctx.stage);
        const contractStatus = this._normalizeContractStatus(ctx.contractStatus);

        if (stage === 'Closed Won') {
            out.push({
                id: 'hired',
                type: 'success',
                typeClass: 'cand-notif cand-notif-success',
                title: 'Felicitations, vous etes embauche(e)',
                message: 'Votre candidature est validee. La phase contrat est en cours.'
            });
        } else if (stage === 'Closed Lost') {
            out.push({
                id: 'rejected',
                type: 'warning',
                typeClass: 'cand-notif cand-notif-warning',
                title: 'Mise a jour candidature',
                message: 'Votre candidature n a pas ete retenue pour cette offre.'
            });
        }

        if (contractStatus === 'Sent') {
            out.push({
                id: 'contract_sent',
                type: 'info',
                typeClass: 'cand-notif cand-notif-info',
                title: 'Contrat envoye pour signature',
                message: ctx.contractSentAtFmt
                    ? ('Contrat envoye le ' + ctx.contractSentAtFmt + '. Verifiez votre email DocuSign.')
                    : 'Contrat envoye. Verifiez votre email DocuSign.'
            });
        }

        if (contractStatus === 'Completed') {
            out.push({
                id: 'contract_signed',
                type: 'success',
                typeClass: 'cand-notif cand-notif-success',
                title: 'Contrat signe',
                message: ctx.contractSignedAtFmt
                    ? ('Contrat signe le ' + ctx.contractSignedAtFmt + '.')
                    : 'Contrat signe et archive.'
            });
        }

        return out;
    }

    _isStageAfter(stage, target) {
        return this._stageRank(stage) > this._stageRank(target);
    }

    _isStageAfterOrEqual(stage, target) {
        return this._stageRank(stage) >= this._stageRank(target);
    }

    _pipelineStepFromSelected(stepIdx) {
        if (!this.selectedCandidature) return 'pipeline-step';
        if (stepIdx === 5 && this.selectedCandidature.contractStatus === 'Completed') {
            return 'pipeline-step done';
        }
        const idx = this.selectedCandidature.progressIndex == null ? -1 : this.selectedCandidature.progressIndex;
        if (idx > stepIdx) return 'pipeline-step done';
        if (idx === stepIdx) return 'pipeline-step active';
        return 'pipeline-step';
    }

    get pipelineStep1Class() { return this._pipelineStepFromSelected(0); }
    get pipelineStep2Class() { return this._pipelineStepFromSelected(1); }
    get pipelineStep3Class() { return this._pipelineStepFromSelected(2); }
    get pipelineStep4bClass() { return this._pipelineStepFromSelected(3); }
    get pipelineStep5bClass() { return this._pipelineStepFromSelected(4); }
    get pipelineStep6bClass() { return this._pipelineStepFromSelected(5); }

    get _globalStageIndex() {
        let maxIdx = -1;
        this.candidatures.forEach(c => {
            const idx = c.progressIndex == null ? -1 : c.progressIndex;
            if (idx > maxIdx) maxIdx = idx;
        });
        return maxIdx;
    }

    get globalStep1Class() { return this._globalStepClass(0); }
    get globalStep2Class() { return this._globalStepClass(1); }
    get globalStep3Class() { return this._globalStepClass(2); }
    get globalStep4Class() { return this._globalStepClass(3); }
    get globalStep5Class() { return this._globalStepClass(4); }
    get globalStep6Class() { return this._globalStepClass(5); }
    get _hasCompletedContract() {
        return (this.candidatures || []).some(c => c.contractStatus === 'Completed');
    }
    renderedCallback() {
        if (!this._mapSent && !this.isGuest && !this.isLoading) {
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            setTimeout(() => this._sendMapData(), 600);
            this._mapSent = true;
        }
    }
}



