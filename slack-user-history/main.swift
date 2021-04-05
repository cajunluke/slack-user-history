//
//  main.swift
//  slack-user-history
//
//  Created by Bex Fortin on 2021-04-04.
//  Copyright © 2021 Bex Fortin. All rights reserved.
//

import Foundation

let IMPORTANT_KEYS = ["Name", "User ID", "Username", "Last active"]

if CommandLine.argc == 1 {
  let usage = """
  Usage: \(CommandLine.arguments[0]) [list of CSV files]
  
  CSV files must start with a header and must contain, at a minimum, the below
  columns, in any order; a user analytics export from Slack with "all columns"
  will work.
  >> \(IMPORTANT_KEYS.joined(separator: ", ")) <<
  """
  print(usage)
  
  exit(-1)
}

// this formatter is used for parsing and rendering
let dateFormatter = DateFormatter()
dateFormatter.locale = Locale(identifier: "en_US_POSIX")
// Slack's analytics seem to use this date format always
dateFormatter.dateFormat = "MMM dd, yyyy"

struct User {
  var name: String
  var userID: String
  var username: String
  var lastActive: Date?
}

// given a non-terminated comma-separated line, split it into elements
// respect quotes
// FIXME: do csvs allow escaping quotes?
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
  
  elements.append(currentElement)
  
  return elements
}

// parse the file contents into User objects
// return the User objects collated by user id so Dictionary#merge works to combine values
func processFile(_ csv: String) -> [String: User] {
  // assume unix files
  let lines = csv.split(separator: "\n")
  
  // all the user objects
  var users: [User] = []
  // actual indices of our desired columns can change in each file; find today's columns
  var columnIndices: Dictionary<String, Int> = [:]
  var firstLine = true
  lines.forEach { (line) in
    let csvLine = parseCSVLine(String(line))
    
    if firstLine {
      // first line is the header - populate our index map
      // (if this isn't a header, it's a malformed file)
      IMPORTANT_KEYS.forEach {
        if let index = csvLine.index(of: $0) {
          columnIndices.updateValue(index, forKey: $0)
        }
      }
      
      firstLine = false
    } else {
      // for data rows, gather all the interesting data points
      var name = ""
      if let index = columnIndices[IMPORTANT_KEYS[0]] {
        name = csvLine[index]
      }
      
      var userID = ""
      if let index = columnIndices[IMPORTANT_KEYS[1]] {
        userID = csvLine[index]
      }
      
      var username = ""
      if let index = columnIndices[IMPORTANT_KEYS[2]] {
        username = csvLine[index]
      }
      
      var lastActive:Date?
      if let index = columnIndices[IMPORTANT_KEYS[3]] {
        let lastActiveString = csvLine[index]
        lastActive = dateFormatter.date(from:lastActiveString)
      }
      
      // and stuff into a struct in the list
      users.append(User(name: name, userID: userID, username: username, lastActive: lastActive))
    }
  }
  
  // collate the user objects by id
  var usersByID:[String: User] = [:]
  users.forEach {
    usersByID.updateValue($0, forKey: $0.userID)
  }
  
  return usersByID
}

// this is the aggregate latest-updated user info
var userInfo: [String: User] = [:]

for file in CommandLine.arguments {
  // skip any non-csv arguments, notably index 0
  if !file.hasSuffix(".csv") {
    continue
  }
  
  // dump the file into memory
  // we could stream it but that's hard and these files aren't *that* big
  guard let text = try? String(contentsOfFile: file) else {
    // if we couldn't read a file, yell at the user and continue
    NSLog("Error reading contents of file \"\(file)\"")
    continue
  }
  
  let users = processFile(text)
  // merge this data into the aggregate
  userInfo.merge(users) { (current, new) in
    let latest: User
    if current.lastActive != nil && new.lastActive != nil {
      // if we have multiple dates, take the most recent one
      let currentDate = current.lastActive!
      let newDate = new.lastActive!
      
      latest = newDate > currentDate ? new : current
    } else if current.lastActive != nil {
      // if only the extant entry has a date, use it
      latest = current
    } else {
      // otherwise, use the new entry
      latest = new
    }
    
    return User(name: latest.name, userID: latest.userID, username: latest.username, lastActive: latest.lastActive)
  }
}

// I wish I didn't have to write this exact function in every environment
func quote(_ value: String) -> String {
  return "\"\(value)\""
}

// print the header to stdout
print(IMPORTANT_KEYS.map(quote).joined(separator: ","))
// and then print the data rows
// TODO: sort the rows so the file's vaguely readable without Excel
userInfo.values.forEach {
  var elements = [$0.name, $0.userID, $0.username]
  
  if let lastActive = $0.lastActive {
    elements.append(dateFormatter.string(from: lastActive))
  } else {
    elements.append("")
  }
  
  if !elements.filter({ element in !element.isEmpty }).isEmpty {
    print(elements.map(quote).joined(separator: ","))
  }
}
