Linux_SSH_IPS
-------------

A Linux SSH intrusion prevention system (IPS)

Requirements are as follows:

  > Design, implement and test an application that will monitor the /var/log/secure file and
    detect password guessing attempts and then use iptables to block that IP.

  > Your application will get user specified parameters and then continuously
    monitor the log file specified.

  > As soon as the monitor detects that the number of attempts from a particular IP has gone
    over a user-specified threshold, it will generate a rule to block that IP.

  > If the user has specified a time limit for a block, your application will flush the rule from
    Firewall rule set upon expiration of the block time limit.

  > User specified parameters:
    - The number of attempts before blocking the IP
    - The time limit for blocking the IP. The default setting will be block indefinitely
    - Monitor a log file of user’s choice (Optional - bonus). Keep in mind that different log files have different formats

  > The application will be activated through the use of crontab 
