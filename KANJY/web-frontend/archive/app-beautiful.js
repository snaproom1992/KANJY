// Supabase設定
const SUPABASE_URL = 'https://jvluhjifihiuopqdwjll.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp2bHVoamlmaWhpdW9wcWR3amxsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTExNTc5OTEsImV4cCI6MjA2NjczMzk5MX0.WDTzIs73X8NHGFcIYFk4CN-7dH5tQT5l0Bd2uY6H9lc';

// Supabaseクライアント初期化
const supabase = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

// グローバル変数
let currentEvent = null;
let currentEventId = null;
let currentResponses = [];
let dateResponses = {}; // Store date responses for beautiful UI

// 初期化
document.addEventListener('DOMContentLoaded', async function() {
    console.log('🎨 Beautiful KANJY DOMContentLoaded');
    
    // URLパラメータからイベントIDを取得
    const urlParams = new URLSearchParams(window.location.search);
    const eventId = urlParams.get('id');
    
    if (!eventId) {
        showError('イベントIDが指定されていません');
        return;
    }
    
    // デバッグ用：テーブル構造を確認
    await debugTableStructure();
    
    currentEventId = eventId;
    
    try {
        // イベントと回答を並行して読み込み
        await Promise.all([
            loadEvent(eventId),
            loadResponses(eventId)
        ]);
        
        // フォームイベントを設定
        setupFormEvents();
        
        // リアルタイム購読を開始
        subscribeToRealtime();
        
        hideLoading();
        
    } catch (error) {
        console.error('初期化エラー:', error);
        showError('データの読み込みに失敗しました: ' + error.message);
    }
});

// デバッグ用：Supabaseテーブル構造を確認
async function debugTableStructure() {
    try {
        console.log('🔍 Supabaseテーブル構造を確認中...');
        
        // eventsテーブルの構造を確認
        const { data: eventData, error: eventError } = await supabase
            .from('events')
            .select('*')
            .limit(1);
        
        if (eventError) {
            console.error('❌ eventsテーブルエラー:', eventError);
        } else {
            console.log('📋 eventsテーブル構造:', eventData);
        }
        
        // responsesテーブルの構造を確認
        const { data: responseData, error: responseError } = await supabase
            .from('responses')
            .select('*')
            .limit(1);
        
        if (responseError) {
            console.error('❌ responsesテーブルエラー:', responseError);
        } else {
            console.log('📋 responsesテーブル構造:', responseData);
        }
        
        // 現在のイベントの回答データを確認
        if (currentEventId) {
            const { data: currentResponses, error: currentError } = await supabase
                .from('responses')
                .select('*')
                .eq('event_id', currentEventId);
            
            if (currentError) {
                console.error('❌ 現在のイベント回答エラー:', currentError);
            } else {
                console.log('📋 現在のイベント回答:', currentResponses);
            }
        }
        
    } catch (error) {
        console.error('❌ テーブル構造確認エラー:', error);
    }
}

// イベント情報を読み込み
async function loadEvent(eventId) {
    try {
        console.log('イベントID:', eventId);
        
        const { data: events, error } = await supabase
            .from('events')
            .select('*')
            .eq('id', eventId);
        
        console.log('Supabaseレスポンス:', { data: events, error });
        
        if (error) throw error;
        if (!events || events.length === 0) throw new Error('イベントが見つかりません');
        if (events.length > 1) throw new Error('複数のイベントが見つかりました');
        
        const event = events[0];
        
        currentEvent = event;
        displayEvent(event);
        await loadResponses(eventId);
        
    } catch (error) {
        console.error('イベント読み込みエラー:', error);
        console.error('エラー詳細:', error.message);
        throw error;
    }
}

// 美しいイベント情報表示
function displayEvent(event) {
    // タイトルと説明
    const titleElement = document.getElementById('event-title');
    const descElement = document.getElementById('event-description');
    
    if (titleElement) {
        titleElement.textContent = event.title;
        titleElement.classList.add('animate-slide-up');
    }
    
    if (event.description && descElement) {
        descElement.textContent = event.description;
        descElement.classList.add('animate-fade-in');
    } else if (descElement) {
        descElement.style.display = 'none';
    }
    
    // 場所
    const locationInfo = document.getElementById('location-info');
    const locationText = document.getElementById('location-text');
    if (event.location && locationText) {
        locationText.textContent = event.location;
        locationInfo.classList.add('animate-scale-in');
    } else if (locationInfo) {
        locationInfo.style.display = 'none';
    }
    
    // 予算
    const budgetInfo = document.getElementById('budget-info');
    const budgetText = document.getElementById('budget-text');
    if (event.budget && budgetText) {
        budgetText.textContent = `¥${event.budget.toLocaleString()}`;
        budgetInfo.classList.add('animate-scale-in');
    } else if (budgetInfo) {
        budgetInfo.style.display = 'none';
    }
    
    // 回答期限
    const deadlineInfo = document.getElementById('deadline-info');
    const deadlineText = document.getElementById('deadline-text');
    if (event.deadline && deadlineText) {
        const deadline = new Date(event.deadline);
        const now = new Date();
        const isExpired = deadline < now;
        
        deadlineText.textContent = 
            `${formatDateTime(deadline)} ${isExpired ? '(期限切れ)' : ''}`;
        
        if (isExpired) {
            deadlineInfo.classList.add('bg-red-50', 'border-red-200');
            deadlineText.classList.add('text-red-700');
        }
        deadlineInfo.classList.add('animate-scale-in');
    } else if (deadlineInfo) {
        deadlineInfo.style.display = 'none';
    }
    
    // 候補日時
    displayCandidateDates(event.candidate_dates);
}

// 美しい候補日時表示
function displayCandidateDates(dates) {
    const datesGrid = document.getElementById('candidate-dates-list');
    const dateStatusSelection = document.getElementById('date-responses');
    
    datesGrid.innerHTML = '';
    dateStatusSelection.innerHTML = '';
    
    if (!dates || !Array.isArray(dates) || dates.length === 0) {
        datesGrid.innerHTML = '<p class="text-gray-500 text-center col-span-full">候補日時が設定されていません</p>';
        return;
    }
    
    dates.forEach((date, index) => {
        const dateObj = new Date(date);
        
        // Beautiful candidate date display
        const dateItem = document.createElement('div');
        dateItem.className = 'floating-element bg-gradient-to-br from-blue-50 to-indigo-50 rounded-2xl p-6 border border-blue-200/50 shadow-soft';
        dateItem.style.animationDelay = `${index * 0.1}s`;
        dateItem.innerHTML = `
            <div class="flex items-center space-x-3">
                <div class="w-12 h-12 bg-gradient-to-br from-blue-400 to-blue-600 rounded-xl flex items-center justify-center">
                    <span class="text-white font-bold text-sm">${dateObj.getDate()}</span>
                </div>
                <div>
                    <div class="text-lg font-semibold text-gray-900">${formatDateTime(dateObj)}</div>
                    <div class="text-sm text-gray-500">候補日時</div>
                </div>
            </div>
        `;
        datesGrid.appendChild(dateItem);
        
        // Beautiful date response buttons
        const responseItem = document.createElement('div');
        responseItem.className = 'bg-gray-50 rounded-2xl p-6 border border-gray-200/50';
        responseItem.innerHTML = `
            <div class="flex items-center justify-between mb-4">
                <div class="text-lg font-semibold text-gray-900">${formatDateTime(dateObj)}</div>
            </div>
            <div class="grid grid-cols-3 gap-3" data-date="${date}">
                <button type="button" class="status-button attending px-4 py-3 bg-attending-100 text-attending-700 rounded-xl border border-attending-200 hover:bg-attending-200 transition-all" data-status="参加">
                    <span class="block text-sm font-semibold">○</span>
                    <span class="block text-xs">参加</span>
                </button>
                <button type="button" class="status-button maybe px-4 py-3 bg-maybe-100 text-maybe-700 rounded-xl border border-maybe-200 hover:bg-maybe-200 transition-all" data-status="微妙">
                    <span class="block text-sm font-semibold">△</span>
                    <span class="block text-xs">微妙</span>
                </button>
                <button type="button" class="status-button not-attending px-4 py-3 bg-notAttending-100 text-notAttending-700 rounded-xl border border-notAttending-200 hover:bg-notAttending-200 transition-all" data-status="不参加">
                    <span class="block text-sm font-semibold">×</span>
                    <span class="block text-xs">不参加</span>
                </button>
            </div>
        `;
        dateStatusSelection.appendChild(responseItem);
    });
    
    // Setup beautiful status button interactions
    setupBeautifulStatusButtons();
}

// 美しいステータスボタンのセットアップ
function setupBeautifulStatusButtons() {
    document.querySelectorAll('.status-button').forEach(button => {
        button.addEventListener('click', function() {
            const container = this.closest('[data-date]');
            const date = container.dataset.date;
            const status = this.dataset.status;
            
            // Remove selected class from siblings
            container.querySelectorAll('.status-button').forEach(btn => {
                btn.classList.remove('selected');
            });
            
            // Add selected class to clicked button with beautiful animation
            this.classList.add('selected');
            
            // Add ripple effect
            const ripple = document.createElement('div');
            ripple.className = 'absolute inset-0 bg-white/30 rounded-xl animate-ping';
            this.style.position = 'relative';
            this.appendChild(ripple);
            setTimeout(() => ripple.remove(), 600);
            
            // Store the response
            if (!window.dateResponses) window.dateResponses = {};
            window.dateResponses[date] = status;
            
            console.log('📅 Date response updated:', { date, status });
        });
    });
}

// 回答一覧を読み込み
async function loadResponses(eventId) {
    try {
        const { data: responses, error } = await supabase
            .from('responses')
            .select('*')
            .eq('event_id', eventId)
            .order('created_at', { ascending: false });
        
        if (error) throw error;
        
        currentResponses = responses || [];
        displayResponses(currentResponses);
        
    } catch (error) {
        console.error('回答読み込みエラー:', error);
        throw error;
    }
}

// 美しい回答一覧表示
function displayResponses(responses) {
    const container = document.getElementById('responses-container');
    
    if (!responses || responses.length === 0) {
        container.innerHTML = `
            <div class="text-center py-12">
                <div class="w-16 h-16 bg-gray-100 rounded-full flex items-center justify-center mx-auto mb-4">
                    <svg class="w-8 h-8 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"/>
                    </svg>
                </div>
                <h3 class="text-lg font-medium text-gray-900 mb-2">まだ回答がありません</h3>
                <p class="text-gray-500">最初の回答者になりましょう！</p>
            </div>
        `;
        return;
    }
    
    // Build beautiful response table
    let html = `
        <div class="overflow-hidden">
            <table class="min-w-full divide-y divide-gray-200/50">
                <thead class="bg-gradient-to-r from-gray-50 to-gray-100">
                    <tr>
                        <th class="px-6 py-4 text-left text-sm font-semibold text-gray-900">参加者</th>
                        <th class="px-6 py-4 text-left text-sm font-semibold text-gray-900">ステータス</th>
                        <th class="px-6 py-4 text-left text-sm font-semibold text-gray-900">参加可能日</th>
                        <th class="px-6 py-4 text-left text-sm font-semibold text-gray-900">コメント</th>
                        <th class="px-6 py-4 text-left text-sm font-semibold text-gray-900">回答日時</th>
                    </tr>
                </thead>
                <tbody class="divide-y divide-gray-200/30">
    `;
    
    responses.forEach((response, index) => {
        const statusColor = getStatusColor(response.status);
        const availableDates = response.available_dates || [];
        const maybeDates = response.maybe_dates || [];
        
        html += `
            <tr class="hover:bg-gray-50/50 transition-colors duration-200 cursor-pointer" onclick="editResponse('${response.participant_name}')">
                <td class="px-6 py-4">
                    <div class="flex items-center">
                        <div class="w-10 h-10 bg-gradient-to-br ${statusColor.bg} rounded-full flex items-center justify-center mr-3">
                            <span class="text-white font-semibold text-sm">${response.participant_name.charAt(0)}</span>
                        </div>
                        <div>
                            <div class="text-sm font-semibold text-gray-900">${response.participant_name}</div>
                            ${response.department ? `<div class="text-xs text-gray-500">${response.department}</div>` : ''}
                        </div>
                    </div>
                </td>
                <td class="px-6 py-4">
                    <span class="status-pill inline-flex items-center px-3 py-1 rounded-full text-xs font-medium ${statusColor.classes}">
                        ${getStatusIcon(response.status)} ${response.status}
                    </span>
                </td>
                <td class="px-6 py-4">
                    <div class="space-y-1">
                        ${availableDates.map(date => `
                            <span class="inline-flex items-center px-2 py-1 bg-attending-100 text-attending-700 rounded-lg text-xs">
                                ○ ${formatDateShort(new Date(date))}
                            </span>
                        `).join('')}
                        ${maybeDates.map(date => `
                            <span class="inline-flex items-center px-2 py-1 bg-maybe-100 text-maybe-700 rounded-lg text-xs">
                                △ ${formatDateShort(new Date(date))}
                            </span>
                        `).join('')}
                    </div>
                </td>
                <td class="px-6 py-4">
                    <div class="text-sm text-gray-600 max-w-xs truncate">
                        ${response.comment || ''}
                    </div>
                </td>
                <td class="px-6 py-4">
                    <div class="text-sm text-gray-500">
                        ${formatDateTime(new Date(response.created_at))}
                    </div>
                </td>
            </tr>
        `;
    });
    
    html += `
                </tbody>
            </table>
        </div>
    `;
    
    container.innerHTML = html;
}

// Status colors for beautiful display
function getStatusColor(status) {
    switch (status) {
        case '参加':
            return {
                classes: 'bg-attending-100 text-attending-700 border border-attending-200',
                bg: 'from-attending-400 to-attending-600'
            };
        case '微妙':
            return {
                classes: 'bg-maybe-100 text-maybe-700 border border-maybe-200',
                bg: 'from-maybe-400 to-maybe-600'
            };
        case '不参加':
            return {
                classes: 'bg-notAttending-100 text-notAttending-700 border border-notAttending-200',
                bg: 'from-notAttending-400 to-notAttending-600'
            };
        default:
            return {
                classes: 'bg-undecided-100 text-undecided-700 border border-undecided-200',
                bg: 'from-undecided-400 to-undecided-600'
            };
    }
}

function getStatusIcon(status) {
    switch (status) {
        case '参加': return '○';
        case '微妙': return '△';
        case '不参加': return '×';
        default: return '?';
    }
}

// フォームイベントのセットアップ
function setupFormEvents() {
    const form = document.getElementById('response-form');
    if (form) {
        form.addEventListener('submit', handleSubmit);
    }
}

// 美しいフォーム送信処理
async function handleSubmit(e) {
    e.preventDefault();
    
    const participantName = document.getElementById('participant-name').value.trim();
    const comment = document.getElementById('comment').value.trim();
    
    if (!participantName) {
        showErrorMessage('お名前を入力してください');
        return;
    }
    
    if (!window.dateResponses || Object.keys(window.dateResponses).length === 0) {
        showErrorMessage('少なくとも1つの日程に回答してください');
        return;
    }
    
    try {
        // Show loading state
        const submitButton = e.target.querySelector('button[type="submit"]');
        const originalContent = submitButton.innerHTML;
        submitButton.innerHTML = `
            <span class="flex items-center justify-center">
                <div class="w-5 h-5 border-2 border-white border-t-transparent rounded-full animate-spin mr-2"></div>
                送信中...
            </span>
        `;
        submitButton.disabled = true;
        
        // Process responses
        const availableDates = [];
        const maybeDates = [];
        let overallStatus = '不参加';
        
        Object.entries(window.dateResponses).forEach(([date, status]) => {
            if (status === '参加') {
                availableDates.push(date);
                overallStatus = '参加';
            } else if (status === '微妙') {
                maybeDates.push(date);
                if (overallStatus === '不参加') overallStatus = '微妙';
            }
        });
        
        // Submit to Supabase
        const responseData = {
            event_id: currentEventId,
            participant_name: participantName,
            available_dates: availableDates,
            maybe_dates: maybeDates,
            status: overallStatus,
            comment: comment || null,
            department: null,
            response_date: new Date().toISOString(),
            created_at: new Date().toISOString()
        };
        
        const { data, error } = await supabase
            .from('responses')
            .insert(responseData)
            .select();
        
        if (error) throw error;
        
        // Reset form with beautiful animation
        form.reset();
        window.dateResponses = {};
        document.querySelectorAll('.status-button').forEach(btn => {
            btn.classList.remove('selected');
        });
        
        // Show success message
        showSuccessMessage();
        
        // Reload responses
        await loadResponses(currentEventId);
        
        // Restore button
        submitButton.innerHTML = originalContent;
        submitButton.disabled = false;
        
    } catch (error) {
        console.error('送信エラー:', error);
        showErrorMessage('送信に失敗しました: ' + error.message);
        
        // Restore button
        const submitButton = e.target.querySelector('button[type="submit"]');
        submitButton.innerHTML = originalContent;
        submitButton.disabled = false;
    }
}

// リアルタイム購読
function subscribeToRealtime() {
    supabase
        .channel('responses')
        .on('postgres_changes', { event: '*', schema: 'public', table: 'responses' }, payload => {
            console.log('🔄 Realtime update:', payload);
            if (payload.new?.event_id === currentEventId || payload.old?.event_id === currentEventId) {
                loadResponses(currentEventId);
            }
        })
        .subscribe();
}

// Utility functions
function formatDateTime(date) {
    const formatter = new Intl.DateTimeFormat('ja-JP', {
        year: 'numeric',
        month: 'short',
        day: 'numeric',
        hour: '2-digit',
        minute: '2-digit'
    });
    return formatter.format(date);
}

function formatDateShort(date) {
    const formatter = new Intl.DateTimeFormat('ja-JP', {
        month: 'short',
        day: 'numeric',
        hour: '2-digit',
        minute: '2-digit'
    });
    return formatter.format(date);
}

function hideLoading() {
    const loading = document.getElementById('loading');
    const eventDetail = document.getElementById('event-detail');
    
    if (loading) {
        loading.style.opacity = '0';
        setTimeout(() => loading.style.display = 'none', 300);
    }
    
    if (eventDetail) {
        eventDetail.classList.remove('hidden');
        eventDetail.style.opacity = '0';
        setTimeout(() => {
            eventDetail.style.opacity = '1';
            eventDetail.style.transition = 'opacity 0.5s ease-in-out';
        }, 100);
    }
}

function showError(message) {
    const errorDiv = document.getElementById('error');
    const errorMessage = document.getElementById('error-message');
    const loading = document.getElementById('loading');
    
    if (loading) loading.style.display = 'none';
    if (errorMessage) errorMessage.textContent = message;
    if (errorDiv) {
        errorDiv.classList.remove('hidden');
        errorDiv.style.opacity = '0';
        setTimeout(() => {
            errorDiv.style.opacity = '1';
            errorDiv.style.transition = 'opacity 0.3s ease-in-out';
        }, 100);
    }
}

function showSuccessMessage() {
    const successDiv = document.getElementById('success-message');
    if (successDiv) {
        successDiv.classList.remove('hidden');
        successDiv.style.opacity = '0';
        setTimeout(() => {
            successDiv.style.opacity = '1';
            successDiv.style.transition = 'opacity 0.3s ease-in-out';
        }, 100);
        
        setTimeout(() => {
            successDiv.style.opacity = '0';
            setTimeout(() => successDiv.classList.add('hidden'), 300);
        }, 2000);
    }
}

function showErrorMessage(message) {
    const errorDiv = document.getElementById('error-message');
    const errorText = document.getElementById('error-text');
    
    if (errorText) errorText.textContent = message;
    if (errorDiv) {
        errorDiv.classList.remove('hidden');
        errorDiv.style.opacity = '0';
        setTimeout(() => {
            errorDiv.style.opacity = '1';
            errorDiv.style.transition = 'opacity 0.3s ease-in-out';
        }, 100);
        
        setTimeout(() => {
            errorDiv.style.opacity = '0';
            setTimeout(() => errorDiv.classList.add('hidden'), 300);
        }, 3000);
    }
}

function editResponse(participantName) {
    // Find the response and populate form
    const response = currentResponses.find(r => r.participant_name === participantName);
    if (response) {
        document.getElementById('participant-name').value = response.participant_name;
        document.getElementById('comment').value = response.comment || '';
        
        // Clear existing selections
        document.querySelectorAll('.status-button').forEach(btn => {
            btn.classList.remove('selected');
        });
        
        // Set date responses
        window.dateResponses = {};
        
        (response.available_dates || []).forEach(date => {
            window.dateResponses[date] = '参加';
            const button = document.querySelector(`[data-date="${date}"] [data-status="参加"]`);
            if (button) button.classList.add('selected');
        });
        
        (response.maybe_dates || []).forEach(date => {
            window.dateResponses[date] = '微妙';
            const button = document.querySelector(`[data-date="${date}"] [data-status="微妙"]`);
            if (button) button.classList.add('selected');
        });
        
        // Scroll to form
        document.getElementById('response-form').scrollIntoView({ 
            behavior: 'smooth', 
            block: 'center' 
        });
    }
}

console.log('🎨 Beautiful KANJY app.js loaded!'); 