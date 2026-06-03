import Foundation

enum Config {
    struct RSSFeed {
        let url: String
        let category: String
    }

    static let rssFeeds: [RSSFeed] = [
        RSSFeed(url: "https://www.themiltonpaper.com/news?format=rss",      category: "News"),
        RSSFeed(url: "https://www.themiltonpaper.com/opinion?format=rss",   category: "Opinion"),
        RSSFeed(url: "https://www.themiltonpaper.com/sports?format=rss",    category: "Sports"),
        RSSFeed(url: "https://www.themiltonpaper.com/editorial?format=rss", category: "Editorial"),
    ]

    static let squarespaceAPIKey = ""
    static let squarespaceCollectionID = ""


    static let appName = "The Milton Paper"
    static let supportEmail = "themiltonpaper40@gmail.com"

    // FCM Topics
    static let topicNewArticles = "new_articles"
    static let topicNews = "news"
    static let topicOpinion = "opinion"
    static let topicSports = "sports"
    static let topicEditorial = "editorial"

    static var useMockData: Bool { rssFeeds.isEmpty }
}
