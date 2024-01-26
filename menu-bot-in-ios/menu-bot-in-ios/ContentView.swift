import SwiftUI
import Combine

// データモデルは変更なし
struct WeeklyMenu: Codable, Hashable {
    let month: Int
    var days: [Int]
    let higawari: [String]

    enum CodingKeys: String, CodingKey {
        case month, days, higawari
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        month = try container.decode(Int.self, forKey: .month)
        higawari = try container.decode([String].self, forKey: .higawari)

        // 'days' をデコードする新しい方法
        var tempDays = [Int]()
        var daysContainer = try container.nestedUnkeyedContainer(forKey: .days)
        while !daysContainer.isAtEnd {
            if let day = try? daysContainer.decode(Int.self) {
                tempDays.append(day)
            } else if let _ = try? daysContainer.decode(String.self) {
                // 数値に変換できない文字列は無視するか、特定のデフォルト値に置き換える
                // 例: tempDays.append(-1) // デフォルト値として -1 を使用
                continue
            }
        }
        days = tempDays
    }


}


extension WeeklyMenu {
    func dayOfWeek(for day: Int) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM/dd/yyyy"
        guard let date = dateFormatter.date(from: "\(month)/\(day)/2024") else { return "" } // 年は適宜調整
        dateFormatter.dateFormat = "EEEE"
        return dateFormatter.string(from: date)
    }
}


// ViewModelを定義
class MenuViewModel: ObservableObject {
    @Published var thisWeekMenu: [WeeklyMenu] = []
    @Published var nextWeekMenu: [WeeklyMenu] = []
    @Published var showRating = false


    func loadMenuData() {
        let url = URL(string: "http://localhost:3000/api")!

        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let data = data else {
                print("Error fetching data: \(error?.localizedDescription ?? "Unknown error")")
                return
            }

            // レスポンスデータを文字列として出力してデバッグ
            let responseString = String(data: data, encoding: .utf8) ?? "Invalid response data"
            print("Received JSON: \(responseString)")

            do {
                // JSONデコード処理
                let menus = try JSONDecoder().decode([WeeklyMenu].self, from: data)
                let currentDate = Date()
                let calendar = Calendar.current
                let currentWeek = calendar.component(.weekOfYear, from: currentDate)

                DispatchQueue.main.async {
                    self?.thisWeekMenu = menus.filter { menu in
                        guard let firstDay = menu.days.first,
                              let date = self?.dateFromString(firstDay, month: menu.month) else {
                            return false
                        }
                        return calendar.component(.weekOfYear, from: date) == currentWeek
                    }

                    self?.nextWeekMenu = menus.filter { menu in
                        guard let firstDay = menu.days.first,
                              let date = self?.dateFromString(firstDay, month: menu.month) else {
                            return false
                        }
                        return calendar.component(.weekOfYear, from: date) != currentWeek
                    }
                }
            } catch {
                print("Error decoding data: \(error.localizedDescription)")
            }
        }
        task.resume()
    }


    func dateFromString(_ day: Int, month: Int) -> Date? {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MM/dd/yyyy"
            return dateFormatter.date(from: "\(month)/\(day)/2024") // 年は適宜調整
        }
}

struct StarRatingView: View {
    let rating: Int // 星の数

    var body: some View {
        HStack {
            ForEach(0..<rating, id: \.self) { _ in
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
            }
        }
    }
}


struct MenuView: View {
    @ObservedObject var viewModel = MenuViewModel()
    var isCurrentWeek: Bool

    var body: some View {
        GeometryReader { geometry in // GeometryReaderを追加
            NavigationView {
                List {
                    ForEach(isCurrentWeek ? viewModel.thisWeekMenu : viewModel.nextWeekMenu, id: \.self) { weeklyMenu in
                        Section {
                            ForEach(0..<weeklyMenu.days.count, id: \.self) { index in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text("日付: \(weeklyMenu.days[index]) (\(weeklyMenu.dayOfWeek(for: weeklyMenu.days[index])))")
                                        Text("メニュー: \(weeklyMenu.higawari[index])")
                                            .lineLimit(nil)
                                    }
                                    Spacer() // HStack内で要素間を均等に配置
                                    Button(action: {
                                        viewModel.showRating.toggle()
                                        // 今週か来週かを判断してコメントを表示
                                        if isCurrentWeek {
                                            print("評価: 今週のメニュー")
                                        } else {
                                            print("評価: 来週のメニュー")
                                        }
                                    }) {
                                        Text("評価する")
                                            .frame(width: geometry.size.width * 0.2)
                                        // ボタンの幅をリストの幅の20%に設定
                                            .padding()
                                            .background(Color.blue)
                                            .foregroundColor(.white)
                                            .cornerRadius(10)
                                    }
                                }
                            }
                        }
                    }
                    if viewModel.showRating {
                                        StarRatingView(rating: 5) // 星5つの評価を表示
                                    }
                }
                .navigationTitle(isCurrentWeek ? "今週のメニュー" : "来週のメニュー")
                .onAppear {
                    viewModel.loadMenuData()
                }
            }
        }
    }
}


struct ContentView: View {
    var body: some View {
        TabView {
            MenuView(isCurrentWeek: true)
                .tabItem {
                    Label("今週", systemImage: "calendar")
                }
            
            MenuView(isCurrentWeek: false)
                .tabItem {
                    Label("来週", systemImage: "calendar.badge.plus")
                }
        }
    }
}
