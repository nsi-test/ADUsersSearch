Class ADSearchForm : System.Windows.Forms.Form {

	[System.Object[]] $labels

	[Hashtable] $textBoxes

	[System.Windows.Forms.Button] $btnSearch

	[System.Windows.Forms.Button] $btnClear

	[System.Windows.Forms.DataGridView] $dataGrid

	[System.Windows.Forms.StatusStrip] $statusStrip

	[System.Windows.Forms.ToolStripStatusLabel] $labelLeft

	[System.Windows.Forms.ToolStripStatusLabel] $labelRight

	[System.Windows.Forms.CheckBox] $HideDisabledChBox #for allow/disallow disabled users in search results

	[System.Drawing.Font] $strikeFont

	ADSearchForm() {

		$thisForm = $this #for event handlers

		#icon
		$this.Icon = $this.LoadIcon({GetIconB64})
		#/icon

		$this.Text = "Active Directory Users Search v$global:ADUSVersion"
		$this.Text += " (running as: $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name))"
		$this.Size = [System.Drawing.Size]::New(1000,620) #plus e-mail tbox (20) ; W beshe 940
		$this.StartPosition = "CenterScreen"

		$panelTop = [System.Windows.Forms.Panel]::New()
		$panelTop.Dock = [System.Windows.Forms.DockStyle]::Top
		$panelTop.Height = 230 #tested

		# --- Labels and TextBoxes ---
		$this.labels = @("First Name", "Last Name", "Description", "Office", "Phone", "E-mail", "UserName")
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
		$phoneDescriptionLabel.Text = "Phone (use * as wildcard, ? as single character):"
		$phoneDescriptionLabel.Location = [System.Drawing.Point]::new(375, 145)
		$phoneDescriptionLabel.AutoSize = $true
		$panelTop.Controls.Add($phoneDescriptionLabel)

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

		# --- DataGridView ---
		$this.dataGrid = [System.Windows.Forms.DataGridView]::New()
		$this.dataGrid.Dock = [System.Windows.Forms.DockStyle]::Fill
		$this.dataGrid.Location = [System.Drawing.Point]::new(10, 240) #plus e-mail tbox
		$this.dataGrid.Size = [System.Drawing.Size]::New(900, 320)
		$this.dataGrid.AutoSizeColumnsMode = 'Fill'
		$this.Controls.Add($this.dataGrid)

		$this.Controls.Add($panelTop) # Then Top panel with  after DataGrid to be on top

		# --- StatusStrip (bottom band) ---
		$this.statusStrip = [System.Windows.Forms.StatusStrip]::new()
		$this.statusStrip.Dock = [System.Windows.Forms.DockStyle]::Bottom
		
		# --- Status label ---
		$this.labelLeft = [System.Windows.Forms.ToolStripStatusLabel]::new()
		$this.labelLeft.Text = "Ready"

		# Optional: make it expand to fill space
		$this.labelLeft.Spring = $true
		$this.labelLeft.TextAlign = 'MiddleLeft'

		$this.labelRight = [System.Windows.Forms.ToolStripStatusLabel]::new()
		$this.labelRight.Text = "Last updated: $(Get-Date)"
		# Add label to strip
		$this.statusStrip.Items.Add($this.labelLeft)
		$this.statusStrip.Items.Add($this.labelRight)

	  #add statusstrip to form (ORDER MATTERS)
		$this.Controls.Add($this.statusStrip)   # Bottom

		# Strikeout font for disabled users
		$this.strikeFont = [System.Drawing.Font]::New($this.Font, [System.Drawing.FontStyle]::Strikeout)


		$this.AcceptButton = $this.btnSearch
		
		$this.CancelButton = $this.btnClear

		$this.btnSearch.Add_Click({$thisForm.SearchClick()}.getNewClosure())

		$this.btnClear.Add_Click({$thisForm.ClearClick()}.getNewClosure())

		$this.dataGrid.Add_CellFormatting({$thisForm.CellFormattingChanged($thisForm.DataGrid, $_)}.GetNewClosure())

		$this.HideDisabledChBox = [System.Windows.Forms.CheckBox]::New()
		$this.HideDisabledChBox.Text = "Hide disabled users"
		$this.HideDisabledChBox.Location = [System.Drawing.Point]::new(400, 100)
		$this.HideDisabledChBox.AutoSize = $true
		$panelTop.Controls.Add($this.HideDisabledChBox)
		$this.HideDisabledChBox.Add_CheckedChanged({$thisForm.HideDisabledChBoxChanged($thisForm.HideDisabledChBox, $_)}.GetNewClosure())


		$this.Add_Shown({$thisForm.textBoxes["First Name"].Focus()}.GetNewClosure())

	} #constructor

		#returns the icon from the icon func, imported from IconB64.psm1 along other modules
		[System.Drawing.Icon] LoadIcon($GetB64) {
			Write-Verbose "$(date) LoadIcon function started"
			#Write-Verbose $(&$GetB64) #an old check
			return [System.Drawing.Icon][IO.MemoryStream][Convert]::FromBase64String($(&$GetB64))
		}


		[void] CellFormattingChanged(
			[object] $sender,
		 	[System.Windows.Forms.DataGridViewCellFormattingEventArgs] $e) {

			$grid = $sender
			$dgvrow = $grid.Rows[$e.RowIndex]

			if ($dgvrow.DataBoundItem -eq $null) {return}

			$dgvitem = $dgvrow.DataBoundItem

			# adjust property name to your data
			if ($dgvitem.Enabled -eq $false) {
				# Skip the "Enabled" column
				$colName = $grid.Columns[$e.ColumnIndex].Name
				if ($colName -ne "Enabled") {
					$e.CellStyle.Font = $this.strikeFont
				} #colName -ne Enabled
			} #dgvitem enabled check
		} # CellFormattingChanged function

		[void] HideDisabledChBoxChanged([System.Windows.Forms.CheckBox] $sender, [System.EventArgs] $e) {
			$this.SearchClick() #just re-run search to apply/hide disabled users in results
		}	



	[Object[]] GetADUsers() {
		#
		try {
			# Build dynamic filter (AND logic)
			$filterParts = @()

			if ($this.textBoxes["First Name"].Text) {
				$filterParts += "GivenName -like '*$($this.textBoxes["First Name"].Text)*'"
			}
			if ($this.textBoxes["Last Name"].Text) {
				$filterParts += "Surname -like '*$($this.textBoxes["Last Name"].Text)*'"
			}
			if ($this.textBoxes["Description"].Text) {
				$filterParts += "Description -like '*$($this.textBoxes["Description"].Text)*'"
			}
			if ($this.textBoxes["Office"].Text) {
				$filterParts += "Office -like '*$($this.textBoxes["Office"].Text)*'"
			}
			<#
			if ($this.textBoxes["Phone"].Text) {
				$filterParts += "telephoneNumber -like '*$($this.textBoxes["Phone"].Text)'"
			}
			#>

			if ($this.textBoxes["Phone"].Text) {

				$PhoneSearchStr = "*$($this.textBoxes["Phone"].Text)" #human input for the end of string

				Write-Host "PhoneSearchStr: $($PhoneSearchStr)"

				$PhoneFilterPart = $this.textBoxes["Phone"].Text.Replace('?', '*') #substitute '?' with '*' for filter part, because AD filter does not support '?'

				Write-Host "PhoneFilterPart: $($PhoneFilterPart)"

				$filterParts += "telephoneNumber -like '*$($PhoneFilterPart)*'"
			}
			else {

				$PhoneSearchStr = '*' #everything

				Write-Host "PhoneSearchStr: $($PhoneSearchStr)"

			}


			if ($this.textBoxes["E-mail"].Text) {
				$filterParts += "mail -like '*$($this.textBoxes["E-mail"].Text)*'"
			}
			if ($this.textBoxes["UserName"].Text) {
				$filterParts += "SamAccountName -like '*$($this.textBoxes["UserName"].Text)*'"
			}

			if ($filterParts.Count -eq 0) {
				#[System.Windows.Forms.MessageBox]::Show("Please enter at least one search criteria.")
				$this.labelLeft.ForeColor = [System.Drawing.Color]::Red
				$this.labelLeft.Text = "Please enter at least one search criteria."
				return @()
			}

			$filter = $filterParts -join " -and "
		
			Write-Host "filter is: $($filter)"

			# Query AD
			#$results = Get-ADUser -Filter $filter -Properties GivenName, Surname, Description, telephoneNumber, physicalDeliveryOfficeName, mail, Enabled

			Write-Host "phonesearchstr before query: $($PhoneSearchStr)"

			$results = Get-ADUser -Filter $filter -Properties GivenName, Surname, Description, telephoneNumber, otherTelephone, physicalDeliveryOfficeName, mail, Enabled | 
				Where-Object {
					$_.telephoneNumber -like $PhoneSearchStr -and (-not $this.HideDisabledChBox.Checked -or $_.Enabled)
				}

			Write-host "Results:`n$($results | Out-String)"


			# Prepare output

			$output = $results | Select-Object `
			@{Name = "UserName"; Expression = { $_.samAccountName } },
			Enabled,
			GivenName,
			Surname,
			Description,
			@{Name = "Office"; Expression = { $_.physicalDeliveryOfficeName } },
			@{Name = "E-Mail"; Expression = { $_.mail } },
			@{Name = "Phone"; Expression = { $_.telephoneNumber } },
			@{Name = "Phone2"; Expression = { $_.otherTelephone[0] } }

		
			Write-Host "Output: $($output | out-string)"

			Write-Host "phonesearchstr after query: $($PhoneSearchStr)"
			
			return $output

			


		}
		catch {
			[System.Windows.Forms.MessageBox]::Show("Datagrid Error: $_")
			$this.labelLeft.ForeColor = [System.Drawing.Color]::Red
			$this.labelLeft.Text = "Error occurred while searching."
			return @()
		}

		return @() #default empty array if error or no criteria

	} # GetADUsers function



	[void] SearchClick() {
		$this.labelLeft.ForeColor = [System.Drawing.Color]::Black #in the beginning of search, color is always black
		$this.labelLeft.Text = "working..."
		#start-sleep -seconds 5 #simulate work to check status label color

		$output = $this.GetADUsers()

		if (! $output) {
			$this.dataGrid.DataSource = $null
			#[System.Windows.Forms.MessageBox]::Show("No results found.")
			if ($this.labelLeft.Text -eq "Please enter at least one search criteria.") { return } #leave message if no criteria - red

			$this.labelLeft.Text = "No results found."
			return #no results, so exit function after updating status label - black
		 #clear grid if no results
		} else {
			$this.labelLeft.Text = "$($output.Count) user(s) found."
		}

		#sort output by UserName (samAccountName)
		$output = $output |Sort-Object UserName

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


	} # SearchClick function


	[void] ClearClick() {
		foreach ($label in $this.labels) {
			$this.textBoxes[$label].Text = ''
		}
		$this.dataGrid.DataSource = $null
		$this.labelLeft.ForeColor = [System.Drawing.Color]::Black
		$this.labelLeft.Text = "Ready"
	}

} #ADSearchForm class

