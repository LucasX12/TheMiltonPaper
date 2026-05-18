import Foundation

extension Date {
    var miltonFormatted: String {
        formatted(.dateTime.month(.wide).day().year())
    }

    var miltonRelative: String {
        let components = Calendar.current.dateComponents([.day, .hour, .minute], from: self, to: .now)
        if let days = components.day, days > 0 {
            return days == 1 ? "1 day ago" : "\(days) days ago"
        }
        if let hours = components.hour, hours > 0 {
            return hours == 1 ? "1 hour ago" : "\(hours) hours ago"
        }
        if let minutes = components.minute, minutes > 0 {
            return minutes == 1 ? "1 minute ago" : "\(minutes) minutes ago"
        }
        return "Just now"
    }
}
