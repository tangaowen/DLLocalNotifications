//
//  DLLocalNotifications.swift
//  DLLocalNotifications
//
//  Created by Devesh Laungani on 12/14/16.
//  Copyright © 2016 Devesh Laungani. All rights reserved.
//

import Foundation
import UserNotifications

let MAX_ALLOWED_NOTIFICATIONS = 64

@available(iOS 10.0, *)
public class DLNotificationScheduler {
    
    // Apple allows you to only schedule 64 notifications at a time
    static let maximumScheduledNotifications = 60
    
    public init () {}
    
    public func cancelAlllNotifications () {
        
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        DLQueue.queue.clear()
        saveQueue()
        
        print("cancelAllNotifications")
    }
    
    
    // Returns all notifications in the notifications queue.
    public func notificationsQueue() -> [DLNotification] {
        return DLQueue.queue.notificationsQueue()
    }
    

    
    // Cancel the notification if scheduled or queued
    public func cancelNotification (notification: DLNotification) {
        //only notification's identify not nil , remove pending notification
        if notification.identifier != nil {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [(notification.identifier)!])
        }

        let queue = DLQueue.queue.notificationsQueue()
        var i = 0
        for noti in queue {
            if notification.identifier == noti.identifier {
                DLQueue.queue.removeAtIndex(i)
                break
            }
            i += 1
        }
        notification.scheduled = false
        
        saveQueue()
    }
    
    public func getScheduledNotification(with identifier: String, handler:@escaping (_ request:UNNotificationRequest?)-> Void) {
        
        
        var foundNotification:UNNotificationRequest? = nil
        UNUserNotificationCenter.current().getPendingNotificationRequests(completionHandler: { (requests) in
           
            for request  in  requests {
                if let request1 =  request.trigger as?  UNTimeIntervalNotificationTrigger {
                    if (request.identifier == identifier) {
                         print("Timer interval notificaiton: \(request1.nextTriggerDate().debugDescription)")
                        handler(request)
                    }
                    break
                   
                }
                if let request2 =  request.trigger as?  UNCalendarNotificationTrigger {
                    if (request.identifier == identifier) {
                        handler(request)
                        if(request2.repeats) {
                            print(request)
                            print("Calendar notification: \(request2.nextTriggerDate().debugDescription) and repeats")
                        } else {
                            print("Calendar notification: \(request2.nextTriggerDate().debugDescription) does not repeat")
                        }
                        break
                    }
                    
                }
                if let request3 = request.trigger as? UNLocationNotificationTrigger {
                    
                    print("Location notification: \(request3.region.debugDescription)")
                }
            }
        })
    
    }
    
    public func printAllNotifications () {
        
        UNUserNotificationCenter.current().getPendingNotificationRequests(completionHandler: { (requests) in
            print(requests.count)
            for request  in  requests {
                if let request1 =  request.trigger as?  UNTimeIntervalNotificationTrigger {
                    print("Timer interval notificaiton: \(request1.nextTriggerDate().debugDescription)")
                }
                if let request2 =  request.trigger as?  UNCalendarNotificationTrigger {
                    if(request2.repeats) {
                        print(request)
                        print("Calendar notification: \(request2.nextTriggerDate().debugDescription) and repeats")
                    } else {
                        print("Calendar notification: \(request2.nextTriggerDate().debugDescription) does not repeat")
                    }
                }
                if let request3 = request.trigger as? UNLocationNotificationTrigger {
                    
                    print("Location notification: \(request3.region.debugDescription)")
                }
            }
        })
    }
    
    private func convertToNotificationDateComponent (notification: DLNotification, repeatInterval: RepeatingInterval   ) -> DateComponents {
        
        var newComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second ], from: notification.fireDate!)
        
        if repeatInterval != .none {
            
            switch repeatInterval {
            case .minute:
                newComponents = Calendar.current.dateComponents([ .second], from: notification.fireDate!)
            case .hourly:
                newComponents = Calendar.current.dateComponents([ .minute], from: notification.fireDate!)
            case .daily:
                newComponents = Calendar.current.dateComponents([.hour, .minute], from: notification.fireDate!)
            case .weekly:
                newComponents = Calendar.current.dateComponents([.hour, .minute, .weekday], from: notification.fireDate!)
            case .monthly:
                newComponents = Calendar.current.dateComponents([.hour, .minute, .day], from: notification.fireDate!)
            case .yearly:
                newComponents = Calendar.current.dateComponents([.hour, .minute, .day, .month], from: notification.fireDate!)
            default:
                break
            }
        }
        
        return newComponents
    }
    
    @discardableResult
    fileprivate func queueNotification (notification: DLNotification) -> String? {
        DLQueue.queue.push(notification)
        DLQueue.queue.reSort()
        
        return notification.identifier
    }
    
    public func scheduleNotification ( notification: DLNotification) {
        queueNotification(notification: notification)
    }
    
    public func reScheduleAllNotifications() {
        
        UNUserNotificationCenter.current().getPendingNotificationRequests(completionHandler: { (requests) in
            DLQueue.queue.reSort()
            
            //get first 60 next schedule notification first
            var nextScheduleNotifications : [DLNotification] = []
            let allNotifications = self.notificationsQueue()
            if allNotifications.count < 60 {
                nextScheduleNotifications = allNotifications
            }
            else {
                nextScheduleNotifications = Array(allNotifications[0..<60])
            }
            
            var alreadyScheduleRequestCount = requests.count
            print("cur pending request count = ",requests.count)
            
            //sort pending requests by trigger date
            var sortedRequests = requests.sorted(by: { (request1, request2) -> Bool in
                let requestTrigger1 =  request1.trigger as?  UNCalendarNotificationTrigger
                let requestTrigger2 =  request2.trigger as?  UNCalendarNotificationTrigger
                if requestTrigger1?.nextTriggerDate() == nil {
                    return false
                }
                else if requestTrigger2?.nextTriggerDate() == nil {
                    return true
                }
                else {
                    if requestTrigger1!.nextTriggerDate()! <= requestTrigger2!.nextTriggerDate()! {
                        return true
                    }
                    else {
                        return false
                    }
                }
            })
            
            var unScheduleCadidatesRequest : [UNNotificationRequest] = [UNNotificationRequest](sortedRequests)
            
            //only for debug output
            for request  in  sortedRequests {
                if let requestTrigger =  request.trigger as?  UNCalendarNotificationTrigger {
                    if(requestTrigger.repeats) {
                        print(requestTrigger)
                        print("Calendar notification: \(requestTrigger.nextTriggerDate().debugDescription), title = \(request.content.title), and content = \(request.content.body), and repeats")
                    } else {
                        print("Calendar notification: \(requestTrigger.nextTriggerDate().debugDescription), title = \(request.content.title), and content = \(request.content.body), does not repeat")
                    }
                }
            }
            
            //Schedule 新的 notifications
            print("have \(nextScheduleNotifications.count) notifications to be schedule")
            var scheduleIndex = 1
            for notification in nextScheduleNotifications {
                
                let findRequestOpt = requests.first(where: { (request) -> Bool in
                    if request.identifier == notification.identifier {
                        return true
                    }
                    else {
                        return false
                    }
                })
                
                //if not scheduled, Schedule new notification
                print("no : \(scheduleIndex) notification, details = \(notification.debugDescription) , triggrTime = \(notification.trigger?.nextTriggerDate()?.description(with: .current))")
                
                if findRequestOpt == nil {
                    print("no : \(scheduleIndex) notification not scheduled before")
                    //if the alreadyScheduleRequestCount >= 60, not unSchedule
                    if alreadyScheduleRequestCount >= 60 {
                        //unSchedule last request in unScheduleCadidatesRequest
                        let unScheduleIdentify : String = unScheduleCadidatesRequest.last!.identifier
                        unScheduleCadidatesRequest.removeLast()
                    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [unScheduleIdentify])
                            
                        self.scheduleNotificationInternal(notification: notification)
                        
                        print("no : \(scheduleIndex) notification replace a scheduled notificaiton , then scheduled")
                    }
                    else {
                        //if alreadyScheduleRequestCount count is < 60 , just schedule
                        alreadyScheduleRequestCount += 1
                        self.scheduleNotificationInternal(notification: notification)
                        
                        print("no : \(scheduleIndex) notification , new add scheduled")
                    }
                }
                else {
                    print("no : \(scheduleIndex) notification is already schedule before, do nothing")
                }
                
                scheduleIndex = scheduleIndex + 1
            }
            
            print("now \(alreadyScheduleRequestCount) notifications scheduled")
        })
    }
    
    // Refactored for backwards compatability
    @discardableResult
    fileprivate func scheduleNotificationInternal ( notification: DLNotification) -> String? {
    
        let content = UNMutableNotificationContent()
        content.title = notification.alertTitle!
        content.body = notification.alertBody!
        content.sound = notification.soundName == "" ? UNNotificationSound.default : UNNotificationSound.init(named: UNNotificationSoundName(rawValue: notification.soundName))
        
        
        if (notification.soundName == "1") { content.sound = nil}
        
        if !(notification.attachments == nil) { content.attachments = notification.attachments! }
        
        if !(notification.launchImageName == nil) { content.launchImageName = notification.launchImageName! }
        
        if !(notification.category == nil) { content.categoryIdentifier = notification.category! }
        
        notification.localNotificationRequest = UNNotificationRequest(identifier: notification.identifier!, content: content, trigger: notification.trigger)
        
        let center = UNUserNotificationCenter.current()
        center.add(notification.localNotificationRequest!, withCompletionHandler: {(error) in
            if error != nil {
                print(error.debugDescription)
            }
        })
        
        notification.scheduled = true
        return notification.identifier
    }
    
    ///Persists the notifications queue to the disk
    ///> Call this method whenever you need to save changes done to the queue and/or before terminating the app.
    
    @discardableResult
    public func saveQueue() -> Bool {
        return DLQueue.queue.save()
    }
    ///- returns: Count of scheduled notifications by iOS.
    func scheduledCount(completion: @escaping (Int) -> Void) {
        UNUserNotificationCenter.current().getPendingNotificationRequests(completionHandler: { (localNotifications) in
            completion(localNotifications.count)
        })
        
    }
    
    // You have to manually keep in mind ios 64 notification limit
    
    public func repeatsFromToDate (identifier: String, alertTitle: String, alertBody: String, fromDate: Date, toDate: Date, interval: Double, repeats: RepeatingInterval, category: String = " ", sound: String = " ") {
        
        let notification = DLNotification(identifier: identifier, alertTitle: alertTitle, alertBody: alertBody, date: fromDate, repeats: repeats)
        notification.category = category
        notification.soundName = sound
        // Create multiple Notifications
        
        self.queueNotification(notification: notification)
        let intervalDifference = Int( toDate.timeIntervalSince(fromDate) / interval )
        
        var nextDate = fromDate
        
        for i in 0..<intervalDifference {
            
            // Next notification Date
            
            nextDate = nextDate.addingTimeInterval(interval)
            let identifier = identifier + String(i + 1)
            
            let notification = DLNotification(identifier: identifier, alertTitle: alertTitle, alertBody: alertBody, date: nextDate, repeats: repeats)
            notification.category = category
            notification.soundName = sound
            self.queueNotification(notification: notification)
        }
        
    }
    
    public func scheduleCategories(categories: [DLCategory]) {
        
        var notificationCategories = Set<UNNotificationCategory>()
        
        for category in categories {
            
            guard let categoryInstance = category.categoryInstance else { continue }
            notificationCategories.insert(categoryInstance)
            
        }
        
        UNUserNotificationCenter.current().setNotificationCategories(notificationCategories)
        
    }
    
}

// Repeating Interval Times

public enum RepeatingInterval: String {
    case none, minute, hourly, daily, weekly, monthly, yearly
}

extension Date {

func removeSeconds() -> Date {
    let calendar = Calendar.current
    let components = (calendar as NSCalendar).components([.year, .month, .day, .hour, .minute], from: self)
    return calendar.date(from: components)!
}
}

