// Supabase設定
const SUPABASE_URL = 'https://jvluhjifihiuopqdwjll.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp2bHVoamlmaWhpdW9wcWR3amxsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTExNTc5OTEsImV4cCI6MjA2NjczMzk5MX0.WDTzIs73X8NHGFcIYFk4CN-7dH5tQT5l0Bd2uY6H9lc';

// Supabaseクライアント初期化
const supabase = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

// グローバル変数
let currentEvent = null;
let currentEventId = null;
let currentResponses = [];

// 初期化
document.addEventListener('DOMContentLoaded', async function() {
    console.log('🚀 DOMContentLoaded');
    
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

// イベント情報を表示
function displayEvent(event) {
    // タイトルと説明
    document.getElementById('event-title').textContent = event.title;
    if (event.description) {
        document.getElementById('event-description').textContent = event.description;
    } else {
        document.getElementById('event-description').style.display = 'none';
    }
    
    // 場所
    if (event.location) {
        document.getElementById('location-text').textContent = event.location;
    } else {
        document.getElementById('location-info').style.display = 'none';
    }
    
    // 予算
    if (event.budget) {
        document.getElementById('budget-text').textContent = `¥${event.budget.toLocaleString()}`;
    } else {
        document.getElementById('budget-info').style.display = 'none';
    }
    
    // 回答期限
    if (event.deadline) {
        const deadline = new Date(event.deadline);
        const now = new Date();
        const isExpired = deadline < now;
        
        document.getElementById('deadline-text').textContent = 
            `${formatDateTime(deadline)} ${isExpired ? '(期限切れ)' : ''}`;
        
        if (isExpired) {
            document.getElementById('deadline-info').style.color = '#dc3545';
        }
    } else {
        document.getElementById('deadline-info').style.display = 'none';
    }
    
    // 候補日時
    displayCandidateDates(event.candidate_dates);
}

// 候補日時を表示
function displayCandidateDates(dates) {
    const datesGrid = document.getElementById('candidate-dates-list');
    const dateStatusSelection = document.getElementById('date-responses');
    
    datesGrid.innerHTML = '';
    dateStatusSelection.innerHTML = '';
    
    // datesが存在しない場合の対処
    if (!dates || !Array.isArray(dates) || dates.length === 0) {
        console.warn('候補日時が設定されていません');
        datesGrid.innerHTML = '<p>候補日時が設定されていません</p>';
        return;
    }
    
    // 候補日時の表示
    dates.forEach(date => {
        const dateObj = new Date(date);
        
        // 候補日時表示
        const dateItem = document.createElement('div');
        dateItem.className = 'date-item fade-in';
        dateItem.innerHTML = `
            <div style="display: flex; align-items: center; gap: 0.5rem;">
                <span>${formatDateTime(dateObj)}</span>
            </div>
        `;
        datesGrid.appendChild(dateItem);
    });
    
    // 行列形式の参加状況選択表を作成
    const tableHtml = `
        <div class="date-status-table-container">
            <table class="date-status-table">
                <thead>
                    <tr>
                        <th class="date-col">日時</th>
                        <th class="status-col">参加</th>
                        <th class="status-col">不参加</th>
                        <th class="status-col">未定</th>
                    </tr>
                </thead>
                <tbody>
                    ${dates.map(date => {
                        const dateObj = new Date(date);
                        const dateId = date.replace(/[^a-zA-Z0-9]/g, '_');
                        return `
                            <tr class="date-status-row">
                                <td class="date-cell">
                                    <div class="date-info">${formatDateTime(dateObj)}</div>
                                </td>
                                <td class="status-cell">
                                    <label class="status-radio attending">
                                        <input type="radio" name="date_status_${dateId}" value="attending" data-date="${date}">
                                        <span class="radio-custom">○</span>
                                    </label>
                                </td>
                                <td class="status-cell">
                                    <label class="status-radio not_attending">
                                        <input type="radio" name="date_status_${dateId}" value="not_attending" data-date="${date}">
                                        <span class="radio-custom">✕</span>
                                    </label>
                                </td>
                                <td class="status-cell">
                                    <label class="status-radio undecided">
                                        <input type="radio" name="date_status_${dateId}" value="undecided" data-date="${date}">
                                        <span class="radio-custom">?</span>
                                    </label>
                                </td>
                            </tr>
                        `;
                    }).join('')}
                </tbody>
            </table>
        </div>
    `;
    
    dateStatusSelection.innerHTML = tableHtml;
    
    // イベントリスナーを設定
    setupDateStatusEvents();
}

// 回答を読み込み
async function loadResponses(eventId) {
    try {
        const { data: responses, error } = await supabase
            .from('responses')
            .select('*')
            .eq('event_id', eventId)
            .order('created_at', { ascending: false });
        
        if (error) throw error;
        
        // 重複データを除去（同名の場合は最新のもののみ保持）
        const uniqueResponses = [];
        const seenNames = new Set();
        
        for (const response of responses || []) {
            if (!seenNames.has(response.participant_name)) {
                uniqueResponses.push(response);
                seenNames.add(response.participant_name);
            }
        }
        
        console.log('📊 回答データ:', {
            total: responses?.length || 0,
            unique: uniqueResponses.length,
            duplicates: (responses?.length || 0) - uniqueResponses.length
        });
        
        currentResponses = uniqueResponses;
        displayResponses(currentResponses);
        
    } catch (error) {
        console.error('回答読み込みエラー:', error);
    }
}

// 回答を表示
function displayResponses(responses) {
    const responsesContainer = document.getElementById('responses-container');
    
    if (!responsesContainer) {
        console.error('responses-container要素が見つかりません');
        return;
    }
    
    if (responses.length === 0) {
        responsesContainer.innerHTML = '<p class="no-responses">まだ回答がありません</p>';
        return;
    }
    
    // 候補日時を取得
    const candidateDates = currentEvent?.candidate_dates || [];
    
    console.log('📊 表示する回答数:', responses.length);
    console.log('📊 候補日時:', candidateDates);
    
    // 転置した表を生成（日時を縦軸、参加者を横軸）
    const tableHtml = `
        <div class="table-container">
            <table class="response-table-view transposed">
                <thead>
                    <tr>
                        <th class="date-header-col">日時</th>
                        <th class="participant-count-col">回答</th>
                        ${responses.map(response => `
                            <th class="participant-col">
                                <div class="participant-header">
                                    <span class="participant-name clickable" onclick="editResponse('${response.participant_name}')">${response.participant_name}</span>
                                </div>
                            </th>
                        `).join('')}
                    </tr>
                </thead>
                <tbody>
                    ${candidateDates.map(dateStr => {
                        // この日時の参加・不参加・未定者数を計算
                        let attendingCount = 0;
                        let notAttendingCount = 0;
                        let undecidedCount = 0;
                        let noResponseCount = 0;
                        
                        responses.forEach(response => {
                            // 新しい形式（date_statuses）をチェック
                            if (response.date_statuses && response.date_statuses[dateStr]) {
                                const status = response.date_statuses[dateStr];
                                if (status === 'attending') {
                                    attendingCount++;
                                } else if (status === 'not_attending') {
                                    notAttendingCount++;
                                } else if (status === 'undecided') {
                                    undecidedCount++;
                                } else {
                                    noResponseCount++;
                                }
                            } else {
                                // 古い形式（available_dates）への対応
                                const isAvailable = response.available_dates && response.available_dates.includes(dateStr);
                                const canAttend = response.status === 'attending';
                                const isNotAttending = response.status === 'not_attending';
                                const isUndecided = response.status === 'undecided';
                                
                                if (isAvailable && canAttend) {
                                    attendingCount++;
                                } else if (isNotAttending) {
                                    notAttendingCount++;
                                } else if (isUndecided) {
                                    undecidedCount++;
                                } else {
                                    noResponseCount++;
                                }
                            }
                        });
                        
                        return `
                            <tr class="date-row">
                                <td class="date-cell-header">
                                    <div class="date-info">
                                        ${formatDateTime(new Date(dateStr))}
                                    </div>
                                </td>
                                <td class="count-cell">
                                    <div class="participant-summary">
                                        <div class="summary-row">
                                            <span class="summary-item attending">○参加：${attendingCount}人</span>
                                            <span class="summary-item not-attending">✕不参加：${notAttendingCount}人</span>
                                            <span class="summary-item undecided">?未定：${undecidedCount}人</span>
                                            ${noResponseCount > 0 ? `<span class="summary-item no-response">-未回答：${noResponseCount}人</span>` : ''}
                                        </div>
                                    </div>
                                </td>
                                ${responses.map(response => {
                                    let cellClass = 'unavailable';
                                    let cellContent = '-';
                                    
                                    // 新しい形式（date_statuses）をチェック
                                    if (response.date_statuses && response.date_statuses[dateStr]) {
                                        const status = response.date_statuses[dateStr];
                                        if (status === 'attending') {
                                            cellClass = 'available';
                                            cellContent = '○';
                                        } else if (status === 'not_attending') {
                                            cellClass = 'not-attending';
                                            cellContent = '✕';
                                        } else if (status === 'undecided') {
                                            cellClass = 'undecided';
                                            cellContent = '?';
                                        } else {
                                            // その他の状態の場合は未回答として扱う
                                            cellClass = 'unavailable';
                                            cellContent = '-';
                                        }
                                    } else {
                                        // 古い形式（available_dates）への対応
                                        const isAvailable = response.available_dates && response.available_dates.includes(dateStr);
                                        const canAttend = response.status === 'attending';
                                        const isNotAttending = response.status === 'not_attending';
                                        const isUndecided = response.status === 'undecided';
                                        
                                        if (isAvailable && canAttend) {
                                            cellClass = 'available';
                                            cellContent = '○';
                                        } else if (isNotAttending) {
                                            cellClass = 'not-attending';
                                            cellContent = '✕';
                                        } else if (isUndecided) {
                                            cellClass = 'undecided';
                                            cellContent = '?';
                                        } else {
                                            // 未回答の場合
                                            cellClass = 'unavailable';
                                            cellContent = '-';
                                        }
                                    }
                                    
                                    return `<td class="availability-cell ${cellClass}">
                                        ${cellContent}
                                    </td>`;
                                }).join('')}
                            </tr>
                        `;
                    }).join('')}
                </tbody>
            </table>
        </div>
    `;
    
    responsesContainer.innerHTML = tableHtml;
}

// 日付を短縮表示
function formatDateShort(date) {
    const options = {
        month: 'numeric',
        day: 'numeric',
        weekday: 'short',
        hour: '2-digit',
        minute: '2-digit'
    };
    return date.toLocaleDateString('ja-JP', options);
}

// 日時ごとの参加状況選択のイベントリスナーを設定
function setupDateStatusEvents() {
    console.log('🔧 イベントリスナーを設定中...');
    
    // 既存のイベントリスナーを削除
    const existingRadios = document.querySelectorAll('.status-radio input[type="radio"]');
    existingRadios.forEach(radio => {
        radio.removeEventListener('change', handleRadioChange);
    });
    
    // 新しいイベントリスナーを設定
    setTimeout(() => {
        const radioInputs = document.querySelectorAll('.status-radio input[type="radio"]');
        console.log(`🔧 ラジオボタン数: ${radioInputs.length}`);
        
        radioInputs.forEach(radio => {
            radio.addEventListener('change', handleRadioChange);
        });
        
        // ラベルクリックイベントも設定
        const radioLabels = document.querySelectorAll('.status-radio');
        radioLabels.forEach(label => {
            label.addEventListener('click', (e) => {
                const radio = label.querySelector('input[type="radio"]');
                if (radio && !radio.checked) {
                    radio.checked = true;
                    radio.dispatchEvent(new Event('change'));
                }
            });
        });
        
        console.log('🔧 イベントリスナー設定完了');
    }, 100);
}

// ラジオボタンの変更ハンドラー
function handleRadioChange(event) {
    console.log('🔧 ラジオボタン変更:', event.target.value, event.target.dataset.date);
    
    const radio = event.target;
    const date = radio.dataset.date;
    const status = radio.value;
    
    if (!date || !status) {
        console.error('🔧 日時または状態が不正です');
        return;
    }
    
    // 選択状態を保存
    if (!window.dateStatuses) {
        window.dateStatuses = {};
    }
    window.dateStatuses[date] = status;
    
    console.log('🔧 現在の選択状態:', window.dateStatuses);
}

// フォームイベントを設定
function setupFormEvents() {
    const form = document.getElementById('response-form');
    
    // フォーム送信
    form.addEventListener('submit', async (e) => {
        e.preventDefault();
        
        const submitBtn = form.querySelector('.submit-btn');
        submitBtn.disabled = true;
        submitBtn.textContent = '送信中...';
        
        try {
            const submittedData = await submitResponse();
            
            // 代理入力のためフォームはリセットしない
            // 代わりに名前フィールドのみクリアして次の入力に備える
            document.querySelector('input[name="participant-name"]').value = '';
            document.querySelector('textarea[name="comment"]').value = '';
            
            // 日時ごとの参加状況をリセット
            document.querySelectorAll('.date-status-option').forEach(option => {
                option.classList.remove('selected');
                option.querySelector('input[type="radio"]').checked = false;
            });
            
            // 送信完了メッセージを表示
            showSubmissionSuccess(submittedData);
            
            // 回答一覧を更新
            await loadResponses(currentEventId);
            
        } catch (error) {
            console.error('送信エラー:', error);
            showError('送信に失敗しました。もう一度お試しください。');
        } finally {
            submitBtn.disabled = false;
            submitBtn.textContent = '回答を送信';
        }
    });
}

// 回答を送信
async function submitResponse() {
    console.log('🔄 フォーム送信: 選択状況を確認中...');
    
    // チェックされたラジオボタンの数を数える
    const checkedRadios = document.querySelectorAll('input[type="radio"]:checked');
    console.log('✅ チェックされたラジオボタン数:', checkedRadios.length);
    
    if (checkedRadios.length === 0) {
        alert('少なくとも1つの日時について参加状況を選択してください。');
        return;
    }
    
    const form = document.getElementById('response-form');
    const formData = new FormData(form);
    const participantName = formData.get('participant-name');
    const comment = formData.get('comment');
    
    console.log('participantName:', participantName);
    console.log('comment:', comment);
    
    if (!participantName || !participantName.trim()) {
        alert('お名前を入力してください。');
        return;
    }
    
    // 編集モードの確認
    const isEditMode = form.dataset.editMode === 'true';
    const originalName = form.dataset.originalName;
    
    console.log('編集モード:', isEditMode);
    
    try {
        // 日時ごとの参加状況を収集
        const dateStatuses = {};
        const availableDates = [];
        
        // 各日時の選択状況を確認
        Array.from(checkedRadios).forEach((radio, index) => {
            const dateString = radio.dataset.date;
            const status = radio.value;
            
            console.log('選択', index + ':', { date: dateString, status });
            
            dateStatuses[dateString] = status;
            
            // 参加のみをavailable_datesに追加（Supabaseテーブル構造に合わせる）
            if (status === 'attending') {
                availableDates.push(dateString);
            }
        });
        
        console.log('収集された参加状況:', dateStatuses);
        console.log('日時ごとの参加状況:', dateStatuses);
        
        // 全体の参加状況を判定（参加 > 未定 > 不参加の優先度）
        const statusValues = Object.values(dateStatuses);
        let overallStatus = 'not_attending';
        
        if (statusValues.includes('attending')) {
            overallStatus = 'attending';
        } else if (statusValues.includes('undecided')) {
            overallStatus = 'undecided';
        }
        
        console.log('全体の参加状況:', overallStatus);
        
        // Supabaseに送信するデータ（実際のテーブル構造に合わせる）
        const responseData = {
            event_id: currentEventId,
            participant_name: participantName.trim(),
            status: overallStatus,
            available_dates: availableDates,
            comment: comment ? comment.trim() : null,
            response_date: new Date().toISOString(),
            created_at: new Date().toISOString()
        };
        
        console.log('送信データ:', responseData);
        console.log('日時ごとの参加状況詳細:', JSON.stringify(dateStatuses, null, 2));
        
        if (isEditMode) {
            // 既存の回答を更新（同じ名前の回答を削除して再挿入）
            console.log('🗑️ 編集モード: 既存回答を削除中...', {
                event_id: currentEventId,
                participant_name: originalName
            });
            
            const { data: deleteData, error: deleteError } = await supabase
                .from('responses')
                .delete()
                .eq('event_id', currentEventId)
                .eq('participant_name', originalName);
            
            console.log('🗑️ 削除結果:', { deleteData, deleteError });
            
            if (deleteError) {
                console.error('削除エラー:', deleteError);
                throw deleteError;
            }
        }
        
        // 新規または更新された回答を挿入
        console.log('✅ 新規回答を挿入中...', responseData);
        
        const { data: insertData, error: insertError } = await supabase
            .from('responses')
            .insert([responseData])
            .select();
        
        console.log('✅ 挿入結果:', { insertData, insertError });
        
        if (insertError) {
            console.error('❌ Supabaseエラー詳細:', insertError);
            console.error('❌ エラーコード:', insertError.code);
            console.error('❌ エラーメッセージ:', insertError.message);
            console.error('❌ エラー詳細:', insertError.details);
            console.error('❌ 送信データ:', responseData);
            
            // より詳細なエラーメッセージを生成
            let errorMessage = 'データベースエラーが発生しました。';
            if (insertError.code === 'PGRST204') {
                errorMessage = 'データベースのカラムが見つかりません。管理者にお問い合わせください。';
            } else if (insertError.code === 'PGRST116') {
                errorMessage = '必須項目が不足しています。すべての項目を入力してください。';
            } else if (insertError.message) {
                errorMessage = insertError.message;
            }
            
            alert(`送信に失敗しました: ${errorMessage}`);
            throw insertError;
        }
        
        // 編集モードをリセット
        delete form.dataset.editMode;
        delete form.dataset.originalName;
        form.querySelector('.submit-btn').textContent = '回答を送信';
        
        // 編集後もフォームを表示したままにする（代理入力のため）
        // 名前フィールドのみクリアして次の入力に備える
        document.querySelector('input[name="participant-name"]').value = '';
        document.querySelector('textarea[name="comment"]').value = '';
        
        // 日時ごとの参加状況をリセット
        document.querySelectorAll('.date-status-option').forEach(option => {
            option.classList.remove('selected');
            option.querySelector('input[type="radio"]').checked = false;
        });
        
        // 成功メッセージを表示（日時ごとの参加状況を含む）
        const successData = {
            ...responseData,
            date_statuses: dateStatuses  // 表示用に日時ごとの参加状況を追加
        };
        showSubmissionSuccess(successData);
        
        // 回答一覧を更新
        await loadResponses(currentEventId);
        
        console.log('✅ 回答送信完了');
        
    } catch (error) {
        console.error('送信エラー:', error);
        alert('送信に失敗しました。もう一度お試しください。\n\nエラー詳細: ' + error.message);
    }
}

// リアルタイム購読を開始
function subscribeToRealtime() {
    // 回答の変更を監視
    supabase
        .channel('responses')
        .on('postgres_changes', 
            { 
                event: '*', 
                schema: 'public', 
                table: 'responses',
                filter: `event_id=eq.${currentEventId}`
            }, 
            (payload) => {
                console.log('リアルタイム更新:', payload);
                loadResponses(currentEventId);
            }
        )
        .subscribe();
}

// ユーティリティ関数
function formatDateTime(date) {
    const year = date.getFullYear();
    const month = date.getMonth() + 1;
    const day = date.getDate();
    const weekdays = ['日', '月', '火', '水', '木', '金', '土'];
    const weekday = weekdays[date.getDay()];
    const hours = date.getHours().toString().padStart(2, '0');
    const minutes = date.getMinutes().toString().padStart(2, '0');
    
    return `${year}年<br/>${month}月${day}日(${weekday}) ${hours}:${minutes}`;
}

function getStatusText(status) {
    const statusMap = {
        'attending': '参加',
        'not_attending': '不参加',
        'undecided': '未定'
    };
    return statusMap[status] || status;
}

function hideLoading() {
    document.getElementById('loading').classList.add('hidden');
    document.getElementById('event-detail').classList.remove('hidden');
}

function showError(message) {
    document.getElementById('loading').classList.add('hidden');
    document.getElementById('event-detail').classList.add('hidden');
    document.getElementById('error').classList.remove('hidden');
    document.getElementById('error-message').textContent = message;
}

function showSuccess(message) {
    const successDiv = document.createElement('div');
    successDiv.className = 'success-message';
    successDiv.textContent = message;
    successDiv.style.cssText = `
        position: fixed;
        top: 20px;
        right: 20px;
        background: #4CAF50;
        color: white;
        padding: 15px 20px;
        border-radius: 5px;
        z-index: 1000;
        box-shadow: 0 2px 10px rgba(0,0,0,0.2);
    `;
    
    document.body.appendChild(successDiv);
    
    setTimeout(() => {
        successDiv.remove();
    }, 3000);
}

function showSuccessMessage() {
    showSuccess('送信しました');
}

function showErrorMessage(message) {
    const errorDiv = document.createElement('div');
    errorDiv.className = 'error-message';
    errorDiv.textContent = message;
    errorDiv.style.cssText = `
        position: fixed;
        top: 20px;
        right: 20px;
        background: #f44336;
        color: white;
        padding: 15px 20px;
        border-radius: 5px;
        z-index: 1000;
        box-shadow: 0 2px 10px rgba(0,0,0,0.2);
    `;
    
    document.body.appendChild(errorDiv);
    
    setTimeout(() => {
        errorDiv.remove();
    }, 5000);
}

// 送信完了メッセージを表示
function showSubmissionSuccess(submittedData) {
    // 既存の成功メッセージを削除
    const existingSuccess = document.querySelector('.submission-success');
    if (existingSuccess) {
        existingSuccess.remove();
    }
    
    const responseSection = document.querySelector('.response-form');
    const successDiv = document.createElement('div');
    successDiv.className = 'submission-success';
    
    successDiv.innerHTML = `
        <div class="success-header">
            <div class="success-icon">✅</div>
            <h3>送信しました</h3>
        </div>
        <div class="success-actions">
            <button onclick="this.parentElement.parentElement.remove()" class="btn btn-secondary">
                閉じる
            </button>
        </div>
    `;
    
    responseSection.appendChild(successDiv);
    
    // 3秒後に自動で閉じる
    setTimeout(() => {
        if (successDiv.parentElement) {
            successDiv.remove();
        }
    }, 3000);
}

// 編集機能
function editResponse(participantName) {
    // 既存の回答を取得
    const existingResponse = currentResponses.find(r => r.participant_name === participantName);
    if (!existingResponse) {
        alert('回答が見つかりません');
        return;
    }
    
    // フォームを表示し、既存データを入力
    const responseForm = document.getElementById('response-form');
    const successDiv = document.querySelector('.submission-success');
    
    // 成功メッセージを非表示
    if (successDiv) {
        successDiv.style.display = 'none';
    }
    
    // 既存データを入力
    document.querySelector('input[name="participant-name"]').value = existingResponse.participant_name || '';
    document.querySelector('textarea[name="comment"]').value = existingResponse.comment || '';
    
    // 日時ごとの参加状況をリセット
    document.querySelectorAll('.date-status-option').forEach(option => {
        option.classList.remove('selected');
        const radio = option.querySelector('input[type="radio"]');
        if (radio) {
            radio.checked = false;
        }
    });
    
    // 日時ごとの参加状況を設定
    if (existingResponse.date_statuses && typeof existingResponse.date_statuses === 'object') {
        // 新しい形式のデータ
        Object.entries(existingResponse.date_statuses).forEach(([date, status]) => {
            const radio = document.querySelector(`input[type="radio"][data-date="${date}"][value="${status}"]`);
            if (radio) {
                const option = radio.closest('.date-status-option');
                if (option) {
                    option.classList.add('selected');
                    radio.checked = true;
                }
            }
        });
    } else if (existingResponse.available_dates && Array.isArray(existingResponse.available_dates)) {
        // 古い形式のデータ（available_datesのみ）
        existingResponse.available_dates.forEach(date => {
            const radio = document.querySelector(`input[type="radio"][data-date="${date}"][value="attending"]`);
            if (radio) {
                const option = radio.closest('.date-status-option');
                if (option) {
                    option.classList.add('selected');
                    radio.checked = true;
                }
            }
        });
    }
    
    // 送信ボタンのテキストを変更
    const submitBtn = responseForm.querySelector('.submit-btn');
    if (submitBtn) {
        submitBtn.textContent = '回答を更新';
    }
    
    // 編集モードであることを示すフラグ
    responseForm.dataset.editMode = 'true';
    responseForm.dataset.originalName = participantName;
    
    // フォーム位置にスクロール
    responseForm.scrollIntoView({ behavior: 'smooth' });
}

// 成功メッセージのアニメーション
const style = document.createElement('style');
style.textContent = `
    @keyframes slideIn {
        from { transform: translateX(100%); opacity: 0; }
        to { transform: translateX(0); opacity: 1; }
    }
`;
document.head.appendChild(style);

// フォーム送信処理
async function handleSubmit(e) {
    e.preventDefault();
    
    const submitButton = document.querySelector('.submit-button');
    const originalText = submitButton.textContent;
    
    try {
        // 送信中の状態に変更
        submitButton.textContent = '送信中...';
        submitButton.disabled = true;
        
        // フォームデータを取得
        const formData = new FormData(e.target);
        const participantName = formData.get('participant_name');
        const comment = formData.get('comment') || '';
        
        // 参加者名のバリデーション
        if (!participantName || participantName.trim() === '') {
            throw new Error('参加者名を入力してください');
        }
        
        // 日時ごとの参加状況を取得
        const dateStatuses = {};
        const radioInputs = document.querySelectorAll('.status-radio input[type="radio"]:checked');
        
        console.log('🔧 選択されたラジオボタン数:', radioInputs.length);
        
        radioInputs.forEach(radio => {
            const date = radio.dataset.date;
            const status = radio.value;
            if (date && status) {
                dateStatuses[date] = status;
                console.log('🔧 日時状況:', date, status);
            }
        });
        
        // 少なくとも1つの日時について回答が必要
        if (Object.keys(dateStatuses).length === 0) {
            throw new Error('少なくとも1つの日時について参加状況を選択してください');
        }
        
        // 全体の参加状況を判定（参加 > 未定 > 不参加の優先度）
        const statusCounts = {
            attending: 0,
            undecided: 0,
            not_attending: 0
        };
        
        Object.values(dateStatuses).forEach(status => {
            if (status === 'attending') statusCounts.attending++;
            else if (status === 'undecided') statusCounts.undecided++;
            else if (status === 'not_attending') statusCounts.not_attending++;
        });
        
        let overallStatus = 'undecided';
        if (statusCounts.attending > 0) {
            overallStatus = 'attending';
        } else if (statusCounts.undecided > 0) {
            overallStatus = 'undecided';
        } else {
            overallStatus = 'not_attending';
        }
        
        // 参加可能な日時を抽出
        const availableDates = Object.keys(dateStatuses).filter(date => 
            dateStatuses[date] === 'attending'
        );
        
        console.log('🔧 送信データ:', {
            participantName,
            comment,
            dateStatuses,
            overallStatus,
            availableDates
        });
        
        // Supabaseに送信
        const response = await fetch(`${SUPABASE_URL}/rest/v1/responses`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'apikey': SUPABASE_ANON_KEY,
                'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
                'Prefer': 'return=minimal'
            },
            body: JSON.stringify({
                event_id: currentEventId,
                participant_name: participantName.trim(),
                available_dates: availableDates,
                status: overallStatus,
                comment: comment.trim(),
                response_date: new Date().toISOString(),
                created_at: new Date().toISOString()
            })
        });
        
        if (!response.ok) {
            const errorData = await response.json();
            console.error('❌ Supabaseエラー:', errorData);
            throw new Error(`送信エラー: ${errorData.message || response.statusText} (${response.status})`);
        }
        
        console.log('✅ 送信成功');
        
        // 成功メッセージを表示
        showSuccessMessage();
        
        // フォームをリセット
        e.target.reset();
        
        // 選択状態をクリア
        window.dateStatuses = {};
        
        // 選択状態をUIからも削除
        const checkedRadios = document.querySelectorAll('.status-radio input[type="radio"]:checked');
        checkedRadios.forEach(radio => {
            radio.checked = false;
        });
        
        // 回答一覧を更新
        await loadResponses(currentEventId);
        
    } catch (error) {
        console.error('❌ 送信エラー:', error);
        showErrorMessage(error.message);
    } finally {
        // ボタンを元の状態に戻す
        submitButton.textContent = originalText;
        submitButton.disabled = false;
    }
} 