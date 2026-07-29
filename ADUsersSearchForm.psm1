Class ADSearchForm : System.Windows.Forms.Form {

	[System.Object[]] $labels

	[Hashtable] $textBoxes

	[System.Windows.Forms.Button] $SearchButton

	[System.Windows.Forms.Button] $ClearButton

	[System.Windows.Forms.Button] $ExportButton

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

	[string] $languageCode

	#help lnk
	[System.Windows.Forms.LinkLabel] $HelpLink

	[string] $HelpFilePath

	#lang
	[string] $CurrentLanguage = "en"
	[string] $LanguagesDirectory
	[string] $HelpDirectory

	[hashtable] $Translations
	[hashtable] $LanguageFiles

	[System.Windows.Forms.LinkLabel] $LanguageLink
	[System.Windows.Forms.ContextMenuStrip] $LanguageMenu
	
	[hashtable] $fieldLabels
	
	[System.Windows.Forms.Label] $phoneDescriptionLabel

	[System.Windows.Forms.Label] $phone2DescriptionLabel
	
	#dynamic statuses
	[string] $CurrentStatusKey = "StatusReady"
	[object[]] $CurrentStatusArguments = @()
	
	[string] $CurrentSaveStatusKey = ""
	[object[]] $CurrentSaveStatusArguments = @()
	
	[string] $CurrentRightStatusKey = ""
	[datetime] $ResultsTimestamp = $(Get-Date)

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
		
		#admin check
		$this.UserIsDomainAdmin = $false
		$this.UserisDomainAdmin = $this.IsCurrentUserDomainAdmin()
		Write-Host "current user domainadmin is: $($this.UserIsDomainAdmin) `r`n"

		$panelTop = [System.Windows.Forms.Panel]::New()
		$panelTop.Dock = [System.Windows.Forms.DockStyle]::Top
		$panelTop.Height = 320 #tested (after memcer of groups); phone 2 (+30); dname (+40)

		# --- Labels and TextBoxes ---
		$this.labels = @("First Name", "Last Name", "Display Name", "Description", "Office", "Phone", "Phone2", "E-mail", "UserName", "Contained in/under OU")
		$this.textBoxes = @{}
		#lang
		$this.fieldLabels = @{}

		for ($i = 0; $i -lt $this.labels.Count; $i++) {
			$label = [System.Windows.Forms.Label]::New()
			$this.fieldLabels[$this.labels[$i]] = $label
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

		$this.phoneDescriptionLabel = [System.Windows.Forms.Label]::New()
		$this.phoneDescriptionLabel.Text = "Phone (use * as wildcard, ? as single character)"
		$this.phoneDescriptionLabel.Location = [System.Drawing.Point]::new(375, 175) #plus dname - +H30
		$this.phoneDescriptionLabel.AutoSize = $true
		$panelTop.Controls.Add($this.phoneDescriptionLabel)

		$this.phone2DescriptionLabel = [System.Windows.Forms.Label]::New()
		$this.phone2DescriptionLabel.Text = "Phone2 (use * as wildcard, ? as single character)"
		$this.phone2DescriptionLabel.Location = [System.Drawing.Point]::new(375, 205) #plus dname - +H30
		$this.phone2DescriptionLabel.AutoSize = $true
		$panelTop.Controls.Add($this.phone2DescriptionLabel)

		# --- Search Button ---
		$this.SearchButton = [System.Windows.Forms.Button]::New()
		$this.SearchButton.Text = "Search"
		$this.SearchButton.Location = [System.Drawing.Point]::new(400, 20)
		$this.SearchButton.Width = 100
		#$this.Controls.Add($this.SearchButton)
		$panelTop.Controls.Add($this.SearchButton)

		# --- Clear Button --- #m
		$this.ClearButton = [System.Windows.Forms.Button]::New()
		$this.ClearButton.Text = "Clear"
		$this.ClearButton.Location = [System.Drawing.Point]::new(400, 60)
		$this.ClearButton.Width = 100
		#$this.Controls.Add($this.ClearButton)
		$panelTop.Controls.Add($this.ClearButton)

		# --- Export Button ---
		$this.ExportButton = [System.Windows.Forms.Button]::New()
		$this.ExportButton.Text = "Export CSV"
		$this.ExportButton.Location = [System.Drawing.Point]::new(650, 10)
		$this.ExportButton.Width = 100
		$panelTop.Controls.Add($this.ExportButton)

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
		$this.IncludeMailObjectsChBox.Location = [System.Drawing.Point]::new(650, 100) #I was 550, now 650 because of languages
		$this.IncludeMailObjectsChBox.Checked = $false
		$this.IncludeMailObjectsChBox.AutoSize = $true
		$panelTop.Controls.Add($this.IncludeMailObjectsChBox)

		$this.IncludeMailObjectsChBox.Add_CheckedChanged({ $thisForm.IncludeMailObjectsChBoxChanged($thisForm.IncludeMailObjectsChBox, $_) }.GetNewClosure()) #mind it to change

		# --- Help link ---
		$this.HelpLink = [System.Windows.Forms.LinkLabel]::new()
		$this.HelpLink.Text = "Help"
		$this.HelpLink.AutoSize = $true
		$this.HelpLink.LinkBehavior = [System.Windows.Forms.LinkBehavior]::HoverUnderline
		$this.HelpLink.Cursor = [System.Windows.Forms.Cursors]::Hand
		$this.HelpLink.Anchor =
    		[System.Windows.Forms.AnchorStyles]::Top -bor
    		[System.Windows.Forms.AnchorStyles]::Right
		$panelTop.Controls.Add($this.HelpLink)
		$this.HelpLink.Left =
    		$panelTop.ClientSize.Width - $this.HelpLink.Width - 20 #it was 10 but 20 for Bulgarian width
		$this.HelpLink.Top = 10

		

		# --- Language link ---
		$this.LanguageLink =
    		[System.Windows.Forms.LinkLabel]::new()

		$this.LanguageLink.Text = "Language"
		$this.LanguageLink.AutoSize = $true
		$this.LanguageLink.Cursor =
    		[System.Windows.Forms.Cursors]::Hand

		$this.LanguageLink.LinkBehavior =
    		[System.Windows.Forms.LinkBehavior]::HoverUnderline

		$this.LanguageLink.Anchor =
    		[System.Windows.Forms.AnchorStyles]::Top -bor
    		[System.Windows.Forms.AnchorStyles]::Right
			$panelTop.Controls.Add($this.LanguageLink)

		#Language menu
		$this.LanguageMenu =
    		[System.Windows.Forms.ContextMenuStrip]::new()

		$this.LanguageLink.ContextMenuStrip =
    		$this.LanguageMenu

		$this.LanguageLink.Add_LinkClicked({
    		$location = [System.Drawing.Point]::new(
				0,
				$thisForm.LanguageLink.Height
    		)

			$thisForm.LanguageMenu.Show(
				$thisForm.LanguageLink,
				$location
			)
		}.GetNewClosure())




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


		$this.AcceptButton = $this.SearchButton
		
		$this.CancelButton = $this.ClearButton

		$this.SearchButton.Add_Click({ $thisForm.SearchClick() }.getNewClosure())

		$this.ClearButton.Add_Click({ $thisForm.ClearClick() }.getNewClosure())

		$this.ExportButton.Add_Click({$thisForm.ExportDataGridToCsv()}.GetNewClosure())

		$this.dataGrid.Add_CellFormatting({ $thisForm.CellFormattingChanged($thisForm.DataGrid, $_) }.GetNewClosure())




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

		#WARNING
		#help lnk
		if ($PSScriptRoot) {
			$applicationDirectory = $PSScriptRoot
		}
		else {
			$applicationDirectory =
				[System.IO.Path]::GetDirectoryName(
					[System.Windows.Forms.Application]::ExecutablePath
				)
		}

		write-host "in constructor, after definning apdir, applicationDirectory is $($applicationDirectory)"


		$this.HelpLink.Add_LinkClicked({
    		$thisForm.ShowHelp()
		}.GetNewClosure())


		$this.LanguagesDirectory =
			[System.IO.Path]::Combine($applicationDirectory, "Languages")

		Write-host "in condtructor, this.LanguagesDirectory is: $($this.LanguagesDirectory)"



		$this.LoadAvailableLanguages()
		if (-not $this.LanguageFiles.ContainsKey($this.languageCode)) {
    		$this.languageCode = "en"
		}
		$this.LoadLanguage($this.LanguageFiles[$this.languageCode])
		
		#$this.HelpFilePath = [System.IO.Path]::Combine($applicationDirectory, "Help_en.txt")
		#$this.HelpFilePath = Join-Path $applicationDirectory "Help_en.txt"
		#$this.HelpFilePath = Join-Path $applicationDirectory "Help_en.rtf"
		$this.HelpDirectory = [System.IO.Path]::Combine($applicationDirectory, "Help")
		$this.helpFilePath = $this.GetHelpFilePath()
		write-host "in the constructor , this.helpFilePath is: $($this.helpFilePath)"
		
		#just the first time
		#$this.labelLeft.Text = $this.T("StatusReady")
		$this.SetStatus("StatusReady")
		
		$this.setRightstatus("StatusLastUpdate", $(Get-Date))

	} #constructor

	#returns the icon from the icon func, imported from IconB64.psm1 along other modules
	[System.Drawing.Icon] LoadIcon($GetB64) {
		Write-Verbose "$(date) LoadIcon function started"
		#Write-Verbose $(&$GetB64) #an old check
		return [System.Drawing.Icon][IO.MemoryStream][Convert]::FromBase64String($(&$GetB64))
	} #LoadIcon

	[void] LoadConfiguration([string] $ConfigFile) {
		[xml]$Config = Get-Content $ConfigFile

		$this.DomainSearchBase =
			$Config.Configuration.DomainSearchBases.Root.distinguishedName

		$this.AllowedSearchBases = @()

		foreach ($OU in $Config.Configuration.DomainSearchBases.OU) {
			$this.AllowedSearchBases += $OU.distinguishedName
		}

		$this.languageCode =
			[string]$config.Configuration.Interface.Language.code

	} #LoadConfiguration


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
			#$this.labelLeft.Text = "Error occurred while searching."
			$this.SetStatus("StatusSearchingError")
			return @()
		}

		return @() #default empty array if error or no criteria

	} # GetADUsers function



	[void] SearchClick() {
		#$this.labelSave.Text = ""
		$this.SetSaveStatus("")
		$this.labelLeft.ForeColor = [System.Drawing.Color]::Black #in the beginning of search, color is always black
		#$this.labelLeft.Text = "working..."
		#$this.labelLeft.Text = $this.T("StatusWorking")
		$this.SetStatus("StatusWorking")
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

			#$this.labelLeft.Text = "No results found."
			$this.SetStatus("StatusNotFound")
			return #no results, so exit function after updating status label - black
		 #clear grid if no results
		}
		else {
			#$this.labelLeft.Text = "$($output.Count) user/object(s) found."
			#$this.labelLeft.Text = [string]::Format(
    		#	$this.T("StatusFound"),
    		#	$output.Count
			#)
			$this.SetStatus(
				"StatusFound",
				@($output.Count)
			)

			#$this.labelRight.Text = "Last updated: $(Get-Date)"
			$this.SetRightStatus("StatusLastUpdate", $(Get-Date))
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
		
		#translate columns here, because they already exist
		$this.TranslateDataGridColumns()

		$this.dataGrid.Sort(
			$this.dataGrid.Columns[$this.LastSortColumn],
			$this.LastSortDirection
		)


	} # SearchClick function


	[void] ClearClick() {
		#$this.labelSave.Text = ""
		$this.SetSaveStatus("")
		foreach ($label in $this.labels) {
			$this.textBoxes[$label].Text = ''
		}
		$this.dataGrid.DataSource = $null
		$this.labelLeft.ForeColor = [System.Drawing.Color]::Black
		#$this.labelLeft.Text = "Ready"
		#$this.labelLeft.Text = $this.T("StatusReady")
		$this.SetStatus("StatusReady")
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

		# Avoid replacing it repeatedly after every binding event.
		if ($this.dataGrid.Columns[$columnName] -is
    		[System.Windows.Forms.DataGridViewLinkColumn]) {
        	return
    	}

		$oldColumn = $this.dataGrid.Columns[$columnName]
		$oldIndex = $oldColumn.Index

		$linkColumn = [System.Windows.Forms.DataGridViewLinkColumn]::new()

		$linkColumn.Name = $oldColumn.Name
		$linkColumn.HeaderText = $oldColumn.HeaderText
		$linkColumn.DataPropertyName = $oldColumn.DataPropertyName		
		$linkColumn.DisplayIndex     = $oldColumn.DisplayIndex
    	$linkColumn.Visible          = $oldColumn.Visible
    	$linkColumn.Width            = $oldColumn.Width
    	$linkColumn.AutoSizeMode     = $oldColumn.AutoSizeMode

		$linkColumn.UseColumnTextForLinkValue = $false
		$linkColumn.TrackVisitedState = $false

		# This enables clicking the header to sort.
    	$linkColumn.SortMode =
        	[System.Windows.Forms.DataGridViewColumnSortMode]::Automatic

		$this.dataGrid.Columns.Remove($oldColumn)
		$this.dataGrid.Columns.Insert($oldIndex, $linkColumn)
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
			#$this.labelLeft.Text = "There is no data to export."
			$this.SetSaveStatus("StatusNothingToExport")
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

		#$this.labelSave.Text = "Exported to: $($dialog.FileName)"

		#$this.labelSave.Text = [string]::Format(
    	#	$this.T("StatusExported"),
    	#	$dialog.FileName
		#)
		$this.SetSaveStatus(
			"StatusExported",
			@($dialog.FileName)
		)

	} #ExportDataGridToCsv()

	#help lnk
	[void] ShowHelp() {

		if (-not [System.IO.File]::Exists($this.HelpFilePath)) {
			[System.Windows.Forms.MessageBox]::Show(
				"The help file was not found:`n$($this.HelpFilePath)",
				"Help",
				[System.Windows.Forms.MessageBoxButtons]::OK,
				[System.Windows.Forms.MessageBoxIcon]::Warning
			)

			return
		}

		try {
			$helpText = [System.IO.File]::ReadAllText(
				$this.HelpFilePath,
				[System.Text.Encoding]::UTF8
			)
		}
		catch {
			[System.Windows.Forms.MessageBox]::Show(
				"The help file could not be read:`n$($_.Exception.Message)",
				"Help",
				[System.Windows.Forms.MessageBoxButtons]::OK,
				[System.Windows.Forms.MessageBoxIcon]::Error
			)

			return
		}

		$helpForm = [System.Windows.Forms.Form]::new()
		#$helpForm.Text = "AD User Search Help"
		$helpForm.Text = $this.T("HelpTitle")
		$helpForm.StartPosition =
			[System.Windows.Forms.FormStartPosition]::CenterParent

		$helpForm.Size =
			[System.Drawing.Size]::new(700, 550)

		$helpForm.MinimumSize =
			[System.Drawing.Size]::new(450, 350)

		#$helpTextBox = [System.Windows.Forms.TextBox]::new()
		$helpTextBox = [System.Windows.Forms.RichTextBox]::new()

		$helpTextBox.Multiline = $true
		$helpTextBox.ReadOnly = $true
		$helpTextBox.BorderStyle = [System.Windows.Forms.BorderStyle]::None
		$helpTextBox.ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical
		$helpTextBox.WordWrap = $true
		$helpTextBox.Dock = [System.Windows.Forms.DockStyle]::Fill

		#$helpTextBox.Text = $helpText
		$helpTextBox.Rtf = $helpText
		$helpTextBox.BackColor = [System.Drawing.SystemColors]::Window

		$closeButton =
			[System.Windows.Forms.Button]::new()

		#$closeButton.Text = "Close"
		$closeButton.Text = $this.T("CloseButton")
		$closeButton.Dock =
			[System.Windows.Forms.DockStyle]::Bottom

		$closeButton.Height = 35
		$closeButton.DialogResult =
			[System.Windows.Forms.DialogResult]::OK

		$helpForm.AcceptButton = $closeButton
		$helpForm.CancelButton = $closeButton

		$helpForm.Controls.Add($helpTextBox)
		$helpForm.Controls.Add($closeButton)

		$helpForm.Add_Shown({$closeButton.Focus()})

		[void]$helpForm.ShowDialog($this)

		$helpForm.Dispose()
	} #ShowHelp

	[void] LoadLanguage([string] $languageFile) {

		Write-Host "in LoadLanguage languageFile is: $($languageFile)"

		if (-not [System.IO.File]::Exists($languageFile)) {
			throw "Language file not found: $languageFile"
		}

		[xml]$xml =
			[System.IO.File]::ReadAllText(
				$languageFile,
				[System.Text.Encoding]::UTF8
			)

		$translationsloc = @{}

		foreach ($entry in $xml.Language.Text) {
			$translationsloc[[string]$entry.key] = [string]$entry.InnerText
		}

		$this.Translations = $translationsloc
		$this.CurrentLanguage = [string]$xml.Language.code

		$this.ApplyLanguage()
		
		
	} # LoadLanguage

	[string] T([string] $key) {

		if ($this.Translations.ContainsKey($key)) {
			return [string]$this.Translations[$key]
		}

		return "[$key]"
	} # T helper

	[void] ApplyLanguage() {

		#$this.Text = $this.T("FormTitle")
		$this.Text = [string]::Format(
			$this.T("FormTitle"), @($global:ADUSVersion, 
			$([System.Security.Principal.WindowsIdentity]::GetCurrent().Name))
		)

		$this.fieldLabels["First Name"].Text =
			$this.T("FirstName")

		$this.fieldLabels["Last Name"].Text =
			$this.T("LastName")
			
		$this.fieldLabels["Display Name"].Text =
			$this.T("DisplayName")

		$this.fieldLabels["Description"].Text =
			$this.T("Description")

		$this.fieldLabels["Office"].Text =
			$this.T("Office")

		$this.fieldLabels["Phone"].Text =
			$this.T("Phone")

		$this.fieldLabels["Phone2"].Text =
			$this.T("Phone2")

		$this.fieldLabels["E-mail"].Text =
			$this.T("Email")

		$this.fieldLabels["UserName"].Text =
			$this.T("UserName")

		$this.fieldLabels["Contained in/under OU"].Text =
			$this.T("ContainedInOU")
			
		$this.phoneDescriptionLabel.Text = 
			$this.T("PhoneSearchDescription")
			
		$this.phone2DescriptionLabel.Text = 
			$this.T("Phone2SearchDescription")

		$this.SearchButton.Text =
			$this.T("SearchButton")

		$this.ClearButton.Text =
			$this.T("ClearButton")

		$this.ExportButton.Text =
			$this.T("ExportButton")

		$this.HideDisabledChBox.Text =
			$this.T("HideDisabled")

		$this.IncludeMailObjectsChBox.Text =
			$this.T("IncludeMailObjects")

		$this.LanguageLink.Text =
			$this.T("Language")

		$this.HelpLink.Text =
			$this.T("Help")

		#if lnguage is changed when dgrid is full
		if ($this.dataGrid.Columns.Count -gt 0) {
			$this.TranslateDataGridColumns()
		}
		
		# Redisplay the existing status in the new language.
		$this.RefreshStatus()
		$this.RefreshSaveStatus()
		$this.RefreshRightStatus()

		#if it is changed
		$this.helpFilePath = $this.GetHelpFilePath()

		$this.PerformLayout()
	} #ApplyLanguage

	[void] TranslateDataGridColumns() {

		$columnTranslations = @{
			"UserName"    = "ColumnUserName"
			"Display Name"= "ColumnDisplayName"
			"ObjectClass" = "ColumnObjectClass"
			"Enabled"     = "ColumnEnabled"
			"GivenName"   = "ColumnGivenName"
			"Surname"     = "ColumnSurname"
			"Job Title"   = "ColumnJobTitle"
			"Description" = "ColumnDescription"
			"Office"      = "ColumnOffice"
			"E-Mail"      = "ColumnEmail"
			"Phone"       = "ColumnPhone"
			"Phone2"      = "ColumnPhone2"
			"Org. Unit"   = "ColumnOU"
		}

		foreach ($columnName in $columnTranslations.Keys) {
			Write-host "In TranslateDataGridColumns() columnName is: $($columnName)"
			if (! $this.dataGrid) {Write-Host "In TranslateDataGridColumns() data grid is not present!"}

			if ($this.dataGrid.Columns.Contains($columnName)) {
				write-host "In TranslateDataGridColumns, contained columnName is : $($columnName)"
				$this.dataGrid.Columns[$columnName].HeaderText =
					$this.T($columnTranslations[$columnName])
			}$columnName
		}
	} #TranslateDataGridColumns

	[void] AddLanguageMenuItem(
		[string] $languageName,
		[string] $languageCode,
		[string] $languageFile
	) {
		$item =
			[System.Windows.Forms.ToolStripMenuItem]::new()

		$item.Text = $languageName
		$item.Tag = $languageCode

		$form = $this
		$file = $languageFile

		$item.Add_Click({
				$form.LoadLanguage($file)
		}.GetNewClosure())

		[void]$this.LanguageMenu.Items.Add($item)
	} #AddLanguageMenuItem

	[void] LoadAvailableLanguages() {

		$this.LanguageMenu.Items.Clear()
		$this.LanguageFiles = @{}

		Write-host "in LoadAvailableLanguages, this.LanguagesDirectory is: $($this.LanguagesDirectory)"

		foreach (
			$file in Get-ChildItem `
				-Path $this.LanguagesDirectory `
				-Filter "*.xml" `
				-File
		) {
			try {
				write-host "in LoadAvailable Languages: any file is: $($file)"
				[xml]$xml =
				[System.IO.File]::ReadAllText(
					$file.FullName,
					[System.Text.Encoding]::UTF8
				)

				$code = [string]$xml.Language.code
				$name = [string]$xml.Language.name

				if ([string]::IsNullOrWhiteSpace($code) -or
					[string]::IsNullOrWhiteSpace($name)) {
					continue
				}

				$this.LanguageFiles[$code] = $file.FullName

				$this.AddLanguageMenuItem(
					$name,
					$code,
					$file.FullName
				)
			}
			catch {
				Write-Warning "Invalid language file: $($file.FullName)"
				Write-host "exception is: $_.Exception"
			}
		}


	} #LoadAvailableLanguages
	
	[string] GetHelpFilePath() {

		return [System.IO.Path]::Combine(
			$this.HelpDirectory,
			"help_$($this.CurrentLanguage).rtf"
		)
	} #
	
	#dynamic statuses
	[void] SetStatus(
		[string] $statusKey,
		[object[]] $arguments
	) {
		$this.CurrentStatusKey = $statusKey
		$this.CurrentStatusArguments = $arguments

		$this.RefreshStatus()
	} # SetStatus
	
	[void] SetStatus([string] $statusKey) {
		$this.SetStatus($statusKey, @())
	} # SetStatus overload
	
	[void] RefreshStatus() {

		if ([string]::IsNullOrWhiteSpace($this.CurrentStatusKey)) {
			$this.labelLeft.Text = ""
			return
		}

		$translatedText = $this.T($this.CurrentStatusKey)

		if ($this.CurrentStatusArguments.Count -gt 0) {
			$this.labelLeft.Text = [string]::Format(
				$translatedText,
				$this.CurrentStatusArguments
			)
		}
		else {
			$this.labelLeft.Text = $translatedText
		}
	} # RefreshStatus

	[void] SetSaveStatus(
		[string] $statusKey,
		[object[]] $arguments
	) {
		$this.CurrentSaveStatusKey = $statusKey
		$this.CurrentSaveStatusArguments = $arguments

		$this.RefreshSaveStatus()
	} # SetSaveStatus
	
	[void] SetSaveStatus([string] $statusKey) {
		$this.SetSaveStatus($statusKey, @())
	} # SetSaveStatus overload
	
	[void] RefreshSaveStatus() {

		if ([string]::IsNullOrWhiteSpace($this.CurrentSaveStatusKey)) {
			$this.labelSave.Text = ""
			return
		}

		$translatedText = $this.T($this.CurrentSaveStatusKey)

		if ($this.CurrentSaveStatusArguments.Count -gt 0) {
			$this.labelSave.Text = [string]::Format(
				$translatedText,
				$this.CurrentSaveStatusArguments
			)
		}
		else {
			$this.labelSave.Text = $translatedText
		}
	} # RefreshSaveStatus	

	[void] SetRightStatus(
		[string] $statusKey,
		[datetime] $argument
	) {
		$this.CurrentRightStatusKey = $statusKey
		$this.ResultsTimestamp = $argument

		write-host "In setRightstatus,  CurrentRightStatusKey is: $($this.CurrentRightStatusKey),ResultsTimestamp is $($this.ResultsTimestamp)"

		$this.RefreshRightStatus()
	} # SetRightStatus
	
	[void] RefreshRightStatus() {

		if ([string]::IsNullOrWhiteSpace($this.CurrentRightStatusKey)) {
			$this.labelRight.Text = ""
			return
		}

		$translatedText = $this.T($this.CurrentRightStatusKey)
		
		write-host "in refreshrightstatus, trabslatedtext is: $($translatedText)"

		if ($this.ResultsTimestamp) {
			$this.labelRight.Text = [string]::Format(
				$translatedText,
				$this.ResultsTimestamp.ToString("G")
			)
		}
		else {
			$this.labelRight.Text = $translatedText
		}
	} # RefreshRightStatus		
	

} #ADSearchForm class
