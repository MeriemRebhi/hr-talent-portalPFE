import { LightningElement, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from 'lightning/uiRecordApi';
import getCandidateDashboard from '@salesforce/apex/ApplicationController.getCandidateDashboard';
import updateCandidateProfile from '@salesforce/apex/ApplicationController.updateCandidateProfile';
import uploadCvForContact from '@salesforce/apex/ApplicationController.uploadCvForContact';
import getCvBase64 from '@salesforce/apex/ApplicationController.getCvBase64';
import getJobPostings from '@salesforce/apex/JobPostingController.getJobPostings';
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
    @track filterSort = 'recent';
    _wiredResult;
    _mapReady = false;
    _mapSent = false;

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
                        + ' à ' + dt.toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' });
                    gamingDurationLabel = c.gamingDuration === '30' ? '30 min'
                        : c.gamingDuration === '60' ? '1 heure'
                        : c.gamingDuration === '90' ? '1h30'
                        : c.gamingDuration === '120' ? '2 heures'
                        : (c.gamingDuration || '') + ' min';
                }
                return {
                    ...c,
                    formattedDate: c.date ? new Date(c.date).toLocaleDateString('fr-FR') : '',
                    closeDateFormatted: c.closeDate ? new Date(c.closeDate).toLocaleDateString('fr-FR') : '—',
                    badgeClass: this.getStageBadgeClass(c.stage),
                    stageLabel: this.getStageLabel(c.stage),
                    scoreClass: this.getScoreClass(c.score),
                    scoreLabel: this.getScoreLabel(c.score),
                    hasScore: c.score != null,
                    scoreBarClass: this.getScoreBarClass(c.score),
                    gamingScheduled,
                    gamingDateFmt,
                    gamingDurationLabel,
                    gamingMeetLink: c.gamingMeetLink || '',
                    gamingPassed: this._isStageAfter(c.stage, 'Gaming'),
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
                    // Step result classes
                    stepResultClass1: 'tl-step' + (c.score != null ? ' tl-done' : ''),
                    stepResultClass2: 'tl-step' + (c.gamingStatus === 'Completed' || this._isStageAfter(c.stage, 'Gaming') ? ' tl-done' : (c.stage === 'Gaming' ? ' tl-active' : '')),
                    stepResultClass3: 'tl-step' + (c.techStatus === 'Completed' ? ' tl-done' : (c.stage === 'Technique' ? ' tl-active' : '')),
                    stepResultClass4: 'tl-step' + (this._isStageAfterOrEqual(c.stage, 'RH Fit') ? ' tl-done' : (c.stage === 'Architecture' ? ' tl-active' : '')),
                    stepResultClass5: 'tl-step' + (c.stage === 'Closed' || c.stage === 'Hired' || c.stage === 'Rejected' ? ' tl-done' : (this._isStageAfterOrEqual(c.stage, 'RH Fit') ? ' tl-active' : ''))
                };
            });
        } else if (error) {
            this.errorMessage = error.body ? error.body.message : 'Erreur de chargement.';
        }
    }

    // ── Tabs ──
    get isOverview() { return this.activeTab === 'overview'; }
    get isCandidatures() { return this.activeTab === 'candidatures'; }
    get isProfile() { return this.activeTab === 'profile'; }

    get overviewTabClass() { return 'tab' + (this.activeTab === 'overview' ? ' active' : ''); }
    get candidaturesTabClass() { return 'tab' + (this.activeTab === 'candidatures' ? ' active' : ''); }
    get profileTabClass() { return 'tab' + (this.activeTab === 'profile' ? ' active' : ''); }

    handleTab(event) {
        this.activeTab = event.currentTarget.dataset.tab;
        this.selectedCandidature = null;
    }

    goToLogin() {
        const baseUrl = window.location.origin;
        const communityPath = window.location.pathname.split('/s/')[0];
        window.location.href = baseUrl + communityPath + '/s/loginp';
    }

    // ── Map ──
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

    // ── Profile Menu ──
    get profileMenuChevron() {
        return this.isProfileMenuOpen ? '▲' : '▼';
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
        const baseUrl = window.location.origin;
        const communityPath = window.location.pathname.split('/s/')[0];
        window.location.href = baseUrl + communityPath + '/s/';
    }

    viewCandidatureFromSidebar(event) {
        const id = event.currentTarget.dataset.id;
        this.selectedCandidature = this.candidatures.find(c => c.id === id);
        this.activeTab = 'candidatures';
    }

    // ── Profile ──
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
                    message: 'Impossible de télécharger le CV.',
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

    // ── Edit Profile ──
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
                title: 'Succès',
                message: 'Profil mis à jour avec succès.',
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

    // ── Pipeline step classes ──
    get saveButtonLabel() { return this.isSaving ? 'Enregistrement...' : 'Enregistrer'; }

    get pipelineStep1Class() {
        if (!this.selectedCandidature) return 'pipeline-step';
        const stageOrder = ['Gaming', 'Technique', 'Architecture', 'RH Fit', 'Closed'];
        const idx = stageOrder.indexOf(this.selectedCandidature.stage);
        if (idx > 0) return 'pipeline-step done';
        if (idx === 0) return 'pipeline-step active';
        return 'pipeline-step';
    }

    get pipelineStep2Class() {
        if (!this.selectedCandidature) return 'pipeline-step';
        const stageOrder = ['Gaming', 'Technique', 'Architecture', 'RH Fit', 'Closed'];
        const idx = stageOrder.indexOf(this.selectedCandidature.stage);
        if (idx > 1) return 'pipeline-step done';
        if (idx === 1) return 'pipeline-step active';
        return 'pipeline-step';
    }

    get pipelineStep3Class() {
        if (!this.selectedCandidature) return 'pipeline-step';
        const stageOrder = ['Gaming', 'Technique', 'Architecture', 'RH Fit', 'Closed'];
        const idx = stageOrder.indexOf(this.selectedCandidature.stage);
        if (idx > 2) return 'pipeline-step done';
        if (idx === 2) return 'pipeline-step active';
        return 'pipeline-step';
    }

    get pipelineStep4bClass() {
        if (!this.selectedCandidature) return 'pipeline-step';
        const stageOrder = ['Gaming', 'Technique', 'Architecture', 'RH Fit', 'Closed'];
        const idx = stageOrder.indexOf(this.selectedCandidature.stage);
        if (idx > 3) return 'pipeline-step done';
        if (idx === 3) return 'pipeline-step active';
        return 'pipeline-step';
    }

    get pipelineStep5bClass() {
        if (!this.selectedCandidature) return 'pipeline-step';
        const stageOrder = ['Gaming', 'Technique', 'Architecture', 'RH Fit', 'Closed'];
        const idx = stageOrder.indexOf(this.selectedCandidature.stage);
        if (idx >= 4) return 'pipeline-step done';
        if (idx === 4) return 'pipeline-step active';
        return 'pipeline-step';
    }

    // ── Candidature Detail ──
    viewCandidature(event) {
        const id = event.currentTarget.dataset.id;
        this.selectedCandidature = this.candidatures.find(c => c.id === id);
    }

    closeCandidatureDetail() {
        this.selectedCandidature = null;
    }

    // ── Upload CV ──
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
            this.cvUploadError = 'Format non supporté. Utilisez PDF ou Word (.doc, .docx).';
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
                        title: 'CV mis à jour',
                        message: 'Votre CV a été uploadé avec succès.',
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

    // ── Navigate ──
    goToOffers() {
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: { name: 'offres__c' }
        });
    }

    // ── Helpers ──
    getStageBadgeClass(stage) {
        if (!stage) return 'badge badge-gray';
        const s = stage.toLowerCase();
        if (s === 'gaming') return 'badge badge-blue';
        if (s === 'technique' || s === 'architecture') return 'badge badge-yellow';
        if (s.includes('rh') || s.includes('fit')) return 'badge badge-yellow';
        if (s.includes('hired') || s.includes('recruté')) return 'badge badge-green';
        if (s.includes('rejeté') || s.includes('closed') || s === 'rejected') return 'badge badge-red';
        return 'badge badge-gray';
    }

    getStageLabel(stage) {
        if (!stage) return 'En attente';
        const map = {
            'Gaming': 'Screening IA',
            'Technique': 'Entretien Technique',
            'Architecture': 'Entretien Architecture',
            'RH Fit': 'Entretien RH',
            'Hired': 'Recruté',
            'Rejected': 'Candidature rejetée'
        };
        return map[stage] || stage;
    }

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

    // ═══ GLOBAL PIPELINE ═══
    get _globalStageIndex() {
        const stageOrder = ['Gaming', 'Technique', 'Architecture', 'RH Fit', 'Closed'];
        let maxIdx = -1;
        this.candidatures.forEach(c => {
            const idx = stageOrder.indexOf(c.stage);
            if (idx > maxIdx) maxIdx = idx;
        });
        return maxIdx;
    }
    _globalStepClass(stepIdx) {
        const idx = this._globalStageIndex;
        if (idx > stepIdx) return 'pipeline-step done';
        if (idx === stepIdx) return 'pipeline-step active';
        return 'pipeline-step';
    }
    get globalStep1Class() { return this._globalStepClass(0); }
    get globalStep2Class() { return this._globalStepClass(1); }
    get globalStep3Class() { return this._globalStepClass(2); }
    get globalStep4Class() { return this._globalStepClass(3); }
    get globalStep5Class() { return this._globalStepClass(4); }

    // ═══ FILTERS ═══
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
            } else {
                list = list.filter(c => c.stage === this.filterStage);
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

    // ═══ HELPERS ═══
    _formatDateFr(dateStr) {
        if (!dateStr) return '';
        const d = new Date(dateStr);
        return d.toLocaleDateString('fr-FR', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' })
            + ' à ' + d.toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' });
    }

    _formatDuration(dur) {
        if (!dur) return '';
        if (dur === '30') return '30 minutes';
        if (dur === '45') return '45 minutes';
        if (dur === '60') return '1 heure';
        if (dur === '90') return '1h30';
        return dur + ' min';
    }

    _isStageAfter(stage, target) {
        const order = ['Gaming', 'Technique', 'Architecture', 'RH Fit', 'Closed'];
        return order.indexOf(stage) > order.indexOf(target);
    }

    _isStageAfterOrEqual(stage, target) {
        const order = ['Gaming', 'Technique', 'Architecture', 'RH Fit', 'Closed'];
        return order.indexOf(stage) >= order.indexOf(target);
    }

    // ═══ MAP (always visible at bottom) ═══
    renderedCallback() {
        if (!this._mapSent && !this.isGuest && !this.isLoading) {
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            setTimeout(() => this._sendMapData(), 600);
            this._mapSent = true;
        }
    }
}
