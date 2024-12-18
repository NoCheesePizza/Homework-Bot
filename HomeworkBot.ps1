# useful Telegram information
$token = "confidential"
$chat_imgg = "confidential"
$chat_george = "confidential"
$chat_coders = "confidential"

# useful files and directories
$sensitive_file = "C:\Users\Scorax\Documents\Totally not an important file.txt" # not included in repo
$scripts_path = "C:\Users\Scorax\Documents\Scripts" 
Set-Location $scripts_path

# todo ------------ log error messages in a specified text file ------------ 

function log {
    param (
        [string] $message, # message to log
        [switch] $exit # whether to exit program
    )
    $date = Get-Date
    $file_path = "C:\Users\Scorax\Documents\What's Due Logs.txt"
    Add-Content -Path $file_path -Value "[$date] $message"
    if ($exit) {
        Add-Content -Path $file_path -Value "[$date] ------------------------`n"
        exit
    } 
}

# todo ------------ search a top secret file for the requested details ------------ 

function get_credentials {
    param (
        [string] $key # which username/password to search for
    )
    return (Get-Content -Path $sensitive_file | Where-Object {$_ -like "$($key):*"}).Substring("$($key):".length + 1)
}

# todo ------------ send a message on Telegram ------------ 

function send_message {
    param (
        [string]$text
    )
    try {
        if ($stream -eq $chat_imgg) {
            $null = Invoke-WebRequest "https://api.telegram.org/bot$token/sendMessage?chat_id=$stream&text=$text&message_thread_id=3" -ErrorAction Stop
        } else {
            $null = Invoke-WebRequest "https://api.telegram.org/bot$token/sendMessage?chat_id=$stream&text=$text" -ErrorAction Stop
        }
    } catch {
        log "Unable to send Telegram message" -exit
    }
}

# todo ------------ ask user for recipient of message ------------

$stream = $null
while (-not($stream -eq "1" -or $stream -eq "2" -or $stream -eq "3")) {
    $stream = Read-Host -Prompt "1: george`n2: imgg`n3: coders`nSend message to" 
}

if ($stream -eq "1") {
    $stream = $chat_george
} elseif ($stream -eq "2") {
    $stream = $chat_imgg
} elseif ($stream -eq "3") {
    $stream = $chat_coders
}

# retrieve my Digipen username and password from the top secret text file
$username = get_credentials "Digipen username"
$password = get_credentials "Digipen password"

# todo ------------ login to Moodle and get the calendar page ------------ 

# send a web request to Moodle's calendar page (any Moodle page will work)
$moodle_link = "https://distance3.sg.digipen.edu/2023sg-spring/calendar/view.php?view=upcoming"
try {
    $session = Invoke-WebRequest -Uri $moodle_link -SessionVariable sbv -ErrorAction Stop
} catch {
    log "Unable to access Moodle" -exit
}

# get current season
$season = $session.Links.href[4]
$moodle_link = "https://distance3.sg.digipen.edu$season/calendar/view.php?view=upcoming"
try {
    $session = Invoke-WebRequest -Uri $moodle_link -SessionVariable sbv -ErrorAction Stop
} catch {
    log "Unable to get correct season" -exit
}
 
# retrieve the form element of the returned web request object and populate it with my Digipen username and password
$form = $session.Forms[0]
$form.Fields["username"] = $username
$form.Fields["password"] = $password

# send a web request to Moodle's login page via $form.Action, now with my login details
$session = Invoke-WebRequest -Uri $form.Action -WebSession $sbv -Method Post -Body $form.Fields -UseBasicParsing

$content = (Invoke-WebRequest -Uri $moodle_link -WebSession $sbv -UseBasicParsing).RawContent

# todo ------------ parse the HTML text for the title and date of upcoming assignments ------------ 

$titles = @()
$dates = @()
$months = @("January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December")

for ($i = 0; ; ++$i) {
    
    # crop the start of $content by 1 character so as to not match the previous "data-event-title="
    $new_content = $content.Substring(1)

    # quit the loop if there is no more "data-event-title=" (the name of the assignment due)
    if ($new_content.IndexOf("data-event-title=") -eq -1) {
        break
    }

    # crop the $content string starting from the assignment name
    $content = $new_content.Substring($new_content.IndexOf("data-event-title="))

    # store a copy of $content that's cropped until "data-event-count=" (the end of the assignment name) in a newly-created element of the array
    $title = $content.Substring(0, $content.IndexOf("data-event-count=")).TrimEnd("`" +") -replace "data-event-title=`""

    if (-not ($title -like "*Attendance*" -or ($title -like "*Quiz*" -and $title -like "*opens*"))) {
        $titles += $title

        $content = $content.Substring($content.IndexOf("<a href="))
        $content = $content.Substring($content.IndexOf(">"))
        
        $dates += $content.Substring(0, $content.IndexOf("</div>")) -replace "</div>", "" -replace "</a>", "" -replace ">", "" -replace "Today", "$([string](Get-Date).DayOfWeek), $($months[$((Get-Date).Month) - 1]) $((Get-Date).day)" -replace "Tomorrow", "$([string]((Get-Date).AddDays(1).DayOfWeek)), $($months[$(((Get-Date).AddDays(1)).Month) - 1]) $(((Get-Date).AddDays(1)).day)" 
    }
}

# todo ------------ convert the array of titles and dates into a more readable format and send the string via Telegram ------------ 

if ($dates.Length) {

    $shortened_dates = @()
    foreach ($date in $dates) {
        $shortened_dates += $date.Substring(0, $date.LastIndexOf(","))
    }
    $shortened_dates = $shortened_dates | Get-Unique
    $shortened_dates = @($shortened_dates) # ensure that $shortened_dates is always an array of strings and not an array of chars (string) even if it has only 1 element

    $message = @()
    for ($i = 0; $i -lt $shortened_dates.Length; ++$i) {
        if ($i -gt 0) {
            $message += "`n"
        }
        $message += $shortened_dates[$i] + "`n------------------------`n"
        for ($j = 0; $j -lt $dates.length; ++$j) {
            if ($dates[$j] -like "*$($shortened_dates[$i])*") {
                    $message += "[" + $dates[$j].Substring($dates[$j].LastIndexOf(",") + 2) + "] " + $titles[$j] + "`n" -replace "&", "and" -replace "amp;", ""
            }
        }
    }
} else {
    $message = "Woohoo no homework due"
}

send_message "Homework report for`n$((Get-Date).ToString("dddd dd/MM/yyyy HH:mm:ss"))"
send_message $message
send_message "Brought to you by GCC-bot"

log "" -exit