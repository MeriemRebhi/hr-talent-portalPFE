const fs = require('fs');
const path = 'c:/Users/rabhi/Downloads/hr-talent-portalPFE-main/hr-talent-portalPFE-main/force-app/main/default/lwc/candidateDashboard/candidateDashboard.html';

const html = `<template>
    <!-- Loading -->
    <template if:true={isLoading}>
        <div class="loading-container">
            <div class="spinner"></div>
            <p>Chargement de votre espace...</p>
        </div>
    </template>

    <!-- Guest / Non connecté -->
    <template if:true={isGuest}>
        <div class="guest-preview">
            <!-- Hero -->
            <div class="guest-hero">
                <div class="guest-hero-badge">Portail RH Talan</div>
                <h1 class="guest-hero-title">Votre Espace Candidat</h1>
                <p class="guest-hero-sub">Suivez vos candidatures, consultez vos scores IA et gérez votre profil en un seul endroit.</p>
                <button class="guest-login-btn" onclick={goToLogin}>
                    <span>Se connecter</span>
                    <span class="btn-arrow">→</span>
                </button>
                <p class="guest-hero-hint">Vous n'avez pas encore de compte ? Postulez à une offre pour en créer un automatiquement.</p>
            </div>

            <!-- Feature cards -->
            <div class="guest-features">
                <div class="guest-feat-card">
                    <div class="feat-icon">📊</div>
                    <h3>Tableau de bord</h3>
                    <p>Visualisez l'état de toutes vos candidatures en temps réel avec des indicateurs clairs.</p>
                </div>
                <div class="guest-feat-card">
                    <div class="feat-icon">🤖</div>
                    <h3>Score IA</h3>
                    <p>Consultez votre score de matching généré par notre IA Groq LLaMA pour chaque poste.</p>
                </div>
                <div class="guest-feat-card">
                    <div class="feat-icon">📄</div>
                    <h3>Gestion CV</h3>
                    <p>Retrouvez votre CV déposé et suivez son analyse automatique.</p>
                </div>
                <div class="guest-feat-card">
                    <div class="feat-icon">👤</div>
                    <h3>Mon Profil</h3>
                    <p>Mettez à jour vos informations personnelles et suivez votre parcours candidat.</p>
                </div>
            </div>

            <!-- Preview dashboard (blurred) -->
            <div class="guest-blur-section">
                <div class="blur-overlay">
                    <div class="blur-cta">
                        <span class="blur-lock">🔐</span>
                        <p>Connectez-vous pour accéder à votre espace</p>
                        <button class="guest-login-btn-sm" onclick={goToLogin}>Se connecter</button>
                    </div>
                </div>
                <div class="blur-content">
                    <div class="fake-stats">
                        <div class="fake-stat-card"><div class="fake-icon">📋</div><div class="fake-val">—</div><div class="fake-lbl">Candidatures</div></div>
                        <div class="fake-stat-card"><div class="fake-icon">✅</div><div class="fake-val">—</div><div class="fake-lbl">En cours</div></div>
                        <div class="fake-stat-card"><div class="fake-icon">🤖</div><div class="fake-val">—%</div><div class="fake-lbl">Meilleur score IA</div></div>
                        <div class="fake-stat-card"><div class="fake-icon">📄</div><div class="fake-val">—</div><div class="fake-lbl">CV déposé</div></div>
                    </div>
                </div>
            </div>
        </div>
    </template>

    <!-- Dashboard principal -->
    <template if:false={isGuest}>
        <template if:false={isLoading}>
            <div class="app-shell">

                <!-- NAVBAR -->
                <nav class="dash-navbar">
                    <div class="nav-logo" onclick={goToHome}>
                        <div class="nav-logo-mark">T</div>
                        <div class="nav-logo-info">
                            <span class="nav-brand-name">Talent Portal</span>
                            <span class="nav-brand-sub">by Talan Tunisie</span>
                        </div>
                    </div>
                    <div class="nav-links">
                        <button class="nav-link-btn" onclick={goToHome}>🏠 Accueil</button>
                        <button class="nav-link-btn" onclick={goToOffers}>🏢 Offres</button>
                        <button class="nav-link-btn active-nav" onclick={goToProfileTab}>📋 Mon espace</button>
                    </div>
                    <div class="nav-right">
                        <button class="btn-primary nav-cta" onclick={goToOffers}>+ Postuler</button>
                        <div class="profile-menu-wrapper">
                            <button class="profile-avatar-btn" onclick={toggleProfileMenu}>
                                <div class="avatar">{initials}</div>
                                <span class="avatar-chevron">{profileMenuChevron}</span>
                            </button>
                            <template if:true={isProfileMenuOpen}>
                                <div class="profile-dropdown">
                                    <div class="pd-head">
                                        <div class="pd-avatar-lg">{initials}</div>
                                        <div class="pd-head-info">
                                            <span class="pd-head-name">{fullName}</span>
                                            <span class="pd-head-email">{profile.email}</span>
                                        </div>
                                    </div>
                                    <div class="pd-actions">
                                        <button class="pd-action-btn" onclick={goToProfileTab}>
                                            <span class="pd-action-icon">👤</span>
                                            <span>Mon profil</span>
                                        </button>
                                        <button class="pd-action-btn" onclick={goToOffers}>
                                            <span class="pd-action-icon">🔍</span>
                                            <span>Voir les offres</span>
                                        </button>
                                    </div>
                                    <div class="pd-separator"></div>
                                    <button class="pd-logout-btn" onclick={handleLogout}>
                                        <span class="pd-action-icon">↪</span>
                                        <span>Se déconnecter</span>
                                    </button>
                                </div>
                            </template>
                        </div>
                    </div>
                </nav>

                <!-- CORPS -->
                <div class="app-body">

                    <!-- SIDEBAR -->
                    <aside class="sidebar">
                        <div class="sb-user">
                            <div class="sb-avatar">{initials}</div>
                            <div class="sb-user-info">
                                <span class="sb-name">{fullName}</span>
                                <span class="sb-role">Candidat</span>
                            </div>
                        </div>

                        <div class="sb-section">
                            <div class="sb-section-label">📋 Mes candidatures</div>
                            <template if:true={hasCandidatures}>
                                <div class="sb-cand-list">
                                    <template for:each={candidatures} for:item="c">
                                        <button key={c.id} class="sb-cand-item" data-id={c.id} onclick={viewCandidatureFromSidebar}>
                                            <div class="sb-cand-name">{c.name}</div>
                                            <div class="sb-cand-meta">
                                                <span class="sb-cand-date">⏰ {c.closeDateFormatted}</span>
                                                <span class={c.badgeClass}>{c.stageLabel}</span>
                                            </div>
                                        </button>
                                    </template>
                                </div>
                            </template>
                            <template if:false={hasCandidatures}>
                                <p class="sb-empty">Aucune candidature pour le moment.</p>
                            </template>
                        </div>

                        <div class="sb-footer">
                            <button class="sb-logout-btn" onclick={handleLogout}>
                                <span>↪</span>
                                <span>Se déconnecter</span>
                            </button>
                        </div>
                    </aside>

                    <!-- CONTENU PRINCIPAL -->
                    <main class="main-content">
                        <div class="main-welcome">
                            <h1 class="welcome-title">Bonjour, {profile.firstName} 👋</h1>
                            <p class="welcome-sub">Bienvenue sur votre espace candidat</p>
                        </div>

                        <!-- STATS -->
                        <div class="stats-row">
                            <div class="stat-card">
                                <div class="stat-icon">📋</div>
                                <div class="stat-value">{totalCandidatures}</div>
                                <div class="stat-label">Candidatures</div>
                            </div>
                            <div class="stat-card">
                                <div class="stat-icon">✅</div>
                                <div class="stat-value">{activeCount}</div>
                                <div class="stat-label">En cours</div>
                            </div>
                            <div class="stat-card">
                                <div class="stat-icon">🤖</div>
                                <div class="stat-value">
                                    <template if:true={bestScore}>{bestScore}%</template>
                                    <template if:false={bestScore}>—</template>
                                </div>
                                <div class="stat-label">Meilleur score IA</div>
                            </div>
                            <div class="stat-card">
                                <div class="stat-icon">📄</div>
                                <div class="stat-value">
                                    <template if:true={cv}>1</template>
                                    <template if:false={cv}>0</template>
                                </div>
                                <div class="stat-label">CV déposé</div>
                            </div>
                        </div>

                        <!-- TABS -->
                        <div class="tabs">
                            <button class={overviewTabClass} data-tab="overview" onclick={handleTab}>Vue d'ensemble</button>
                            <button class={candidaturesTabClass} data-tab="candidatures" onclick={handleTab}>Mes candidatures</button>
                            <button class={profileTabClass} data-tab="profile" onclick={handleTab}>Mon profil</button>
                        </div>

                        <!-- TAB: VUE D'ENSEMBLE -->
                        <template if:true={isOverview}>
                            <div class="tab-content">
                                <div class="overview-grid">
                                    <div class="panel">
                                        <div class="panel-header">
                                            <h3>📋 Dernières candidatures</h3>
                                        </div>
                                        <template if:true={hasCandidatures}>
                                            <div class="candidature-list">
                                                <template for:each={candidatures} for:item="c">
                                                    <div key={c.id} class="cand-row" data-id={c.id} onclick={viewCandidature}>
                                                        <div class="cand-info">
                                                            <span class="cand-name">{c.name}</span>
                                                            <div class="cand-chips">
                                                                <template if:true={c.department}><span class="chip chip-dept">🏢 {c.department}</span></template>
                                                                <template if:true={c.location}><span class="chip chip-loc">📍 {c.location}</span></template>
                                                                <template if:true={c.contractType}><span class="chip chip-ct">📝 {c.contractType}</span></template>
                                                                <span class="chip chip-date">📅 {c.formattedDate}</span>
                                                                <span class="chip chip-close">⏰ Clôture: {c.closeDateFormatted}</span>
                                                            </div>
                                                        </div>
                                                        <div class="cand-right">
                                                            <template if:true={c.hasScore}>
                                                                <span class={c.scoreClass}>{c.score}%</span>
                                                            </template>
                                                            <span class={c.badgeClass}>{c.stageLabel}</span>
                                                        </div>
                                                    </div>
                                                </template>
                                            </div>
                                        </template>
                                        <template if:false={hasCandidatures}>
                                            <div class="empty-panel">
                                                <p>Aucune candidature pour le moment.</p>
                                                <button class="btn-secondary" onclick={goToOffers}>Explorer les offres</button>
                                            </div>
                                        </template>
                                    </div>

                                    <div class="side-panels">
                                        <div class="panel panel-sm">
                                            <div class="panel-header">
                                                <h3>📄 Mon CV</h3>
                                                <label class="btn-mini-upload">
                                                    <template if:true={cv}>🔄 Remplacer</template>
                                                    <template if:false={cv}>⬆ Uploader</template>
                                                    <input type="file" accept=".pdf,.doc,.docx" onchange={handleCvFileChange} class="cv-hidden-input" />
                                                </label>
                                            </div>
                                            <template if:true={isUploadingCv}>
                                                <div class="cv-upload-progress">
                                                    <div class="cv-progress-bar"></div>
                                                    <span>Upload en cours...</span>
                                                </div>
                                            </template>
                                            <template if:true={cv}>
                                                <div class="cv-info">
                                                    <div class="cv-icon">📎</div>
                                                    <div class="cv-details">
                                                        <span class="cv-name">{cv.title}.{cv.extension}</span>
                                                        <span class="cv-meta">{cvSizeFormatted} • Déposé le {cvDateFormatted}</span>
                                                    </div>
                                                    <button class="btn-view-cv-sm" onclick={viewCv} title="Voir le CV">👁</button>
                                                </div>
                                            </template>
                                            <template if:false={cv}>
                                                <div class="empty-panel">
                                                    <p>Aucun CV déposé.</p>
                                                </div>
                                            </template>
                                        </div>
                                        <div class="panel panel-sm">
                                            <div class="panel-header">
                                                <h3>👤 Profil</h3>
                                            </div>
                                            <div class="profile-quick">
                                                <div class="pq-row">
                                                    <span class="pq-label">📧</span>
                                                    <span class="pq-value">{profile.email}</span>
                                                </div>
                                                <template if:true={profile.phone}>
                                                    <div class="pq-row">
                                                        <span class="pq-label">📞</span>
                                                        <span class="pq-value">{profile.phone}</span>
                                                    </div>
                                                </template>
                                                <div class="pq-row">
                                                    <span class="pq-label">📅</span>
                                                    <span class="pq-value">Depuis {memberSinceFormatted}</span>
                                                </div>
                                            </div>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </template>

                        <!-- TAB: CANDIDATURES -->
                        <template if:true={isCandidatures}>
                            <div class="tab-content">
                                <template if:true={selectedCandidature}>
                                    <div class="detail-panel">
                                        <button class="btn-back" onclick={closeCandidatureDetail}>← Retour</button>
                                        <div class="detail-header">
                                            <h2>{selectedCandidature.name}</h2>
                                            <span class={selectedCandidature.badgeClass}>{selectedCandidature.stageLabel}</span>
                                        </div>
                                        <div class="detail-grid">
                                            <div class="detail-item">
                                                <span class="detail-label">📅 Date de candidature</span>
                                                <span class="detail-value">{selectedCandidature.formattedDate}</span>
                                            </div>
                                            <div class="detail-item">
                                                <span class="detail-label">⏰ Date de clôture</span>
                                                <span class="detail-value">{selectedCandidature.closeDateFormatted}</span>
                                            </div>
                                            <template if:true={selectedCandidature.department}>
                                                <div class="detail-item">
                                                    <span class="detail-label">🏢 Département</span>
                                                    <span class="detail-value">{selectedCandidature.department}</span>
                                                </div>
                                            </template>
                                            <template if:true={selectedCandidature.location}>
                                                <div class="detail-item">
                                                    <span class="detail-label">📍 Localisation</span>
                                                    <span class="detail-value">{selectedCandidature.location}</span>
                                                </div>
                                            </template>
                                            <template if:true={selectedCandidature.contractType}>
                                                <div class="detail-item">
                                                    <span class="detail-label">📝 Type de contrat</span>
                                                    <span class="detail-value">{selectedCandidature.contractType}</span>
                                                </div>
                                            </template>
                                            <template if:true={selectedCandidature.hasScore}>
                                                <div class="detail-item">
                                                    <span class="detail-label">🤖 Score IA</span>
                                                    <span class={selectedCandidature.scoreClass}>{selectedCandidature.score}% — {selectedCandidature.scoreLabel}</span>
                                                </div>
                                            </template>
                                        </div>
                                        <div class="pipeline-section">
                                            <h3>Progression</h3>
                                            <div class="pipeline-track">
                                                <div class="pipeline-step done"><div class="step-dot">✓</div><span>Postulé</span></div>
                                                <div class="pipeline-line-h"></div>
                                                <div class="pipeline-step done"><div class="step-dot">✓</div><span>Analyse IA</span></div>
                                                <div class="pipeline-line-h"></div>
                                                <div class={pipelineStep3Class}><div class="step-dot">3</div><span>Screening</span></div>
                                                <div class="pipeline-line-h"></div>
                                                <div class={pipelineStep4Class}><div class="step-dot">4</div><span>Entretien</span></div>
                                                <div class="pipeline-line-h"></div>
                                                <div class={pipelineStep5Class}><div class="step-dot">5</div><span>Recruté</span></div>
                                            </div>
                                        </div>
                                    </div>
                                </template>
                                <template if:false={selectedCandidature}>
                                    <template if:true={hasCandidatures}>
                                        <div class="cand-cards">
                                            <template for:each={candidatures} for:item="c">
                                                <div key={c.id} class="cand-card" data-id={c.id} onclick={viewCandidature}>
                                                    <div class="cc-top">
                                                        <h3>{c.name}</h3>
                                                        <span class={c.badgeClass}>{c.stageLabel}</span>
                                                    </div>
                                                    <div class="cc-meta">
                                                        <template if:true={c.department}><span>🏢 {c.department}</span></template>
                                                        <template if:true={c.location}><span>📍 {c.location}</span></template>
                                                        <template if:true={c.contractType}><span>📝 {c.contractType}</span></template>
                                                        <span>📅 {c.formattedDate}</span>
                                                        <span>⏰ Clôture : {c.closeDateFormatted}</span>
                                                    </div>
                                                    <template if:true={c.hasScore}>
                                                        <div class="cc-score">
                                                            <div class="score-bar-bg"><div class={c.scoreBarClass}></div></div>
                                                            <span class={c.scoreClass}>{c.score}%</span>
                                                        </div>
                                                    </template>
                                                </div>
                                            </template>
                                        </div>
                                    </template>
                                    <template if:false={hasCandidatures}>
                                        <div class="empty-state">
                                            <div class="empty-icon">📋</div>
                                            <h3>Aucune candidature</h3>
                                            <p>Explorez les offres disponibles et postulez !</p>
                                            <button class="btn-primary" onclick={goToOffers}>Voir les offres</button>
                                        </div>
                                    </template>
                                </template>
                            </div>
                        </template>

                        <!-- TAB: PROFIL -->
                        <template if:true={isProfile}>
                            <div class="tab-content">
                                <div class="profile-panel">
                                    <div class="profile-card">
                                        <div class="pc-header">
                                            <div class="avatar avatar-lg">{initials}</div>
                                            <div>
                                                <h2>{fullName}</h2>
                                                <p class="pc-sub">Candidat • Membre depuis {memberSinceFormatted}</p>
                                            </div>
                                            <template if:false={isEditingProfile}>
                                                <button class="btn-edit" onclick={startEditProfile}>✏ Modifier</button>
                                            </template>
                                        </div>
                                        <template if:false={isEditingProfile}>
                                            <div class="profile-details">
                                                <div class="pd-row"><span class="pd-icon">📧</span><div><span class="pd-label">Email</span><span class="pd-value">{profile.email}</span></div></div>
                                                <div class="pd-row"><span class="pd-icon">📞</span><div><span class="pd-label">Téléphone</span><span class="pd-value">{profile.phone}</span></div></div>
                                                <div class="pd-row"><span class="pd-icon">📍</span><div><span class="pd-label">Adresse</span><span class="pd-value">{profile.address} {profile.city} {profile.postalCode}</span></div></div>
                                            </div>
                                        </template>
                                        <template if:true={isEditingProfile}>
                                            <div class="edit-form">
                                                <div class="form-row"><label>Téléphone</label><input type="tel" value={editPhone} onchange={handleEditPhone} /></div>
                                                <div class="form-row"><label>Adresse</label><input type="text" value={editAddress} onchange={handleEditAddress} /></div>
                                                <div class="form-row-2">
                                                    <div class="form-row"><label>Ville</label><input type="text" value={editCity} onchange={handleEditCity} /></div>
                                                    <div class="form-row"><label>Code postal</label><input type="text" value={editPostalCode} onchange={handleEditPostalCode} /></div>
                                                </div>
                                                <div class="form-actions">
                                                    <button class="btn-secondary" onclick={cancelEditProfile}>Annuler</button>
                                                    <button class="btn-primary" onclick={saveProfile} disabled={isSaving}>{saveButtonLabel}</button>
                                                </div>
                                            </div>
                                        </template>
                                    </div>

                                    <!-- CV Section -->
                                    <div class="profile-card cv-upload-card">
                                        <div class="cv-card-header">
                                            <h3 class="pc-title">📄 Mon CV</h3>
                                            <label class="btn-upload-cv">
                                                <span class="upload-btn-icon">☁</span>
                                                <template if:true={cv}>Remplacer le CV</template>
                                                <template if:false={cv}>Uploader mon CV</template>
                                                <input type="file" accept=".pdf,.doc,.docx" onchange={handleCvFileChange} class="cv-hidden-input" />
                                            </label>
                                        </div>
                                        <template if:true={isUploadingCv}>
                                            <div class="cv-uploading-banner"><div class="cv-spinner-sm"></div><span>Upload en cours...</span></div>
                                        </template>
                                        <template if:true={cvUploadSuccess}>
                                            <div class="cv-success-banner"><span>CV mis à jour avec succès !</span></div>
                                        </template>
                                        <template if:true={cvUploadError}>
                                            <div class="cv-error-banner">{cvUploadError}</div>
                                        </template>
                                        <template if:true={cv}>
                                            <div class="cv-file-display">
                                                <div class="cv-file-thumb"><span class="cv-ext-badge">{cv.extension}</span></div>
                                                <div class="cv-file-info">
                                                    <span class="cv-file-name">{cv.title}.{cv.extension}</span>
                                                    <span class="cv-file-meta">{cvSizeFormatted} • Déposé le {cvDateFormatted}</span>
                                                </div>
                                                <div class="cv-file-actions">
                                                    <button class="btn-view-cv" onclick={viewCv}><span>👁</span> Voir</button>
                                                    <button class="btn-dl-cv" onclick={downloadCv}><span>⬇</span> Télécharger</button>
                                                </div>
                                            </div>
                                        </template>
                                        <template if:false={cv}>
                                            <div class="cv-empty-zone">
                                                <div class="cv-empty-icon">⬆</div>
                                                <p class="cv-empty-title">Aucun CV déposé</p>
                                                <p class="cv-empty-hint">Formats acceptés : PDF, Word (.doc, .docx) — Max 5 MB</p>
                                            </div>
                                        </template>
                                    </div>
                                </div>
                            </div>
                        </template>

                        <!-- Error -->
                        <template if:true={errorMessage}>
                            <div class="error-bar">{errorMessage}</div>
                        </template>
                    </main>
                </div>
            </div>
        </template>
    </template>
</template>`;

fs.writeFileSync(path, html, 'utf8');
console.log('HTML file written successfully. Lines:', html.split('\n').length);
