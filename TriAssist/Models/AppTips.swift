//
//  AppTips.swift
//  TriAssist
//

import TipKit

struct DashboardInputTip: Tip {
    var title: Text { Text("用自然語言告訴 AI") }
    var message: Text? {
        Text("直接輸入句子，AI 會自動判斷並分類：\n「明天下午三點開會」→ 行程\n「要買牛奶兩瓶」→ 購物清單\n「記得繳電話費」→ 待辦")
    }
    var image: Image? { Image(systemName: "sparkles") }
}

struct CalendarSwipeTip: Tip {
    var title: Text { Text("滑動操作行程") }
    var message: Text? { Text("向左滑動可刪除行程，向右滑動可編輯行程的時間與標題。") }
    var image: Image? { Image(systemName: "hand.draw") }
}

struct TodoSwipeTip: Tip {
    var title: Text { Text("滑動操作任務") }
    var message: Text? { Text("向右滑動可編輯任務，向左滑動可刪除。購物清單也支援相同操作。") }
    var image: Image? { Image(systemName: "hand.draw") }
}

struct MapRadarTip: Tip {
    var title: Text { Text("找附近的地點") }
    var message: Text? {
        Text("點「我有空」，AI 會掃描 500 公尺內符合你待辦和購物清單的店家，並預估步行與停留時間。")
    }
    var image: Image? { Image(systemName: "location.fill.viewfinder") }
}

struct RoutineSettingsTip: Tip {
    var title: Text { Text("設定固定行程讓 AI 更準確") }
    var message: Text? { Text("把你的上課時間、起床睡覺時間加進來，AI 每日排程建議就會自動避開這些時段。") }
    var image: Image? { Image(systemName: "calendar.badge.clock") }
}
