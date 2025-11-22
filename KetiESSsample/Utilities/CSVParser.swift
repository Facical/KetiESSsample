// KetiESSsample/Utilities/CSVParser.swift

import Foundation

struct CSVParser {
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()

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
            guard let timestamp = dateFormatter.date(from: columns[0]),
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
            guard let timestamp = dateFormatter.date(from: columns[0]),
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
}
