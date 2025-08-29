//
//  EventAdder.swift
//  methodiqal
//
//  Created by Jayen Agrawal on 8/29/25.
//

import Foundation
import EventKit


public struct EventAdder {
    let eventStore: EKEventStore
    
    static let global = EventAdder()
    
    init() {
        self.eventStore = EKEventStore()
    }
    
    func requestEventStore() {
        eventStore.requestAccess(to: .event) { granted, error in }
    }
    
    func timeInterval(from duration: Duration) -> TimeInterval {
        let components = duration.components
        let seconds = Double(components.seconds)
        let attoseconds = Double(components.attoseconds) / 1_000_000_000_000_000_000.0
        return seconds + attoseconds
    }

    func addEvent(assignmentEvent: AssignmentEvent) {
        let event = EKEvent(eventStore: eventStore)
        event.title = assignmentEvent.title
        event.notes = assignmentEvent.description
        event.startDate = assignmentEvent.date
        event.endDate = assignmentEvent.date + timeInterval(from: assignmentEvent.duration)
        event.calendar = eventStore.defaultCalendarForNewEvents
        
        do {
            try eventStore.save(event, span: .thisEvent)
            print("Event saved to calendar.")
        } catch {
            print("Failed to save event: \(error)")
        }
    }
}
