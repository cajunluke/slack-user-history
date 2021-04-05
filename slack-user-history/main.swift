//
//  main.swift
//  slack-user-history
//
//  Created by Bex Fortin on 2021-04-04.
//  Copyright © 2021 Bex Fortin. All rights reserved.
//

import Foundation

let IMPORTANT_KEYS = ["Name", "User ID", "Last active"]

let dateFormatter = DateFormatter()
dateFormatter.locale = Locale(identifier: "en_US_POSIX")
dateFormatter.dateFormat = "MMM dd, yyyy"

struct User : CustomStringConvertible {
  var name: String
  var userID: String
  var lastActive: Date?
  
  public var description: String {
    var elements = [name, userID]
    
    if let lastActive = self.lastActive {
      elements.append(dateFormatter.string(from: lastActive))
    }
    
    return "[\(elements.joined(separator: " "))]"
  }
}

func parseCSVLine(_ line: String) -> [String] {
  var elements: [String] = []
  
  var isQuoted = false
  var currentElement = ""
  line.forEach { char in
    if !isQuoted && char == "," {
      elements.append(currentElement)
      currentElement = ""
    } else if char == "\"" {
      isQuoted = !isQuoted
    } else {
      currentElement = "\(currentElement)\(char)"
    }
  }
  
  return elements
}

func processFile(_ csv: String) -> [String: User] {
  let lines = csv.split(separator: "\n")
  
  var users: [User] = []
  var columnIndices: Dictionary<String, Int> = [:]
  var firstLine = true
  lines.forEach { (line) in
    let csvLine = parseCSVLine(String(line))
    
    if firstLine {
      IMPORTANT_KEYS.forEach {
        if let index = csvLine.index(of: $0) {
          columnIndices.updateValue(index, forKey: $0)
        }
      }
      
      firstLine = false
    } else {
      var name = ""
      if let index = columnIndices[IMPORTANT_KEYS[0]] {
        name = csvLine[index]
      }
      
      var userID = ""
      if let index = columnIndices[IMPORTANT_KEYS[1]] {
        userID = csvLine[index]
      }
      
      var lastActive:Date?
      if let index = columnIndices[IMPORTANT_KEYS[2]] {
        let lastActiveString = csvLine[index]
        lastActive = dateFormatter.date(from:lastActiveString)
      }
      
      users.append(User(name: name, userID: userID, lastActive: lastActive))
    }
  }
  
  var usersByID:[String: User] = [:]
  users.forEach {
    usersByID.updateValue($0, forKey: $0.userID)
  }
  
  return usersByID
}

var userInfo: [String: User] = [:]
for file in CommandLine.arguments {
  // skip any non-csv arguments, notably index 0
  if !file.hasSuffix(".csv") {
    continue
  }
  
  guard let text = try? String(contentsOfFile: file) else {
    continue
  }
  
  let users = processFile(text)
  userInfo.merge(users) { (current, new) in
    let latest: User, oldest: User
    if current.lastActive != nil && new.lastActive != nil {
      let currentDate = current.lastActive!
      let newDate = new.lastActive!
      if currentDate < newDate {
        latest = new
        oldest = current
      } else {
        latest = current
        oldest = new
      }
    } else if current.lastActive != nil {
      latest = current
      oldest = current
    } else if new.lastActive != nil {
      latest = new
      oldest = new
    } else {
      latest = User(name: "", userID: "", lastActive: nil)
      oldest = latest
    }
    
    
    return User(name: latest.name, userID: oldest.userID, lastActive: oldest.lastActive)
  }
}

func quote(_ value: String) -> String {
  return "\"\(value)\""
}

print(IMPORTANT_KEYS.map(quote).joined(separator: ","))
userInfo.values.forEach {
  var elements = [$0.name, $0.userID]
  
  if let lastActive = $0.lastActive {
    elements.append(dateFormatter.string(from: lastActive))
  } else {
    elements.append("")
  }
  
  if !elements.filter({ element in !element.isEmpty }).isEmpty {
    print(elements.map(quote).joined(separator: ","))
  }
}
