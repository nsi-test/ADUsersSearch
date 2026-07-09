Class ADSearchForm : System.Windows.Forms.Form {

	[System.Object[]] $labels

	[Hashtable] $textBoxes

	[System.Windows.Forms.Button] $btnSearch

	[System.Windows.Forms.Button] $btnClear

	[System.Windows.Forms.Button] $btnExportCsv

	[System.Windows.Forms.DataGridView] $dataGrid

	[System.Windows.Forms.ContextMenuStrip] $dataGridContextMenu

	[System.Windows.Forms.ToolStripMenuItem] $copyMenuItem

	[System.Windows.Forms.StatusStrip] $statusStrip

	[System.Windows.Forms.ToolStripStatusLabel] $labelLeft

	[System.Windows.Forms.ToolStripStatusLabel] $labelSave

	[System.Windows.Forms.ToolStripStatusLabel] $labelRight

	[System.Windows.Forms.CheckBox] $HideDisabledChBox #for allow/disallow disabled users in search results

	[System.Windows.Forms.CheckBox]	$IncludeMailObjectsChBox #for allow/disallow groups/contacts with emails in results

	[System.Drawing.Font] $strikeFont

	[string] $LastSortColumn = "Display Name"

	[System.ComponentModel.ListSortDirection] $LastSortDirection = [System.ComponentModel.ListSortDirection]::Ascending

	[System.DirectoryServices.DirectorySearcher] $ADSearcher


	[string] $DomainSearchBase

	[string[]] $AllowedSearchBases

	[bool] $IncludeMailObjects = $false

	[bool] $UserIsDomainAdmin

	ADSearchForm() {

		$thisForm = $this #for event handlers

		#icon
		$this.Icon = $this.LoadIcon({ GetIconB64 })
		#/icon

		$this.LoadConfiguration(".\ADUsersSearchConf.xml")

		$this.Text = "Active Directory Users Search v$global:ADUSVersion"
		$this.Text += " (running as: $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name))"
		$this.Size = [System.Drawing.Size]::New(1400, 700) #plus e-mail tbox (20); plus phone2 tbox (20); W beshe 940; W beshe 1200
		#last W:1000;H:640
		$this.StartPosition = "CenterScreen"

		$panelTop = [System.Windows.Forms.Panel]::New()
		$panelTop.Dock = [System.Windows.Forms.DockStyle]::Top
		$panelTop.Height = 320 #tested (after memcer of groups); phone 2 (+30); dname (+40)

		# --- Labels and TextBoxes ---
		$this.labels = @("First Name", "Last Name", "Display Name", "Description", "Office", "Phone", "Phone2", "E-mail", "UserName", "Contained in/under OU")
		$this.textBoxes = @{}

		for ($i = 0; $i -lt $this.labels.Count; $i++) {
			$label = [System.Windows.Forms.Label]::New()
			$label.Text = $this.labels[$i]
			$label.Location = [System.Drawing.Point]::new(10, 20 + ($i * 30))
			$label.AutoSize = $true
			#$this.Controls.Add($label)
			$panelTop.Controls.Add($label)

			$tb = [System.Windows.Forms.TextBox]::New()
			$tb.Location = [System.Drawing.Point]::new(150, 20 + ($i * 30))
			$tb.Width = 200
			#$this.Controls.Add($tb)
			$panelTop.Controls.Add($tb)
			$this.textBoxes[$this.labels[$i]] = $tb
		} # for i=0 to labels.Count

		$phoneDescriptionLabel = [System.Windows.Forms.Label]::New()
		$phoneDescriptionLabel.Text = "Phone (use * as wildcard, ? as single character)"
		$phoneDescriptionLabel.Location = [System.Drawing.Point]::new(375, 175) #plus dname - +H30
		$phoneDescriptionLabel.AutoSize = $true
		$panelTop.Controls.Add($phoneDescriptionLabel)

		$phone2DescriptionLabel = [System.Windows.Forms.Label]::New()
		$phone2DescriptionLabel.Text = "Phone2 (use * as wildcard, ? as single character)"
		$phone2DescriptionLabel.Location = [System.Drawing.Point]::new(375, 205) #plus dname - +H30
		$phone2DescriptionLabel.AutoSize = $true
		$panelTop.Controls.Add($phone2DescriptionLabel)

		# --- Search Button ---
		$this.btnSearch = [System.Windows.Forms.Button]::New()
		$this.btnSearch.Text = "Search"
		$this.btnSearch.Location = [System.Drawing.Point]::new(400, 20)
		$this.btnSearch.Width = 100
		#$this.Controls.Add($this.btnSearch)
		$panelTop.Controls.Add($this.btnSearch)

		# --- Clear Button --- #m
		$this.btnClear = [System.Windows.Forms.Button]::New()
		$this.btnClear.Text = "Clear"
		$this.btnClear.Location = [System.Drawing.Point]::new(400, 60)
		$this.btnClear.Width = 100
		#$this.Controls.Add($this.btnClear)
		$panelTop.Controls.Add($this.btnClear)

		# --- Export Button ---
		$this.btnExportCsv = [System.Windows.Forms.Button]::New()
		$this.btnExportCsv.Text = "Export CSV"
		$this.btnExportCsv.Location = [System.Drawing.Point]::new(650, 10)
		$this.btnExportCsv.Width = 100
		$panelTop.Controls.Add($this.btnExportCsv)


		# --- DataGridView ---
		$this.dataGrid = [System.Windows.Forms.DataGridView]::New()
		$this.dataGrid.Dock = [System.Windows.Forms.DockStyle]::Fill
		$this.dataGrid.Location = [System.Drawing.Point]::new(10, 260) #plus e-mail tbox; plus phone2 tbox; plus dname tbox
		$this.dataGrid.Size = [System.Drawing.Size]::New(900, 320)
		$this.dataGrid.AutoSizeColumnsMode = 'Fill'
		$this.dataGrid.ReadOnly = $true
		$this.dataGrid.AllowUserToAddRows = $false
		$this.dataGrid.AllowUserToDeleteRows = $false
		$this.dataGrid.SelectionMode =
		    [System.Windows.Forms.DataGridViewSelectionMode]::CellSelect
		#$this.dataGrid.SelectionMode = 'FullRowSelect'		
		$this.dataGrid.MultiSelect = $true
		$this.dataGrid.ClipboardCopyMode =
			[System.Windows.Forms.DataGridViewClipboardCopyMode]::EnableWithoutHeaderText

		# Context menu for DataGridView
		$this.dataGridContextMenu = [System.Windows.Forms.ContextMenuStrip]::New()
		$this.copyMenuItem = [System.Windows.Forms.ToolStripMenuItem]::New()
		$this.copyMenuItem.Text = "Copy"
		$this.copyMenuItem.Add_Click({
				$dataObj = $thisForm.dataGrid.GetClipboardContent()
				if ($null -ne $dataObj) {
					[System.Windows.Forms.Clipboard]::SetDataObject($dataObj)
				}
		}.GetNewClosure())

		[void]$this.dataGridContextMenu.Items.Add($this.copyMenuItem)
		$this.dataGrid.ContextMenuStrip = $this.dataGridContextMenu

		$this.Controls.Add($this.dataGrid)

		$this.Controls.Add($panelTop) # Then Top panel with  after DataGrid to be on top

		# -- ADSearcher
		$this.ADSearcher = [System.DirectoryServices.DirectorySearcher]::New()
		$this.ADSearcher.PropertiesToLoad.Add("givenname")
		$this.ADSearcher.PropertiesToLoad.Add("sn")
		$this.ADSearcher.PropertiesToLoad.Add("description")
		$this.ADSearcher.PropertiesToLoad.Add("telephoneNumber")
		$this.ADSearcher.PropertiesToLoad.Add("othertelephone")
		$this.ADSearcher.PropertiesToLoad.Add("physicaldeliveryofficeName")
		$this.ADSearcher.PropertiesToLoad.Add("mail")
		$this.ADSearcher.PropertiesToLoad.Add("samaccountName")
		$this.ADSearcher.PropertiesToLoad.Add("distinguishedname")
		$this.ADSearcher.PropertiesToLoad.Add("useraccountcontrol")
		$this.ADSearcher.PropertiesToLoad.Add("memberof")
		$this.ADSearcher.PropertiesToLoad.Add("title")
		$this.ADSearcher.PropertiesToLoad.Add("objectclass")
		$this.ADSearcher.PropertiesToLoad.Add("displayname")

		$this.ADSearcher.PageSize = 1000

		#admin check
		$this.UserIsDomainAdmin = $false
		$this.UserisDomainAdmin = $this.IsCurrentUserDomainAdmin()
		Write-Host "current user domainadmin is: $($this.UserIsDomainAdmin) `r`n"

		# --- StatusStrip (bottom band) ---
		$this.statusStrip = [System.Windows.Forms.StatusStrip]::new()
		$this.statusStrip.Dock = [System.Windows.Forms.DockStyle]::Bottom
		
		# --- Status label ---
		$this.labelLeft = [System.Windows.Forms.ToolStripStatusLabel]::new()
		$this.labelLeft.Text = "Ready"
		$this.labelLeft.Spring = $false
		$this.labelLeft.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft

		$this.labelSave  = [System.Windows.Forms.ToolStripStatusLabel]::new()
		#$this.labelSave  = "Save..."
		$this.labelSave.Spring = $true
		$this.labelSave.TextAlign  = [System.Drawing.ContentAlignment]::MiddleLeft
		$this.labelSave.ForeColor = [System.Drawing.Color]::DarkGreen

		$this.labelRight = [System.Windows.Forms.ToolStripStatusLabel]::new()
		$this.labelRight.Spring = $false
		$this.labelRight.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
		$this.labelRight.Text = "Last updated: $(Get-Date)"


		# Add label to strip
		$this.statusStrip.Items.Add($this.labelLeft)
		$this.statusStrip.Items.Add($this.labelSave)
		$this.statusStrip.Items.Add($this.labelRight)

		#add statusstrip to form (ORDER MATTERS)
		$this.Controls.Add($this.statusStrip)   # Bottom

		# Strikeout font for disabled users
		$this.strikeFont = [System.Drawing.Font]::New($this.Font, [System.Drawing.FontStyle]::Strikeout)


		$this.AcceptButton = $this.btnSearch
		
		$this.CancelButton = $this.btnClear

		$this.btnSearch.Add_Click({ $thisForm.SearchClick() }.getNewClosure())

		$this.btnClear.Add_Click({ $thisForm.ClearClick() }.getNewClosure())

		$this.btnExportCsv.Add_Click({$thisForm.ExportDataGridToCsv()}.GetNewClosure())

		$this.dataGrid.Add_CellFormatting({ $thisForm.CellFormattingChanged($thisForm.DataGrid, $_) }.GetNewClosure())

		#hide disabled chbox
		$this.HideDisabledChBox = [System.Windows.Forms.CheckBox]::New()
		$this.HideDisabledChBox.Text = "Hide disabled users"
		$this.HideDisabledChBox.Location = [System.Drawing.Point]::new(400, 100)
		$this.HideDisabledChBox.AutoSize = $true
		If ($this.UserIsDomainAdmin) { $panelTop.Controls.Add($this.HideDisabledChBox) }
	
		$this.HideDisabledChBox.Add_CheckedChanged({ $thisForm.HideDisabledChBoxChanged($thisForm.HideDisabledChBox, $_) }.GetNewClosure())

		#groups/contacts with email
		$this.IncludeMailObjectsChBox = [System.Windows.Forms.CheckBox]::New()
		$this.IncludeMailObjectsChBox.Text = "Include groups/contacts with e-mail"
		$this.IncludeMailObjectsChBox.Location = [System.Drawing.Point]::new(550, 100) #I think 550 is ok
		$this.IncludeMailObjectsChBox.Checked = $false
		$this.IncludeMailObjectsChBox.AutoSize = $true
		$panelTop.Controls.Add($this.IncludeMailObjectsChBox)

		$this.IncludeMailObjectsChBox.Add_CheckedChanged({ $thisForm.IncludeMailObjectsChBoxChanged($thisForm.IncludeMailObjectsChBox, $_) }.GetNewClosure()) #mind it to change


		$this.dataGrid.Add_DataBindingComplete({
   			$thisForm.DataGrid_DataBindingComplete($this, $_)
		}.GetNewClosure())

		$this.dataGrid.Add_CellContentClick({
    		$thisForm.DataGrid_CellContentClick($this, $_)
		}.GetNewClosure())

		$this.Add_Shown({
    		$thisForm.WindowState = [System.Windows.Forms.FormWindowState]::Normal
    		$thisForm.Show()
    		$thisForm.Activate()
    		$thisForm.BringToFront()
    		$thisForm.TopMost = $true
    		$thisForm.TopMost = $false

			 $thisForm.textBoxes["First Name"].Focus() 
			}.GetNewClosure())

	} #constructor

	#returns the icon from the icon func, imported from IconB64.psm1 along other modules
	[System.Drawing.Icon] LoadIcon($GetB64) {
		Write-Verbose "$(date) LoadIcon function started"
		#Write-Verbose $(&$GetB64) #an old check
		return [System.Drawing.Icon][IO.MemoryStream][Convert]::FromBase64String($(&$GetB64))
	}

	[void] LoadConfiguration([string] $ConfigFile) {
		[xml]$Config = Get-Content $ConfigFile

		$this.DomainSearchBase =
			$Config.Configuration.DomainSearchBases.Root.distinguishedName

		$this.AllowedSearchBases = @()

		foreach ($OU in $Config.Configuration.DomainSearchBases.OU) {
			$this.AllowedSearchBases += $OU.distinguishedName
		}
	}


	[void] CellFormattingChanged(
		[object] $sender,
		[System.Windows.Forms.DataGridViewCellFormattingEventArgs] $e) {

		$grid = $sender
		$dgvrow = $grid.Rows[$e.RowIndex]

		if ($dgvrow.DataBoundItem -eq $null) { return }

		$dgvitem = $dgvrow.DataBoundItem

		# adjust property name to your data
		if ($dgvitem.Enabled -eq $false) {
			# Skip the "Enabled" column
			$colName = $grid.Columns[$e.ColumnIndex].Name
			if ($colName -ne "Enabled") {
				$e.CellStyle.Font = $this.strikeFont
				$e.CellStyle.ForeColor = [System.Drawing.Color]::Red
			} #colName -ne Enabled
		} #dgvitem enabled check
	} # CellFormattingChanged function

	[void] HideDisabledChBoxChanged([System.Windows.Forms.CheckBox] $sender, [System.EventArgs] $e) {
		$this.SearchClick() #just re-run search to apply/hide disabled users in results
	}	

	[void] IncludeMailObjectsChBoxChanged([System.Windows.Forms.CheckBox] $sender, [System.EventArgs] $e) {
		$this.IncludeMailObjects = $this.IncludeMailObjectsChBox.Checked
		$this.SearchClick() #and re-run search to apply/hide disabled users in results
	}

	[string] GetUserBaseFilter() {
		return "(&(objectCategory=person)(objectClass=user))"
	}

	[string] GetUserWithContactInfoBaseFilter() {
    	return "(&(|(mail=*)(telephoneNumber=*)(otherTelephone=*))(objectCategory=person)(objectClass=user))"
	}

	[string] GetMailObjectBaseFilter() {
		return "(&(mail=*)(|(objectClass=group)(objectClass=contact)))"
	}


	[hashtable] BuildLDAPFilter([string] $BaseFilter) {

		$filterParts = @()

		if ($this.textBoxes["First Name"].Text) {
			$filterParts += "(givenName=*$($this.textBoxes['First Name'].Text)*)"
		}

		if ($this.textBoxes["Last Name"].Text) {
			$filterParts += "(sn=*$($this.textBoxes['Last Name'].Text)*)"
		}

		if ($this.textBoxes["Display Name"].Text) {
			$filterParts += "(displayname=*$($this.textBoxes['Display Name'].Text)*)"
		}

		if ($this.textBoxes["Description"].Text) {
			$filterParts += "(description=*$($this.textBoxes['Description'].Text)*)"
		}

		if ($this.textBoxes["Office"].Text) {
			$filterParts += "(physicaldeliveryOfficeName=*$($this.textBoxes['Office'].Text)*)"
		}

		if ($this.textBoxes["E-mail"].Text) {
			$filterParts += "(mail=*$($this.textBoxes['E-mail'].Text)*)"
		}

		if ($this.textBoxes["UserName"].Text) {
			$filterParts += "(samaccountName=*$($this.textBoxes['UserName'].Text)*)"
		}

		#phone
		if ($this.textBoxes["Phone"].Text) {

			$PhoneSearchStr = "*$($this.textBoxes["Phone"].Text)" #human input for the end of string

			Write-Host "PhoneSearchStr: $($PhoneSearchStr)"

			$PhoneFilterPart = $this.textBoxes["Phone"].Text.Replace('?', '*') #substitute '?' with '*' for filter part, because AD filter does not support '?'

			Write-Host "PhoneFilterPart: $($PhoneFilterPart)"

			$filterParts += "(telephonenumber=*$PhoneFilterPart*)"
		}
		else {

			$PhoneSearchStr = '*' #everything

			Write-Host "PhoneSearchStr: $($PhoneSearchStr)"

		}
		#/phone

		#phone2
		if ($this.textBoxes["Phone2"].Text) {

			$Phone2SearchStr = "*$($this.textBoxes["Phone2"].Text)" #human input for the end of string

			Write-Host "Phone2SearchStr: $($Phone2SearchStr)"

			$Phone2FilterPart = $this.textBoxes["Phone2"].Text.Replace('?', '*') #substitute '?' with '*' for filter part, because AD filter does not support '?'

			Write-Host "Phone2FilterPart: $($Phone2FilterPart)"

			$filterParts += "(othertelephone=*$Phone2FilterPart*)"
		}
		else {

			$Phone2SearchStr = '*' #everything

			Write-Host "Phone2SearchStr: $($Phone2SearchStr)"

		}
		#/phone2

		#in/under OU
		if ($this.textBoxes["Contained in/under OU"].Text) {
			$ouFilter = "*OU=$($this.textBoxes["Contained in/under OU"].Text),*" #the coma is limitinq the specific OU
			# We will filter by OU after getting results, because AD filter does not support distinguishedname directly by wildcard, etc. (!)
			$filterParts += "(distinguishedname=*)" #we need to get all users and then filter by OU in Where-Object
		}
		else {
			$ouFilter = '*' #everything
		}
		#/in/under OU


		$filter = "(&$($BaseFilter)$($filterParts -join ''))"


		$LDAPFIlterparts = @{}

		$LDAPFIlterparts['mainfilter'] = $filter

		$LDAPFIlterparts['PhoneSearchStr'] = $PhoneSearchStr

		$LDAPFIlterparts['ouFilter'] = $ouFilter

		$LDAPFIlterparts['Phone2SearchStr'] = $Phone2SearchStr

		Return $LDAPFIlterparts
	}

	#helper for creating different searchers
	[System.DirectoryServices.DirectorySearcher] CreateSearcher(
		[string] $baseDn,
		[string] $filter
	) {
		$root = [System.DirectoryServices.DirectoryEntry]::new("LDAP://$baseDn")

		$searcher = [System.DirectoryServices.DirectorySearcher]::new($root)
		$searcher.Filter = $filter
		$searcher.SearchScope = [System.DirectoryServices.SearchScope]::Subtree
		$searcher.PageSize = 1000

		foreach ($prop in $this.ADPropertiesToLoad) {
			$null = $searcher.PropertiesToLoad.Add($prop)
		}

		return $searcher
	}


	[object[]] FindADUsers() {

		Write-Host "Start of FindADUsers ..."

		$allResults = @()

		$userFilter = $this.BuildLDAPFilter($this.GetUserBaseFilter())['mainfilter'] #new

		Write-Host "in FindADUsers,  userFilter is: $($userFilter)"

		$mailFilter = $this.BuildLDAPFilter($this.GetMailObjectBaseFilter())['mainfilter'] #new

		Write-Host "in FindADUsers, mailFilter is: $($mailFilter)"

		# Domain admin: normal whole-domain search (two parts)
		if ($this.UserIsDomainAdmin) {
			$this.ADSearcher.Filter = $userFilter
			$allResults += $this.ADSearcher.FindAll()

			Write-Host "in FindADUsers, if domainadmin, user results count is $($allResults.count)"

			if ($this.IncludeMailObjects) {

				$mailSearcher = $this.CreateSearcher($this.DomainSearchBase, $mailFilter)

				$allResults += $mailSearcher.FindAll()

				Write-Host "in FindADUsers, if domainadmin, user results, plus incl mailobjects, count is $($allResults.count)"
			}

			return $allResults
		}

		# Ordinary user: filter for users with mail, phone, or otherphone
		$userFilter = $this.BuildLDAPFilter($this.GetUserWithContactInfoBaseFilter())['mainfilter']

		Write-Host "user filter for ordinary users naow is: $($userFilter)"

		# Ordinary user: search allowed OUs only
		foreach ($baseDn in $this.AllowedSearchBases) {

			$searcher = $this.CreateSearcher($baseDn, $userFilter)

			Write-host "in FindADUsers, foreach basedn, created a temp searcher for users"
			Write-Host "in FindADUsers, foreach basedn, the searcher's alowed searchbase is $($baseDn)"

			$allResults += $searcher.FindAll()

			Write-Host "allResults count is now $($allResults.count)"
			
		} # foreach basedn

		# Optional extra search: mail-enabled groups/contacts in whole AD
		if ($this.IncludeMailObjects) {

			Write-Host "In Find ADUsers , in if IncludeMailObjects , mailFilter is: $($mailFilter)"

			$mailSearcher = $this.CreateSearcher($this.DomainSearchBase, $mailFilter)

			Write-Host "mail filter in users mail/contact search is: $($mailFilter)"
			Write-Host "domain serach base for users mail/contact search is: $($this.DomainSearchBase)"

			$allResults += $mailSearcher.FindAll()
		}
		Write-Host "after optional extra search - all results count is: $($allResults.count)"

		return $allResults
	} #FindADUsers()


	[Object[]] GetADUsers() {
		
		Write-Host "start of GetADUsers..."

		try {
			# Build dynamic filter (AND logic)


			# Query AD
			$LDAPFilterResults = $this.BuildLDAPFIlter($this.GetUserBaseFilter()) #I think it's ok

			Write-Host "main LDAP filter before query: $($LDAPFilterResults['mainfilter'])"
		
			#when user enters nothing (?)
			<#If ($LDAPFilterResults['mainfilter'] -eq "(&(objectCategory=person)(objectClass=user))") {
				#[System.Windows.Forms.MessageBox]::Show("Please enter at least one search criteria.")
				$this.labelLeft.ForeColor = [System.Drawing.Color]::Red
				$this.labelLeft.Text = "Please enter at least one search criteria."
				return @()
			}#>

			Write-Host "phonesearchstr before query: $($LDAPFilterResults['PhoneSearchStr'])"

			Write-Host "ouFilter before query: $($LDAPFilterResults['ouFilter'])"

			Write-Host "phone2searchstr before query: $($LDAPFilterResults['Phone2SearchStr'])"
			
			$results = $this.FindADUsers()

			Write-Host "in GetADUsers, after calling FindADUsers, results count is $($results.count)"

			$results = $results.properties | 
			Where-Object {

				$phoneMatch = $_.telephonenumber -like $LDAPFilterResults['PhoneSearchStr']

    			$ouMatch = $_.distinguishedname -like $LDAPFilterResults['ouFilter']

    			$phone2Match =	$_.othertelephone -like $LDAPFilterResults['Phone2SearchStr']

    			$enabledMatch = $true

    			if ($this.HideDisabledChBox.Checked) {

					$isUser = $_.objectclass -contains 'user'

					if ($isUser) {
						if ($_.useraccountcontrol.Count -gt 0) {
							$enabledMatch = -not ([int]$_.useraccountcontrol[0] -band 2)
						}
						else {
							# user but cannot read userAccountControl -> safest is hide
							$enabledMatch = $false
						}
					}
					else {
						# groups/contacts do not have userAccountControl -> do not filter them out
						$enabledMatch = $true
					}
    			} #if hidechbox.checked

    			$phoneMatch -and $ouMatch -and $phone2Match -and $enabledMatch

			} #where object


			#Write-host "Results:`n$($results | Out-String)"


			# Prepare output

			$selectProperties = @(
				@{Name = "UserName"; Expression = { $_.samaccountname } }
			)
		
			if ($this.UserIsDomainAdmin) {
				$selectProperties += @{Name = "Enabled"; Expression = { if (-not ([int]$_.useraccountcontrol[0] -band 2)) { $true } else { $false } } }
			}

			$selectProperties += @(
				@{Name = "Display Name"; Expression = { $_.displayname } }
				@{Name = "GivenName"; Expression = { $_.givenname } }
				@{Name = "Surname"; Expression = { $_.sn } }
				@{Name = "Job Title"; Expression = { $_.title } }
				@{Name = "Description" ; Expression = { $_.description } }
				@{Name = "Office"; Expression = { $_.physicaldeliveryofficename } }
				@{Name = "E-Mail"; Expression = { $_.mail } }
				@{Name = "Phone"; Expression = { $_.telephonenumber } }
				@{Name = "Phone2"; Expression = { $_.othertelephone[0] } }
				@{Name = "Org. Unit"; Expression = { [regex]::Match($_.distinguishedname[0], '^CN=[^,]+,OU=([^,]+)').Groups[1].Value } }
				@{Name = "ObjectClass"; Expression = {
						$item = $_
						switch ($true) {
							{ $item.objectclass -contains 'user' } { 'user'; break }
							{ $item.objectclass -contains 'contact' } { 'contact'; break }
							{ $item.objectclass -contains 'group' } { 'group'; break }
							default { 'unknown' }
						} #switch
					} #Expression
				} #Name
			)
			#no comas because of the newline

			$output = $results | Select-Object $selectProperties

			#Write-Host "Output: $($output | out-string)"

			Write-Host "phonesearchstr after query: $($LDAPFilterResults['PhoneSearchStr'])"

			Write-Host "ouFilter after query: $($LDAPFilterResults['ouFilter'])"

			Write-Host "phone2searchstr after query: $($LDAPFilterResults['Phone2SearchStr'])"

			Write-Host "main LDAP filter after query (clarity): $($LDAPFilterResults['mainfilter'])"
			
			return $output

		} #try
		catch {
			[System.Windows.Forms.MessageBox]::Show("Datagrid Error: $_")
			$this.labelLeft.ForeColor = [System.Drawing.Color]::Red
			$this.labelLeft.Text = "Error occurred while searching."
			return @()
		}

		return @() #default empty array if error or no criteria

	} # GetADUsers function



	[void] SearchClick() {
		$this.labelSave.Text = ""
		$this.labelLeft.ForeColor = [System.Drawing.Color]::Black #in the beginning of search, color is always black
		$this.labelLeft.Text = "working..."
		$this.statusStrip.Refresh()
		#start-sleep -seconds 5 #simulate work to check status label color

		if ($this.dataGrid.SortedColumn) {
			$this.LastSortColumn = $this.dataGrid.SortedColumn.Name

			$this.LastSortDirection = if (
				$this.dataGrid.SortOrder -eq [System.Windows.Forms.SortOrder]::Descending
			) {
				[System.ComponentModel.ListSortDirection]::Descending
			}
			else {
				[System.ComponentModel.ListSortDirection]::Ascending
			}
		} #this guards from the different types of SortOrder (None, Ascending, Descending) and sets the LastSortDirection accordingly for later use after search results are updated in datagrid


		$output = $this.GetADUsers()

		if (! $output) {
			$this.dataGrid.DataSource = $null
			#[System.Windows.Forms.MessageBox]::Show("No results found.")
			if ($this.labelLeft.Text -eq "Please enter at least one search criteria.") { return } #leave message if no criteria - red (not applicable at now)

			$this.labelLeft.Text = "No results found."
			return #no results, so exit function after updating status label - black
		 #clear grid if no results
		}
		else {
			$this.labelLeft.Text = "$($output.Count) user/object(s) found."
			$this.labelRight.Text = "Last updated: $(Get-Date)"
		}

		#sort output by UserName (samAccountName)
		#$output = $output |Sort-Object UserName
		# now we have inital column and sort order in declaring, so we don't need to sort the output here

		$table = [System.Data.DataTable]::New()

		foreach ($column in $output[0].PSObject.Properties.Name) {
			[void] $table.Columns.Add($column)
		}

		#datatable filling rows
		foreach ($item in $output) {
			$row = $table.NewRow()
			foreach ($property in $table.columns.columnName) {
				$row.$property = $item.$property
			}
			[void] $table.Rows.Add($row)
		}
		
		#datagrid datasource is table
		$this.DataGrid.DataSource = $table

		$this.dataGrid.Sort(
			$this.dataGrid.Columns[$this.LastSortColumn],
			$this.LastSortDirection
		)


	} # SearchClick function


	[void] ClearClick() {
		$this.labelSave.Text = ""
		foreach ($label in $this.labels) {
			$this.textBoxes[$label].Text = ''
		}
		$this.dataGrid.DataSource = $null
		$this.labelLeft.ForeColor = [System.Drawing.Color]::Black
		$this.labelLeft.Text = "Ready"
	}

	#use with caution
	[bool] IsCurrentUserDomainAdmin() {

		$userSam = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name.Split('\')[-1]

		$searcher = [System.DirectoryServices.DirectorySearcher]::new()
		$searcher.Filter = "(&(objectCategory=person)(objectClass=user)(sAMAccountName=$userSam))"

		$result = $searcher.FindOne()

		$isDomainAdmin = $false

		foreach ($group in $result.Properties.memberof) {
			if ($group -like "CN=Domain Admins,*") {
				$isDomainAdmin = $true
				break
			}
		}

		return $isDomainAdmin
	}


	[void] MakeEmailColumnHyperlink() {
		$columnName = "E-Mail"

		if (-not $this.dataGrid.Columns.Contains($columnName)) {
			return
		}

		$oldColumn = $this.dataGrid.Columns[$columnName]
		$index = $oldColumn.Index

		$linkColumn = [System.Windows.Forms.DataGridViewLinkColumn]::new()

		$linkColumn.Name = $oldColumn.Name
		$linkColumn.HeaderText = $oldColumn.HeaderText
		$linkColumn.DataPropertyName = $oldColumn.DataPropertyName
		$linkColumn.TrackVisitedState = $false
		$linkColumn.UseColumnTextForLinkValue = $false

		$this.dataGrid.Columns.Remove($oldColumn)
		$this.dataGrid.Columns.Insert($index, $linkColumn)
	}


	[void] DataGrid_DataBindingComplete(
		[object] $sender,
		[System.Windows.Forms.DataGridViewBindingCompleteEventArgs] $e
	) {
		$this.MakeEmailColumnHyperlink()
	}


	[void] DataGrid_CellContentClick(
		[object] $sender,
		[System.Windows.Forms.DataGridViewCellEventArgs] $e
	) {
		if ($e.RowIndex -lt 0 -or $e.ColumnIndex -lt 0) {
			return
		}

		$grid = [System.Windows.Forms.DataGridView]$sender
		$columnName = $grid.Columns[$e.ColumnIndex].Name

		if ($columnName -ne "E-Mail") {
			return
		}

		$email = [string]$grid.Rows[$e.RowIndex].Cells[$e.ColumnIndex].Value

		if ([string]::IsNullOrWhiteSpace($email)) {
			return
		}

		[System.Diagnostics.Process]::Start("mailto:$email")
	}

	[void] ExportDataGridToCsv() {

		if ($this.dataGrid.Rows.Count -eq 0) {
			$this.labelLeft.Text = "There is no data to export."
			return
		}

		$dialog = [System.Windows.Forms.SaveFileDialog]::New()
		$dialog.Filter = "CSV files (*.csv)|*.csv"
		$dialog.Title = "Export results to CSV"
		$dialog.FileName = "ADSearchResults.csv"

		if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
			return
		}

		$lines = New-Object System.Collections.Generic.List[string]

		# Headers
		$headers = foreach ($col in $this.dataGrid.Columns) {
			if ($col.Visible) {
				'"' + ($col.HeaderText -replace '"', '""') + '"'
			}
		}

		$lines.Add(($headers -join ';'))

		# Rows
		foreach ($row in $this.dataGrid.Rows) {

			if ($row.IsNewRow) {
				continue
			}

			$values = foreach ($col in $this.dataGrid.Columns) {

				if ($col.Visible) {

					$value = $row.Cells[$col.Index].Value

					if ($null -eq $value) {
						$value = ""
					}

					'"' + ([string]$value -replace '"', '""') + '"'
				}
			}

			$lines.Add(($values -join ';'))
		}

		[System.IO.File]::WriteAllLines(
			$dialog.FileName,
			$lines,
			[System.Text.Encoding]::UTF8
		)

		$this.labelSave.Text = "Exported to: $($dialog.FileName)"
	}


} #ADSearchForm class
