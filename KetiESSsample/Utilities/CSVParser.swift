// KetiESSsample/Utilities/CSVParser.swift

import Foundation

struct CSVParser {
    // 날짜 캐시 (동일 타임스탬프 재사용으로 성능 향상)
    private static var dateCache: [String: Date] = [:]
    private static let cacheLock = NSLock()

    // UTC 캘린더 (재사용)
    private static let utcCalendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()

    /// 빠른 날짜 파싱 (DateFormatter 대신 수동 파싱 - 10배 이상 빠름)
    static func parseDate(_ string: String) -> Date? {
        // 캐시 확인
        cacheLock.lock()
        if let cached = dateCache[string] {
            cacheLock.unlock()
            return cached
        }
        cacheLock.unlock()

        var date: Date? = nil

        // 형식 1: "2025.7.1 0:00" (CSV 형식)
        if string.contains(".") {
            date = parseDateManual_dot(string)
        }
        // 형식 2: "yyyy-MM-dd HH:mm:ss"
        else if string.contains("-") {
            date = parseDateManual_dash(string)
        }

        // 캐시에 저장
        if let date = date {
            cacheLock.lock()
            dateCache[string] = date
            cacheLock.unlock()
        }

        return date
    }

    /// "2025.7.1 0:00" 형식 수동 파싱
    private static func parseDateManual_dot(_ string: String) -> Date? {
        // "2025.7.1 0:00" -> ["2025.7.1", "0:00"]
        let parts = string.split(separator: " ", maxSplits: 1)
        guard parts.count >= 1 else { return nil }

        // 날짜 파싱: "2025.7.1"
        let dateParts = parts[0].split(separator: ".")
        guard dateParts.count == 3,
              let year = Int(dateParts[0]),
              let month = Int(dateParts[1]),
              let day = Int(dateParts[2]) else { return nil }

        // 시간 파싱: "0:00" (옵션)
        var hour = 0, minute = 0
        if parts.count == 2 {
            let timeParts = parts[1].split(separator: ":")
            if timeParts.count >= 2 {
                hour = Int(timeParts[0]) ?? 0
                minute = Int(timeParts[1]) ?? 0
            }
        }

        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = 0

        return utcCalendar.date(from: components)
    }

    /// "yyyy-MM-dd HH:mm:ss" 형식 수동 파싱
    private static func parseDateManual_dash(_ string: String) -> Date? {
        // "2025-07-01 00:00:00" -> ["2025-07-01", "00:00:00"]
        let parts = string.split(separator: " ", maxSplits: 1)
        guard parts.count >= 1 else { return nil }

        // 날짜 파싱
        let dateParts = parts[0].split(separator: "-")
        guard dateParts.count == 3,
              let year = Int(dateParts[0]),
              let month = Int(dateParts[1]),
              let day = Int(dateParts[2]) else { return nil }

        // 시간 파싱
        var hour = 0, minute = 0, second = 0
        if parts.count == 2 {
            let timeParts = parts[1].split(separator: ":")
            if timeParts.count >= 3 {
                hour = Int(timeParts[0]) ?? 0
                minute = Int(timeParts[1]) ?? 0
                second = Int(timeParts[2]) ?? 0
            }
        }

        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = second

        return utcCalendar.date(from: components)
    }

    /// 캐시 클리어 (메모리 관리용)
    static func clearDateCache() {
        cacheLock.lock()
        dateCache.removeAll()
        cacheLock.unlock()
    }

    // MARK: - Parse Rack Data
    static func parseRackData(from url: URL) -> [RackData] {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            print("❌ Failed to read file at \(url)")
            return []
        }

        let lines = content.components(separatedBy: .newlines)
        var result: [RackData] = []

        // Skip header (first line)
        for line in lines.dropFirst() {
            guard !line.isEmpty else { continue }

            let columns = line.components(separatedBy: ",")
            guard columns.count >= 6 else { continue }

            // Parse data
            guard let timestamp = parseDate(columns[0]),
                  let voltage = Double(columns[2]),
                  let current = Double(columns[3]),
                  let soc = Double(columns[4]),
                  let soh = Double(columns[5]) else {
                continue
            }

            let rackData = RackData(
                timestamp: timestamp,
                rackId: columns[1],
                systemBusVoltage: voltage,
                systemBusCurrent: current,
                systemOnlineSOC: soc,
                systemOnlineSOH: soh
            )

            result.append(rackData)
        }

        return result
    }

    // MARK: - Parse Module Data
    static func parseModuleData(from url: URL) -> [ModuleData] {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            print("❌ Failed to read file at \(url)")
            return []
        }

        let lines = content.components(separatedBy: .newlines)
        var result: [ModuleData] = []

        // Skip header (first line)
        for line in lines.dropFirst() {
            guard !line.isEmpty else { continue }

            let columns = line.components(separatedBy: ",")
            guard columns.count >= 15 else { continue }

            // Parse data
            guard let timestamp = parseDate(columns[0]),
                  let maxCellTemp = Double(columns[3]),
                  let minCellTemp = Double(columns[4]),
                  let avgTemp = Double(columns[5]),
                  let maxCellVoltage = Double(columns[6]),
                  let minCellVoltage = Double(columns[7]),
                  let avgVoltage = Double(columns[8]),
                  let stringMaxCurrent = Double(columns[9]),
                  let stringMinCurrent = Double(columns[10]),
                  let avgCurrent = Double(columns[11]),
                  let soc = Double(columns[12]),
                  let soh = Double(columns[13]),
                  let cellBalancingStatus = Int(columns[14]) else {
                continue
            }

            let moduleData = ModuleData(
                timestamp: timestamp,
                rackId: columns[1],
                moduleId: columns[2],
                maxCellTemp: maxCellTemp,
                minCellTemp: minCellTemp,
                avgTemp: avgTemp,
                maxCellVoltage: maxCellVoltage,
                minCellVoltage: minCellVoltage,
                avgVoltage: avgVoltage,
                stringMaxCurrent: stringMaxCurrent,
                stringMinCurrent: stringMinCurrent,
                avgCurrent: avgCurrent,
                soc: soc,
                soh: soh,
                cellBalancingStatus: cellBalancingStatus
            )

            result.append(moduleData)
        }

        return result
    }

    // MARK: - Parse Cell Data
    static func parseCellData(from url: URL) -> [CellData] {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            print("❌ Failed to read file at \(url)")
            return []
        }

        let lines = content.components(separatedBy: .newlines)
        var result: [CellData] = []

        // Skip header (first line)
        // timestamp,rack_id,module_id,cell_id,voltage,current,temp,soc,soh
        for line in lines.dropFirst() {
            guard !line.isEmpty else { continue }

            let columns = line.components(separatedBy: ",")
            guard columns.count >= 9 else { continue }

            // Parse data
            guard let timestamp = parseDate(columns[0]),
                  let voltage = Double(columns[4]),
                  let current = Double(columns[5]),
                  let temp = Double(columns[6]),
                  let soc = Double(columns[7]),
                  let soh = Double(columns[8]) else {
                continue
            }

            let cellData = CellData(
                timestamp: timestamp,
                rackId: columns[1],
                moduleId: columns[2],
                cellId: columns[3],
                voltage: voltage,
                current: current,
                temp: temp,
                soc: soc,
                soh: soh
            )

            result.append(cellData)
        }

        return result
    }
}
