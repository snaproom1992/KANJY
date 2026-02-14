/**
 * KANJY 共有イベント情報コンポーネント
 * HTML + CSS + JS を完全に一元管理し、全ページで統一
 */
(function () {
    'use strict';

    // ========================================
    // コンポーネント専用CSS（各ページのCSSに依存しない）
    // ========================================
    const eventInfoStyles = `
        /* イベント情報セクション - 共有スタイル */
        .kanjy-event-info-section {
            background: #ffffff;
            border-bottom: 1px solid #E9E5E0;
            padding: 2rem 0;
        }

        .kanjy-event-info-section .kanjy-container {
            max-width: 56rem;
            margin: 0 auto;
            padding: 0 1.5rem;
        }

        @media (min-width: 640px) {
            .kanjy-event-info-section .kanjy-container {
                padding: 0 2rem;
            }
        }

        @media (min-width: 1024px) {
            .kanjy-event-info-section .kanjy-container {
                padding: 0 3rem;
            }
        }

        /* タイトル */
        .kanjy-event-title {
            font-size: 2rem;
            line-height: 1.3;
            font-weight: 600;
            letter-spacing: -0.01em;
            color: #111827;
            margin-bottom: 0.75rem;
        }

        /* 説明文 */
        .kanjy-event-description {
            font-size: 1rem;
            line-height: 1.6;
            font-weight: 400;
            color: #78716c;
            margin-top: 0.5rem;
        }

        /* ローディングステータス */
        .kanjy-loading-status {
            color: #666;
            font-size: 14px;
            margin-top: 8px;
        }

        /* 情報カード（場所・予算・回答期限）のコンテナ */
        .kanjy-info-cards {
            margin-top: 2rem;
        }

        .kanjy-info-cards > div {
            margin-bottom: 1rem;
        }

        .kanjy-info-cards > div:last-child {
            margin-bottom: 0;
        }

        /* ラベル（場所・回答期限等） */
        .kanjy-info-label {
            font-size: 0.75rem;
            line-height: 1.4;
            font-weight: 500;
            color: #9CA3AF;
            text-transform: uppercase;
            letter-spacing: 0.05em;
            margin-bottom: 0.75rem;
        }

        /* 値（新橋、2026年2月21日 等） */
        .kanjy-info-value {
            font-size: 1rem;
            line-height: 1.6;
            font-weight: 500;
            color: #374151;
        }

        /* エラー表示 */
        .kanjy-error-display {
            margin-top: 1rem;
        }

        /* モバイル対応 */
        @media (max-width: 768px) {
            .kanjy-event-title {
                font-size: 1.5rem;
                line-height: 1.3;
            }
        }

        @media (max-width: 375px) {
            .kanjy-event-title {
                font-size: 1.5rem;
            }
        }
    `;

    // ========================================
    // イベント情報セクション HTML
    // ========================================
    const eventInfoHTML = `
        <section class="kanjy-event-info-section">
            <div class="kanjy-container">
                <!-- Event Title & Description -->
                <div style="margin-bottom: 2rem;">
                    <h1 id="event-title" class="kanjy-event-title">
                        読み込み中...
                    </h1>
                    <div id="loading-status" class="kanjy-loading-status">
                        ステータス: 初期化中...
                    </div>

                    <!-- 説明文（タイトル直下に表示） -->
                    <p id="event-description" class="kanjy-event-description" style="display: none;"></p>

                    <!-- エラー表示UI -->
                    <div id="error-display" class="kanjy-error-display" style="display: none;">
                        <div style="background: #fef2f2; border-left: 4px solid #ef4444; border-radius: 0.75rem; padding: 1.25rem; box-shadow: 0 4px 6px -1px rgba(0,0,0,0.1);">
                            <div style="display: flex; align-items: flex-start;">
                                <div style="flex-shrink: 0;">
                                    <svg style="width: 1.5rem; height: 1.5rem; color: #ef4444;" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                                    </svg>
                                </div>
                                <div style="margin-left: 1rem; flex: 1;">
                                    <h3 id="error-title" style="font-size: 1.125rem; font-weight: 600; color: #991b1b; margin-bottom: 0.5rem;"></h3>
                                    <p id="error-message" style="font-size: 0.875rem; color: #b91c1c; margin-bottom: 0.75rem;"></p>
                                    <div id="error-actions" style="display: flex; flex-wrap: wrap; gap: 0.75rem;">
                                        <button onclick="location.reload()"
                                            style="display: inline-flex; align-items: center; padding: 0.5rem 1rem; background: #dc2626; color: white; font-size: 0.875rem; font-weight: 500; border-radius: 0.5rem; border: none; cursor: pointer;">
                                            再試行
                                        </button>
                                        <a href="mailto:snaproom.info@gmail.com?subject=KANJY エラー報告"
                                            style="display: inline-flex; align-items: center; padding: 0.5rem 1rem; background: white; color: #b91c1c; font-size: 0.875rem; font-weight: 500; border-radius: 0.5rem; border: 1px solid #fca5a5; text-decoration: none;">
                                            サポートに連絡
                                        </a>
                                    </div>
                                    <details style="margin-top: 1rem;">
                                        <summary style="font-size: 0.875rem; color: #dc2626; cursor: pointer; font-weight: 500;">
                                            技術的な詳細を表示</summary>
                                        <pre id="error-details"
                                            style="margin-top: 0.5rem; font-size: 0.75rem; color: #4b5563; background: white; padding: 0.75rem; border-radius: 0.25rem; border: 1px solid #fecaca; overflow-x: auto;"></pre>
                                    </details>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>

                <!-- Event Details (Location, Budget, Deadline) -->
                <div id="event-info-cards" class="kanjy-info-cards">
                    <div id="location-section" style="display: none;">
                        <h3 class="kanjy-info-label">場所</h3>
                        <p id="location-text" class="kanjy-info-value"></p>
                    </div>
                    <div id="budget-card" style="display: none;">
                        <h3 class="kanjy-info-label">Budget</h3>
                        <p id="budget-text" class="kanjy-info-value"></p>
                    </div>
                    <div id="deadline-section" style="display: none;">
                        <h3 class="kanjy-info-label">回答期限</h3>
                        <p id="deadline-text" class="kanjy-info-value"></p>
                    </div>
                </div>
            </div>
        </section>
    `;

    // ========================================
    // CSS注入
    // ========================================
    const styleElement = document.createElement('style');
    styleElement.setAttribute('data-kanjy-event-info', 'true');
    styleElement.textContent = eventInfoStyles;
    document.head.appendChild(styleElement);

    // ========================================
    // HTML挿入（即時実行）
    // ========================================
    function injectEventInfo() {
        const placeholder = document.getElementById('kanjy-event-info');
        if (placeholder) {
            placeholder.innerHTML = eventInfoHTML;
        }
    }

    if (document.getElementById('kanjy-event-info')) {
        injectEventInfo();
    } else {
        document.addEventListener('DOMContentLoaded', injectEventInfo);
    }

    // ========================================
    // 共有表示ロジック（グローバル関数として公開）
    // ========================================

    /**
     * イベント情報セクションを表示する（共通ロジック）
     * @param {Object} event - イベントデータオブジェクト
     */
    window.displayEventInfo = function (event) {
        // ローディングステータスを非表示
        const loadingStatus = document.getElementById('loading-status');
        if (loadingStatus) {
            loadingStatus.style.display = 'none';
        }

        // イベントオブジェクトの検証
        if (!event) {
            var titleElement = document.getElementById('event-title');
            if (titleElement) {
                titleElement.textContent = 'データの読み込みに失敗しました';
                titleElement.style.color = '#ef4444';
            }
            return;
        }

        // タイトル
        var titleElement = document.getElementById('event-title');
        if (titleElement) {
            titleElement.textContent = event.title || 'イベント名が設定されていません';
            titleElement.style.color = '';
        }

        // 説明（設定されている場合のみ表示）
        var descElement = document.getElementById('event-description');
        if (descElement) {
            if (event.description && event.description.trim() !== '') {
                descElement.innerHTML = event.description.replace(/\n/g, '<br>');
                descElement.style.display = 'block';
            } else {
                descElement.style.display = 'none';
            }
        }

        // 開催場所（設定されている場合のみ表示）
        var locationSection = document.getElementById('location-section');
        var locationText = document.getElementById('location-text');
        if (locationSection && locationText) {
            if (event.location && event.location.trim() !== '') {
                locationText.textContent = event.location;
                locationSection.style.display = 'block';
            } else {
                locationSection.style.display = 'none';
            }
        }

        // 予算（設定されている場合のみ表示）
        var budgetCard = document.getElementById('budget-card');
        var budgetText = document.getElementById('budget-text');
        if (budgetCard && budgetText) {
            if (event.budget && event.budget > 0) {
                budgetText.textContent = event.budget.toLocaleString() + '円';
                budgetCard.style.display = 'block';
            } else {
                budgetCard.style.display = 'none';
            }
        }

        // 回答期限（設定されている場合のみ表示）
        var deadlineSection = document.getElementById('deadline-section');
        var deadlineText = document.getElementById('deadline-text');
        if (deadlineSection && deadlineText) {
            if (event.deadline) {
                try {
                    var deadlineDate = new Date(event.deadline);
                    if (isNaN(deadlineDate.getTime())) {
                        var cleanedDate = event.deadline.replace('T', ' ').replace('Z', '').replace(/-/g, '/');
                        deadlineDate = new Date(cleanedDate);
                    }
                    if (!isNaN(deadlineDate.getTime())) {
                        deadlineText.textContent = deadlineDate.toLocaleDateString('ja-JP', {
                            year: 'numeric',
                            month: 'long',
                            day: 'numeric',
                            hour: '2-digit',
                            minute: '2-digit'
                        });
                        deadlineSection.style.display = 'block';
                    } else {
                        deadlineSection.style.display = 'none';
                    }
                } catch (error) {
                    console.error('締切日時のフォーマットエラー:', error);
                    deadlineSection.style.display = 'none';
                }
            } else {
                deadlineSection.style.display = 'none';
            }
        }
    };
})();
