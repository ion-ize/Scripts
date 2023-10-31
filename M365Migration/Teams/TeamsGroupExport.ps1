# This script creates a CSV file that contains five columns: DisplayName, Members, Owners, Visibility, and Description. 
# The DisplayName column contains the name of the Microsoft Teams group you want to create, the Members column contains a
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

# Get the team information
$teams = get-team

foreach ($team in $teams) {
	# Get the Group's Group Id (use the MailNickname value to avoid issues with sybmols in the team name)
	$GroupId = $team.GroupId

	# Get the members of a team
	$owners = Get-TeamUser -GroupId $GroupId -Role Owner

	# Concatenate the members into one cell separated by commas
	$owners_list = $owners.User -join ','
	
	# Export the list to a CSV file
	#$owners_list | Export-Csv -Path <path_to_csv_file> -NoTypeInformation
		
	# Get the members of a team
	$members = Get-TeamUser -GroupId $GroupId -Role Member

	# Concatenate the members into one cell separated by commas
	$members_list = $members.User -join ','

	# Export the list to a CSV file
	#$members_list | Export-Csv -Path <path_to_csv_file> -NoTypeInformation
}