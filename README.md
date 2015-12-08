# ios-database-helper
Objective C class that eases working with databases

# Usage

Implemented from: http://www.appcoda.com/sqlite-database-ios-app-tutorial/

Added transactions

    [db beginTransaction];
    @try {
      //make changes
      [db commitTransaction];
    } @catch (NSException* e) {
      [db rollbackTransaction];
    }

