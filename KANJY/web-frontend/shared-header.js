/**
 * KANJY 共有ヘッダーコンポーネント
 * 全ページで統一されたヘッダーを表示するための共有モジュール
 */
(function () {
    'use strict';

    // ========================================
    // ヘッダー用CSS（モバイル対応含む）
    // ========================================
    const headerStyles = `
        /* ヘッダーベーススタイル */
        .kanjy-header nav {
            border-bottom: 1px solid rgba(0, 0, 0, 0.05);
        }

        /* モバイル対応 (768px以下) */
        @media (max-width: 768px) {
            /* ナビゲーションのパディング調整 */
            .kanjy-header nav .max-w-4xl {
                padding-left: 1rem;
                padding-right: 1rem;
            }

            /* ヘッダーの高さを調整 */
            .kanjy-header nav .h-20 {
                height: auto;
                min-height: 60px;
                padding: 0.75rem 0;
            }

            /* App Storeボタンをアイコンのみに */
            .kanjy-header nav a span {
                display: none;
            }

            .kanjy-header nav a {
                padding: 0.5rem !important;
                min-width: 40px;
                justify-content: center;
            }

            .kanjy-header nav a svg {
                margin: 0;
            }
        }
    `;

    // ========================================
    // ヘッダーHTML
    // ========================================
    const headerHTML = `
        <nav class="bg-white shadow-sm backdrop-blur-xl">
            <div class="max-w-4xl mx-auto px-6 sm:px-8 lg:px-12">
                <div class="flex justify-between items-center h-20">
                    <div class="flex items-center">
                        <span class="text-gray-900 font-light text-xl tracking-[0.2em] uppercase">K A N J Y</span>
                    </div>
                    <div class="flex items-center">
                        <a href="https://apps.apple.com/jp/app/kanjy/id6746665673" target="_blank"
                            class="inline-flex items-center space-x-2 bg-gray-100 hover:bg-gray-200 transition-colors duration-200 px-4 py-2 rounded-lg text-sm font-medium text-gray-700">
                            <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 24 24">
                                <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z" />
                            </svg>
                            <span>App Storeでダウンロード</span>
                        </a>
                    </div>
                </div>
            </div>
        </nav>
    `;

    // ========================================
    // スタイル注入
    // ========================================
    const styleElement = document.createElement('style');
    styleElement.setAttribute('data-kanjy-header', 'true');
    styleElement.textContent = headerStyles;
    document.head.appendChild(styleElement);

    // ========================================
    // ヘッダー挿入（即時実行 - DOMContentLoaded前でも動作）
    // ========================================
    function injectHeader() {
        const placeholder = document.getElementById('kanjy-header');
        if (placeholder) {
            placeholder.classList.add('kanjy-header');
            placeholder.innerHTML = headerHTML;
        }
    }

    // スクリプトがbody内で読み込まれる場合、即時実行を試みる
    if (document.getElementById('kanjy-header')) {
        injectHeader();
    } else {
        document.addEventListener('DOMContentLoaded', injectHeader);
    }
})();
