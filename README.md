🖥️ Server Monitor (Bash)

Lightweight server monitoring tool built in Bash that generates automated HTML dashboards and JSON reports, including alert detection, Git integration, and cron automation.

🚀 Features

Collects:

Hostname, user, date, uptime

CPU usage

Memory usage

Root disk usage

Lists:

Top 10 largest files

Top 10 CPU-consuming processes

⚠️ Alert when disk usage exceeds 80%

📊 Generates:

HTML dashboard report

JSON structured output

🔄 Automatically deletes reports older than 30 days

🔐 Automatic Git commit & push via SSH

⏰ Designed to run every 2 hours using cron

📂 Project Structure
```
server_monitor/
├── monitor.sh
├── reports/
│   ├── html/
│   └── json/
├── logs/
└── README.md
```

⚙️ Requirements

Linux / WSL (Ubuntu recommended)
* Bash
* Git
* SSH configured for GitHub
* (Optional) jq

Install dependencies (Ubuntu):
```
sudo apt update
sudo apt install git jq -y
```
▶️ Usage

Make the script executable:
```
chmod +x monitor.sh
```

Run manually:
```
./monitor.sh
```

Reports will be generated inside:
```
reports/html/
reports/json/
```
⏰ Cron Automation (Every 2 Hours)

Edit crontab:
```
crontab -e
```

Add:
```
0 */2 * * * /full/path/to/monitor.sh >> /full/path/to/logs/cron.log 2>&1
```
🔐 Git Integration

The script automatically:
* Adds generated reports
* Commits with dynamic message
* Pushes to GitHub using SSH

Example remote:
```
git@github.com:Rivan17RS/server_monitor.git
```
🛡️ Alert Logic

If root partition usage exceeds 80%, the system:
* Displays alert in HTML
* Logs the event
* Includes alert in JSON output
