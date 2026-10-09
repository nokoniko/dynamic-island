import Foundation
import Testing
@testable import DynamicIsland

struct UpdateScheduleTests {
	let calendar: Calendar = {
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = TimeZone(identifier: "UTC")!
		return calendar
	}()

	func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
		calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
	}

	func next(after last: Date?, _ frequency: UpdateFrequency, _ time: UpdateTimeOfDay = .morning, now: Date) -> Date {
		UpdateSchedule.nextCheck(after: last, frequency: frequency, timeOfDay: time, now: now, calendar: calendar)
	}

	@Test func hourlyIsAnHourAfterTheLastCheck() {
		#expect(next(after: date(9, 10, 30), .hourly, now: date(9, 11)) == date(9, 11, 30))
	}

	@Test func hourlyWithoutAPreviousCheckIsDueNow() {
		#expect(next(after: nil, .hourly, now: date(9, 11)) == date(9, 11))
	}

	@Test func hourlyIgnoresTheTimeOfDay() {
		#expect(next(after: date(9, 10), .hourly, .evening, now: date(9, 10)) == date(9, 11))
	}

	@Test(arguments: [
		(UpdateFrequency.daily, 10),
		(.everyTwoDays, 11),
		(.weekly, 16),
	])
	func daysAfterTheDayOfTheLastCheck(frequency: UpdateFrequency, day: Int) {
		#expect(next(after: date(9, 9, 2), frequency, now: date(9, 12)) == date(day, 9))
	}

	@Test(arguments: [
		(UpdateTimeOfDay.morning, 9),
		(.afternoon, 14),
		(.evening, 19),
	])
	func usesTheChosenTimeOfDay(time: UpdateTimeOfDay, hour: Int) {
		#expect(next(after: date(9, 8), .daily, time, now: date(9, 8)) == date(10, hour))
	}

	@Test func aLateCheckDoesNotPushTheNextOneLater() {
		// Asleep at 09:00, checked at 15:00 instead: tomorrow is still 09:00.
		#expect(next(after: date(9, 15), .daily, now: date(9, 15)) == date(10, 9))
	}

	@Test func withoutAPreviousCheckTodaysSlotCounts() {
		#expect(next(after: nil, .weekly, .evening, now: date(9, 10)) == date(9, 19))
		#expect(next(after: nil, .daily, .morning, now: date(9, 10)) == date(9, 9))
	}

	@Test func aLastCheckInTheFutureCountsAsNow() {
		#expect(next(after: date(20, 9), .daily, now: date(9, 10)) == date(10, 9))
		#expect(next(after: date(20, 9), .hourly, now: date(9, 10)) == date(9, 11))
	}
}
