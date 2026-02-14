/**
 * KANJY 共有イベント情報コンポーネント
 * タイトル・説明文・回答期限・場所・予算・エラー表示を全ページで統一管理
 */
(function () {
    'use strict';

    // ========================================
    // イベント情報セクション HTML
    // index.html（イベント詳細ページ）を正として統一
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
                                <!-- エラーアイコン -->
                                <div class="flex-shrink-0">
                                    <svg class="h-6 w-6 text-red-500" fill="none" stroke="currentColor"
                                        viewBox="0 0 24 24">
                                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                                            d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                                    </svg>
                                </div>
                                <!-- エラー内容 -->
                                <div class="ml-4 flex-1">
                                    <h3 id="error-title" class="text-lg font-semibold text-red-800 mb-2"></h3>
                                    <p id="error-message" class="text-sm text-red-700 mb-3"></p>
                                    <div id="error-actions" class="flex flex-wrap gap-3">
                                        <!-- リトライボタン -->
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
                                        <!-- サポート連絡ボタン -->
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
                                    <!-- 詳細情報（折りたたみ可能） -->
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
                    <!-- Location Card -->
                    <div id="location-section" style="display: none;">
                        <h3 class="notion-small mb-3">場所</h3>
                        <p id="location-text" class="notion-body-medium"></p>
                    </div>

                    <!-- Budget Card -->
                    <div id="budget-card" style="display: none;">
                        <h3 class="notion-small mb-3">Budget</h3>
                        <p id="budget-text" class="notion-body-medium"></p>
                    </div>

                    <!-- Deadline Card -->
                    <div id="deadline-section" style="display: none;">
                        <h3 class="notion-small mb-3">回答期限</h3>
                        <p id="deadline-text" class="notion-body-medium"></p>
                    </div>
                </div>
            </div>
        </section>
    `;

    // ========================================
    // コンポーネント挿入（即時実行 - DOMContentLoaded前でも動作）
    // ========================================
    function injectEventInfo() {
        const placeholder = document.getElementById('kanjy-event-info');
        if (placeholder) {
            placeholder.innerHTML = eventInfoHTML;
        }
    }

    // スクリプトがbody内で読み込まれる場合、即時実行を試みる
    if (document.getElementById('kanjy-event-info')) {
        injectEventInfo();
    } else {
        // DOM未構築の場合はDOMContentLoadedで実行
        document.addEventListener('DOMContentLoaded', injectEventInfo);
    }
})();
