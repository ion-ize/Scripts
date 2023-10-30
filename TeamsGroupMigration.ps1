# This script reads a CSV file that contains five columns: GroupName, Members, Owners, Visibility, and Description. 
# The GroupName column contains the name of the Microsoft Teams group you want to create, the Members column contains a
# comma-separated list of members you want to add to that group (ex: "user1@domain.com,user2@domain.com"), the Owners column 
# contains a comma-separated list of owners you want to add to that group, the Visibility column contains the visibility of 
# the group (e.g. Public, Private, etc.), and the Description column contains a brief description of the group. The script 
# creates the group, looks up the group by Mailnickname, retrieves its ID, and adds members and owners as specified in the CSV file.
# Make sure all Owners and Users listed exist in the target tenant before using this script.

# Set the teams environment and connect
$TeamsEnvironment = Read-Host -Prompt "1 - Commercial
2 - GCC High
3 - DoD
Tenant type?"
$MigrationUser = Read-Host -Prompt "Username"
if ($TeamsEnvironment -eq 1) {
	Connect-MicrosoftTeams
} elseif ($TeamsEnvironment -eq 2) {
	Connect-MicrosoftTeams -TeamsEnvironmentName TeamsGCCH
} elseif ($TeamsEnvironment -eq 3) {
	Connect-MicrosoftTeams -TeamsEnvironmentName TeamsDOD
} else {
	Connect-MicrosoftTeams
}
# Determine if they user wants to remove their user from the groups
$RemoveUser = Read-Host -Prompt "Do you want to remove your user from these groups after creating them? 
(By default when creating a team in powershell it will add your logged in user to the group as an owner and member.)
Answer (Y/N)"

# Import the CSV file
$csvPath = Read-Host -Prompt "Enter CSV path"
$csv = Import-Csv -Path $csvPath

# Loop through each row in the CSV file
foreach ($row in $csv) {
    # Create the Group
    New-Team -DisplayName $row.GroupName -MailNickname $row.MailNickname -Visibility $row.Visibility -Description $row.Description
	
	# Get the new Group's Group Id (use the MailNickname value to avoid issues with sybmols in the team name)
	$group = Get-Team -MailNickname $row.MailNickname
    $GroupId = $group.GroupId

    # Add the owners to the group
    $owners = $row.Owners.Split(",")
    foreach ($owner in $owners) {
        Add-TeamUser -GroupId $GroupId -User $owner -Role Owner
    }

    # Add the members to the group
    $members = $row.Members.Split(",")
    foreach ($member in $members) {
        Add-TeamUser -GroupId $GroupId -User $member
    }
	
    if ($RemoveUser -eq "Y" -or "y") {
		# Remove the migration user from the group
		Remove-TeamUser -GroupId $GroupId -User $MigrationUser
	} 
}