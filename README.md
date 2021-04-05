# slack-user-history-test
Aggregate and keep Slack user history for longer than 90 days

Can be compiled into an executable or run as a script with the `swift` command.

    Usage: ./slack-user-history [list of CSV files]
    
    CSV files must start with a header and must contain, at a minimum, the below
    columns, in any order; a user analytics export from Slack with "all columns"
    will work.
    >> Name, User ID, Username, Last active <<
