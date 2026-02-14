/**
 * KANJY 共有イベント情報コンポーネント
 * HTML構造 + 表示ロジックを一元管理し、全ページで統一
 */
(function () {
    'use strict';

    // ========================================
    // イベント情報セクション HTML
    // ========================================
    const eventInfoHTML = `
        <section class="notion-section py-8" style="border-top: none;">
            <div class="max-w-4xl mx-auto px-6 sm:px-8 lg:px-12">
                <!-- Event Title & Description -->
                <div class="mb-8">
                    <h1 id="event-title" class="notion-heading-2 mb-3">
                        読み込み中...
                    </h1>
                    <div id="loading-status" style="color: #666; font-size: 14px; margin-top: 8px;">
                        ステータス: 初期化中...
                    </div>

                    <!-- 説明文（タイトル直下に表示） -->
                    <p id="event-description" class="notion-body text-stone-500 mt-2" style="display: none;"></p>

                    <!-- エラー表示UI -->
                    <div id="error-display" style="display: none;" class="animate-slide-up">
                        <div class="bg-red-50 border-l-4 border-red-500 rounded-lg p-5 shadow-md">
                            <div class="flex items-start">
                                <div class="flex-shrink-0">
                                    <svg class="h-6 w-6 text-red-500" fill="none" stroke="currentColor"
                                        viewBox="0 0 24 24">
                                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                                            d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                                    </svg>
                                </div>
                                <div class="ml-4 flex-1">
                                    <h3 id="error-title" class="text-lg font-semibold text-red-800 mb-2"></h3>
                                    <p id="error-message" class="text-sm text-red-700 mb-3"></p>
                                    <div id="error-actions" class="flex flex-wrap gap-3">
                                        <button onclick="location.reload()"
                                            class="inline-flex items-center px-4 py-2 bg-red-600 hover:bg-red-700 text-white text-sm font-medium rounded-lg transition-colors duration-200 shadow-sm">
                                            <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor"
                                                viewBox="0 0 24 24">
                                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                                                    d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15">
                                                </path>
                                            </svg>
                                            再試行
                                        </button>
                                        <a href="mailto:snaproom.info@gmail.com?subject=KANJY エラー報告"
                                            class="inline-flex items-center px-4 py-2 bg-white hover:bg-gray-50 text-red-700 text-sm font-medium rounded-lg border border-red-300 transition-colors duration-200">
                                            <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor"
                                                viewBox="0 0 24 24">
                                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                                                    d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z">
                                                </path>
                                            </svg>
                                            サポートに連絡
                                        </a>
                                    </div>
                                    <details class="mt-4">
                                        <summary
                                            class="text-sm text-red-600 cursor-pointer hover:text-red-700 font-medium">
                                            技術的な詳細を表示</summary>
                                        <pre id="error-details"
                                            class="mt-2 text-xs text-gray-600 bg-white p-3 rounded border border-red-200 overflow-x-auto"></pre>
                                    </details>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>

                <!-- Event Details (Location, Budget, Deadline) -->
                <div id="event-info-cards">
                    <div id="location-section" style="display: none;">
                        <h3 class="notion-small mb-3">場所</h3>
                        <p id="location-text" class="notion-body-medium"></p>
                    </div>
                    <div id="budget-card" style="display: none;">
                        <h3 class="notion-small mb-3">Budget</h3>
                        <p id="budget-text" class="notion-body-medium"></p>
                    </div>
                    <div id="deadline-section" style="display: none;">
                        <h3 class="notion-small mb-3">回答期限</h3>
                        <p id="deadline-text" class="notion-body-medium"></p>
                    </div>
                </div>
            </div>
        </section>
    `;

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
    // 各ページの displayEvent から呼び出す
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
            console.error('❌ イベントオブジェクトがnullまたはundefinedです');
            const titleElement = document.getElementById('event-title');
            if (titleElement) {
                titleElement.textContent = 'データの読み込みに失敗しました';
                titleElement.style.color = '#ef4444';
            }
            return;
        }

        // タイトル
        const titleElement = document.getElementById('event-title');
        if (titleElement) {
            titleElement.textContent = event.title || 'イベント名が設定されていません';
            titleElement.style.color = '';
        }

        // 説明（設定されている場合のみ表示）
        const descElement = document.getElementById('event-description');
        if (descElement) {
            if (event.description && event.description.trim() !== '') {
                descElement.innerHTML = event.description.replace(/\n/g, '<br>');
                descElement.style.display = 'block';
            } else {
                descElement.style.display = 'none';
            }
        }

        // 開催場所（設定されている場合のみ表示）
        const locationSection = document.getElementById('location-section');
        const locationText = document.getElementById('location-text');
        if (locationSection && locationText) {
            if (event.location && event.location.trim() !== '') {
                locationText.textContent = event.location;
                locationSection.style.display = 'block';
            } else {
                locationSection.style.display = 'none';
            }
        }

        // 予算（設定されている場合のみ表示）
        const budgetCard = document.getElementById('budget-card');
        const budgetText = document.getElementById('budget-text');
        if (budgetCard && budgetText) {
            if (event.budget && event.budget > 0) {
                budgetText.textContent = event.budget.toLocaleString() + '円';
                budgetCard.style.display = 'block';
            } else {
                budgetCard.style.display = 'none';
            }
        }

        // 回答期限（設定されている場合のみ表示）
        const deadlineSection = document.getElementById('deadline-section');
        const deadlineText = document.getElementById('deadline-text');
        if (deadlineSection && deadlineText) {
            if (event.deadline) {
                try {
                    let deadlineDate = new Date(event.deadline);
                    // Safari等の互換性対応
                    if (isNaN(deadlineDate.getTime())) {
                        const cleanedDate = event.deadline.replace('T', ' ').replace('Z', '').replace(/-/g, '/');
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
